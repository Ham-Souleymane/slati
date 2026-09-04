import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../mosques/domain/imam_model.dart';
import '../data/question_repository.dart';
import '../domain/islamic_field.dart';
import '../domain/question_model.dart';

class AskQuestionScreen extends ConsumerStatefulWidget {
  final ImamModel imam;

  const AskQuestionScreen({super.key, required this.imam});

  @override
  ConsumerState<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends ConsumerState<AskQuestionScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedField;
  bool _isAnonymous = false;
  bool _isSending = false;

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    // Pre-select first field if imam has fields
    if (widget.imam.fields.isNotEmpty) {
      _selectedField = widget.imam.fields.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedField == null) {
      context.showSnackBar('يرجى اختيار تخصص للسؤال', isError: true);
      return;
    }

    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      final question = QuestionModel(
        id: '',
        userId: user.uid,
        userDisplayName: _isAnonymous ? 'مجهول' : (user.displayName ?? 'مستخدم'),
        isAnonymous: _isAnonymous,
        imamId: widget.imam.id,
        imamName: widget.imam.fullName,
        imamPhotoUrl: widget.imam.photoUrl,
        field: _selectedField!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        status: QuestionStatus.pending,
        createdAt: DateTime.now(),
      );

      await ref.read(questionRepositoryProvider).submitQuestion(question);

      if (mounted) {
        context.showSnackBar('تم إرسال سؤالك بنجاح ✅');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('فشل الإرسال، حاول مجدداً', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imam = widget.imam;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'طرح سؤال',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            // ── Sheikh card ─────────────────────────────────────
            _SheikhHeader(imam: imam, isAr: _isAr),
            const SizedBox(height: 24),

            // ── Title ───────────────────────────────────────────
            _InputLabel(text: 'عنوان السؤال'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: GoogleFonts.tajawal(fontSize: 15),
              textDirection: TextDirection.rtl,
              decoration: _inputDecoration('عنوان السؤال باختصار...'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'يرجى كتابة عنوان' : null,
              maxLength: 120,
            ),

            const SizedBox(height: 16),

            // ── Field selector ──────────────────────────────────
            _InputLabel(text: 'نوع السؤال'),
            const SizedBox(height: 8),
            _FieldSelector(
              imamFields: imam.fields,
              selectedField: _selectedField,
              isAr: _isAr,
              onChanged: (f) => setState(() => _selectedField = f),
            ),

            const SizedBox(height: 16),

            // ── Body ────────────────────────────────────────────
            _InputLabel(text: 'تفاصيل السؤال'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyController,
              style: GoogleFonts.tajawal(fontSize: 15),
              textDirection: TextDirection.rtl,
              decoration: _inputDecoration('اكتب سؤالك هنا بالتفصيل...'),
              maxLines: 7,
              validator: (v) =>
                  (v == null || v.trim().length < 10)
                      ? 'يرجى كتابة سؤال واضح (10 أحرف على الأقل)'
                      : null,
              maxLength: 2000,
            ),

            const SizedBox(height: 16),

            // ── Anonymous toggle ────────────────────────────────
            _AnonymousToggle(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
            ),
          ],
        ),
      ),

      // ── Send button ─────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: ElevatedButton.icon(
          onPressed: _isSending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emeraldDark,
            disabledBackgroundColor: AppColors.grey300,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _isSending ? 'جارٍ الإرسال...' : 'إرسال السؤال',
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.tajawal(color: AppColors.grey500, fontSize: 14),
      filled: true,
      fillColor: AppColors.white,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheikh Header
// ─────────────────────────────────────────────────────────────────────────────

class _SheikhHeader extends StatelessWidget {
  final ImamModel imam;
  final bool isAr;

  const _SheikhHeader({required this.imam, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.emeraldDark,
            backgroundImage: imam.photoUrl != null
                ? NetworkImage(imam.photoUrl!)
                : null,
            child: imam.photoUrl == null
                ? Text(
                    imam.fullName.isNotEmpty ? imam.fullName[0] : '؟',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  imam.fullName,
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldDark,
                  ),
                ),
                if (imam.bio != null && imam.bio!.isNotEmpty)
                  Text(
                    imam.bio!,
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: AppColors.grey500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (imam.fields.isNotEmpty)
                  Text(
                    imam.fields
                        .take(2)
                        .map((id) => IslamicField.labelForId(id, isArabic: isAr))
                        .join(' · '),
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded,
              color: AppColors.emerald, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Selector
// ─────────────────────────────────────────────────────────────────────────────

class _FieldSelector extends StatelessWidget {
  final List<String> imamFields;
  final String? selectedField;
  final bool isAr;
  final ValueChanged<String?> onChanged;

  const _FieldSelector({
    required this.imamFields,
    required this.selectedField,
    required this.isAr,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Show imam's fields first, then all others
    final all = IslamicField.values.map((f) => f.id).toList();
    final sorted = [
      ...imamFields.where(all.contains),
      ...all.where((id) => !imamFields.contains(id)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.map((fieldId) {
        final field = IslamicField.fromId(fieldId);
        final isSelected = selectedField == fieldId;
        final isImamField = imamFields.contains(fieldId);
        return GestureDetector(
          onTap: () => onChanged(fieldId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.emeraldDark
                  : (isImamField
                      ? AppColors.emeraldPale.withValues(alpha: 0.5)
                      : AppColors.white),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSelected
                    ? AppColors.emeraldDark
                    : (isImamField
                        ? AppColors.emeraldLight
                        : AppColors.grey300),
              ),
            ),
            child: Text(
              field != null
                  ? '${field.icon} ${field.label(isAr)}'
                  : IslamicField.labelForId(fieldId, isArabic: isAr),
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isImamField
                        ? AppColors.emeraldDark
                        : AppColors.grey700),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Anonymous Toggle
// ─────────────────────────────────────────────────────────────────────────────

class _AnonymousToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AnonymousToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? AppColors.emerald : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                value
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                key: ValueKey(value),
                color: value ? AppColors.emerald : AppColors.grey500,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طرح السؤال بشكل مجهول',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.charcoal,
                    ),
                  ),
                  Text(
                    'سيظهر اسمك كـ "مجهول" للشيخ فقط',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: AppColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.emerald,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable label
// ─────────────────────────────────────────────────────────────────────────────

class _InputLabel extends StatelessWidget {
  final String text;
  const _InputLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.tajawal(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.charcoal,
      ),
    );
  }
}
