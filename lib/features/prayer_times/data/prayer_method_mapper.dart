/// Maps country ISO-3166-1 alpha-2 codes to Aladhan calculation method IDs.
///
/// Full Aladhan method list: https://aladhan.com/calculation-methods
/// The list is deliberately comprehensive for the most populated Muslim-majority
/// and diaspora countries. Unmapped countries fall back to method 3 (MWL).
abstract class PrayerMethodMapper {
  PrayerMethodMapper._();

  /// Returns the Aladhan method ID most appropriate for [countryCode].
  /// Falls back to MWL (3) for unmapped countries.
  static int methodForCountry(String countryCode) {
    return _map[countryCode.toUpperCase()] ?? 3;
  }

  /// Returns the Aladhan school ID most appropriate for [countryCode].
  /// 1 = Hanafi (later Asr timing), 0 = Shafi'i/Maliki/Hanbali (standard, default).
  /// Falls back to 0 (Shafi'i) for unmapped countries.
  static int schoolForCountry(String countryCode) {
    return _schoolMap[countryCode.toUpperCase()] ?? 0;
  }

  /// Human-readable label for [methodId] (Arabic).
  static String labelForMethod(int methodId) {
    return _labels[methodId] ?? 'رابطة العالم الإسلامي (MWL)';
  }

  /// Human-readable label for [methodId] (English).
  static String labelForMethodEn(int methodId) {
    return _labelsEn[methodId] ?? 'Muslim World League (MWL)';
  }

  /// Full list of methods available in-app for the Settings picker (Arabic labels).
  static const List<MapEntry<int, String>> allMethods = [
    MapEntry(1, 'هيئة الرصد الجوي الكويتية'),
    MapEntry(2, 'جامعة العلوم الإسلامية، كراتشي'),
    MapEntry(3, 'رابطة العالم الإسلامي (MWL)'),
    MapEntry(4, 'أم القرى، مكة المكرمة'),
    MapEntry(5, 'الهيئة المصرية العامة للمساحة'),
    MapEntry(7, 'اتحاد المنظمات الإسلامية في أمريكا الشمالية (ISNA)'),
    MapEntry(8, 'الخليج العربي'),
    MapEntry(9, 'ديانت إيشلري باشقانليغي (تركيا)'),
    MapEntry(10, 'الجزائر — وزارة الشؤون الدينية'),
    MapEntry(11, 'لجنة التحقق الوطنية (اندونيسيا)'),
    MapEntry(12, 'المجلس الإسلامي للفرنسيين في المناطق الشمالية'),
    MapEntry(13, 'المطالبة الرسمية العُمانية'),
    MapEntry(14, 'قطر — وزارة الشؤون الدينية'),
    MapEntry(15, 'سنغافورة'),
    MapEntry(16, 'اتحاد المنظمات الإسلامية في فرنسا (UOIF)'),
    MapEntry(17, 'دائرة الشؤون الدينية، كوالالمبور'),
    MapEntry(18, 'المغرب — وزارة الأوقاف'),
    MapEntry(19, 'الجامعة الإسلامية في الإمارات'),
    MapEntry(21, 'المجلس الأوروبي للإفتاء والبحوث'),
    MapEntry(22, 'الجمعية الإسلامية في أمريكا الشمالية (Canada)'),
    MapEntry(23, 'التقويم الرسمي — بنجلاديش'),
    MapEntry(24, 'هيئة أبوظبي للزراعة والسلامة الغذائية'),
  ];

