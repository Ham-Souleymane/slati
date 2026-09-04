import 'package:flutter/material.dart';

class AdhanSoundOption {
  final String id;
  final String titleAr;
  final String titleEn;
  final String muazzinAr;
  final String muazzinEn;
  final String descriptionAr;
  final String descriptionEn;
  final String assetPath;
  final String rawResource;
  final IconData icon;
  final bool isSilent;

  const AdhanSoundOption({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.muazzinAr,
    required this.muazzinEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.assetPath,
    required this.rawResource,
    required this.icon,
    this.isSilent = false,
  });

  String title(bool isArabic) => isArabic ? titleAr : titleEn;
  String muazzin(bool isArabic) => isArabic ? muazzinAr : muazzinEn;
  String description(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  static const String defaultSoundId = 'adhan_makkah';
  static const String silentSoundId = 'silent';

  static const List<AdhanSoundOption> allSounds = [
    AdhanSoundOption(
      id: 'adhan_makkah',
      titleAr: 'أذان الحرم المكي الشريف',
      titleEn: 'Makkah Al-Mukarramah Adhan',
      muazzinAr: 'الشيخ علي أحمد ملا (شيخ المؤذنين)',
      muazzinEn: 'Sheikh Ali Ahmed Mulla',
      descriptionAr: 'الأذان الحجازي المهيب والشهير من المسجد الحرام',
      descriptionEn: 'The iconic Hijazi call to prayer from the Holy Mosque in Makkah',
      assetPath: 'assets/audio/adhan_makkah.mp3',
      rawResource: 'adhan_makkah',
      icon: Icons.mosque_rounded,
    ),
    AdhanSoundOption(
      id: 'adhan_madina',
      titleAr: 'أذان المسجد النبوي الشريف',
      titleEn: 'Madina Al-Munawwarah Adhan',
      muazzinAr: 'الشيخ محمد مروان قصاص',
      muazzinEn: 'Sheikh Muhammad Marwan Qassas',
      descriptionAr: 'أذان المدينة المنورة العذب والمؤثر من المسجد النبوي',
      descriptionEn: 'The melodious and touching call to prayer from the Prophet\'s Mosque',
      assetPath: 'assets/audio/adhan_madina.mp3',
      rawResource: 'adhan_madina',
      icon: Icons.location_city_rounded,
    ),
    AdhanSoundOption(
      id: 'adhan_default',
      titleAr: 'الأذان الكلاسيكي الهادئ',
      titleEn: 'Classic Soft Adhan',
      muazzinAr: 'أذان الحرم المختصر',
      muazzinEn: 'Traditional Short Adhan',
      descriptionAr: 'نغمة أذان هادئة وواضحة ومناسبة لجميع الأوقات',
      descriptionEn: 'Clear and gentle adhan tone suitable for all times',
      assetPath: 'assets/audio/adhan_default.mp3',
      rawResource: 'adhan',
      icon: Icons.volume_up_rounded,
    ),
    AdhanSoundOption(
      id: 'silent',
      titleAr: 'إشعار فقط (بدون صوت أذان)',
      titleEn: 'Notification Only (Mute Adhan)',
      muazzinAr: 'تنبيه صامت مع اهتزاز وإشعار',
      muazzinEn: 'Silent alert with banner & vibration',
      descriptionAr: 'الحصول على إشعار وتنبيه مرئي بالصلاة دون تشغيل صوت الأذان',
      descriptionEn: 'Receive visual notification without playing audio',
      assetPath: '',
      rawResource: '',
      icon: Icons.notifications_off_rounded,
      isSilent: true,
    ),
  ];

  static AdhanSoundOption findById(String? id) {
    if (id == null || id.isEmpty) return allSounds.first;
    // Map legacy 'adhan' id to 'adhan_default'
    final normalized = id == 'adhan' ? 'adhan_default' : id;
    return allSounds.firstWhere(
      (s) => s.id == normalized,
      orElse: () => allSounds.first,
    );
  }
}
