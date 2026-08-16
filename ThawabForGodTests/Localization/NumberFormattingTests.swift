//
//  NumberFormattingTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

struct NumberFormattingTests {
    private let service = LocaleNumberFormattingService()

    @Test func rendersArabicIndicDigits() {
        #expect(service.string(from: 0, system: .arabicIndic) == "٠")
        #expect(service.string(from: 7, system: .arabicIndic) == "٧")
        #expect(service.string(from: 99, system: .arabicIndic) == "٩٩")
    }

    @Test func rendersLatinDigits() {
        #expect(service.string(from: 0, system: .latin) == "0")
        #expect(service.string(from: 7, system: .latin) == "7")
        #expect(service.string(from: 99, system: .latin) == "99")
    }

    @Test func theSameValueDiffersBetweenSystems() {
        let arabic = service.string(from: 1234, system: .arabicIndic)
        let latin = service.string(from: 1234, system: .latin)

        // Computed outside `#expect`: `allSatisfy` is `rethrows`, which the macro insists on
        // seeing wrapped in `try`.
        let arabicIsASCII = arabic.allSatisfy(\.isASCII)
        let latinIsASCII = latin.allSatisfy(\.isASCII)

        #expect(arabic != latin)
        #expect(arabic.contains("١"))
        #expect(arabicIsASCII == false)
        #expect(latinIsASCII)
    }

    @Test func groupsThousandsInBothSystems() {
        // Each system carries its own separator: "," for Latin, U+066C for Arabic-Indic.
        #expect(service.string(from: 1234, system: .latin) == "1,234")
        #expect(service.string(from: 1234, system: .arabicIndic) == "١٬٢٣٤")
    }

    /// Grouping is right for a count and wrong for a year: a Hijri year rendered as "1,448"
    /// is a bug users see on the Home screen every day of the 1400s.
    @Test func groupingCanBeTurnedOffForNumbersThatNameRatherThanCount() {
        #expect(service.string(from: 1448, grouped: false, system: .latin) == "1448")
        #expect(service.string(from: 1448, grouped: false, system: .arabicIndic) == "١٤٤٨")
    }

    @Test func honoursFractionDigits() {
        #expect(service.string(from: 21.5, fractionDigits: 1, system: .latin) == "21.5")
        #expect(service.string(from: 21.5, fractionDigits: 0, system: .latin) == "22")
        #expect(service.string(from: 3.25, fractionDigits: 2, system: .latin) == "3.25")

        let arabic = service.string(from: 21.5, fractionDigits: 1, system: .arabicIndic)
        #expect(arabic.contains("٢"))
        #expect(arabic.contains("٥"))
    }

    @Test(arguments: [AppLanguage.arabic, .english])
    func digitsDefaultToTheLanguage(_ language: AppLanguage) {
        let expected: NumberSystem = language == .arabic ? .arabicIndic : .latin
        #expect(NumberSystem.preferred(for: language) == expected)
    }
}
