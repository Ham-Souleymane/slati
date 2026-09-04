import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Screen
// ─────────────────────────────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.emerald,
            foregroundColor: AppColors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 20,
                bottom: 16,
              ),
              title: Text(
                isRtl ? 'سياسة الخصوصية' : 'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.emeraldDark,
                      AppColors.emerald,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      left: 60,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.goldLight.withOpacity(0.12),
                        ),
                      ),
                    ),
                    // Lock icon
                    Positioned(
                      top: 20,
                      right: 24,
                      child: Icon(
                        Icons.privacy_tip_rounded,
                        size: 42,
                        color: AppColors.white.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body Content ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                isRtl ? _arabicContent(context) : _englishContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Arabic sections ───────────────────────────────────────────

  List<Widget> _arabicContent(BuildContext context) => [
        _UpdateBadge(label: 'آخر تحديث: 2 سبتمبر 2026'),
        const SizedBox(height: 16),
        _IntroCard(
          text:
              'نحن في صلاتي قربك ("نحن"، "التطبيق"، أو "الشركة") نلتزم بحماية خصوصيتك واحترام بياناتك الشخصية. توضح سياسة الخصوصية هذه كيفية جمع بياناتك، استخدامها، مشاركتها، وحمايتها عند استخدامك لتطبيقنا والخدمات المرتبطة به.\n\nباستخدامك للتطبيق، فإنك توافق على جمع المعلومات واستخدامها وفقاً لهذه السياسة.',
        ),
        const SizedBox(height: 16),
        _PolicySection(
          number: '1',
          title: 'البيانات التي نجمعها',
          items: const [
            _BulletItem(
              label: 'بيانات الحساب والهوية:',
              body:
                  'تشمل الاسم، البريد الإلكتروني، وصورة الملف الشخصي (عند التسجيل أو إنشاء حساب).',
            ),
            _BulletItem(
              label: 'بيانات الموقع الجغرافي (Location Data):',
              body:
                  'نجمع ونعالج بيانات موقعك الدقيق (GPS) أو غير الدقيق أثناء استخدام التطبيق أو في الخلفية (في حال التفعيل) لحساب مواقيت الصلاة بدقة، وتحديد اتجاه القبلة، وإظهار المساجد القريبة منك.',
            ),
            _BulletItem(
              label: 'بيانات الاستخدام والجهاز:',
              body:
                  'تشمل نوع الجهاز، نظام التشغيل، المعرفات الفريدة للجهاز (Device ID)، عنوان IP، وسجلات التفاعل داخل التطبيق.',
            ),
            _BulletItem(
              label: 'المحتوى والتفاعلات:',
              body:
                  'أي منشورات، تعليقات، أو بلاغات تقوم بإرسالها عبر التطبيق.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '2',
          title: 'كيف نستخدم بياناتك',
          items: const [
            _BulletItem(
              label: 'تقديم الخدمات الأساسية:',
              body:
                  'عرض مواقيت الصلاة الدقيقة، القبلة، وتحديد موقع المساجد حولك.',
            ),
            _BulletItem(
              label: 'إدارة الحساب:',
              body:
                  'إنشاء حسابك الشخصي وإدارته وتمكينك من متابعة المساجد وتلقي الإشعارات.',
            ),
            _BulletItem(
              label: 'التنبيهات والإشعارات:',
              body:
                  'إرسال إشعارات الأذان، التنبيهات، وتحديثات المساجد التي تتابعها.',
            ),
            _BulletItem(
              label: 'تحسين وتطوير التطبيق:',
              body:
                  'تحليل كيفية استخدام التطبيق لإصلاح الأخطاء البرمجية وتحسين تجربة المستخدم.',
            ),
            _BulletItem(
              label: 'الأمان والحماية:',
              body:
                  'الكشف عن الأنشطة الاحتيالية أو غير المصرح بها ومنعها لحماية مستخدمينا.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '3',
          title: 'مشاركة البيانات والإفصاح عنها',
          body:
              'نحن لا نبيع بياناتك الشخصية لأي أطراف خارجية أو شبكات إعلانية. قد نشارك بياناتك فقط في الحالات التالية:',
          items: const [
            _BulletItem(
              label: 'مزودو الخدمات (Third-Party Service Providers):',
              body:
                  'مع شركات خارجية موثوقة تساعدنا في تشغيل التطبيق (مثل استضافة السيرفرات، إرسال الإشعارات، أو تحليل الأداء)، بشرط التزامهم بالسرية التامة.',
            ),
            _BulletItem(
              label: 'الامتثال القانوني:',
              body:
                  'إذا كان ذلك مطلوباً بموجب القانون أو استجابة لطلبات قانونية صحيحة من السلطات الحكومية.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '4',
          title: 'حفظ البيانات وحذفها',
          body:
              'يحتفظ التطبيق ببياناتك الشخصية طالما كان حسابك نشطاً أو طالما كان ذلك ضرورياً لتقديم الخدمات.',
          items: const [
            _BulletItem(
              label: 'حق الحذف:',
              body:
                  'يمكنك حذف حسابك وكافة البيانات المرتبطة به نهائياً في أي وقت مباشرة من داخل التطبيق عبر: الملف الشخصي › حذف الحساب.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '5',
          title: 'أمان البيانات',
          body:
              'نحن نطبق إجراءات أمنية واستباقية معقدة (بما في ذلك التشفير ونقل البيانات عبر البروتوكولات الآمنة SSL/TLS) لحماية بياناتك من الوصول غير المصرح به، أو التغيير، أو الإفصاح، أو الإتلاف.',
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '6',
          title: 'حقوقك وحماية الخصوصية',
          body: 'وفقاً لقوانين حماية البيانات العالمية، يحق لك:',
          items: const [
            _BulletItem(label: 'الوصول', body: 'إلى بياناتك الشخصية التي نحتفظ بها.'),
            _BulletItem(label: 'تصحيح', body: 'أي بيانات غير دقيقة.'),
            _BulletItem(
                label: 'طلب حذف', body: 'بياناتك أو تقييد معالجتها.'),
            _BulletItem(
              label: 'سحب موافقتك',
              body:
                  'على الوصول إلى الموقع الجغرافي أو الإشعارات في أي وقت من خلال إعدادات هاتفك.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '7',
          title: 'التغييرات على سياسة الخصوصية',
          body:
              'قد نحدّث سياسة الخصوصية هذه من وقت لآخر. سنقوم بإخطارك بأي تغييرات عن طريق نشر السياسة الجديدة على هذه الصفحة وتحديث تاريخ "آخر تحديث" في الأعلى.',
        ),
        const SizedBox(height: 24),
        _ContactCard(
          title: 'اتصل بنا',
          body: 'إذا كانت لديك أي أسئلة أو استفسارات بشأن سياسة الخصوصية، يمكنك التواصل معنا عبر:',
          email: 'stayfixsupport@gmail.com',
        ),
        const SizedBox(height: 32),
      ];

  // ── English sections ──────────────────────────────────────────

  List<Widget> _englishContent(BuildContext context) => [
        _UpdateBadge(label: 'Last Updated: September 2, 2026'),
        const SizedBox(height: 16),
        _IntroCard(
          text:
              'At Salati Qurbak ("we," "the App," or "the Company"), we are committed to protecting your privacy and respecting your personal data. This Privacy Policy explains how we collect, use, share, and safeguard your information when you use our application.\n\nBy using the App, you agree to the collection and use of information in accordance with this policy.',
        ),
        const SizedBox(height: 16),
        _PolicySection(
          number: '1',
          title: 'Data We Collect',
          items: const [
            _BulletItem(
              label: 'Account & Identity Data:',
              body:
                  'Including your name, email address, and profile picture (when you register or create an account).',
            ),
            _BulletItem(
              label: 'Location Data:',
              body:
                  'We collect and process your precise (GPS) or approximate location while using the App or in the background (if enabled) to calculate prayer times, determine the Qibla direction, and display nearby mosques.',
            ),
            _BulletItem(
              label: 'Usage & Device Data:',
              body:
                  'Including device type, OS, unique device identifiers (Device ID), IP address, and in-app interaction logs.',
            ),
            _BulletItem(
              label: 'Content & Interactions:',
              body: 'Any posts, comments, or reports you submit through the App.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '2',
          title: 'How We Use Your Data',
          items: const [
            _BulletItem(
              label: 'Core Services:',
              body:
                  'Displaying accurate prayer times, Qibla direction, and locating mosques near you.',
            ),
            _BulletItem(
              label: 'Account Management:',
              body:
                  'Creating and managing your account, enabling you to follow mosques and receive notifications.',
            ),
            _BulletItem(
              label: 'Alerts & Notifications:',
              body:
                  'Sending Adhan notifications, reminders, and updates about mosques you follow.',
            ),
            _BulletItem(
              label: 'App Improvement:',
              body: 'Analyzing usage to fix bugs and enhance the user experience.',
            ),
            _BulletItem(
              label: 'Security & Protection:',
              body:
                  'Detecting and preventing fraudulent or unauthorized activities to protect our users.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '3',
          title: 'Data Sharing & Disclosure',
          body:
              'We do not sell your personal data to any third parties or advertising networks. We may share your data only in these cases:',
          items: const [
            _BulletItem(
              label: 'Third-Party Service Providers:',
              body:
                  'With trusted companies that help us operate the App (hosting, push notifications, analytics), subject to strict confidentiality.',
            ),
            _BulletItem(
              label: 'Legal Compliance:',
              body:
                  'When required by law or in response to valid legal requests from governmental authorities.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '4',
          title: 'Data Retention & Deletion',
          body:
              'The App retains your personal data for as long as your account is active or as necessary to provide services.',
          items: const [
            _BulletItem(
              label: 'Right to Delete:',
              body:
                  'You can permanently delete your account and all associated data at any time via: Profile › Delete Account.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '5',
          title: 'Data Security',
          body:
              'We implement robust security measures — including encryption and secure data transmission via SSL/TLS protocols — to protect your data from unauthorized access, alteration, disclosure, or destruction.',
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '6',
          title: 'Your Rights & Privacy Protections',
          body: 'Under global data protection laws, you have the right to:',
          items: const [
            _BulletItem(label: 'Access', body: 'the personal data we hold about you.'),
            _BulletItem(label: 'Correct', body: 'any inaccurate data.'),
            _BulletItem(
                label: 'Request deletion', body: 'of your data or restrict its processing.'),
            _BulletItem(
              label: 'Withdraw consent',
              body:
                  'for location access or notifications at any time through your device settings.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PolicySection(
          number: '7',
          title: 'Changes to This Privacy Policy',
          body:
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "Last Updated" date at the top.',
        ),
        const SizedBox(height: 24),
        _ContactCard(
          title: 'Contact Us',
          body:
              'If you have any questions or concerns about this Privacy Policy or how your data is handled, reach us at:',
          email: 'stayfixsupport@gmail.com',
        ),
        const SizedBox(height: 32),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _UpdateBadge extends StatelessWidget {
  final String label;
  const _UpdateBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.emeraldPale,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.emeraldLight.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: AppColors.emerald),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String text;
  const _IntroCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldPale,
            AppColors.emeraldPale.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13.5,
          height: 1.85,
          color: AppColors.grey700,
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String number;
  final String title;
  final String? body;
  final List<_BulletItem> items;

  const _PolicySection({
    required this.number,
    required this.title,
    this.body,
    this.items = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.emeraldDark, AppColors.emeraldLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraldDark,
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
                if (body != null) ...[
                  Text(
                    body!,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.75,
                      color: AppColors.grey700,
                    ),
                  ),
                  if (items.isNotEmpty) const SizedBox(height: 10),
                ],
                ...items,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String label;
  final String body;
  const _BulletItem({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                      height: 1.65,
                    ),
                  ),
                  TextSpan(
                    text: body,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.grey700,
                      height: 1.65,
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

class _ContactCard extends StatelessWidget {
  final String title;
  final String body;
  final String email;
  const _ContactCard({
    required this.title,
    required this.body,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emeraldDark, AppColors.emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline_rounded,
                  color: AppColors.goldLight, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.7,
              color: AppColors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: AppColors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_rounded,
                    size: 15, color: AppColors.goldLight),
                const SizedBox(width: 8),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
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
