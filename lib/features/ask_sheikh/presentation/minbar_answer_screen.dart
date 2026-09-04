import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../mosques/data/mosque_repository.dart';
import '../data/question_repository.dart';
import '../domain/islamic_field.dart';
import '../domain/question_model.dart';

class MinbarAnswerScreen extends ConsumerStatefulWidget {
  final QuestionModel question;
  final String imamId;

  const MinbarAnswerScreen({
    super.key,
    required this.question,
    required this.imamId,
  });

  @override
  ConsumerState<MinbarAnswerScreen> createState() => _MinbarAnswerScreenState();
}

class _MinbarAnswerScreenState extends ConsumerState<MinbarAnswerScreen> {
  final _answerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPublishing = false;

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    // If answering the initial question and an initial answer exists, pre-fill it.
    // If responding to a follow-up, keep the compose box fresh.
    if (widget.question.answer != null &&
        widget.question.answer!.isNotEmpty &&
        widget.question.replies.isEmpty &&
        widget.question.isAnswered) {
      _answerController.text = widget.question.answer!;
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _publishAnswer(QuestionModel q) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPublishing = true);

    try {
      final answerText = _answerController.text.trim();
      final imamDoc = await ref.read(mosqueRepositoryProvider).getImamById(widget.imamId);
      final imamName = imamDoc?.fullName ?? q.imamName;
      final imamPhotoUrl = imamDoc?.photoUrl ?? q.imamPhotoUrl;

      final isFollowUp = q.answer != null && q.answer!.isNotEmpty;

      if (isFollowUp) {
        // Submit follow-up response
        await ref.read(questionRepositoryProvider).submitFollowUpAnswer(
              questionId: q.id,
              message: answerText,
              imamId: widget.imamId,
              imamName: imamName,
              imamPhotoUrl: imamPhotoUrl,
            );
      } else {
        // Submit initial answer
        await ref.read(questionRepositoryProvider).submitAnswer(
              questionId: q.id,
              answer: answerText,
              imamId: widget.imamId,
            );

        if (widget.imamId.isNotEmpty) {
          await ref
              .read(mosqueRepositoryProvider)
              .incrementAnsweredCount(widget.imamId);
        }
      }

      if (mounted) {
        context.showSnackBar(_isAr
            ? 'تم نشر الإجابة وإشعار السائل بنجاح ✅'
            : 'Answer published and user notified successfully ✅');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          _isAr ? 'فشل نشر الإجابة، حاول مجدداً' : 'Failed to publish answer',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionAsync = ref.watch(questionByIdProvider(widget.question.id));
    final q = questionAsync.asData?.value ?? widget.question;

    final field = IslamicField.fromId(q.field);
    final hasInitialAnswer = q.answer != null && q.answer!.isNotEmpty;
    final isFollowUpPending = q.isFollowUpPending;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isFollowUpPending
              ? (_isAr ? 'الرد على الاستفسار' : 'Answer Follow-Up')
              : (_isAr ? 'الإجابة على السؤال' : 'Answer Question'),
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          children: [
            // ── Question overview card ─────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.07),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(15)),
                      border: const Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.emeraldDark, AppColors.emeraldLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _isAr ? 'س' : 'Q',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q.title,
                            style: GoogleFonts.tajawal(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emeraldDark,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.body,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            color: AppColors.charcoal,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 10),
                        _AnswerDetailBullet(
                          label: _isAr ? 'السائل:' : 'Asker:',
                          value: q.isAnonymous
                              ? (_isAr ? 'مجهول الهوية 🔒' : 'Anonymous 🔒')
                              : (q.userDisplayName.isNotEmpty
                                  ? q.userDisplayName
                                  : (_isAr ? 'مُصلٍّ' : 'Worshipper')),
                        ),
                        _AnswerDetailBullet(
                          label: _isAr ? 'المجال:' : 'Field:',
                          value: field != null
                              ? '${field.icon} ${field.label(_isAr)}'
                              : IslamicField.labelForId(q.field, isArabic: _isAr),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Previous Answer if exists ─────────────────────────
            if (hasInitialAnswer) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.emerald, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _isAr ? 'إجابتكم السابقة:' : 'Your Previous Answer:',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.answer!,
                      style: GoogleFonts.tajawal(
                        fontSize: 13.5,
                        color: AppColors.charcoal,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Thread / Follow-up Messages ────────────────────────
            if (q.replies.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...q.replies.map((reply) {
                final dateStr =
                    DateFormat('yyyy/MM/dd - hh:mm a').format(reply.createdAt);
                if (reply.isFromUser) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.goldPale.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.help_outline_rounded,
                                size: 16, color: AppColors.charcoal),
                            const SizedBox(width: 6),
                            Text(
                              _isAr
                                  ? 'استفسار من السائل:'
                                  : 'Follow-up from Asker:',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reply.message,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            color: AppColors.charcoal,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPale.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.emeraldLight.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 16, color: AppColors.emeraldDark),
                            const SizedBox(width: 6),
                            Text(
                              _isAr ? 'ردكم السابق:' : 'Your Response:',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldDark,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reply.message,
                          style: GoogleFonts.tajawal(
                            fontSize: 13.5,
                            color: AppColors.charcoal,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }),
            ],

            const SizedBox(height: 20),

            // ── Answer Compose Box ────────────────────────────────
            Text(
              isFollowUpPending
                  ? (_isAr ? 'نص الرد على الاستفسار' : 'Response to Follow-Up')
                  : (_isAr ? 'نص الإجابة والفتوى' : 'Your Answer'),
              style: GoogleFonts.tajawal(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _answerController,
              style: GoogleFonts.tajawal(fontSize: 15, height: 1.6),
              textDirection: TextDirection.rtl,
              maxLines: 9,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: isFollowUpPending
                    ? (_isAr
                        ? 'اكتب الرد والتوضيح على استفسار السائل هنا...'
                        : 'Write the clarification for the user here...')
                    : (_isAr
                        ? 'اكتب الإجابة الشافية والموثقة هنا مع ذكر الأدلة عند الحاجة...'
                        : 'Write the comprehensive answer here...'),
                hintStyle: GoogleFonts.tajawal(
                  color: AppColors.grey500,
                  fontSize: 14,
                ),
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
                  borderSide:
                      const BorderSide(color: AppColors.emerald, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? (_isAr
                      ? 'يرجى كتابة إجابة واضحة'
                      : 'Please write a clear answer')
                  : null,
            ),

            const SizedBox(height: 12),

            // Guidance Tip Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emeraldPale.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.emeraldLight.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.emerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isAr
                          ? 'سيتم إشعار السائل فور نشر الرد وستكون متاحة له في قسم "أسئلتي".'
                          : 'The asker will be immediately notified once the answer is published.',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: AppColors.emeraldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Bottom publish button ─────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: ElevatedButton.icon(
          onPressed: _isPublishing ? null : () => _publishAnswer(q),
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
          icon: _isPublishing
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
            _isPublishing
                ? (_isAr ? 'جارٍ النشر...' : 'Publishing...')
                : (isFollowUpPending
                    ? (_isAr ? 'نشر الرد على الاستفسار' : 'Publish Follow-up Answer')
                    : (_isAr ? 'نشر الإجابة' : 'Publish Answer')),
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerDetailBullet extends StatelessWidget {
  final String label;
  final String value;

  const _AnswerDetailBullet({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.emeraldLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                      height: 1.5,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
