// Facts not present in the QUL layout/text files. Kept as static tables and
// cross-checked against the QUL data by QuranDataIntegrityTests.

public enum StaticTables {
    /// (Arabic name, English transliteration), index 0 = surah 1.
    public static let surahNames: [(ar: String, en: String)] = [
        ("الفاتحة", "Al-Fatihah"), ("البقرة", "Al-Baqarah"), ("آل عمران", "Ali 'Imran"),
        ("النساء", "An-Nisa"), ("المائدة", "Al-Ma'idah"), ("الأنعام", "Al-An'am"),
        ("الأعراف", "Al-A'raf"), ("الأنفال", "Al-Anfal"), ("التوبة", "At-Tawbah"),
        ("يونس", "Yunus"), ("هود", "Hud"), ("يوسف", "Yusuf"),
        ("الرعد", "Ar-Ra'd"), ("إبراهيم", "Ibrahim"), ("الحجر", "Al-Hijr"),
        ("النحل", "An-Nahl"), ("الإسراء", "Al-Isra"), ("الكهف", "Al-Kahf"),
        ("مريم", "Maryam"), ("طه", "Taha"), ("الأنبياء", "Al-Anbya"),
        ("الحج", "Al-Hajj"), ("المؤمنون", "Al-Mu'minun"), ("النور", "An-Nur"),
        ("الفرقان", "Al-Furqan"), ("الشعراء", "Ash-Shu'ara"), ("النمل", "An-Naml"),
        ("القصص", "Al-Qasas"), ("العنكبوت", "Al-'Ankabut"), ("الروم", "Ar-Rum"),
        ("لقمان", "Luqman"), ("السجدة", "As-Sajdah"), ("الأحزاب", "Al-Ahzab"),
        ("سبأ", "Saba"), ("فاطر", "Fatir"), ("يس", "Ya-Sin"),
        ("الصافات", "As-Saffat"), ("ص", "Sad"), ("الزمر", "Az-Zumar"),
        ("غافر", "Ghafir"), ("فصلت", "Fussilat"), ("الشورى", "Ash-Shuraa"),
        ("الزخرف", "Az-Zukhruf"), ("الدخان", "Ad-Dukhan"), ("الجاثية", "Al-Jathiyah"),
        ("الأحقاف", "Al-Ahqaf"), ("محمد", "Muhammad"), ("الفتح", "Al-Fath"),
        ("الحجرات", "Al-Hujurat"), ("ق", "Qaf"), ("الذاريات", "Adh-Dhariyat"),
        ("الطور", "At-Tur"), ("النجم", "An-Najm"), ("القمر", "Al-Qamar"),
        ("الرحمن", "Ar-Rahman"), ("الواقعة", "Al-Waqi'ah"), ("الحديد", "Al-Hadid"),
        ("المجادلة", "Al-Mujadila"), ("الحشر", "Al-Hashr"), ("الممتحنة", "Al-Mumtahanah"),
        ("الصف", "As-Saf"), ("الجمعة", "Al-Jumu'ah"), ("المنافقون", "Al-Munafiqun"),
        ("التغابن", "At-Taghabun"), ("الطلاق", "At-Talaq"), ("التحريم", "At-Tahrim"),
        ("الملك", "Al-Mulk"), ("القلم", "Al-Qalam"), ("الحاقة", "Al-Haqqah"),
        ("المعارج", "Al-Ma'arij"), ("نوح", "Nuh"), ("الجن", "Al-Jinn"),
        ("المزمل", "Al-Muzzammil"), ("المدثر", "Al-Muddaththir"), ("القيامة", "Al-Qiyamah"),
        ("الإنسان", "Al-Insan"), ("المرسلات", "Al-Mursalat"), ("النبأ", "An-Naba"),
        ("النازعات", "An-Nazi'at"), ("عبس", "'Abasa"), ("التكوير", "At-Takwir"),
        ("الانفطار", "Al-Infitar"), ("المطففين", "Al-Mutaffifin"), ("الانشقاق", "Al-Inshiqaq"),
        ("البروج", "Al-Buruj"), ("الطارق", "At-Tariq"), ("الأعلى", "Al-A'la"),
        ("الغاشية", "Al-Ghashiyah"), ("الفجر", "Al-Fajr"), ("البلد", "Al-Balad"),
        ("الشمس", "Ash-Shams"), ("الليل", "Al-Layl"), ("الضحى", "Ad-Duhaa"),
        ("الشرح", "Ash-Sharh"), ("التين", "At-Tin"), ("العلق", "Al-'Alaq"),
        ("القدر", "Al-Qadr"), ("البينة", "Al-Bayyinah"), ("الزلزلة", "Az-Zalzalah"),
        ("العاديات", "Al-'Adiyat"), ("القارعة", "Al-Qari'ah"), ("التكاثر", "At-Takathur"),
        ("العصر", "Al-'Asr"), ("الهمزة", "Al-Humazah"), ("الفيل", "Al-Fil"),
        ("قريش", "Quraysh"), ("الماعون", "Al-Ma'un"), ("الكوثر", "Al-Kawthar"),
        ("الكافرون", "Al-Kafirun"), ("النصر", "An-Nasr"), ("المسد", "Al-Masad"),
        ("الإخلاص", "Al-Ikhlas"), ("الفلق", "Al-Falaq"), ("الناس", "An-Nas"),
    ]

    /// Madinan surahs as classified in the Madinah Mushaf (28 surahs); all others are Makkan.
    public static let madinanSurahs: Set<Int> = [
        2, 3, 4, 5, 8, 9, 13, 22, 24, 33, 47, 48, 49, 55, 57,
        58, 59, 60, 61, 62, 63, 64, 65, 66, 76, 98, 99, 110,
    ]

    /// First ayah of each juz (index 0 = juz 1), Madinah Mushaf.
    public static let juzStarts: [(surah: Int, ayah: Int)] = [
        (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111),
        (7, 88), (8, 41), (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75),
        (21, 1), (23, 1), (25, 21), (27, 56), (29, 46), (33, 31), (36, 28), (39, 32),
        (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
    ]

    /// Juz containing the given ayah.
    public static func juz(surah: Int, ayah: Int) -> Int {
        var result = 1
        for (index, start) in juzStarts.enumerated()
        where (surah, ayah) >= (start.surah, start.ayah) {
            result = index + 1
        }
        return result
    }
}
