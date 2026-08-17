//
//  InlineNotice.swift
//  ThawabForGod
//

import SwiftUI

/// A short explanation that takes the place of content that could not be shown.
///
/// Shared rather than feature-owned because two features already need exactly this shape — the
/// adhkar list and the tasbih list, both of which fail the same way when the corpus cannot be
/// opened — and a third reaching across into another feature's `Views` folder to borrow it would
/// be worse than either the duplication or this file.
///
/// It says something went wrong without dressing it as an alert: there is nothing to dismiss and
/// nothing the reader can do, so it sits in the layout where the content would have been.
struct InlineNotice: View {
    let message: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .appFont(.title2)
                .foregroundStyle(theme.warning)

            Text(message)
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    InlineNotice(message: "The adhkar could not be loaded.")
        .padding()
        .themed(ThemeManager(settingsStore: InMemorySettingsStore()))
}
