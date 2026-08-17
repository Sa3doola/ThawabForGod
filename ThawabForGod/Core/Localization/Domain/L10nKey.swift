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

    case paletteTitle = "palette_title"
    case typeScaleTitle = "type_scale_title"
    case sampleGreeting = "sample_greeting"
    case sampleCount = "sample_count"

    // MARK: Prayer times

    case homeTitle = "home_title"
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
