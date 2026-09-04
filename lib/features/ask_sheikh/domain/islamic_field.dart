/// The 8 Islamic academic fields used for the "Ask the Sheikh" feature.
///
/// The [id] is the Firestore-stored key. [labelAr] / [labelEn] are for UI.
/// Additional fields can be added by the admin without a code change —
/// just store new IDs in Firestore; only the display labels need an update here.
enum IslamicField {
  aqeedah(
    id: 'aqeedah',
    labelAr: 'العقيدة',
    labelEn: 'Aqeedah',
    icon: '📖',
  ),
  fiqh(
    id: 'fiqh',
    labelAr: 'الفقه',
    labelEn: 'Fiqh',
    icon: '⚖️',
  ),
  muamalat(
    id: 'muamalat',
    labelAr: 'المعاملات',
    labelEn: 'Mu\'amalat',
    icon: '🤝',
  ),
  history(
    id: 'history',
    labelAr: 'التاريخ و السير',
    labelEn: 'History & Seerah',
    icon: '📜',
  ),
  language(
    id: 'language',
    labelAr: 'اللغة',
    labelEn: 'Arabic Language',
    icon: '✍️',
  ),
  hadith(
    id: 'hadith',
    labelAr: 'علم الحديث',
    labelEn: 'Hadith Sciences',
    icon: '📚',
  ),
  usul(
    id: 'usul',
    labelAr: 'أصول الفقه',
    labelEn: 'Usul al-Fiqh',
    icon: '🏛️',
  ),
  tafsir(
    id: 'tafsir',
    labelAr: 'التفسير و علومه',
    labelEn: 'Tafsir & Quranic Sciences',
    icon: '🌙',
  );

  const IslamicField({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
  });

  final String id;
  final String labelAr;
  final String labelEn;
  final String icon;

  String label(bool isArabic) => isArabic ? labelAr : labelEn;

  /// Looks up a field by its Firestore ID.
  /// Returns null if the ID is unknown (for future admin-added fields).
  static IslamicField? fromId(String id) {
    for (final f in values) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Returns the Arabic label for an unknown field ID (fallback for
  /// admin-added fields not yet in this enum).
  static String labelForId(String id, {bool isArabic = true}) {
    final field = fromId(id);
    if (field != null) return isArabic ? field.labelAr : field.labelEn;
    return id; // raw ID as last resort
  }

  /// All field IDs, for use in Firestore queries.
  static List<String> get allIds => values.map((f) => f.id).toList();
}
