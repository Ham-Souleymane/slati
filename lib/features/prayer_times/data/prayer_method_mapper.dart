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

  /// Geographically infers country code directly from coordinates [lat]/[lng].
  /// Operates 100% offline without requiring device geocoding services.
  static String? detectCountryFromCoordinates(double lat, double lng) {
    // Algeria (lat 19°N to 37.2°N, lng -8.7°W to 12°E)
    if (lat >= 19.0 && lat <= 37.2 && lng >= -8.7 && lng <= 12.0) {
      // Differentiate Morocco from West Algeria if lng <= -2.1
      if (lng <= -2.1 && lat >= 27.6 && lat <= 36.0) {
        return 'MA';
      }
      // Differentiate Tunisia from East Algeria if lng >= 8.2
      if (lng >= 8.2 && lat >= 30.2 && lat <= 37.5) {
        return 'TN';
      }
      return 'DZ';
    }

    // Morocco
    if (lat >= 21.0 && lat <= 36.0 && lng >= -17.1 && lng <= -1.0) {
      return 'MA';
    }

    // Tunisia
    if (lat >= 30.2 && lat <= 37.5 && lng >= 7.5 && lng <= 11.6) {
      return 'TN';
    }

    // Egypt
    if (lat >= 22.0 && lat <= 31.7 && lng >= 25.0 && lng <= 36.9) {
      return 'EG';
    }

    // Libya
    if (lat >= 19.5 && lat <= 33.2 && lng >= 9.3 && lng <= 25.2) {
      return 'LY';
    }

    // Saudi Arabia & Arabian Peninsula
    if (lat >= 16.0 && lat <= 32.2 && lng >= 34.5 && lng <= 55.7) {
      if (lng >= 51.5 && lat <= 26.1 && lat >= 22.5) return 'AE';
      if (lng >= 50.7 && lng <= 51.7 && lat >= 24.5 && lat <= 26.2) return 'QA';
      if (lng >= 46.5 && lng <= 48.5 && lat >= 28.5 && lat <= 30.1) return 'KW';
      if (lng >= 50.3 && lng <= 50.8 && lat >= 25.8 && lat <= 26.4) return 'BH';
      if (lng >= 52.0 && lat <= 24.0) return 'OM';
      return 'SA';
    }

    // UAE
    if (lat >= 22.5 && lat <= 26.1 && lng >= 51.5 && lng <= 56.4) {
      return 'AE';
    }

    // Kuwait
    if (lat >= 28.5 && lat <= 30.1 && lng >= 46.5 && lng <= 48.5) {
      return 'KW';
    }

    // Qatar
    if (lat >= 24.5 && lat <= 26.2 && lng >= 50.7 && lng <= 51.7) {
      return 'QA';
    }

    // Jordan
    if (lat >= 29.2 && lat <= 33.4 && lng >= 34.9 && lng <= 39.3) {
      return 'JO';
    }

    // Palestine / Israel
    if (lat >= 29.5 && lat <= 33.3 && lng >= 34.2 && lng <= 35.9) {
      return 'PS';
    }

    // Turkey
    if (lat >= 36.0 && lat <= 42.1 && lng >= 26.0 && lng <= 44.8) {
      return 'TR';
    }

    // France
    if (lat >= 41.3 && lat <= 51.1 && lng >= -5.0 && lng <= 9.6) {
      return 'FR';
    }

    // United Kingdom
    if (lat >= 49.9 && lat <= 58.7 && lng >= -8.0 && lng <= 1.8) {
      return 'GB';
    }

    // Pakistan
    if (lat >= 23.6 && lat <= 37.1 && lng >= 60.9 && lng <= 77.8) {
      return 'PK';
    }

    // India
    if (lat >= 8.0 && lat <= 35.5 && lng >= 68.1 && lng <= 97.4) {
      return 'IN';
    }

    // Indonesia
    if (lat >= -11.0 && lat <= 6.0 && lng >= 95.0 && lng <= 141.0) {
      return 'ID';
    }

    // Malaysia
    if (lat >= 1.0 && lat <= 7.4 && lng >= 99.6 && lng <= 119.3) {
      return 'MY';
    }

    // USA
    if (lat >= 24.5 && lat <= 49.4 && lng >= -125.0 && lng <= -66.9) {
      return 'US';
    }

    // Canada
    if (lat >= 42.0 && lat <= 70.0 && lng >= -141.0 && lng <= -52.6) {
      return 'CA';
    }

    return null;
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
  /// Accurately aligned with official Aladhan API method IDs (https://api.aladhan.com/v1/methods).
  static const List<MapEntry<int, String>> allMethods = [
    MapEntry(2, 'الجمعية الإسلامية لأمريكا الشمالية (ISNA — زاوية 15°)'),
    MapEntry(19, 'الجزائر — وزارة الشؤون الدينية والأوقاف (زاوية 17°)'),
    MapEntry(3, 'رابطة العالم الإسلامي (MWL — زاوية 17°)'),
    MapEntry(4, 'أم القرى، مكة المكرمة (Umm Al-Qura)'),
    MapEntry(5, 'الهيئة المصرية العامة للمساحة (زاوية 17.5°)'),
    MapEntry(1, 'جامعة العلوم الإسلامية، كراتشي (Karachi)'),
    MapEntry(18, 'تونس — وزارة الشؤون الدينية'),
    MapEntry(21, 'المغرب — وزارة الأوقاف والشؤون الإسلامية'),
    MapEntry(16, 'دبي — دائرة الشؤون الإسلامية (UAE)'),
    MapEntry(9, 'الكويت — وزارة الأوقاف'),
    MapEntry(10, 'قطر — وزارة الأوقاف والشؤون الإسلامية'),
    MapEntry(23, 'الأردن — وزارة الأوقاف والمقدسات الإسلامية'),
    MapEntry(8, 'منطقة الخليج العربي'),
    MapEntry(12, 'فرنسا — اتحاد المنظمات الإسلامية (UOIF — زاوية 12°)'),
    MapEntry(13, 'تركيا — ديانت إيشلري باشقانليغي (Diyanet)'),
    MapEntry(17, 'ماليزيا — إدارة التنمية الإسلامية (JAKIM)'),
    MapEntry(20, 'إندونيسيا — وزارة الشؤون الدينية (Kemenag)'),
    MapEntry(11, 'سنغافورة — المجلس الإسلامي (MUIS)'),
    MapEntry(14, 'روسيا — الإدارة الدينية لمسلمي روسيا'),
    MapEntry(15, 'لجنة تحري الهلال العالمية (Moonsighting.com)'),
    MapEntry(22, 'البرتغال — الجالية الإسلامية في لشبونة'),
    MapEntry(7, 'معهد الجيوفيزياء، جامعة طهران'),
  ];

  /// Full list of methods available in-app for the Settings picker (English labels).
  static const List<MapEntry<int, String>> allMethodsEn = [
    MapEntry(2, 'Islamic Society of North America (ISNA — 15° angle)'),
    MapEntry(19, 'Algeria — Ministry of Religious Affairs (17° angle)'),
    MapEntry(3, 'Muslim World League (MWL — 17° angle)'),
    MapEntry(4, 'Umm Al-Qura University, Makkah'),
    MapEntry(5, 'Egyptian General Authority of Survey (17.5° angle)'),
    MapEntry(1, 'University of Islamic Sciences, Karachi'),
    MapEntry(18, 'Tunisia — Ministry of Religious Affairs'),
    MapEntry(21, 'Morocco — Ministry of Habous and Islamic Affairs'),
    MapEntry(16, 'Dubai — Islamic Affairs (UAE)'),
    MapEntry(9, 'Kuwait — Ministry of Awqaf'),
    MapEntry(10, 'Qatar — Ministry of Awqaf'),
    MapEntry(23, 'Jordan — Ministry of Awqaf'),
    MapEntry(8, 'Gulf Region'),
    MapEntry(12, 'France — UOIF (12° angle)'),
    MapEntry(13, 'Turkey — Diyanet'),
    MapEntry(17, 'Malaysia — JAKIM'),
    MapEntry(20, 'Indonesia — Kemenag'),
    MapEntry(11, 'Singapore — MUIS'),
    MapEntry(14, 'Russia — Spiritual Administration of Muslims'),
    MapEntry(15, 'Moonsighting Committee Worldwide'),
    MapEntry(22, 'Portugal — Islamic Community of Lisbon'),
    MapEntry(7, 'Institute of Geophysics, University of Tehran'),
  ];

  // ── Private tables ─────────────────────────────────────────────

  static const Map<String, int> _map = {
    // Gulf / Arabian Peninsula
    'SA': 4,  // Saudi Arabia — Umm Al-Qura
    'AE': 16, // UAE — Dubai
    'KW': 9,  // Kuwait
    'QA': 10, // Qatar
    'BH': 8,  // Bahrain — Gulf
    'OM': 8,  // Oman — Gulf
    'YE': 4,  // Yemen — Umm Al-Qura

    // North Africa
    'EG': 5,  // Egypt — Egyptian General Authority
    'DZ': 19, // Algeria — Ministry of Religious Affairs & Wakfs
    'MA': 21, // Morocco — Ministry of Habous
    'TN': 18, // Tunisia — Ministry of Religious Affairs
    'LY': 5,  // Libya — Egyptian
    'SD': 5,  // Sudan — Egyptian

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
    'ET': 3,  // Ethiopia
    'TZ': 3,  // Tanzania
    'KE': 3,  // Kenya

    // Levant / Middle East
    'JO': 23, // Jordan
    'SY': 5,  // Syria
    'LB': 5,  // Lebanon
    'IQ': 3,  // Iraq
    'PS': 3,  // Palestine
    'IL': 3,  // Israel

    // Central / South Asia
    'PK': 1,  // Pakistan — Karachi
    'BD': 1,  // Bangladesh
    'IN': 1,  // India
    'AF': 1,  // Afghanistan
    'IR': 7,  // Iran — Tehran
    'UZ': 3,  // Uzbekistan
    'TJ': 3,  // Tajikistan
    'KG': 3,  // Kyrgyzstan
    'TM': 3,  // Turkmenistan
    'KZ': 3,  // Kazakhstan
    'AZ': 3,  // Azerbaijan

    // South-East Asia
    'MY': 17, // Malaysia — JAKIM
    'ID': 20, // Indonesia — Kemenag
    'SG': 11, // Singapore — MUIS
    'BN': 17, // Brunei — JAKIM

    // Turkey
    'TR': 13, // Turkey — Diyanet

    // Europe
    'FR': 12, // France — UOIF
    'RU': 14, // Russia
    'PT': 22, // Portugal
    'BE': 3,  // Belgium
    'DE': 3,  // Germany
    'GB': 3,  // UK
    'IT': 3,  // Italy
    'NL': 3,  // Netherlands
    'ES': 3,  // Spain
    'SE': 3,  // Sweden
    'NO': 3,  // Norway
    'DK': 3,  // Denmark
    'AT': 3,  // Austria
    'CH': 3,  // Switzerland

    // North America
    'US': 2,  // USA — ISNA
    'CA': 2,  // Canada — ISNA
    'MX': 2,  // Mexico — ISNA

    // Australia / NZ
    'AU': 3,  // Australia — MWL
    'NZ': 3,  // New Zealand
  };

  static const Map<int, String> _labels = {
    1: 'جامعة العلوم الإسلامية، كراتشي',
    2: 'الجمعية الإسلامية لأمريكا الشمالية (ISNA — زاوية 15°)',
    3: 'رابطة العالم الإسلامي (MWL — زاوية 17°)',
    4: 'أم القرى، مكة المكرمة',
    5: 'الهيئة المصرية العامة للمساحة',
    7: 'معهد الجيوفيزياء، جامعة طهران',
    8: 'منطقة الخليج العربي',
    9: 'الكويت — وزارة الأوقاف',
    10: 'قطر — وزارة الأوقاف والشؤون الإسلامية',
    11: 'سنغافورة — المجلس الإسلامي (MUIS)',
    12: 'فرنسا — اتحاد المنظمات الإسلامية (UOIF)',
    13: 'تركيا — ديانت إيشلري باشقانليغي (Diyanet)',
    14: 'الإدارة الدينية لمسلمي روسيا',
    15: 'لجنة تحري الهلال العالمية',
    16: 'دبي — دائرة الشؤون الإسلامية',
    17: 'ماليزيا — إدارة التنمية الإسلامية (JAKIM)',
    18: 'تونس — وزارة الشؤون الدينية',
    19: 'الجزائر — وزارة الشؤون الدينية والأوقاف',
    20: 'إندونيسيا — وزارة الشؤون الدينية (Kemenag)',
    21: 'المغرب — وزارة الأوقاف والشؤون الإسلامية',
    22: 'البرتغال — الجالية الإسلامية في لشبونة',
    23: 'الأردن — وزارة الأوقاف والمقدسات الإسلامية',
  };

  static const Map<int, String> _labelsEn = {
    1: 'University of Islamic Sciences, Karachi',
    2: 'Islamic Society of North America (ISNA — 15°)',
    3: 'Muslim World League (MWL — 17°)',
    4: 'Umm Al-Qura University, Makkah',
    5: 'Egyptian General Authority of Survey',
    7: 'Institute of Geophysics, University of Tehran',
    8: 'Gulf Region',
    9: 'Kuwait — Ministry of Awqaf',
    10: 'Qatar — Ministry of Awqaf',
    11: 'Singapore — MUIS',
    12: 'France — UOIF (12°)',
    13: 'Turkey — Diyanet',
    14: 'Russia — Spiritual Administration of Muslims',
    15: 'Moonsighting Committee Worldwide',
    16: 'Dubai — Islamic Affairs',
    17: 'Malaysia — JAKIM',
    18: 'Tunisia — Ministry of Religious Affairs',
    19: 'Algeria — Ministry of Religious Affairs',
    20: 'Indonesia — Kemenag',
    21: 'Morocco — Ministry of Habous',
    22: 'Portugal — Islamic Community of Lisbon',
    23: 'Jordan — Ministry of Awqaf',
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
