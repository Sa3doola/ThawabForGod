//
//  NoorWidgetsBundle.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Noor's widgets.
///
/// One kind today. The bundle exists so adding a second — a Hijri date, a verse of the day — is
/// a line here rather than a second extension target with a second copy of everything in
/// `Shared/`.
@main
struct NoorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
    }
}
