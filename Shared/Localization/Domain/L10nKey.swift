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

    case appIconLabel = "app_icon_label"
    case appIconDefault = "app_icon_default"
    case appIconGreen = "app_icon_green"
    case appIconNight = "app_icon_night"
    case appIconSand = "app_icon_sand"
    case appIconChangeFailed = "app_icon_change_failed"

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
    case settingsQuranSection = "settings_quran_section"

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
    case sourcePlexTitle = "source_plex_title"
    case sourcePlexAttribution = "source_plex_attribution"
    case sourceAmiriTitle = "source_amiri_title"
    case sourceAmiriAttribution = "source_amiri_attribution"
    case sourceKFGQPCTitle = "source_kfgqpc_title"
    case sourceKFGQPCAttribution = "source_kfgqpc_attribution"
    case sourceQuranMushafTitle = "source_quran_mushaf_title"
    case sourceQuranMushafAttribution = "source_quran_mushaf_attribution"
    case sourceQULFontsTitle = "source_qul_fonts_title"
    case sourceQULFontsAttribution = "source_qul_fonts_attribution"
    /// The section of the Sources screen that lists the bundled translations and tafsirs.
    case sourcePacksSection = "source_packs_section"
    /// What a row with a bundled licence file offers to open.
    case sourceReadLicence = "source_read_licence"

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
    case licenceOFL = "licence_ofl"
    case licenceKFGQPC = "licence_kfgqpc"

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

    case homeShortcutMorningEveningAdhkar = "home_shortcut_morning_evening_adhkar"

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

    case settingsRemindersPrayerSection = "settings_reminders_prayer_section"
    case settingsCalculationReset = "settings_calculation_reset"
    case settingsCalculationResetConfirm = "settings_calculation_reset_confirm"
    case settingsPrivacyNote = "settings_privacy_note"
    case inTimeLabel = "in_time_label"
    case reminderOnLabel = "reminder_on_label"
    case reminderOffLabel = "reminder_off_label"
    case previousWeekAction = "previous_week_action"
    case nextWeekAction = "next_week_action"
    case todayAction = "today_action"
    case doneAction = "done_action"
    /// The note editor's confirm button. Generic: nothing here says what is being saved.
    case saveAction = "save_action"
    /// The note editor's cancel button. Generic, as `saveAction` is.
    case cancelAction = "cancel_action"
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
    case qiblaAlignedValue = "qibla_aligned_value"
    case qiblaCompassUnavailable = "qibla_compass_unavailable"
    case qiblaCalibrationHint = "qibla_calibration_hint"
    case qiblaLocationNeededBody = "qibla_location_needed_body"
    case qiblaSetLocation = "qibla_set_location"
    case qiblaDone = "qibla_done"

    // MARK: Quran

    case quranTitle = "quran_title"
    /// The reader's leading button, which returns to the chapter and part list. Not `libraryTitle`,
    /// which is Home's menu and reads differently in Arabic.
    case quranLibrary = "quran_library"
    /// The overflow menu at compact width, which holds the mode toggle and the reader settings.
    case quranMore = "quran_more"
    /// Followed by a number. Written as a label with a colon rather than "7 verses", which
    /// Arabic cannot say with one noun form across every count.
    case quranVersesLabel = "quran_verses_label"
    case quranMeccan = "quran_meccan"
    case quranMedinan = "quran_medinan"
    case quranVerseLabel = "quran_verse_label"
    case quranUnavailable = "quran_unavailable"
    case quranTryAgain = "quran_try_again"
    /// The mode toggle while the reader is showing Mushaf pages — switches to the verse list.
    case quranShowSeparated = "quran_show_separated"
    /// The mode toggle while the reader is showing the verse list — switches to Mushaf pages.
    case quranShowMushaf = "quran_show_mushaf"
    case quranBookmarkAdd = "quran_bookmark_add"
    case quranBookmarkRemove = "quran_bookmark_remove"
    /// The VoiceOver name of a bookmark, as custom content. A noun, not the button's verb: Arabic
    /// uses a different word for the thing kept than for the act of keeping it.
    case quranBookmarkTitle = "quran_bookmark_title"
    /// The VoiceOver value of a bookmarked ayah.
    case quranBookmarked = "quran_bookmarked"
    case quranPageBookmarkAdd = "quran_page_bookmark_add"
    case quranPageBookmarkRemove = "quran_page_bookmark_remove"
    /// The noun: the editor's VoiceOver label and the VoiceOver name of a note.
    case quranNote = "quran_note"
    case quranNoteAdd = "quran_note_add"
    case quranNoteEdit = "quran_note_edit"
    case quranNoteDelete = "quran_note_delete"
    case quranNoteDeleteConfirm = "quran_note_delete_confirm"
    case quranHighlight = "quran_highlight"
    case quranHighlightRemove = "quran_highlight_remove"
    case quranHighlightYellow = "quran_highlight_yellow"
    case quranHighlightGreen = "quran_highlight_green"
    case quranHighlightBlue = "quran_highlight_blue"
    case quranHighlightPink = "quran_highlight_pink"
    /// The Bookmarks screen's three kinds: its title, its segmented control and its empty state.
    case quranMarksBookmarks = "quran_marks_bookmarks"
    case quranMarksNotes = "quran_marks_notes"
    case quranMarksHighlights = "quran_marks_highlights"
    /// The kind picker's VoiceOver label, hidden on screen.
    case quranMarksShow = "quran_marks_show"
    /// The sort menu's label, and the title of its icon.
    case quranMarksSort = "quran_marks_sort"
    case quranMarksByDate = "quran_marks_by_date"
    case quranMarksBySurah = "quran_marks_by_surah"
    /// Removes a bookmark, note or highlight. A verb, as on the swipe action and in the menu.
    case quranMarksDelete = "quran_marks_delete"
    case quranMarksEmptyBookmarks = "quran_marks_empty_bookmarks"
    case quranMarksEmptyNotes = "quran_marks_empty_notes"
    case quranMarksEmptyHighlights = "quran_marks_empty_highlights"
    /// The empty state's description, shown under whichever kind is empty.
    case quranMarksEmptyHint = "quran_marks_empty_hint"
    case quranContinueReading = "quran_continue_reading"
    case quranSearchPrompt = "quran_search_prompt"
    /// The toolbar button and the search screen's title.
    case quranSearch = "quran_search"
    /// The search field's prompt in the Quran scope.
    case quranSearchPromptArabic = "quran_search_prompt_arabic"
    /// The search field's prompt in the translations scope.
    case quranSearchPromptTranslations = "quran_search_prompt_translations"
    case quranSearchKeepTyping = "quran_search_keep_typing"
    case quranSearchTooShort = "quran_search_too_short"
    /// `%@` the number of results, already formatted.
    case quranSearchResultCount = "quran_search_result_count"
    /// `%@` the number of ayahs found only through attached letters, already formatted.
    case quranSearchAttached = "quran_search_attached"
    case quranSearchAttachedNote = "quran_search_attached_note"
    /// The idle description when translations are installed.
    case quranSearchEmptyDescription = "quran_search_empty_description"
    /// The idle description when only the Arabic text is searchable.
    case quranSearchEmptyDescriptionArabic = "quran_search_empty_description_arabic"
    case quranSearchNoResults = "quran_search_no_results"
    case quranSearchFailed = "quran_search_failed"
    /// `%@` the query, isolated by the caller so an English interface does not reorder it.
    case quranSearchInAyahs = "quran_search_in_ayahs"
    /// The search screen's scopes; the first is `quranTitle`.
    case quranSearchScopeTranslations = "quran_search_scope_translations"
    /// The juz a Mushaf page is in, as its header and as a margin label — "Juz 7", `%@` the number.
    case quranJuzNumber = "quran_juz_number"
    /// The VoiceOver name of the custom content listing an ayah's margin labels.
    case quranMargin = "quran_margin"
    /// A hizb start in a Mushaf page's margin, `%@` the number — "Hizb 3".
    case quranMarginHizb = "quran_margin_hizb"
    /// A quarter of a hizb in the margin, `%@` the hizb — "¼ Hizb 3".
    case quranMarginQuarterHizb = "quran_margin_quarter_hizb"
    /// A half hizb in the margin, `%@` the hizb — "½ Hizb 3".
    case quranMarginHalfHizb = "quran_margin_half_hizb"
    /// Three quarters of a hizb in the margin, `%@` the hizb — "¾ Hizb 3".
    case quranMarginThreeQuarterHizb = "quran_margin_three_quarter_hizb"
    /// A sajdah marker in a Mushaf page's margin, beside its ayah.
    case quranMarginSajdah = "quran_margin_sajdah"
    /// A Mushaf page's footer — "Juz 7 · Page 142". `%1$@` is the juz, `%2$@` the page.
    case quranPageFooter = "quran_page_footer"
    /// VoiceOver for a Mushaf page's surah header, `%@` the surah name.
    case quranSurahHeading = "quran_surah_heading"
    /// VoiceOver for an ayah on a Mushaf page — "Al-Fatihah, ayah 2". `%1$@` the surah name,
    /// `%2$@` the ayah number.
    case quranSurahAyah = "quran_surah_ayah"
    /// The button at the end of a surah in separated mode, leading to the next one.
    case quranNextSurah = "quran_next_surah"
    /// That button's VoiceOver hint, `%@` the next surah's name — "Opens Al-Baqarah".
    case quranOpensSurah = "quran_opens_surah"

    // The Quran's menu bar commands: the Mac's Quran menu, and the shortcuts shown beside each item

    case quranCommandNextPage = "quran_command_next_page"
    case quranCommandPreviousPage = "quran_command_previous_page"
    case quranCommandNextSurah = "quran_command_next_surah"
    case quranCommandPreviousSurah = "quran_command_previous_surah"
    case quranCommandGoTo = "quran_command_go_to"
    case quranCommandBookmark = "quran_command_bookmark"
    case quranCommandToggleAyahPanel = "quran_command_toggle_ayah_panel"
    case quranCommandToggleDisplayMode = "quran_command_toggle_display_mode"
    case quranCommandNextTheme = "quran_command_next_theme"
    case quranCommandBiggerText = "quran_command_bigger_text"
    case quranCommandSmallerText = "quran_command_smaller_text"

    /// The hint under the tabletop reader's page, shown until an ayah is tapped.
    case quranTabletopHint = "quran_tabletop_hint"

    // The Quran's home-screen widgets: the gallery's names and descriptions, the empty states, and the
    // VoiceOver labels of an ayah

    /// The continue-reading widget's gallery description.
    case quranWidgetContinueDescription = "quran_widget_continue_description"
    /// The ayah-of-the-day widget's gallery name.
    case quranWidgetAyahName = "quran_widget_ayah_name"
    /// The ayah-of-the-day widget's gallery description.
    case quranWidgetAyahDescription = "quran_widget_ayah_description"
    /// The continue-reading widget before anything has been read.
    case quranWidgetContinueEmpty = "quran_widget_continue_empty"
    /// The ayah-of-the-day widget before the app has been opened to load its data.
    case quranWidgetAyahEmpty = "quran_widget_ayah_empty"
    /// A single ayah's VoiceOver label — "Al-Fatihah, ayah 2". `%1$@` the surah name, `%2$@` the ayah.
    case quranWidgetAyahLabel = "quran_widget_ayah_label"
    /// A range of ayahs' VoiceOver label — "Al-Baqarah, ayahs 1 to 5". `%1$@` the surah name, `%2$@`
    /// the first ayah, `%3$@` the last.
    case quranWidgetAyahRangeLabel = "quran_widget_ayah_range_label"

    // The Library: the field, its example and failures, the index picker and its tabs, the rows

    /// The field's placeholder on a build with Mushaf pages.
    case quranFieldPlaceholderPages = "quran_field_placeholder_pages"
    /// The field's placeholder on the public build, where there are no pages to type.
    case quranFieldPlaceholderSurahs = "quran_field_placeholder_surahs"
    /// The field's clear button, read by VoiceOver.
    case quranClear = "quran_clear"
    case quranRecentSearches = "quran_recent_searches"
    case quranRecentSearchesClear = "quran_recent_searches_clear"
    /// The button that goes to what was typed.
    case quranGo = "quran_go"
    /// The example line under the field. Four arguments, each already formatted by the caller: the
    /// first example (a page or a surah), the ayah reference, the juz number and the hizb number.
    case quranExample = "quran_example"
    /// The failure for a number that names nothing, on a build with Mushaf pages.
    case quranNotFoundPages = "quran_not_found_pages"
    /// The failure for a number that names nothing, on the public build.
    case quranNotFoundSurahs = "quran_not_found_surahs"
    /// The failure for a page asked of the public build, which has none.
    case quranPagesUnavailable = "quran_pages_unavailable"
    /// The empty state of a filtered surah list.
    case quranNoSurahMatch = "quran_no_surah_match"
    /// The picker's VoiceOver label. Not `quranLibrary`: same Arabic, different English.
    case quranIndex = "quran_index"
    /// The four index tabs, in the order the Library shows them.
    case quranTabSurah = "quran_tab_surah"
    case quranTabJuz = "quran_tab_juz"
    case quranTabHizb = "quran_tab_hizb"
    case quranTabPage = "quran_tab_page"
    /// Followed by a count, already formatted — "Ayahs: 286" — on a surah row.
    case quranAyahsLabel = "quran_ayahs_label"
    /// A page's number as a label, `%@` the number — "Page 293".
    case quranPageNumber = "quran_page_number"

    // The surah-info screen: its action, its four facts and the text it has none of

    /// The swipe and context-menu action that opens a surah's introduction.
    case quranSurahInfo = "quran_surah_info"
    case quranSurahInfoRevelation = "quran_surah_info_revelation"
    case quranSurahInfoAyahs = "quran_surah_info_ayahs"
    case quranSurahInfoPages = "quran_surah_info_pages"
    /// The juz a surah starts in. Its value is a `quranJuzNumber`.
    case quranSurahInfoStartsIn = "quran_surah_info_starts_in"
    /// Shown where the interface language has no surah-info pack.
    case quranSurahInfoUnavailable = "quran_surah_info_unavailable"

    // The ayah panel: its actions, its section picker and a translation's footnotes

    case quranPanelShowWhole = "quran_panel_show_whole"
    case quranPanelPreviousAyah = "quran_panel_previous_ayah"
    case quranPanelNextAyah = "quran_panel_next_ayah"
    case quranPanelClose = "quran_panel_close"
    case quranPanelCopy = "quran_panel_copy"
    case quranPanelCopied = "quran_panel_copied"
    case quranPanelShare = "quran_panel_share"
    case quranPanelTranslation = "quran_panel_translation"
    case quranPanelSection = "quran_panel_section"
    /// A translation's footnote, `%@` the number — "Footnote 3". Also its VoiceOver name.
    case quranPanelFootnote = "quran_panel_footnote"

    // MARK: Tafsir

    case tafsirTitle = "tafsir_title"
    case tafsirSilent = "tafsir_silent"
    case tafsirUnavailable = "tafsir_unavailable"
    /// The panel's Tafsir section for a group of ayahs, `%@` the range — "Tafsir of ayahs 2:3–5".
    case quranTafsirOfAyahs = "quran_tafsir_of_ayahs"
    /// Opens the whole tafsir entry from the panel's collapsed text.
    case quranTafsirReadMore = "quran_tafsir_read_more"

    // MARK: Quran settings

    /// The Translations & Tafsir screen, named the same from the settings form and from Settings.
    case quranPacksTitle = "quran_packs_title"
    case quranPacksTranslations = "quran_packs_translations"
    case quranPacksTranslationsFooter = "quran_packs_translations_footer"
    case quranPacksTafsir = "quran_packs_tafsir"
    case quranPacksTafsirFooter = "quran_packs_tafsir_footer"
    /// The default-tafsir picker's first row: the first enabled tafsir in the app's language.
    case quranPacksAutomatic = "quran_packs_automatic"
    case quranPacksDefaultTafsir = "quran_packs_default_tafsir"
    case quranPacksDefaultTafsirFooter = "quran_packs_default_tafsir_footer"

    case quranSettingsDisplayMode = "quran_settings_display_mode"
    case quranSettingsDisplayFooter = "quran_settings_display_footer"
    case quranSettingsTranslationUnderAyah = "quran_settings_translation_under_ayah"
    case quranSettingsTheme = "quran_settings_theme"
    case quranSettingsFollowDark = "quran_settings_follow_dark"
    case quranSettingsTextFooter = "quran_settings_text_footer"
    case quranSettingsMushafPages = "quran_settings_mushaf_pages"
    case quranSettingsMarginMarkers = "quran_settings_margin_markers"
    case quranSettingsMarginMarkersFooter = "quran_settings_margin_markers_footer"
    case quranSettingsLandscape = "quran_settings_landscape"
    case quranSettingsOpenFlat = "quran_settings_open_flat"
    case quranSettingsPageTurn = "quran_settings_page_turn"
    case quranSettingsPageTurnFooter = "quran_settings_page_turn_footer"
    case quranSettingsSources = "quran_settings_sources"

    // MARK: The reading panel

    case readerOptionsTitle = "reader_options_title"
    case readerKeepScreenAwake = "reader_keep_screen_awake"
    case readerKeepScreenAwakeDetail = "reader_keep_screen_awake_detail"
    case readerTextSize = "reader_text_size"
    case readerReset = "reader_reset"
    case readerFontSection = "reader_font_section"
    case readerFontKFGQPC = "reader_font_kfgqpc"
    case readerFontAmiri = "reader_font_amiri"
    case readerDone = "reader_done"
    /// `ReaderTheme`: the page the Quran is read on.
    case readerThemePaper = "reader_theme_paper"
    case readerThemeSepia = "reader_theme_sepia"
    case readerThemeDark = "reader_theme_dark"
    /// `QuranDisplayMode`.
    case readerModeMushaf = "reader_mode_mushaf"
    case readerModeSeparated = "reader_mode_separated"
    /// `PhoneLandscapeLayout`: an iPhone held sideways.
    case readerLandscapeOnePage = "reader_landscape_one_page"
    case readerLandscapeTwoPages = "reader_landscape_two_pages"
    /// `FlatOpenLayout`: a foldable iPhone opened flat.
    case readerFlatOpenSpread = "reader_flat_open_spread"
    case readerFlatOpenSinglePage = "reader_flat_open_single_page"
    /// `MushafPageTurnStyle`: the page turns like paper.
    case readerPageTurnCurl = "reader_page_turn_curl"
    /// `MushafPageTurnStyle`: the page slides.
    case readerPageTurnSlide = "reader_page_turn_slide"

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
    case hadithMemorizeDue = "hadith_memorize_due"
    case hadithDeckSize = "hadith_deck_size"
    case hadithBookmarksSaved = "hadith_bookmarks_saved"
    case hadithBookmarksAcross = "hadith_bookmarks_across"
    case hadithPreviousBook = "hadith_previous_book"
    case hadithNextBook = "hadith_next_book"
    case hadithGradeTomorrow = "hadith_grade_tomorrow"
    case hadithGradeInDays = "hadith_grade_in_days"
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
    case adhkarLoading = "adhkar_loading"
    case adhkarUnavailable = "adhkar_unavailable"
    case adhkarEmpty = "adhkar_empty"
    case adhkarSearchPrompt = "adhkar_search_prompt"
    case adhkarNoResults = "adhkar_no_results"
    case adhkarCategoryCount = "adhkar_category_count"
    case adhkarSourceAttribution = "adhkar_source_attribution"
    case adhkarChapterComplete = "adhkar_chapter_complete"
    case adhkarMarkRead = "adhkar_mark_read"
    case adhkarMarkedRead = "adhkar_marked_read"
    case adhkarNext = "adhkar_next"
    case adhkarPrevious = "adhkar_previous"
    case adhkarTextSize = "adhkar_text_size"
    case adhkarTextLarger = "adhkar_text_larger"
    case adhkarTextSmaller = "adhkar_text_smaller"

    /// The twelve headings the 132 chapters are gathered under. This project's grouping, not the
    /// book's — see `AdhkarGroup`.
    case adhkarGroupDaily = "adhkar_group_daily"
    case adhkarGroupPurification = "adhkar_group_purification"
    case adhkarGroupPrayer = "adhkar_group_prayer"
    case adhkarGroupHome = "adhkar_group_home"
    case adhkarGroupFood = "adhkar_group_food"
    case adhkarGroupTravel = "adhkar_group_travel"
    case adhkarGroupHajj = "adhkar_group_hajj"
    case adhkarGroupDistress = "adhkar_group_distress"
    case adhkarGroupIllness = "adhkar_group_illness"
    case adhkarGroupNature = "adhkar_group_nature"
    case adhkarGroupSocial = "adhkar_group_social"
    case adhkarGroupPraise = "adhkar_group_praise"

    case adhkarProgressLabel = "adhkar_progress_label"
    case adhkarRepeatLabel = "adhkar_repeat_label"
    case adhkarCountHint = "adhkar_count_hint"
    case adhkarCompleted = "adhkar_completed"
    case adhkarRemaining = "adhkar_remaining"
    case adhkarOfTotal = "adhkar_of_total"
    case adhkarDhikrNumber = "adhkar_dhikr_number"
    case adhkarSwipeHint = "adhkar_swipe_hint"
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

    case namesPrevious = "names_previous"
    case namesNext = "names_next"
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

    // MARK: macOS — menu bar and login item

    case settingsMacSection = "settings_mac_section"
    case settingsMenuBarSection = "settings_menu_bar_section"
    case settingsMenuBarShow = "settings_menu_bar_show"
    case settingsMenuBarOnly = "settings_menu_bar_only"
    case settingsMenuBarFooter = "settings_menu_bar_footer"
    case settingsMenuBarStyle = "settings_menu_bar_style"
    case settingsMenuBarStyleAutomatic = "settings_menu_bar_style_automatic"
    case settingsMenuBarStyleFull = "settings_menu_bar_style_full"
    case settingsMenuBarStyleTimeOnly = "settings_menu_bar_style_time_only"
    case settingsMenuBarStyleSymbolOnly = "settings_menu_bar_style_symbol_only"
    case settingsMenuBarStyleFooter = "settings_menu_bar_style_footer"
    case settingsLaunchAtLogin = "settings_launch_at_login"
    case settingsLaunchAtLoginFooter = "settings_launch_at_login_footer"
    case settingsLaunchAtLoginApprove = "settings_launch_at_login_approve"
    case settingsLaunchAtLoginApprovalFooter = "settings_launch_at_login_approval_footer"
    case settingsLaunchAtLoginUnavailable = "settings_launch_at_login_unavailable"
    case settingsLaunchAtLoginFailed = "settings_launch_at_login_failed"
    case menuBarLogPrayer = "menu_bar_log_prayer"
    case menuBarLoggedPrayer = "menu_bar_logged_prayer"
    case menuBarQuit = "menu_bar_quit"

    // MARK: Widgets

    case widgetNextPrayerName = "widget_next_prayer_name"
    case widgetNextPrayerDescription = "widget_next_prayer_description"
    case widgetNoLocation = "widget_no_location"
    case widgetTimesUnavailable = "widget_times_unavailable"
    case widgetCountdownName = "widget_countdown_name"
    case widgetCountdownDescription = "widget_countdown_description"
    case widgetAllPrayersName = "widget_all_prayers_name"
    case widgetAllPrayersDescription = "widget_all_prayers_description"
    case widgetHijriDateName = "widget_hijri_date_name"
    case widgetHijriDateDescription = "widget_hijri_date_description"
    case widgetPrayerIn = "widget_prayer_in"
    case widgetAtTime = "widget_at_time"

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

    case moonPhaseNewMoon = "moon_phase_new_moon"
    case moonPhaseWaxingCrescent = "moon_phase_waxing_crescent"
    case moonPhaseFirstQuarter = "moon_phase_first_quarter"
    case moonPhaseWaxingGibbous = "moon_phase_waxing_gibbous"
    case moonPhaseFullMoon = "moon_phase_full_moon"
    case moonPhaseWaningGibbous = "moon_phase_waning_gibbous"
    case moonPhaseLastQuarter = "moon_phase_last_quarter"
    case moonPhaseWaningCrescent = "moon_phase_waning_crescent"
    case moonAccessibilityLabel = "moon_accessibility_label"

    case moonPercentValue = "moon_percent_value"

    case eventLastTenNights = "event_last_ten_nights"
    case eventSixShawwal = "event_six_shawwal"
    case eventFirstTenDhulHijjah = "event_first_ten_dhul_hijjah"
    case eventTashreeq = "event_tashreeq"
    case eventAyyamAlBid = "event_ayyam_al_bid"
    case eventMondayThursday = "event_monday_thursday"
    case eventBadr = "event_badr"
    case eventConquestMakkah = "event_conquest_makkah"
    case eventSummaryIslamicNewYear = "event_summary_islamic_new_year"
    case eventSummaryAshura = "event_summary_ashura"
    case eventSummaryMawlid = "event_summary_mawlid"
    case eventSummaryIsraMiraj = "event_summary_isra_miraj"
    case eventSummaryNisfShaban = "event_summary_nisf_shaban"
    case eventSummaryRamadanStart = "event_summary_ramadan_start"
    case eventSummaryLaylatAlQadr = "event_summary_laylat_al_qadr"
    case eventSummaryEidAlFitr = "event_summary_eid_al_fitr"
    case eventSummaryArafah = "event_summary_arafah"
    case eventSummaryEidAlAdha = "event_summary_eid_al_adha"
    case eventSummaryLastTenNights = "event_summary_last_ten_nights"
    case eventSummarySixShawwal = "event_summary_six_shawwal"
    case eventSummaryFirstTenDhulHijjah = "event_summary_first_ten_dhul_hijjah"
    case eventSummaryTashreeq = "event_summary_tashreeq"
    case eventSummaryAyyamAlBid = "event_summary_ayyam_al_bid"
    case eventSummaryMondayThursday = "event_summary_monday_thursday"
    case eventSummaryBadr = "event_summary_badr"
    case eventSummaryConquestMakkah = "event_summary_conquest_makkah"
    case eventVirtueAshura = "event_virtue_ashura"
    case eventVirtueArafah = "event_virtue_arafah"
    case eventVirtueLaylatAlQadr = "event_virtue_laylat_al_qadr"
    case eventVirtueSixShawwal = "event_virtue_six_shawwal"
    case eventVirtueFirstTenDhulHijjah = "event_virtue_first_ten_dhul_hijjah"
    case eventVirtueTashreeq = "event_virtue_tashreeq"
    case eventVirtueAyyamAlBid = "event_virtue_ayyam_al_bid"
    case eventVirtueMondayThursday = "event_virtue_monday_thursday"
    case eventScholarlyMawlid = "event_scholarly_mawlid"
    case eventScholarlyIsraMiraj = "event_scholarly_isra_miraj"
    case eventScholarlyNisfShaban = "event_scholarly_nisf_shaban"
    case eventScholarlyLaylatAlQadr = "event_scholarly_laylat_al_qadr"
    case eventScholarlySixShawwal = "event_scholarly_six_shawwal"
    case eventScholarlyBadr = "event_scholarly_badr"
    case eventScholarlyConquestMakkah = "event_scholarly_conquest_makkah"
    case workSahihBukhari = "work_sahih_bukhari"
    case workSahihMuslim = "work_sahih_muslim"
    case workJamiTirmidhi = "work_jami_tirmidhi"
    case gradingSahih = "grading_sahih"
    case gradingHasanTirmidhi = "grading_hasan_tirmidhi"
    case occasionCategoryEid = "occasion_category_eid"
    case occasionCategoryFasting = "occasion_category_fasting"
    case occasionCategoryNight = "occasion_category_night"
    case occasionCategorySeason = "occasion_category_season"
    case occasionCategoryHistorical = "occasion_category_historical"

    case calendarTitle = "calendar_title"
    case calendarToday = "calendar_today"
    case calendarPickMonth = "calendar_pick_month"
    case calendarMonthLabel = "calendar_month_label"
    case calendarYearLabel = "calendar_year_label"
    case calendarDone = "calendar_done"
    case calendarShowGregorian = "calendar_show_gregorian"
    case calendarWeekStartsOn = "calendar_week_starts_on"
    case calendarWeekStartLocale = "calendar_week_start_locale"
    case calendarWeekStartSaturday = "calendar_week_start_saturday"
    case calendarWeekStartSunday = "calendar_week_start_sunday"
    case calendarWeekStartMonday = "calendar_week_start_monday"
    case calendarPreviousMonth = "calendar_previous_month"
    case calendarNextMonth = "calendar_next_month"
    case calendarDayAccessibility = "calendar_day_accessibility"
    case calendarOccasionsHeading = "calendar_occasions_heading"
    case calendarNoOccasions = "calendar_no_occasions"
    case calendarRecurring = "calendar_recurring"
    case calendarMoonHeading = "calendar_moon_heading"
    case calendarMoonSummary = "calendar_moon_summary"
    case calendarOffsetNote = "calendar_offset_note"

    case dayCountOne = "day_count_one"
    case dayCountTwo = "day_count_two"
    case dayCountFew = "day_count_few"
    case dayCountMany = "day_count_many"
    case inDayCount = "in_day_count"
    case occasionTomorrow = "occasion_tomorrow"
    case occasionHappeningNow = "occasion_happening_now"
    case occasionsUpcomingHeading = "occasions_upcoming_heading"
    case occasionsAllYear = "occasions_all_year"
    case occasionsYearTitle = "occasions_year_title"
    case occasionsYearNone = "occasions_year_none"
    case occasionsPreviousYear = "occasions_previous_year"
    case occasionsNextYear = "occasions_next_year"
    case occasionDetailVirtue = "occasion_detail_virtue"
    case occasionDetailSources = "occasion_detail_sources"
    case occasionDetailScholarlyNote = "occasion_detail_scholarly_note"
    case occasionDetailDates = "occasion_detail_dates"
    case occasionSourceLine = "occasion_source_line"
    case occasionSourceGraded = "occasion_source_graded"
    case moonDetailTitle = "moon_detail_title"
    case moonDetailPill = "moon_detail_pill"
    case moonDetailAge = "moon_detail_age"
    case moonDetailDistance = "moon_detail_distance"
    case moonDetailIlluminated = "moon_detail_illuminated"
    case moonDistanceValue = "moon_distance_value"
    case moonDistanceSpoken = "moon_distance_spoken"
    case moonCardAccessibility = "moon_card_accessibility"
    case moonPhaseStripHeading = "moon_phase_strip_heading"
    case moonPhaseStripHint = "moon_phase_strip_hint"
    case moonNextNewMoon = "moon_next_new_moon"
    case moonNextFullMoon = "moon_next_full_moon"
    case moonExplainerTitle = "moon_explainer_title"
    case moonExplainerBody = "moon_explainer_body"

    case sourceMoonImageTitle = "source_moon_image_title"
    case sourceMoonImageAttribution = "source_moon_image_attribution"
    case licenceNASA = "licence_nasa"
    case sourceMeeusTitle = "source_meeus_title"
    case sourceMeeusAttribution = "source_meeus_attribution"
    case licencePublishedAlgorithm = "licence_published_algorithm"

    case homeCalendarTodayLine = "home_calendar_today_line"
    case homeCalendarNextLine = "home_calendar_next_line"
    case homeCalendarHint = "home_calendar_hint"

    case homeCalendarMoonLine = "home_calendar_moon_line"

    case calendarHideRecurringDots = "calendar_hide_recurring_dots"
    case calendarHideRecurringFooter = "calendar_hide_recurring_footer"
    case calendarOffsetTitle = "calendar_offset_title"
    case calendarOffsetFooter = "calendar_offset_footer"
    case calendarOffsetNone = "calendar_offset_none"
    case calendarOffsetAdvance1 = "calendar_offset_advance_1"
    case calendarOffsetAdvance2 = "calendar_offset_advance_2"
    case calendarOffsetDelay1 = "calendar_offset_delay_1"
    case calendarOffsetDelay2 = "calendar_offset_delay_2"
}
