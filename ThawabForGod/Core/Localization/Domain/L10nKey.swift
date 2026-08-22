//
//  L10nKey.swift
//  ThawabForGod
//

import Foundation

/// Every user-facing string in the app, as a typed key.
///
/// Raw values are the keys in `Localizable.xcstrings`. Features never pass raw strings
/// around, and a missing key is a compile error rather than a wrong-looking screen.
/// `Decodable` so bundled reference data — the Islamic events table — can name a key by its
/// raw value. A key that does not exist fails to decode, and the table's own test catches it.
nonisolated enum L10nKey: String, CaseIterable, Sendable, Decodable {
    case appName = "app_name"

    case settingsTitle = "settings_title"

    case languageLabel = "language_label"
    case settingsLanguageFooter = "settings_language_footer"
    case languageArabic = "language_arabic"
    case languageEnglish = "language_english"

    case appearanceLabel = "appearance_label"
    case appearanceSystem = "appearance_system"
    case appearanceLight = "appearance_light"
    case appearanceDark = "appearance_dark"

    case accentLabel = "accent_label"
    case accentAmber = "accent_amber"
    case accentEmerald = "accent_emerald"
    case accentSapphire = "accent_sapphire"
    case accentRose = "accent_rose"

    case numbersLabel = "numbers_label"
    case numbersArabicIndic = "numbers_arabic_indic"
    case numbersLatin = "numbers_latin"

    case clockLabel = "clock_label"
    case clockSystem = "clock_system"
    case clockTwelveHour = "clock_twelve_hour"
    case clockTwentyFourHour = "clock_twenty_four_hour"

    // MARK: Settings

    case settingsAppearanceSection = "settings_appearance_section"
    case settingsFormatSection = "settings_format_section"
    case settingsCalculationSection = "settings_calculation_section"
    case settingsTipsSection = "settings_tips_section"
    case settingsAboutSection = "settings_about_section"

    case settingsRemindersSection = "settings_reminders_section"
    case settingsRemindersFooter = "settings_reminders_footer"
    case settingsRemindersDenied = "settings_reminders_denied"

    case settingsSampleLabel = "settings_sample_label"
    case settingsCalculationFooter = "settings_calculation_footer"
    case settingsResetTips = "settings_reset_tips"
    case settingsResetTipsFooter = "settings_reset_tips_footer"
    case settingsResetTipsDone = "settings_reset_tips_done"
    case settingsVersionLabel = "settings_version_label"
    case settingsSourcesTitle = "settings_sources_title"
    case settingsSourcesFooter = "settings_sources_footer"

    // MARK: Attribution

    case sourceQuranTitle = "source_quran_title"
    case sourceQuranAttribution = "source_quran_attribution"
    case sourceAdhkarTitle = "source_adhkar_title"
    case sourceAdhkarAttribution = "source_adhkar_attribution"
    case sourceAdhkarNote = "source_adhkar_note"
    case sourceNamesTitle = "source_names_title"
    case sourceNamesAttribution = "source_names_attribution"
    case sourceNamesNote = "source_names_note"
    case sourceHadithTitle = "source_hadith_title"
    case sourceHadithAttribution = "source_hadith_attribution"
    case sourceHadithNote = "source_hadith_note"
    case sourceTasbihTitle = "source_tasbih_title"
    case sourceTasbihAttribution = "source_tasbih_attribution"
    case sourceAdhanTitle = "source_adhan_title"
    case sourceAdhanAttribution = "source_adhan_attribution"
    case sourceGRDBTitle = "source_grdb_title"
    case sourceGRDBAttribution = "source_grdb_attribution"

    // MARK: Reminders

    /// The one sentence every prayer reminder carries. The prayer's own name is the title, so
    /// this stays free of anything that would have to be interpolated — or read on a lock
    /// screen by someone other than the user.
    case notificationPrayerBody = "notification_prayer_body"

    case licenceMIT = "licence_mit"
    case licenceCCBY = "licence_cc_by"
    /// Not a licence granted by anybody — the fact that the work is old enough to need none.
    case licencePublicDomain = "licence_public_domain"
    case licenceUnsettled = "licence_unsettled"
    case licenceNone = "licence_none"

    // MARK: Prayer times

    case homeTitle = "home_title"
    case greetingMorning = "greeting_morning"
    case greetingAfternoon = "greeting_afternoon"
    case greetingEvening = "greeting_evening"

    /// The sections Home can stack, named for the customization screen — and, where a section
    /// draws its own heading, for that too.
    case homeSectionNextPrayer = "home_section_next_prayer"
    case homeSectionShortcuts = "home_section_shortcuts"
    case homeSectionContinueReading = "home_section_continue_reading"
    case homeSectionLastActivity = "home_section_last_activity"
    case homeSectionPrayerTracker = "home_section_prayer_tracker"
    case homeSectionIslamicCalendar = "home_section_islamic_calendar"
    case homeSectionAyahOfDay = "home_section_ayah_of_day"
    case homeSectionHadithOfDay = "home_section_hadith_of_day"
    case homeSectionDuaOfDay = "home_section_dua_of_day"

    case homeShortcutMorningAdhkar = "home_shortcut_morning_adhkar"
    case homeShortcutEveningAdhkar = "home_shortcut_evening_adhkar"

    /// A count against a target — `7 / 28`. Both parts arrive already in the user's digits.
    case activityProgress = "activity_progress"

    case homeCustomizeAction = "home_customize_action"
    case homeCustomizeTitle = "home_customize_title"
    case homeCustomizeSectionsHeader = "home_customize_sections_header"
    case homeCustomizeSectionsFooter = "home_customize_sections_footer"
    case homeCustomizeReset = "home_customize_reset"
    case homeCustomizeResetConfirm = "home_customize_reset_confirm"

    /// Reordering as an action rather than a drag — drag handles are reachable by neither
    /// VoiceOver nor a switch control.
    case reorderMoveUp = "reorder_move_up"
    case reorderMoveDown = "reorder_move_down"
    /// The tab-bar label for the same screen `homeTitle` titles. Short on purpose: a tab item
    /// truncates where a navigation title wraps, and "مواقيت الصلاة" does not fit one.
    case homeTabLabel = "home_tab_label"
    case libraryTitle = "library_title"
    case prayerFajr = "prayer_fajr"
    case prayerSunrise = "prayer_sunrise"
    case prayerDhuhr = "prayer_dhuhr"
    case prayerAsr = "prayer_asr"
    case prayerMaghrib = "prayer_maghrib"
    case prayerIsha = "prayer_isha"
    case nextPrayerLabel = "next_prayer_label"
    case currentPrayerLabel = "current_prayer_label"
    case tomorrowLabel = "tomorrow_label"
    case timeRemainingLabel = "time_remaining_label"

    case prayerTimesSheetTitle = "prayer_times_sheet_title"
    case prayerTimesSheetHint = "prayer_times_sheet_hint"
    case nextPrayerBadge = "next_prayer_badge"

    case settingsRemindersPrayerSection = "settings_reminders_prayer_section"
    case settingsCalculationReset = "settings_calculation_reset"
    case settingsCalculationResetConfirm = "settings_calculation_reset_confirm"
    case settingsPrivacyNote = "settings_privacy_note"
    case previousDayAction = "previous_day_action"
    case nextDayAction = "next_day_action"
    case todayAction = "today_action"
    case doneAction = "done_action"
    case aboutThisPrayerAction = "about_this_prayer_action"
    case nightSectionTitle = "night_section_title"
    case middleOfNightLabel = "middle_of_night_label"
    case lastThirdOfNightLabel = "last_third_of_night_label"
    /// Followed by a number of days.
    case prayerStreakLabel = "prayer_streak_label"

    case prayerInfoFajr = "prayer_info_fajr"
    case prayerInfoSunrise = "prayer_info_sunrise"
    case prayerInfoDhuhr = "prayer_info_dhuhr"
    case prayerInfoAsr = "prayer_info_asr"
    case prayerInfoMaghrib = "prayer_info_maghrib"
    case prayerInfoIsha = "prayer_info_isha"
    /// Spoken, never drawn: `%1$@` is a worded duration, `%2$@` a prayer name.
    case countdownAccessibility = "countdown_accessibility"
    case prayerTimesUnavailable = "prayer_times_unavailable"
    case prayerTimesLoading = "prayer_times_loading"

    case madhabLabel = "madhab_label"
    case madhabShafi = "madhab_shafi"
    case madhabHanafi = "madhab_hanafi"

    case methodLabel = "method_label"
    case methodMuslimWorldLeague = "method_muslim_world_league"
    case methodEgyptian = "method_egyptian"
    case methodKarachi = "method_karachi"
    case methodUmmAlQura = "method_umm_al_qura"
    case methodDubai = "method_dubai"
    case methodMoonsightingCommittee = "method_moonsighting_committee"
    case methodNorthAmerica = "method_north_america"
    case methodKuwait = "method_kuwait"
    case methodQatar = "method_qatar"
    case methodSingapore = "method_singapore"
    case methodTehran = "method_tehran"
    case methodTurkey = "method_turkey"

    // MARK: Qibla

    case qiblaTitle = "qibla_title"
    case qiblaLocating = "qibla_locating"
    case qiblaBearingLabel = "qibla_bearing_label"
    case qiblaDistanceLabel = "qibla_distance_label"
    case qiblaDistanceUnitKilometres = "qibla_distance_unit_km"
    case qiblaNorthMarker = "qibla_north_marker"
    case qiblaNeedleLabel = "qibla_needle_label"
    case qiblaCompassUnavailable = "qibla_compass_unavailable"
    case qiblaCalibrationHint = "qibla_calibration_hint"
    case qiblaLocationNeededBody = "qibla_location_needed_body"
    case qiblaSetLocation = "qibla_set_location"
    case qiblaDone = "qibla_done"

    // MARK: Quran

    case quranTitle = "quran_title"
    case quranSectionSurahs = "quran_section_surahs"
    case quranSectionJuz = "quran_section_juz"
    /// Precedes a number — "Juz 7", "جزء ٧" — rather than carrying one, because the digits go
    /// through `LocalizationManager` and a format string would take that away from it.
    case quranJuzLabel = "quran_juz_label"
    /// Followed by a number. Written as a label with a colon rather than "7 verses", which
    /// Arabic cannot say with one noun form across every count.
    case quranVersesLabel = "quran_verses_label"
    case quranMeccan = "quran_meccan"
    case quranMedinan = "quran_medinan"
    case quranSajda = "quran_sajda"
    case quranVerseLabel = "quran_verse_label"
    case quranUnavailable = "quran_unavailable"
    case quranSectionBookmarks = "quran_section_bookmarks"
    case quranBookmarksEmpty = "quran_bookmarks_empty"
    case quranBookmarkAdd = "quran_bookmark_add"
    case quranBookmarkRemove = "quran_bookmark_remove"
    case quranContinueReading = "quran_continue_reading"
    case quranSearchPrompt = "quran_search_prompt"
    case quranSearchChapters = "quran_search_chapters"
    case quranSearchVerses = "quran_search_verses"
    case quranSearchEmpty = "quran_search_empty"
    case quranSearchHint = "quran_search_hint"

    // MARK: Tafsir

    case tafsirTitle = "tafsir_title"
    case tafsirOpen = "tafsir_open"
    case tafsirSilent = "tafsir_silent"
    case tafsirUnavailable = "tafsir_unavailable"
    /// Precedes a number — "On verse 255" — rather than carrying one, so the digits go through
    /// `LocalizationManager` instead of a format string.
    case tafsirVerseLabel = "tafsir_verse_label"

    // MARK: The reading panel

    case readerOptionsTitle = "reader_options_title"
    case readerPaperSection = "reader_paper_section"
    case readerPaperSystem = "reader_paper_system"
    case readerPaperParchment = "reader_paper_parchment"
    case readerPaperNight = "reader_paper_night"
    case readerTextSection = "reader_text_section"
    case readerTextSize = "reader_text_size"
    case readerLineSpacing = "reader_line_spacing"
    case readerReset = "reader_reset"
    case readerDone = "reader_done"

    // MARK: Hadith

    case hadithTitle = "hadith_title"
    case hadithLoading = "hadith_loading"
    case hadithUnavailable = "hadith_unavailable"
    /// Why the app carries two collections and not nine, and why they are Arabic only. On the
    /// screen rather than in a settings page, for the reason `adhkarVerificationNotice` is.
    case hadithScopeNotice = "hadith_scope_notice"
    /// Followed by a number, like `quranVersesLabel` — written as a label with a colon rather
    /// than "97 books", which Arabic cannot say with one noun form across every count.
    case hadithBooksLabel = "hadith_books_label"
    case hadithNarrationsLabel = "hadith_narrations_label"
    /// Precedes the reference number a narration is cited by, or the first of its span.
    case hadithNumberLabel = "hadith_number_label"
    case hadithSearchPrompt = "hadith_search_prompt"
    case hadithSearchHint = "hadith_search_hint"
    case hadithSearchEmpty = "hadith_search_empty"
    /// Precedes a count — "Narrations: 50 of 912" — rather than carrying one, so the digits go
    /// through `LocalizationManager` instead of a format string.
    case hadithSearchResults = "hadith_search_results"
    /// The word between the shown count and the total, in that same line.
    case hadithSearchOf = "hadith_search_of"
    case hadithBookmarksSection = "hadith_bookmarks_section"
    case hadithBookmarkAdd = "hadith_bookmark_add"
    case hadithBookmarkRemove = "hadith_bookmark_remove"
    case hadithContinueReading = "hadith_continue_reading"
    /// Precedes a kitab's number, where its title is not to hand.
    case hadithBookLabel = "hadith_book_label"

    // MARK: Memorizing hadith

    case hadithMemorizeTitle = "hadith_memorize_title"
    case hadithMemorizeStart = "hadith_memorize_start"
    case hadithMemorizeStop = "hadith_memorize_stop"
    /// Follows a count — "3 due" — rather than carrying one, so the digits go through
    /// `LocalizationManager` instead of a format string.
    case hadithMemorizeDueLabel = "hadith_memorize_due_label"
    case hadithMemorizeCaughtUp = "hadith_memorize_caught_up"
    case hadithMemorizePrompt = "hadith_memorize_prompt"
    case hadithMemorizeRecall = "hadith_memorize_recall"
    case hadithMemorizeReveal = "hadith_memorize_reveal"
    case hadithMemorizeDone = "hadith_memorize_done"
    case hadithMemorizeEmpty = "hadith_memorize_empty"
    case hadithGradeAgain = "hadith_grade_again"
    case hadithGradeHard = "hadith_grade_hard"
    case hadithGradeGood = "hadith_grade_good"
    case hadithGradeEasy = "hadith_grade_easy"

    // MARK: Adhkar

    case adhkarTitle = "adhkar_title"
    case adhkarCategoryMorning = "adhkar_category_morning"
    case adhkarCategoryMorningSubtitle = "adhkar_category_morning_subtitle"
    case adhkarCategoryEvening = "adhkar_category_evening"
    case adhkarCategoryEveningSubtitle = "adhkar_category_evening_subtitle"
    case adhkarLoading = "adhkar_loading"
    case adhkarUnavailable = "adhkar_unavailable"
    case adhkarEmpty = "adhkar_empty"
    case adhkarSourceLabel = "adhkar_source_label"
    case adhkarVirtueLabel = "adhkar_virtue_label"
    case adhkarShowTranslation = "adhkar_show_translation"
    case adhkarShowTransliteration = "adhkar_show_transliteration"
    case adhkarProgressLabel = "adhkar_progress_label"
    case adhkarRepeatLabel = "adhkar_repeat_label"
    case adhkarCountHint = "adhkar_count_hint"
    case adhkarCompleted = "adhkar_completed"
    case adhkarReset = "adhkar_reset"
    case adhkarVerificationNotice = "adhkar_verification_notice"

    // MARK: Tasbih

    case tasbihTitle = "tasbih_title"
    case tasbihLoading = "tasbih_loading"
    case tasbihUnavailable = "tasbih_unavailable"
    case tasbihTargetLabel = "tasbih_target_label"
    case tasbihLapsLabel = "tasbih_laps_label"
    case tasbihCountLabel = "tasbih_count_label"
    case tasbihCountHint = "tasbih_count_hint"
    case tasbihReset = "tasbih_reset"

    // MARK: The 99 names

    case namesTitle = "names_title"
    case namesLoading = "names_loading"
    case namesUnavailable = "names_unavailable"
    case namesSearchPrompt = "names_search_prompt"
    case namesNoMatches = "names_no_matches"
    case namesMeaningLabel = "names_meaning_label"
    case namesExplanationLabel = "names_explanation_label"
    case namesReferenceLabel = "names_reference_label"
    case namesNumberLabel = "names_number_label"
    case namesVerificationNotice = "names_verification_notice"

    // MARK: Onboarding

    case onboardingWelcomeTitle = "onboarding_welcome_title"
    case onboardingWelcomeBody = "onboarding_welcome_body"
    case onboardingOfflineTitle = "onboarding_offline_title"
    case onboardingOfflineBody = "onboarding_offline_body"
    case onboardingPrivacyTitle = "onboarding_privacy_title"
    case onboardingPrivacyBody = "onboarding_privacy_body"

    case onboardingLocationTitle = "onboarding_location_title"
    case onboardingLocationBody = "onboarding_location_body"
    case onboardingLocationAllow = "onboarding_location_allow"
    case onboardingLocationGranted = "onboarding_location_granted"
    case onboardingLocationDeniedBody = "onboarding_location_denied_body"
    case onboardingManualTitle = "onboarding_manual_title"
    case onboardingLatitude = "onboarding_latitude"
    case onboardingLongitude = "onboarding_longitude"
    case onboardingManualSave = "onboarding_manual_save"
    case onboardingManualSaved = "onboarding_manual_saved"

    case onboardingNotificationsTitle = "onboarding_notifications_title"
    case onboardingNotificationsBody = "onboarding_notifications_body"
    case onboardingNotificationsAllow = "onboarding_notifications_allow"
    case onboardingNotificationsGranted = "onboarding_notifications_granted"
    case onboardingNotificationsDeniedBody = "onboarding_notifications_denied_body"

    case onboardingMethodTitle = "onboarding_method_title"
    case onboardingMethodBody = "onboarding_method_body"

    case onboardingContinue = "onboarding_continue"
    case onboardingBack = "onboarding_back"
    case onboardingSkip = "onboarding_skip"
    case onboardingFinish = "onboarding_finish"

    // MARK: Tips

    case tipHomeTomorrowTitle = "tip_home_tomorrow_title"
    case tipHomeTomorrowMessage = "tip_home_tomorrow_message"
    case tipOnboardingMethodTitle = "tip_onboarding_method_title"
    case tipOnboardingMethodMessage = "tip_onboarding_method_message"
    case tipHomeHijriTitle = "tip_home_hijri_title"
    case tipHomeHijriMessage = "tip_home_hijri_message"
    case tipTasbihResetTitle = "tip_tasbih_reset_title"
    case tipTasbihResetMessage = "tip_tasbih_reset_message"
    case tipNamesTapTitle = "tip_names_tap_title"
    case tipNamesTapMessage = "tip_names_tap_message"

    // MARK: Hijri calendar

    case hijriMonthMuharram = "hijri_month_muharram"
    case hijriMonthSafar = "hijri_month_safar"
    case hijriMonthRabiAlAwwal = "hijri_month_rabi_al_awwal"
    case hijriMonthRabiAlThani = "hijri_month_rabi_al_thani"
    case hijriMonthJumadaAlUla = "hijri_month_jumada_al_ula"
    case hijriMonthJumadaAlAkhirah = "hijri_month_jumada_al_akhirah"
    case hijriMonthRajab = "hijri_month_rajab"
    case hijriMonthShaban = "hijri_month_shaban"
    case hijriMonthRamadan = "hijri_month_ramadan"
    case hijriMonthShawwal = "hijri_month_shawwal"
    case hijriMonthDhulQadah = "hijri_month_dhul_qadah"
    case hijriMonthDhulHijjah = "hijri_month_dhul_hijjah"

    // MARK: Islamic events

    case eventIslamicNewYear = "event_islamic_new_year"
    case eventAshura = "event_ashura"
    case eventMawlid = "event_mawlid"
    case eventIsraMiraj = "event_isra_miraj"
    case eventNisfShaban = "event_nisf_shaban"
    case eventRamadanStart = "event_ramadan_start"
    case eventLaylatAlQadr = "event_laylat_al_qadr"
    case eventEidAlFitr = "event_eid_al_fitr"
    case eventArafah = "event_arafah"
    case eventEidAlAdha = "event_eid_al_adha"

    case eventNoteMoonSighting = "event_note_moon_sighting"
    case eventNoteObservanceVaries = "event_note_observance_varies"
    case eventNoteLastTenNights = "event_note_last_ten_nights"
}
