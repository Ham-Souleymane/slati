import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../mosques/data/mosque_repository.dart';
import '../../mosques/domain/imam_model.dart';
import '../data/question_repository.dart';
import '../domain/islamic_field.dart';

// ── Palette matching the HTML template ────────────────────────────────────────
class _AskColors {
  static const primary = Color(0xFF003527);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFC3ECD7);
  static const onSecondaryContainer = Color(0xFF0B513D);
  static const surface = Color(0xFFF9F9FF);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFE7EEFE);
  static const onSurface = Color(0xFF151C27);
  static const onSurfaceVariant = Color(0xFF404944);
  static const outlineVariant = Color(0xFFBFC9C3);
  static const surfaceVariant = Color(0xFFDCE2F3);
}

class AskSheikhScreen extends ConsumerStatefulWidget {
  const AskSheikhScreen({super.key});

  @override
  ConsumerState<AskSheikhScreen> createState() => _AskSheikhScreenState();
}

class _AskSheikhScreenState extends ConsumerState<AskSheikhScreen> {
  String _selectedCategory = 'all';

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  // Categories list matching the HTML template
  static const _categories = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'aqeedah', 'label': 'العقيدة'},
    {'id': 'fiqh', 'label': 'الفقه'},
    {'id': 'muamalat', 'label': 'المعاملات'},
    {'id': 'history', 'label': 'التاريخ و السير'},
    {'id': 'language', 'label': 'اللغة'},
    {'id': 'hadith', 'label': 'علم الحديث'},
    {'id': 'usul', 'label': 'اصول الفقه'},
    {'id': 'tafsir', 'label': 'التفسير و علومه'},
  ];

  // Default seed scholars shown if Firestore collection has no verified imams yet
  static final List<ImamModel> _defaultScholars = [
    ImamModel(
      id: 'scholar_1',
      fullName: 'د. محمد عبد الله',
      email: 'm.abdullah@slati.org',
      phone: '',
      mosqueId: '',
      status: 'verified',
      commentsNotify: true,
      verificationNotify: true,
      createdAt: DateTime(2025, 1, 1),
      fields: const ['fiqh', 'muamalat'],
      bio: 'أستاذ الفقه و المعاملات',
      photoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBte9BSt9fDqUqPTbcm9eraVKz9De1y7MwMWeiZx89EkLiX1vcUT8v_2pLBON8iTyjNB2SxKJ_yFWBY_DoqV3hP_BwpzaiHw2RD0Dm_c75Uw6PJ4jDryJ1pHmnQzI2tdyiHo4hSjZwyH5DzgqJeR1DkFOx4m03e9miLT5wLaNjXDgISm9ksjm209GqMbx3LVEmDSkJO8fbDY7kYCIc_LSK3TwUtEOAXxlxTGWLi5A57sX9ex-oSU6pWqg',
      answeredCount: 24,
    ),
    ImamModel(
      id: 'scholar_2',
      fullName: 'الشيخ أحمد سعيد',
      email: 'a.saeed@slati.org',
      phone: '',
      mosqueId: '',
      status: 'verified',
      commentsNotify: true,
      verificationNotify: true,
      createdAt: DateTime(2025, 1, 1),
      fields: const ['aqeedah', 'tafsir'],
      bio: 'متخصص في العقيدة والتفسير',
      photoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBpYXIlqr7peU9dQLhDrBJvGgiRxeoExELuNRLZg860ig8mcD2yHaJevVoCprb1Eap-CA1muWhzafVb8AePP-NxpsX1yrH4VxOR75gl6wye1lYyLj6GrfE2qgdzUEXntC74qzDfCvSY9x4qQn-1a1v9VqrCDbpwT4d0EAG7DGKQ7MGXoaY2Kz7da0F8uXUvXZDRoxjhe6CTqcn5eK0SPoQhRvoHCB0lLWyzAfVYonEzOIuZ34V9uRf8Fg',
      answeredCount: 18,
    ),
    ImamModel(
      id: 'scholar_3',
      fullName: 'د. عمر الفاروق',
      email: 'o.farooq@slati.org',
      phone: '',
      mosqueId: '',
      status: 'verified',
      commentsNotify: true,
      verificationNotify: true,
      createdAt: DateTime(2025, 1, 1),
      fields: const ['hadith', 'history'],
      bio: 'أستاذ الحديث والسيرة',
      photoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDZfpZBRWCqbsW-A9ZP_KLwC8zTfJEFanenzv-ENYp4chTD4mWWQGfa8DZ6UPzdcHGOYEtKbaHMdbPU8NgqlE1Iy4yXTWJ7Iv7Vm0c-2uDjD_ccumuqzkA7EsozYnqzDnPRmN0pJV8pQuHJqW9QFcPKddE5RiBmqTx46uOAZdhTv54A3XEAClCt5LIQXR8DLl0QtsJZq_1irCVZhI7Mm-c5Xaa0Ve1tN_Z1KZ1YI6aol5cmSuSspBsmNw',
      answeredCount: 31,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch verified imams from Firestore
    final fieldFilter = _selectedCategory == 'all' ? null : _selectedCategory;
    final imamsAsync = ref.watch(verifiedImamsProvider(fieldFilter));

    // Watch pending questions count for the badge
    final pendingCountAsync = ref.watch(pendingQuestionsCountProvider);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;

    return Scaffold(
      backgroundColor: _AskColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── TopAppBar matching HTML template ─────────────────
            _TopAppBar(
              isAr: _isAr,
              pendingCount: pendingCount,
              onMyQuestionsTap: () => context.push(AppRoutes.myQuestions),
            ),

            // ── Scrollable Body ──────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                children: [
                  // ── Header Section: Title & Subtitle ───────────
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'اسأل الشيخ',
                      style: GoogleFonts.tajawal(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _AskColors.primary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'اختر التخصص المناسب لطرح سؤالك على نخبة من العلماء المتخصصين.',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _AskColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Horizontal Chips Category Filter ───────────
                  _CategoryChipsBar(
                    categories: _categories,
                    selectedId: _selectedCategory,
                    onSelected: (id) =>
                        setState(() => _selectedCategory = id),
                  ),

                  const SizedBox(height: 20),

                  // ── Sheikh Cards Grid / List ───────────────────
                  imamsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: _AskColors.primary,
                        ),
                      ),
                    ),
                    error: (_, __) => _buildScholarsList(
                      _filterScholars(_defaultScholars, _selectedCategory),
                    ),
                    data: (imams) {
                      final list = imams.isNotEmpty
                          ? imams
                          : _filterScholars(
                              _defaultScholars, _selectedCategory);

                      if (list.isEmpty) {
                        return _EmptyScholarsState(
                          categoryName: _categories.firstWhere(
                            (c) => c['id'] == _selectedCategory,
                            orElse: () => {'label': ''},
                          )['label']!,
                        );
                      }

                      return _buildScholarsList(list);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ImamModel> _filterScholars(List<ImamModel> list, String category) {
    if (category == 'all') return list;
    return list.where((s) => s.fields.contains(category)).toList();
  }

  Widget _buildScholarsList(List<ImamModel> scholars) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: scholars.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final scholar = scholars[index];
        return _SheikhCard(
          scholar: scholar,
          isAr: _isAr,
          onAsk: () => context.push(
            AppRoutes.askQuestion,
            extra: scholar,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopAppBar extends StatelessWidget {
  final bool isAr;
  final int pendingCount;
  final VoidCallback onMyQuestionsTap;

  const _TopAppBar({
    required this.isAr,
    required this.pendingCount,
    required this.onMyQuestionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _AskColors.surface,
        border: Border(
          bottom: BorderSide(color: Color(0xFFECEFF6), width: 1),
        ),
      ),
      child: Stack(
        children: [
          // Centered title in the middle
          Center(
            child: Text(
              isAr ? 'اسأل أهل العلم' : 'Ask Scholars',
              style: GoogleFonts.tajawal(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _AskColors.primary,
              ),
            ),
          ),

          // Button on the right
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onMyQuestionsTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _AskColors.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _AskColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        Icons.question_answer_outlined,
                        size: 20,
                        color: _AskColors.primary,
                      ),
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFBA1A1A),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              pendingCount > 9 ? '9+' : '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChipsBar extends StatelessWidget {
  final List<Map<String, String>> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _CategoryChipsBar({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final id = cat['id']!;
          final label = cat['label']!;
          final isSelected = selectedId == id;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => onSelected(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _AskColors.secondaryContainer
                      : _AskColors.surface,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : _AskColors.outlineVariant.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _AskColors.secondaryContainer
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? _AskColors.onSecondaryContainer
                        : _AskColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheikh Card — exact replica of the HTML mockup card
// ─────────────────────────────────────────────────────────────────────────────

class _SheikhCard extends StatelessWidget {
  final ImamModel scholar;
  final bool isAr;
  final VoidCallback onAsk;

  const _SheikhCard({
    required this.scholar,
    required this.isAr,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = scholar.photoUrl;
    final fields = scholar.fields;

    return Container(
      decoration: BoxDecoration(
        color: _AskColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _AskColors.surfaceVariant.withValues(alpha: 0.9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Circular Avatar with Double Ring ───────────────────
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _AskColors.secondaryContainer,
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              color: _AskColors.secondaryContainer,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _AskColors.primary,
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) =>
                          _FallbackScholarAvatar(name: scholar.fullName),
                    )
                  : _FallbackScholarAvatar(name: scholar.fullName),
            ),
          ),

          const SizedBox(height: 14),

          // ── Sheikh Name ────────────────────────────────────────
          Text(
            scholar.fullName,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _AskColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 3),

          // ── Specialization Subtitle ────────────────────────────
          Text(
            scholar.bio != null && scholar.bio!.isNotEmpty
                ? scholar.bio!
                : _formatSpecializationSubtitle(fields),
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _AskColors.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // ── Field Tags ─────────────────────────────────────────
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: fields.map((fieldId) {
              final field = IslamicField.fromId(fieldId);
              final label = field != null
                  ? field.label(isAr)
                  : IslamicField.labelForId(fieldId, isArabic: isAr);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: _AskColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _AskColors.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // ── Action Button "طرح سؤال" ───────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onAsk,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AskColors.primary,
                foregroundColor: _AskColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.chat_bubble_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'طرح سؤال',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpecializationSubtitle(List<String> fields) {
    if (fields.isEmpty) return 'متخصص في العلوم الشرعية';
    final labels =
        fields.map((f) => IslamicField.labelForId(f, isArabic: true)).join(' و ');
    return 'أستاذ $labels';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback Scholar Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackScholarAvatar extends StatelessWidget {
  final String name;

  const _FallbackScholarAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty
        ? (name.trim().split(' ').length >= 2
            ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'
            : name[0])
        : '؟';

    return Container(
      color: _AskColors.primary,
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyScholarsState extends StatelessWidget {
  final String categoryName;

  const _EmptyScholarsState({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.school_outlined,
            size: 56,
            color: _AskColors.outlineVariant,
          ),
          const SizedBox(height: 14),
          Text(
            categoryName.isNotEmpty
                ? 'لا يوجد علماء متخصصون في $categoryName حالياً'
                : 'لا يوجد علماء متاحون حالياً',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _AskColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
