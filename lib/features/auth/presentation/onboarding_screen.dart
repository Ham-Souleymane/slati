import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      title: 'مواقيت الصلاة الدقيقة',
      description: 'تعرف على أوقات الصلاة بدقة بناءً على موقعك، مع إشعارات وتنبيهات عند دخول الوقت.',
      icon: Icons.access_time_filled_rounded,
    ),
    _OnboardingPage(
      title: 'اكتشف المساجد القريبة',
      description: 'تصفح المساجد من حولك، تابع إعلاناتها، وتعرف على الأنشطة والمناسبات المقامة فيها.',
      icon: Icons.mosque_rounded,
    ),
    _OnboardingPage(
      title: 'تواصل مع الأئمة',
      description: 'اطرح أسئلتك مباشرة على أئمة المساجد واحصل على إجابات موثوقة بكل سهولة وسرية.',
      icon: Icons.chat_bubble_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              // Top action (Skip)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'تخطي',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey500,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  reverse: true, // Forces Arabic RTL swipe order
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.emerald, AppColors.emeraldDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              page.icon,
                              size: 64,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            page.title,
                            style: GoogleFonts.tajawal(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emeraldDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.description,
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              height: 1.6,
                              color: AppColors.grey700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Centered Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 10,
                          width: _currentIndex == index ? 32 : 10,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? AppColors.emerald
                                : AppColors.grey300,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ).reversed.toList(),
                    ),
                    const SizedBox(height: 32),

                    // Next / Start Button (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentIndex == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
