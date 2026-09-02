//
//  ArabicNumerals.swift
//  ThawabForGod
//
//  Created by Saad Sherif on 27/08/2026.
//


import SwiftUI

// MARK: - Numerals

enum ArabicNumerals {
    /// 256 -> "٢٥٦"
    static func easternArabic(_ value: Int) -> String {
        let map: [Character: Character] = [
            "0":"٠","1":"١","2":"٢","3":"٣","4":"٤",
            "5":"٥","6":"٦","7":"٧","8":"٨","9":"٩"
        ]
        return String(String(value).map { map[$0] ?? $0 })
    }
}

// MARK: - Surah header

struct SurahHeaderView: View {
    let surahName: String
    var tint: Color = .primary
    var fontName: String? = nil          // your mushaf/Arabic font, nil = system

    private let centerWidthRatio: CGFloat = 0.45   // clear zone in the middle
    private let aspectRatio: CGFloat = 1000.0 / 220.0   // match your PDF

    var body: some View {
        Image("surah-header-2")                     // template PDF in asset catalog
            .renderingMode(.template)           // ← tinting mechanism
            .resizable()
            .aspectRatio(aspectRatio, contentMode: .fit)
            .foregroundStyle(tint)              // ← recolors the ornament
            .overlay {
                GeometryReader { proxy in
                    Text(surahName)
                        .font(font(size: proxy.size.height * 0.2))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)          // ← auto-fit
                        .frame(width: proxy.size.width * centerWidthRatio)
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // center
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .accessibilityLabel(surahName)
    }

    private func font(size: CGFloat) -> Font {
        fontName.map { .custom($0, size: size) } ?? .system(size: size, weight: .medium)
    }
}

// MARK: - Ayah medallion

struct AyahNumberView: View {
    let number: Int
    var tint: Color = .primary
    var useEasternArabicNumerals: Bool = false
    var fontName: String? = nil

    private let centerRatio: CGFloat = 0.5   // clear circle in the middle

    var body: some View {
        Image("ayah-medallion")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(1, contentMode: .fit)   // square
            .foregroundStyle(tint)
            .overlay {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    Text(display)
                        .font(font(size: side * 0.2))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .frame(width: side * centerRatio, height: side * centerRatio)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .accessibilityLabel("Ayah \(number)")
    }

    private var display: String {
        useEasternArabicNumerals ? ArabicNumerals.easternArabic(number) : "\(number)"
    }

    private func font(size: CGFloat) -> Font {
        fontName.map { .custom($0, size: size) } ?? .system(size: size, weight: .semibold)
    }
}

// MARK: - Previews

#Preview("Surah — light") {
    VStack(spacing: 24) {
        SurahHeaderView(surahName: "سورة الفاتحة")
        SurahHeaderView(surahName: "سورة البقرة")
        SurahHeaderView(surahName: "سورة آل عمران",
                        tint: Color(red: 0.72, green: 0.6, blue: 0.35))
    }
    .padding()
}

#Preview("Surah — dark") {
    VStack(spacing: 24) {
        SurahHeaderView(surahName: "سورة البقرة", tint: .white)
        SurahHeaderView(surahName: "سورة البقرة")
        SurahHeaderView(surahName: "سورة آل عمران",
                        tint: Color(red: 0.72, green: 0.6, blue: 0.35))
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}

#Preview("Ayah numbers") {
    HStack(spacing: 16) {
        AyahNumberView(number: 1)
        AyahNumberView(number: 25)
        AyahNumberView(number: 259, tint: .accent)
    }
    .frame(height: 60)
    .padding()
}
