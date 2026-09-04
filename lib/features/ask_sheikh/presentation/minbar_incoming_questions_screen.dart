import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../mosques/data/mosque_repository.dart';
import '../data/question_repository.dart';
import '../domain/islamic_field.dart';
import '../domain/question_model.dart';
import 'minbar_answer_screen.dart';

class MinbarIncomingQuestionsScreen extends ConsumerStatefulWidget {
  final String? imamId;

  const MinbarIncomingQuestionsScreen({super.key, this.imamId});

  @override
  ConsumerState<MinbarIncomingQuestionsScreen> createState() =>
      _MinbarIncomingQuestionsScreenState();
}

class _MinbarIncomingQuestionsScreenState
    extends ConsumerState<MinbarIncomingQuestionsScreen> {
  String? _selectedField; // null = all

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    // Determine the current imam's ID
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final currentImamId = widget.imamId ?? currentUser?.uid ?? '';

    final imamAsync = ref.watch(imamByIdProvider(currentImamId));
    final imam = imamAsync.asData?.value;

    final questionsAsync =
        ref.watch(imamQuestionsProvider(currentImamId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.emeraldLight,
              backgroundImage: (imam?.photoUrl != null &&
                      imam!.photoUrl!.isNotEmpty)
                  ? NetworkImage(imam.photoUrl!)
                  : null,
              child: (imam?.photoUrl == null || imam!.photoUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              _isAr ? 'منبر - الأسئلة الواردة' : 'Minbar - Incoming Questions',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Horizontal category filters ────────────────────────
          Container(
            color: AppColors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _CategoryFilterChip(
                    label: _isAr ? 'الكل' : 'All',
                    isSelected: _selectedField == null,
                    onTap: () => setState(() => _selectedField = null),
                  ),
                  ...IslamicField.values.map(
                    (f) => _CategoryFilterChip(
                      label: '${f.icon} ${f.label(_isAr)}',
                      isSelected: _selectedField == f.id,
                      onTap: () => setState(() =>
                          _selectedField = _selectedField == f.id ? null : f.id),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Questions list / grid ──────────────────────────────
          Expanded(
            child: questionsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.emerald),
              ),
              error: (e, _) => Center(
                child: Text(
                  _isAr
                      ? 'حدث خطأ في تحميل الأسئلة'
                      : 'Error loading questions',
                  style: GoogleFonts.tajawal(color: AppColors.error),
                ),
              ),
              data: (questions) {
                final filtered = _selectedField == null
                    ? questions
                    : questions
                        .where((q) => q.field == _selectedField)
                        .toList();

                if (filtered.isEmpty) {
                  return _EmptyIncomingState(
                    selectedField: _selectedField,
                    isAr: _isAr,
                  );
                }

                // Calculate stats
                final answeredCount =
                    questions.where((q) => q.isAnswered).length;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  itemCount: filtered.length + 1, // +1 for the stats banner
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _WeeklyStatsCard(
                        answeredCount: answeredCount,
                        isAr: _isAr,
                      );
                    }

                    final q = filtered[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _IncomingQuestionCard(
                        index: index,
                        question: q,
                        isAr: _isAr,
                        onAnswer: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MinbarAnswerScreen(
                                question: q,
                                imamId: currentImamId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emeraldDark : AppColors.grey100,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? AppColors.emeraldDark : AppColors.grey300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.grey700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly Stats Card
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyStatsCard extends StatelessWidget {
  final int answeredCount;
  final bool isAr;

  const _WeeklyStatsCard({
    required this.answeredCount,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emeraldPale.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.emeraldLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppColors.emerald,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? '$answeredCount سؤالاً مُجاباً'
                      : '$answeredCount Answered Questions',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldDark,
                  ),
                ),
                Text(
                  isAr
                      ? 'بارك الله في علمكم ووقتكم ونفع بكم الأمة.'
                      : 'May Allah bless your knowledge and time.',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: AppColors.grey700,
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
// Incoming Question Card
// ─────────────────────────────────────────────────────────────────────────────

class _IncomingQuestionCard extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final bool isAr;
  final VoidCallback onAnswer;

  const _IncomingQuestionCard({
    required this.index,
    required this.question,
    required this.isAr,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final field = IslamicField.fromId(question.field);
    final isAnswered = question.isAnswered;
    final isFollowUpPending = question.isFollowUpPending;
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(question.createdAt);

    Color badgeBg;
    Color badgeFg;
    String badgeText;

    if (isFollowUpPending) {
      badgeBg = AppColors.goldPale;
      badgeFg = AppColors.gold;
      badgeText = isAr ? 'استفسار إضافي' : 'Follow-up';
    } else if (isAnswered) {
      badgeBg = AppColors.grey100;
      badgeFg = AppColors.grey700;
      badgeText = isAr ? 'تمت الإجابة' : 'Answered';
    } else {
      badgeBg = AppColors.emeraldDark;
      badgeFg = Colors.white;
      badgeText = isAr ? 'جديد' : 'New';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFollowUpPending
              ? AppColors.gold.withValues(alpha: 0.5)
              : isAnswered
                  ? AppColors.divider
                  : AppColors.emeraldLight.withValues(alpha: 0.5),
          width: isAnswered ? 1 : 1.3,
        ),
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
          // ── Header Bar with Green Number Badge & Title ────────────────
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
                // Green number badge
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
                    '$index',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    question.title,
                    style: GoogleFonts.tajawal(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldDark,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Body text snippet
                Text(
                  isFollowUpPending && question.replies.isNotEmpty
                      ? question.replies.last.message
                      : question.body,
                  style: GoogleFonts.tajawal(
                    fontSize: 13.5,
                    color: AppColors.grey700,
                    height: 1.65,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Bullet: Asker
                _IncomingBulletItem(
                  label: isAr ? 'السائل:' : 'Asker:',
                  value: question.isAnonymous
                      ? (isAr ? 'مجهول الهوية 🔒' : 'Anonymous 🔒')
                      : (question.userDisplayName.isNotEmpty
                          ? question.userDisplayName
                          : (isAr ? 'مُصلٍّ' : 'Worshipper')),
                ),

                // Bullet: Field
                _IncomingBulletItem(
                  label: isAr ? 'المجال والتخصص:' : 'Field:',
                  value: field != null
                      ? '${field.icon} ${field.label(isAr)}'
                      : IslamicField.labelForId(question.field, isArabic: isAr),
                ),

                // Bullet: Date
                _IncomingBulletItem(
                  label: isAr ? 'تاريخ الإرسال:' : 'Date:',
                  value: dateStr,
                ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 10),

                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowUpPending
                            ? AppColors.gold
                            : isAnswered
                                ? AppColors.grey100
                                : AppColors.emeraldDark,
                        foregroundColor: isAnswered && !isFollowUpPending
                            ? AppColors.emeraldDark
                            : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: (!isFollowUpPending && isAnswered)
                              ? const BorderSide(color: AppColors.emerald)
                              : BorderSide.none,
                        ),
                      ),
                      icon: Icon(
                        isFollowUpPending
                            ? Icons.reply_rounded
                            : isAnswered
                                ? Icons.visibility_rounded
                                : Icons.edit_note_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isFollowUpPending
                            ? (isAr ? 'الرد على الاستفسار' : 'Reply to Follow-up')
                            : isAnswered
                                ? (isAr ? 'عرض الإجابة' : 'View Answer')
                                : (isAr ? 'أجب الآن' : 'Answer Now'),
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingBulletItem extends StatelessWidget {
  final String label;
  final String value;

  const _IncomingBulletItem({required this.label, required this.value});

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

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyIncomingState extends StatelessWidget {
  final String? selectedField;
  final bool isAr;

  const _EmptyIncomingState({
    required this.selectedField,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.emeraldPale),
            const SizedBox(height: 16),
            Text(
              isAr
                  ? 'لا توجد أسئلة واردة حالياً'
                  : 'No incoming questions at the moment',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.grey700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'ستظهر هنا الأسئلة الموجهة إليكم من المصلين عبر تطبيق صلاتي.'
                  : 'Questions directed to you from worshippers will appear here.',
              style: GoogleFonts.tajawal(
                fontSize: 13,
                color: AppColors.grey500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
