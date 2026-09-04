import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../mosques/data/mosque_repository.dart';
import '../domain/islamic_field.dart';

class MinbarOnboardingFieldsSheet extends ConsumerStatefulWidget {
  final String imamId;
  final List<String> initialFields;

  const MinbarOnboardingFieldsSheet({
    super.key,
    required this.imamId,
    this.initialFields = const [],
  });

  @override
  ConsumerState<MinbarOnboardingFieldsSheet> createState() =>
      _MinbarOnboardingFieldsSheetState();
}

class _MinbarOnboardingFieldsSheetState
    extends ConsumerState<MinbarOnboardingFieldsSheet> {
  late Set<String> _selectedFields;
  final _bioController = TextEditingController();
  bool _isSaving = false;

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _selectedFields = Set.from(widget.initialFields);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  void _toggleField(String id) {
    setState(() {
      if (_selectedFields.contains(id)) {
        _selectedFields.remove(id);
      } else {
        _selectedFields.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedFields.isEmpty) {
      context.showSnackBar(
        _isAr
            ? 'يرجى اختيار تخصص واحد على الأقل'
            : 'Please select at least one field',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(mosqueRepositoryProvider).updateImamAskFields(
            imamId: widget.imamId,
            fields: _selectedFields.toList(),
            bio: _bioController.text.trim().isNotEmpty
                ? _bioController.text.trim()
                : null,
            isVisible: true,
          );

      if (mounted) {
        context.showSnackBar(
          _isAr ? 'تم حفظ التخصصات بنجاح ✅' : 'Specializations saved ✅',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          _isAr ? 'فشل الحفظ، حاول مجدداً' : 'Failed to save',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _isAr ? 'مجالات التخصص العلمي' : 'Fields of Expertise',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.emeraldDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isAr
                ? 'اختر المجالات التي ترغب في استقبال أسئلة المصلين حولها:'
                : 'Select the fields in which you would like to receive questions:',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: 16),

          // Fields wrap
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: IslamicField.values.map((f) {
              final isSelected = _selectedFields.contains(f.id);
              return FilterChip(
                label: Text('${f.icon} ${f.label(_isAr)}'),
                selected: isSelected,
                onSelected: (_) => _toggleField(f.id),
                selectedColor: AppColors.emeraldDark,
                checkmarkColor: Colors.white,
                backgroundColor: AppColors.grey100,
                labelStyle: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.grey700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                  side: BorderSide(
                    color: isSelected ? AppColors.emeraldDark : AppColors.grey300,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isAr ? 'حفظ ومتابعة' : 'Save & Continue',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
