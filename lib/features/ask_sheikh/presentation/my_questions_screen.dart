import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../data/question_repository.dart';
import '../domain/islamic_field.dart';
import '../domain/question_model.dart';

class MyQuestionsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const MyQuestionsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<MyQuestionsScreen> createState() => _MyQuestionsScreenState();
}

class _MyQuestionsScreenState extends ConsumerState<MyQuestionsScreen> {
  QuestionStatus? _selectedStatus; // null = all

  bool get _isAr =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(myQuestionsProvider);

    final content = Column(
      children: [
        // ── Filter status chips ─────────────────────────────────
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StatusFilterChip(
                label: _isAr ? 'الكل' : 'All',
                isSelected: _selectedStatus == null,
                onTap: () => setState(() => _selectedStatus = null),
              ),
              const SizedBox(width: 8),
              _StatusFilterChip(
                label: _isAr ? 'تمت الإجابة' : 'Answered',
                isSelected: _selectedStatus == QuestionStatus.answered,
                onTap: () => setState(
                    () => _selectedStatus = QuestionStatus.answered),
              ),
              const SizedBox(width: 8),
              _StatusFilterChip(
                label: _isAr ? 'قيد الانتظار' : 'Pending',
                isSelected: _selectedStatus == QuestionStatus.pending,
                onTap: () => setState(
                    () => _selectedStatus = QuestionStatus.pending),
              ),
            ],
          ),
        ),

        // ── List of questions ───────────────────────────────────
        Expanded(
          child: questionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.emerald),
            ),
            error: (e, _) => Center(
              child: Text(
                _isAr ? 'حدث خطأ أثناء تحميل الأسئلة' : 'Error loading questions',
                style: GoogleFonts.tajawal(color: AppColors.error),
              ),
            ),
            data: (questions) {
              final filtered = _selectedStatus == null
                  ? questions
                  : questions
                      .where((q) => q.status == _selectedStatus)
                      .toList();

              if (filtered.isEmpty) {
                return _EmptyMyQuestionsState(
                  status: _selectedStatus,
                  isAr: _isAr,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final q = filtered[i];
                  return _QuestionCard(
                    index: i + 1,
                    question: q,
                    isAr: _isAr,
                    onTap: () => context.push(
                      AppRoutes.questionDetail,
                      extra: q,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isAr ? 'أسئلتي' : 'My Questions',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
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
// Question Card
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final bool isAr;
  final VoidCallback onTap;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final field = IslamicField.fromId(question.field);
    final isAnswered = question.isAnswered;
    final dateStr = DateFormat('yyyy/MM/dd').format(question.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAnswered
                  ? AppColors.emeraldLight.withValues(alpha: 0.4)
                  : AppColors.divider,
              width: 1.2,
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
                    _StatusBadge(
                      status: question.status,
                      isAr: isAr,
                      isFollowUp: question.isFollowUpPending,
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
                    // Question text snippet
                    Text(
                      question.body,
                      style: GoogleFonts.tajawal(
                        fontSize: 13.5,
                        color: AppColors.grey700,
                        height: 1.65,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    // Bullet: Sheikh
                    _QuestionBulletItem(
                      label: isAr ? 'الشيخ المُوجّه إليه:' : 'Scholar:',
                      value: question.imamName.isNotEmpty
                          ? question.imamName
                          : (isAr ? 'الشيخ' : 'The Sheikh'),
                    ),

                    // Bullet: Islamic Field
                    _QuestionBulletItem(
                      label: isAr ? 'المجال والتخصص:' : 'Field:',
                      value: field != null
                          ? '${field.icon} ${field.label(isAr)}'
                          : IslamicField.labelForId(question.field, isArabic: isAr),
                    ),

                    // Bullet: Date
                    _QuestionBulletItem(
                      label: isAr ? 'تاريخ الإرسال:' : 'Date:',
                      value: dateStr,
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),

                    // Bottom Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          isAnswered
                              ? (isAr ? 'عرض الإجابة والفتوى' : 'View Answer')
                              : (isAr ? 'عرض تفاصيل السؤال' : 'View Details'),
                          style: GoogleFonts.tajawal(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isAnswered ? AppColors.emerald : AppColors.grey500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: isAnswered ? AppColors.emerald : AppColors.grey500,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionBulletItem extends StatelessWidget {
  final String label;
  final String value;

  const _QuestionBulletItem({required this.label, required this.value});

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
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final QuestionStatus status;
  final bool isAr;
  final bool isFollowUp;

  const _StatusBadge({
    required this.status,
    required this.isAr,
    this.isFollowUp = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    if (isFollowUp) {
      bg = AppColors.goldPale;
      fg = AppColors.gold;
      text = isAr ? 'استفسار قيد المراجعة' : 'Follow-up Pending';
    } else {
      switch (status) {
        case QuestionStatus.answered:
          bg = AppColors.emeraldPale;
          fg = AppColors.emeraldDark;
          text = isAr ? 'تمت الإجابة' : 'Answered';
          break;
        case QuestionStatus.pending:
          bg = AppColors.goldPale;
          fg = AppColors.gold;
          text = isAr ? 'قيد الانتظار' : 'Pending';
          break;
        case QuestionStatus.rejected:
          bg = AppColors.error.withValues(alpha: 0.1);
          fg = AppColors.error;
          text = isAr ? 'مرفوض' : 'Rejected';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.tajawal(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMyQuestionsState extends StatelessWidget {
  final QuestionStatus? status;
  final bool isAr;

  const _EmptyMyQuestionsState({this.status, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: AppColors.emeraldPale),
            const SizedBox(height: 16),
            Text(
              status == null
                  ? (isAr
                      ? 'لم تطرح أي أسئلة بعد'
                      : 'You haven\'t asked any questions yet')
                  : (isAr
                      ? 'لا توجد أسئلة بهذه الحالة'
                      : 'No questions with this status'),
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.grey700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'اختر شيخاً من تبويب "العلماء" واطرح سؤالك'
                  : 'Select a scholar from the Scholars tab and ask your question',
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
