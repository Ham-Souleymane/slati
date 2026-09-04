import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/google_places_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../data/mosque_repository.dart';
import '../domain/mosque_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add Mosque Screen
// ─────────────────────────────────────────────────────────────────────────────

class AddMosqueScreen extends ConsumerStatefulWidget {
  const AddMosqueScreen({super.key});

  @override
  ConsumerState<AddMosqueScreen> createState() => _AddMosqueScreenState();
}

class _AddMosqueScreenState extends ConsumerState<AddMosqueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final MapController _mapController = MapController();
  final GooglePlacesService _placesService = GooglePlacesService();

  LatLng _selectedLocation = const LatLng(24.7136, 46.6753);
  bool _isLocating = false;
  bool _isSubmitting = false;

  // Search state
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  Timer? _debounce;
  String? _selectedAddress;

  // Language
  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initUserLocation());
  }

  void _initUserLocation() {
    final userLoc = ref.read(userLocationProvider);
    if (userLoc != null) {
      setState(() {
        _selectedLocation = LatLng(userLoc.latitude, userLoc.longitude);
      });
      _mapController.move(_selectedLocation, 16.0);
    } else {
      _locateUser();
    }
  }

  Future<void> _locateUser() async {
    setState(() => _isLocating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedLocation = latLng;
        _isLocating = false;
      });
      _mapController.move(latLng, 16.5);
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Address Search ──────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(value));
  }

  Future<void> _fetchSuggestions(String query) async {
    final lang = _isAr ? 'ar' : 'en';
    final suggestions = await _placesService.autocomplete(
      query,
      locationBias: _selectedLocation,
      language: lang,
    );
    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
      _isSearching = false;
      _showSuggestions = true;
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    setState(() {
      _showSuggestions = false;
      _searchController.text = suggestion.mainText;
      _selectedAddress = suggestion.fullText;
      _isSearching = true;
    });

    final lang = _isAr ? 'ar' : 'en';
    final details = await _placesService.getDetails(suggestion.placeId, language: lang);
    if (!mounted) return;
    if (details != null) {
      setState(() {
        _selectedLocation = details.latLng;
        _selectedAddress = details.address;
        _isSearching = false;
      });
      _mapController.move(details.latLng, 17.0);
    } else {
      setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _selectedAddress = null;
    });
  }

  // ── Form Submit ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    final uid = currentUser?.uid;

    String city = _isAr ? 'المدينة' : 'City';
    String country = _isAr ? 'المملكة العربية السعودية' : 'Saudi Arabia';
    String address = _selectedAddress ?? (_isAr ? 'موقع المسجد على الخريطة' : 'Mosque location on map');

    try {
      final geoResult = await GeocodingService().reverseGeocode(_selectedLocation);
      if (geoResult.city != null && geoResult.city!.isNotEmpty) city = geoResult.city!;
      if (geoResult.country != null && geoResult.country!.isNotEmpty) country = geoResult.country!;
      if (_selectedAddress == null && geoResult.address != null && geoResult.address!.isNotEmpty) {
        address = geoResult.address!;
      }
    } catch (_) {}

    final userLoc = ref.read(userLocationProvider);
    final fallbackCity = _isAr ? 'المدينة' : 'City';
    if (city == fallbackCity && userLoc != null && userLoc.name.isNotEmpty) {
      city = userLoc.name;
    }

    final mosque = MosqueModel(
      id: '',
      name: _nameController.text.trim(),
      country: country,
      city: city,
      address: address,
      geopoint: GeoPoint(_selectedLocation.latitude, _selectedLocation.longitude),
      addedByUid: uid,
      verified: true,
      status: 'approved',
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(mosqueRepositoryProvider).addMosque(mosque);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.showSnackBar(context.tr('mosque_add_success'));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/nearby-mosques');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.showSnackBar(e.toString(), isError: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_showSuggestions) setState(() => _showSuggestions = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.emeraldDark,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/nearby-mosques'),
          ),
          title: Text(
            context.tr('add_mosque_title'),
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Form Section ───────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mosque name field
                      Text(
                        context.tr('mosque_name_label'),
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldDark,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return context.tr('mosque_name_req');
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: context.tr('mosque_name_hint'),
                          hintStyle: GoogleFonts.tajawal(fontSize: 14, color: AppColors.grey500),
                          prefixIcon: const Icon(
                            Icons.account_balance_rounded,
                            color: AppColors.emerald,
                            size: 22,
                          ),
                          filled: true,
                          fillColor: AppColors.cream,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.emerald, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Address search field
                      Text(
                        context.tr('mosque_search_address_label'),
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldDark,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      _AddressSearchField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        isSearching: _isSearching,
                        hintText: context.tr('mosque_search_hint'),
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Map & Suggestions Stack ────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: 16.0,
                        onPositionChanged: (pos, hasGesture) {
                          if (hasGesture) {
                            _selectedLocation = pos.center;
                            // Hide suggestions when map is panned
                            if (_showSuggestions) {
                              setState(() => _showSuggestions = false);
                            }
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.slatk.slatkapp',
                        ),
                      ],
                    ),

                    // Fixed center pin
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 36),
                        child: Icon(
                          Icons.location_pin,
                          size: 52,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),

                    // Instruction pill (shown only when no address selected)
                    if (_selectedAddress == null)
                      Positioned(
                        top: 12,
                        left: 20,
                        right: 20,
                        child: _InstructionPill(isAr: _isAr),
                      ),

                    // Selected address pill (shown after search)
                    if (_selectedAddress != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: _SelectedAddressPill(
                          address: _selectedAddress!,
                          onClear: _clearSearch,
                        ),
                      ),

                    // Locate me FAB
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: FloatingActionButton(
                        heroTag: 'add_mosque_locate_me',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.emeraldDark,
                        elevation: 4,
                        onPressed: _isLocating ? null : _locateUser,
                        child: _isLocating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.emerald,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 26),
                      ),
                    ),

                    // Floating Suggestions Overlay on top of Map
                    if (_showSuggestions)
                      Positioned.fill(
                        child: _SuggestionsList(
                          suggestions: _suggestions,
                          isSearching: _isSearching,
                          noResultsText: context.tr('mosque_search_no_results'),
                          searchingText: context.tr('mosque_search_searching'),
                          onSelect: _selectSuggestion,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Submit Button ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      disabledBackgroundColor: AppColors.emerald.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            textDirection: TextDirection.rtl,
                            children: [
                              const Icon(Icons.add_location_alt_rounded, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                context.tr('add_mosque_btn'),
                                style: GoogleFonts.tajawal(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Address Search Field
// ─────────────────────────────────────────────────────────────────────────────

class _AddressSearchField extends StatelessWidget {
  const _AddressSearchField({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textDirection: TextDirection.rtl,
      style: GoogleFonts.tajawal(fontSize: 15, color: AppColors.charcoal),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.tajawal(fontSize: 14, color: AppColors.grey500),
        prefixIcon: isSearching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.emerald,
                  ),
                ),
              )
            : const Icon(Icons.search_rounded, color: AppColors.emerald, size: 22),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: AppColors.grey500, size: 20),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppColors.cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestions List
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({
    required this.suggestions,
    required this.isSearching,
    required this.noResultsText,
    required this.searchingText,
    required this.onSelect,
  });

  final List<PlaceSuggestion> suggestions;
  final bool isSearching;
  final String noResultsText;
  final String searchingText;
  final ValueChanged<PlaceSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: isSearching && suggestions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      searchingText,
                      style: GoogleFonts.tajawal(
                        color: AppColors.grey500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      noResultsText,
                      style: GoogleFonts.tajawal(
                        color: AppColors.grey500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 52,
                  ),
                  itemBuilder: (context, index) {
                    final s = suggestions[index];
                    return InkWell(
                      onTap: () => onSelect(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.emerald,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    s.mainText,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.charcoal,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (s.secondaryText.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      s.secondaryText,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 12,
                                        color: AppColors.grey500,
                                      ),
                                      textDirection: TextDirection.rtl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Instruction Pill (shown when no address selected)
// ─────────────────────────────────────────────────────────────────────────────

class _InstructionPill extends StatelessWidget {
  const _InstructionPill({required this.isAr});
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.emeraldDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            isAr
                ? 'حرّك الخريطة لتحديد موقع المسجد بدقة'
                : 'Drag the map to pinpoint the mosque',
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected Address Pill (shown after address is chosen)
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedAddressPill extends StatelessWidget {
  const _SelectedAddressPill({required this.address, required this.onClear});
  final String address;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address,
              style: GoogleFonts.tajawal(
                fontSize: 12,
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded, color: AppColors.grey500, size: 18),
          ),
        ],
      ),
    );
  }
}
