import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../data/question_repository.dart';
import '../domain/islamic_field.dart';
import '../domain/question_model.dart';

class QuestionDetailScreen extends ConsumerStatefulWidget {
  final QuestionModel question;

  const QuestionDetailScreen({super.key, required this.question});

  @override
  ConsumerState<QuestionDetailScreen> createState() =>
      _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _followUpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSendingFollowUp = false;
  bool _showFollowUpInput = false;

  @override
  void initState() {
    super.initState();
    // Mark as read if answered and unread
    if (widget.question.isAnswered && !widget.question.isReadByAsker) {
      ref
          .read(questionRepositoryProvider)
          .markAnswerRead(widget.question.id);
    }
  }

  @override
  void dispose() {
    _followUpController.dispose();
    super.dispose();
  }

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  void _copyText(String text, String successMessage) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.emeraldDark,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.goldLight, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                successMessage,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendFollowUp(QuestionModel currentQuestion) async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;

    setState(() => _isSendingFollowUp = true);

    try {
      final message = _followUpController.text.trim();
      await ref.read(questionRepositoryProvider).submitFollowUpQuestion(
            questionId: currentQuestion.id,
            message: message,
            userId: user.uid,
            userDisplayName: currentQuestion.isAnonymous
                ? (_isAr ? 'مجهول' : 'Anonymous')
                : (user.displayName ?? (_isAr ? 'مُصلٍّ' : 'Worshipper')),
            userPhotoUrl: currentQuestion.isAnonymous ? null : user.photoURL,
          );

      _followUpController.clear();
      setState(() {
        _showFollowUpInput = false;
      });

      if (mounted) {
        context.showSnackBar(
          _isAr
              ? 'تم إرسال استفسارك الإضافي لفضيلة الشيخ بنجاح ✅'
              : 'Follow-up question sent to the scholar successfully ✅',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          _isAr ? 'فشل إرسال الاستفسار، حاول مجدداً' : 'Failed to send follow-up',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingFollowUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream live question doc for updates (e.g. when answered while viewing)
    final questionAsync =
        ref.watch(questionByIdProvider(widget.question.id));
    final q = questionAsync.asData?.value ?? widget.question;

    final field = IslamicField.fromId(q.field);
    final hasInitialAnswer = q.answer != null && q.answer!.isNotEmpty;
    final dateFormatted = DateFormat('yyyy/MM/dd - hh:mm a').format(q.createdAt);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isAr ? 'تفاصيل السؤال والفتوى' : 'Question & Fatwa Details',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isAr ? 'نسخ نص السؤال' : 'Copy Question',
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
            onPressed: () => _copyText(
              '${q.title}\n\n${q.body}',
              _isAr ? 'تم نسخ نص السؤال إلى الحافظة' : 'Question copied to clipboard',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
        children: [
          // ── 1. Hero Status Ribbon (HCI: Immediate Status Feedback) ──
          _StatusRibbon(
            status: q.status,
            isFollowUpPending: q.isFollowUpPending,
            isAr: _isAr,
          ),

          const SizedBox(height: 14),

          // ── 2. Assigned Scholar Bar ─────────────────────────────────
          _AssignedScholarBar(
            imamName: q.imamName,
            imamPhotoUrl: q.imamPhotoUrl,
            field: field,
            fieldId: q.field,
            isAr: _isAr,
          ),

          const SizedBox(height: 14),

          // ── 3. The Question Card (Inquirer's Inquiry) ───────────────
          _QuestionCard(
            title: q.title,
            body: q.body,
            dateStr: dateFormatted,
            isAnonymous: q.isAnonymous,
            userDisplayName: q.userDisplayName,
            field: field,
            fieldId: q.field,
            isAr: _isAr,
            onCopy: () => _copyText(
              '${q.title}\n\n${q.body}',
              _isAr ? 'تم نسخ السؤال بنجاح 📋' : 'Question copied 📋',
            ),
          ),

          const SizedBox(height: 16),

          // ── 4. Scholar's Fatwa / Answer Card ────────────────────────
          if (hasInitialAnswer) ...[
            _ScholarFatwaCard(
              answer: q.answer!,
              answeredAt: q.answeredAt,
              imamName: q.imamName,
              imamPhotoUrl: q.imamPhotoUrl,
              isAr: _isAr,
              onCopy: () {
                final textToCopy = _isAr
                    ? 'فتوى فضيلة الشيخ ${q.imamName.isNotEmpty ? q.imamName : ""}:\n\n${q.answer}\n\n(هذا والله تعالى أعلم وأحكم - تطبيق صلاتي)'
                    : 'Fatwa by ${q.imamName}:\n\n${q.answer}\n\n(And Allah knows best - Slatk App)';
                _copyText(
                  textToCopy,
                  _isAr ? 'تم نسخ نص الفتوى المعتمدة بنجاح 📋' : 'Fatwa copied 📋',
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── 5. Thread / Follow-up Messages ──────────────────────────
          if (q.replies.isNotEmpty) ...[
            _ThreadHeader(isAr: _isAr, count: q.replies.length),
            const SizedBox(height: 10),
            ...q.replies.map((reply) {
              if (reply.isFromUser) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UserFollowUpBubble(
                    reply: reply,
                    isAr: _isAr,
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScholarReplyBubble(
                    reply: reply,
                    imamName: reply.senderName.isNotEmpty ? reply.senderName : q.imamName,
                    imamPhotoUrl: reply.senderPhotoUrl ?? q.imamPhotoUrl,
                    isAr: _isAr,
                    onCopy: () => _copyText(
                      reply.message,
                      _isAr ? 'تم نسخ توضيح الشيخ 📋' : 'Copied 📋',
                    ),
                  ),
                );
              }
            }),
            const SizedBox(height: 8),
          ],

          // ── 6. Contextual Action / Status Cards ──────────────────────
          if (q.status == QuestionStatus.answered) ...[
            _FollowUpComposeSection(
              isAr: _isAr,
              formKey: _formKey,
              controller: _followUpController,
              isSending: _isSendingFollowUp,
              showInput: _showFollowUpInput,
              onToggleShow: () => setState(() => _showFollowUpInput = !_showFollowUpInput),
              onSend: () => _sendFollowUp(q),
            ),
          ] else if (q.isFollowUpPending) ...[
            _FollowUpPendingNotice(isAr: _isAr),
          ] else if (q.isPending && !hasInitialAnswer) ...[
            _PendingTimelineCard(isAr: _isAr),
          ] else if (q.status == QuestionStatus.rejected) ...[
            _RejectedNotice(isAr: _isAr),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Status Ribbon (HCI: Visibility of System Status)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusRibbon extends StatelessWidget {
  final QuestionStatus status;
  final bool isFollowUpPending;
  final bool isAr;

  const _StatusRibbon({
    required this.status,
    required this.isFollowUpPending,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    Color bgStart;
    Color bgEnd;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    if (isFollowUpPending) {
      bgStart = const Color(0xFFB45309);
      bgEnd = const Color(0xFFD97706);
      iconColor = AppColors.goldPale;
      icon = Icons.hourglass_top_rounded;
      title = isAr ? 'استفسارك الإضافي قيد المراجعة' : 'Follow-Up Under Review';
      subtitle = isAr
          ? 'تم إرسال نقطتك التوضيحية لفضيلة الشيخ وسيجيب عليها قريباً'
          : 'Your follow-up is being reviewed by the scholar';
    } else {
      switch (status) {
        case QuestionStatus.answered:
          bgStart = AppColors.emeraldDark;
          bgEnd = AppColors.emerald;
          iconColor = AppColors.goldLight;
          icon = Icons.verified_rounded;
          title = isAr ? 'صدرت الفتوى الشرعية المعتمدة' : 'Official Fatwa Issued';
          subtitle = isAr
              ? 'أجاب فضيلة الشيخ على سؤالك بتفصيل وبيان'
              : 'The scholar has answered your question';
          break;
        case QuestionStatus.pending:
          bgStart = const Color(0xFF92400E);
          bgEnd = const Color(0xFFB45309);
          iconColor = AppColors.goldPale;
          icon = Icons.access_time_filled_rounded;
          title = isAr ? 'السؤال قيد الدراسة والمراجعة' : 'Question Under Review';
          subtitle = isAr
              ? 'السؤال في قائمة انتظار الشيخ، وسيصلك إشعار فوري عند الإجابة'
              : 'Awaiting scholar response, notification will be sent';
          break;
        case QuestionStatus.rejected:
          bgStart = const Color(0xFF991B1B);
          bgEnd = const Color(0xFFDC2626);
          iconColor = Colors.white;
          icon = Icons.info_rounded;
          title = isAr ? 'اعتذر الشيخ عن الإجابة' : 'Question Declined';
          subtitle = isAr
              ? 'تعذر على الشيخ الإجابة على هذا الاستفسار في الوقت الحالي'
              : 'The scholar is unable to answer this inquiry at this time';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgStart, bgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bgStart.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.tajawal(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Assigned Scholar Bar
// ─────────────────────────────────────────────────────────────────────────────

class _AssignedScholarBar extends StatelessWidget {
  final String imamName;
  final String? imamPhotoUrl;
  final IslamicField? field;
  final String fieldId;
  final bool isAr;

  const _AssignedScholarBar({
    required this.imamName,
    required this.imamPhotoUrl,
    required this.field,
    required this.fieldId,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = imamName.isNotEmpty ? imamName : (isAr ? 'الشيخ المُختص' : 'Assigned Scholar');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.emeraldPale,
            backgroundImage: imamPhotoUrl != null ? NetworkImage(imamPhotoUrl!) : null,
            child: imamPhotoUrl == null
                ? Text(
                    displayName[0],
                    style: GoogleFonts.tajawal(
                      color: AppColors.emeraldDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isAr ? 'فضيلة الشيخ' : 'Scholar',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        color: AppColors.grey500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 14, color: AppColors.emerald),
                  ],
                ),
                Text(
                  displayName,
                  style: GoogleFonts.tajawal(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldPale.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              field != null
                  ? '${field!.icon} ${field!.label(isAr)}'
                  : IslamicField.labelForId(fieldId, isArabic: isAr),
              style: GoogleFonts.tajawal(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. The Question Card (Inquirer's Inquiry)
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final String title;
  final String body;
  final String dateStr;
  final bool isAnonymous;
  final String userDisplayName;
  final IslamicField? field;
  final String fieldId;
  final bool isAr;
  final VoidCallback onCopy;

  const _QuestionCard({
    required this.title,
    required this.body,
    required this.dateStr,
    required this.isAnonymous,
    required this.userDisplayName,
    required this.field,
    required this.fieldId,
    required this.isAr,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: const Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAr ? 'نص السؤال' : 'Question',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.grey500),
                ),
                const Spacer(),
                if (isAnonymous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off_rounded, size: 12, color: AppColors.grey500),
                        const SizedBox(width: 4),
                        Text(
                          isAr ? 'مجهول' : 'Anonymous',
                          style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.grey700),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 16, color: AppColors.grey500),
                  ),
                ),
              ],
            ),
          ),

          // Question Body Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cream.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    body,
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      color: AppColors.grey700,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Scholar's Fatwa / Answer Card (Primary Visual Highlight)
// ─────────────────────────────────────────────────────────────────────────────

class _ScholarFatwaCard extends StatelessWidget {
  final String answer;
  final DateTime? answeredAt;
  final String imamName;
  final String? imamPhotoUrl;
  final bool isAr;
  final VoidCallback onCopy;

  const _ScholarFatwaCard({
    required this.answer,
    required this.answeredAt,
    required this.imamName,
    required this.imamPhotoUrl,
    required this.isAr,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final answerDateStr = answeredAt != null
        ? DateFormat('yyyy/MM/dd - hh:mm a').format(answeredAt!)
        : null;

    final displayName = imamName.isNotEmpty ? imamName : (isAr ? 'فضيلة الشيخ' : 'The Scholar');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.emeraldLight.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Islamic Fatwa Banner Header ───────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF044837), AppColors.emeraldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'إجابة وفتوى فضيلة الشيخ' : 'Official Fatwa / Ruling',
                        style: GoogleFonts.tajawal(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (answerDateStr != null)
                        Text(
                          answerDateStr,
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: AppColors.goldPale.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onCopy,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.goldLight),
                  label: Text(
                    isAr ? 'نسخ الفتوى' : 'Copy',
                    style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // ── Fatwa Body ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quote container with left/right accent border
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPale.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      right: isAr
                          ? const BorderSide(color: AppColors.emerald, width: 4)
                          : BorderSide.none,
                      left: !isAr
                          ? const BorderSide(color: AppColors.emerald, width: 4)
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    answer,
                    style: GoogleFonts.tajawal(
                      fontSize: 15.5,
                      color: AppColors.charcoal,
                      height: 1.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Attributed Scholar Signature Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.emeraldDark,
                      backgroundImage: imamPhotoUrl != null ? NetworkImage(imamPhotoUrl!) : null,
                      child: imamPhotoUrl == null
                          ? Text(
                              displayName[0],
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAr ? 'صدرت عن: ' : 'Issued by: ',
                      style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.grey500),
                    ),
                    Text(
                      displayName,
                      style: GoogleFonts.tajawal(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Concluding Islamic Benediction
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.goldPale.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        isAr
                            ? 'هذا والله تعالى أعلم وأحكم'
                            : 'And Allah knows best.',
                        style: GoogleFonts.tajawal(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Follow-Up Dialogue Threads
// ─────────────────────────────────────────────────────────────────────────────

class _ThreadHeader extends StatelessWidget {
  final bool isAr;
  final int count;

  const _ThreadHeader({required this.isAr, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.forum_outlined, size: 18, color: AppColors.emeraldDark),
        const SizedBox(width: 8),
        Text(
          isAr ? 'الاستفسارات التوضيحية ($count)' : 'Follow-Up Inquiries ($count)',
          style: GoogleFonts.tajawal(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.emeraldDark,
          ),
        ),
        const Spacer(),
        Container(
          height: 1,
          width: 60,
          color: AppColors.divider,
        ),
      ],
    );
  }
}

class _UserFollowUpBubble extends StatelessWidget {
  final QuestionReply reply;
  final bool isAr;

  const _UserFollowUpBubble({required this.reply, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(reply.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.goldPale,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAr ? 'استفسار من السائل' : 'Inquirer Inquiry',
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF78350F),
                  ),
                ),
              ),
              const Spacer(),
              Text(dateStr, style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.grey500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.message,
            style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.charcoal, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ScholarReplyBubble extends StatelessWidget {
  final QuestionReply reply;
  final String imamName;
  final String? imamPhotoUrl;
  final bool isAr;
  final VoidCallback onCopy;

  const _ScholarReplyBubble({
    required this.reply,
    required this.imamName,
    required this.imamPhotoUrl,
    required this.isAr,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(reply.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.emeraldPale.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emeraldLight.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.emeraldDark,
                backgroundImage: imamPhotoUrl != null ? NetworkImage(imamPhotoUrl!) : null,
                child: imamPhotoUrl == null ? const Icon(Icons.person, size: 10, color: Colors.white) : null,
              ),
              const SizedBox(width: 6),
              Text(
                isAr ? 'توضيح فضيلة الشيخ ($imamName)' : 'Scholar Response ($imamName)',
                style: GoogleFonts.tajawal(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emeraldDark,
                ),
              ),
              const Spacer(),
              Text(dateStr, style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.grey500)),
              const SizedBox(width: 4),
              InkWell(
                onTap: onCopy,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.copy_rounded, size: 14, color: AppColors.grey500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.message,
            style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.charcoal, height: 1.65),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Follow-Up Compose Section
// ─────────────────────────────────────────────────────────────────────────────

class _FollowUpComposeSection extends StatelessWidget {
  final bool isAr;
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isSending;
  final bool showInput;
  final VoidCallback onToggleShow;
  final VoidCallback onSend;

  const _FollowUpComposeSection({
    required this.isAr,
    required this.formKey,
    required this.controller,
    required this.isSending,
    required this.showInput,
    required this.onToggleShow,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    if (!showInput) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPale.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.contact_support_rounded,
                    color: AppColors.emeraldDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'هل تحتاج إلى استفسار إضافي؟' : 'Need more clarification?',
                        style: GoogleFonts.tajawal(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        isAr
                            ? 'يمكنك طرح استفسار تكميلي على الشيخ حول هذه الفتوى'
                            : 'You can ask a follow-up inquiry about this ruling',
                        style: GoogleFonts.tajawal(
                          fontSize: 11.5,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onToggleShow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_comment_rounded, size: 16),
                label: Text(
                  isAr ? 'طرح استفسار توضيحي' : 'Ask Follow-Up',
                  style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.emerald, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppColors.emeraldDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'اكتب استفسارك التوضيحي للشيخ' : 'Write Follow-Up Inquiry',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.grey500),
                  onPressed: onToggleShow,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: controller,
              style: GoogleFonts.tajawal(fontSize: 14, height: 1.5),
              textDirection: TextDirection.rtl,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: isAr
                    ? 'اكتب النقطة التي تحتاج لمزيد من البيان هنا...'
                    : 'Type your clarification request here...',
                hintStyle: GoogleFonts.tajawal(color: AppColors.grey500, fontSize: 13),
                filled: true,
                fillColor: AppColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.emerald, width: 1.8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? (isAr ? 'يرجى كتابة استفسار واضح (5 أحرف على الأقل)' : 'Min 5 characters')
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSending ? null : onToggleShow,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.grey300),
                    ),
                    child: Text(
                      isAr ? 'إلغاء' : 'Cancel',
                      style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.grey700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isSending ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 15),
                    label: Text(
                      isSending
                          ? (isAr ? 'جارٍ الإرسال...' : 'Sending...')
                          : (isAr ? 'إرسال الاستفسار' : 'Send Inquiry'),
                      style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Follow-Up Pending Notice
// ─────────────────────────────────────────────────────────────────────────────

class _FollowUpPendingNotice extends StatelessWidget {
  final bool isAr;

  const _FollowUpPendingNotice({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'استفسارك الإضافي قيد المراجعة' : 'Follow-up under review',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAr
                      ? 'تم إرسال استفسارك للشيخ وسيصلك إشعار فوري عند الإجابة عليه بإذن الله.'
                      : 'Your inquiry was sent. You will be notified once answered.',
                  style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.grey700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Pending Timeline Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTimelineCard extends StatelessWidget {
  final bool isAr;

  const _PendingTimelineCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.goldPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'مراحل مراجعة السؤال' : 'Question Progress',
                      style: GoogleFonts.tajawal(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      isAr
                          ? 'سيصلك تنبيه فوري فور اعتماد الفتوى من الشيخ'
                          : 'You will receive an alert once fatwa is issued',
                      style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.grey500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TimelineStepRow(
            stepNumber: '1',
            title: isAr ? 'استلام السؤال وتوجيهه' : 'Question Submitted',
            isCompleted: true,
            isCurrent: false,
          ),
          _TimelineStepRow(
            stepNumber: '2',
            title: isAr ? 'مراجعة وتأصيل الشيخ للفتوى' : 'Scholar Reviewing',
            isCompleted: false,
            isCurrent: true,
          ),
          _TimelineStepRow(
            stepNumber: '3',
            title: isAr ? 'اعتماد الفتوى ونشر الإجابة' : 'Fatwa Publication',
            isCompleted: false,
            isCurrent: false,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineStepRow extends StatelessWidget {
  final String stepNumber;
  final String title;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStepRow({
    required this.stepNumber,
    required this.title,
    required this.isCompleted,
    required this.isCurrent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color circleColor = isCompleted
        ? AppColors.emerald
        : isCurrent
            ? AppColors.gold
            : AppColors.grey300;
    Color textColor = isCompleted || isCurrent ? AppColors.charcoal : AppColors.grey500;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      stepNumber,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 20,
                color: isCompleted ? AppColors.emeraldLight : AppColors.grey300,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              title,
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. Rejected Notice
// ─────────────────────────────────────────────────────────────────────────────

class _RejectedNotice extends StatelessWidget {
  final bool isAr;

  const _RejectedNotice({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 24, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAr
                  ? 'تم الاعتذار عن الإجابة على هذا السؤال من قبل الشيخ.'
                  : 'The scholar was unable to answer this question.',
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