  /// Full list of methods available in-app for the Settings picker (English labels).
  static const List<MapEntry<int, String>> allMethodsEn = [
    MapEntry(1, 'Kuwait Meteorological Authority'),
    MapEntry(2, 'University of Islamic Sciences, Karachi'),
    MapEntry(3, 'Muslim World League (MWL)'),
    MapEntry(4, 'Umm Al-Qura, Makkah'),
    MapEntry(5, 'Egyptian General Authority of Survey'),
    MapEntry(7, 'Islamic Society of North America (ISNA)'),
    MapEntry(8, 'Gulf Region'),
    MapEntry(9, 'Diyanet İşleri Başkanlığı (Turkey)'),
    MapEntry(10, 'Algeria — Ministry of Religious Affairs'),
    MapEntry(11, 'National Verification Committee (Indonesia)'),
    MapEntry(12, 'Islamic Council of France (North)'),
    MapEntry(13, 'Omani Official Method'),
    MapEntry(14, 'Qatar — Ministry of Religious Affairs'),
    MapEntry(15, 'Singapore'),
    MapEntry(16, 'Union of Islamic Organisations in France (UOIF)'),
    MapEntry(17, 'Department of Islamic Development, Kuala Lumpur'),
    MapEntry(18, 'Morocco — Ministry of Awqaf'),
    MapEntry(19, 'Islamic University of UAE'),
    MapEntry(21, 'European Council for Fatwa and Research'),
    MapEntry(22, 'Islamic Association of North America (Canada)'),
    MapEntry(23, 'Official Calendar — Bangladesh'),
    MapEntry(24, 'Abu Dhabi Agriculture and Food Safety Authority'),
  ];

  // ── Private tables ─────────────────────────────────────────────

  static const Map<String, int> _map = {
    // Gulf / Arabian Peninsula
    'SA': 4,  // Saudi Arabia — Umm Al-Qura
    'AE': 8,  // UAE
    'KW': 1,  // Kuwait
    'QA': 14, // Qatar
    'BH': 8,  // Bahrain
    'OM': 13, // Oman
    'YE': 4,  // Yemen

    // North Africa
    'EG': 5,  // Egypt
    'DZ': 10, // Algeria
    'MA': 18, // Morocco
    'TN': 5,  // Tunisia
    'LY': 5,  // Libya
    'SD': 5,  // Sudan

    // Sub-Saharan Africa (Muslim-majority)
    'MR': 3,  // Mauritania
    'ML': 3,  // Mali
    'NE': 3,  // Niger
    'SN': 3,  // Senegal
    'GM': 3,  // Gambia
    'GN': 3,  // Guinea
    'GW': 3,  // Guinea-Bissau
    'SL': 3,  // Sierra Leone
    'CI': 3,  // Côte d'Ivoire
    'NG': 3,  // Nigeria
    'BF': 3,  // Burkina Faso
    'TD': 3,  // Chad
    'SO': 3,  // Somalia
    'ET': 3,  // Ethiopia (partial)
    'TZ': 3,  // Tanzania
    'KE': 3,  // Kenya (diaspora)

    // Levant / Middle East
    'JO': 3,  // Jordan
    'SY': 5,  // Syria
    'LB': 5,  // Lebanon
    'IQ': 3,  // Iraq
    'PS': 3,  // Palestine
    'IL': 3,  // Israel

    // Central / South Asia
    'PK': 2,  // Pakistan — Karachi
    'BD': 23, // Bangladesh
    'IN': 2,  // India
    'AF': 2,  // Afghanistan
    'IR': 7,  // Iran
    'UZ': 3,  // Uzbekistan
    'TJ': 3,  // Tajikistan
    'KG': 3,  // Kyrgyzstan
    'TM': 3,  // Turkmenistan
    'KZ': 3,  // Kazakhstan
    'AZ': 3,  // Azerbaijan

    // South-East Asia
    'MY': 17, // Malaysia
    'ID': 11, // Indonesia
    'SG': 15, // Singapore
    'BN': 17, // Brunei

    // Turkey
    'TR': 9,  // Turkey (Diyanet)

    // Europe (Muslim minority)
    'FR': 16, // France — UOIF
    'BE': 21, // Belgium — ECFR
    'DE': 3,  // Germany — MWL
    'GB': 3,  // UK — MWL
    'IT': 21, // Italy — ECFR
    'NL': 21, // Netherlands — ECFR
    'ES': 21, // Spain — ECFR
    'SE': 3,  // Sweden
    'NO': 3,  // Norway
    'DK': 3,  // Denmark
    'AT': 21, // Austria — ECFR
    'CH': 3,  // Switzerland
    'RU': 3,  // Russia

    // North America
    'US': 7,  // USA — ISNA
    'CA': 22, // Canada
    'MX': 7,  // Mexico

    // Australia / NZ
    'AU': 3,  // Australia — MWL
    'NZ': 3,  // New Zealand
  };

  static const Map<int, String> _labels = {
    1: 'هيئة الرصد الجوي الكويتية',
    2: 'جامعة العلوم الإسلامية، كراتشي',
    3: 'رابطة العالم الإسلامي (MWL)',
    4: 'أم القرى، مكة المكرمة',
    5: 'الهيئة المصرية العامة للمساحة',
    7: 'اتحاد المنظمات الإسلامية في أمريكا الشمالية (ISNA)',
    8: 'الخليج العربي',
    9: 'ديانت إيشلري باشقانليغي (تركيا)',
    10: 'الجزائر — وزارة الشؤون الدينية',
    11: 'لجنة التحقق الوطنية (اندونيسيا)',
    12: 'المجلس الإسلامي للفرنسيين في المناطق الشمالية',
    13: 'المطالبة الرسمية العُمانية',
    14: 'قطر — وزارة الشؤون الدينية',
    15: 'سنغافورة',
    16: 'اتحاد المنظمات الإسلامية في فرنسا (UOIF)',
    17: 'دائرة الشؤون الدينية، كوالالمبور',
    18: 'المغرب — وزارة الأوقاف',
    19: 'الجامعة الإسلامية في الإمارات',
    21: 'المجلس الأوروبي للإفتاء والبحوث',
    22: 'الجمعية الإسلامية في أمريكا الشمالية (Canada)',
    23: 'التقويم الرسمي — بنجلاديش',
    24: 'هيئة أبوظبي للزراعة والسلامة الغذائية',
  };

  static const Map<int, String> _labelsEn = {
    1: 'Kuwait Meteorological Authority',
    2: 'University of Islamic Sciences, Karachi',
    3: 'Muslim World League (MWL)',
    4: 'Umm Al-Qura, Makkah',
    5: 'Egyptian General Authority of Survey',
    7: 'Islamic Society of North America (ISNA)',
    8: 'Gulf Region',
    9: 'Diyanet İşleri Başkanlığı (Turkey)',
    10: 'Algeria — Ministry of Religious Affairs',
    11: 'National Verification Committee (Indonesia)',
    12: 'Islamic Council of France (North)',
    13: 'Omani Official Method',
    14: 'Qatar — Ministry of Religious Affairs',
    15: 'Singapore',
    16: 'Union of Islamic Organisations in France (UOIF)',
    17: 'Department of Islamic Development, Kuala Lumpur',
    18: 'Morocco — Ministry of Awqaf',
    19: 'Islamic University of UAE',
    21: 'European Council for Fatwa and Research',
    22: 'Islamic Association of North America (Canada)',
    23: 'Official Calendar — Bangladesh',
    24: 'Abu Dhabi Agriculture and Food Safety Authority',
  };

  /// Maps country codes to Aladhan school IDs.
  /// 1 = Hanafi, 0 = Shafi'i/Maliki/Hanbali (default — not listed here).
  static const Map<String, int> _schoolMap = {
    // Hanafi-majority countries
    'PK': 1, // Pakistan
    'AF': 1, // Afghanistan
    'BD': 1, // Bangladesh
    'IN': 1, // India (majority Hanafi)
    'TR': 1, // Turkey
    'UZ': 1, // Uzbekistan
    'TJ': 1, // Tajikistan
    'KG': 1, // Kyrgyzstan
    'TM': 1, // Turkmenistan
    'KZ': 1, // Kazakhstan
    'AZ': 1, // Azerbaijan
    'AM': 1, // Armenia (Muslim minority, Hanafi)
    'GE': 1, // Georgia (Muslim minority, Hanafi)
    'RU': 1, // Russia (majority Hanafi in Muslim communities)
    'AL': 1, // Albania
    'BA': 1, // Bosnia and Herzegovina
    'MK': 1, // North Macedonia
    'XK': 1, // Kosovo
  };
}
