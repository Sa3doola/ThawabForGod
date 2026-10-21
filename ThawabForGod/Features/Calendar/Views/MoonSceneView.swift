//
//  MoonSceneView.swift
//  ThawabForGod
//

import SwiftUI

/// The Moon as a lit sphere for the selected day, which the reader can turn with a finger or the
/// pointer.
///
/// The phase decides where the light is (see `MoonLighting`); the reader decides which face turns
/// toward it. Under the sphere: the phase name, how much of the Moon is lit, and the date. Drawn on
/// the same dark ground as the Moon card, so the lit part reads against night.
struct MoonSceneView: View {
    let viewModel: MoonDetailViewModel

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var scene: MoonScene
    @State private var yaw = 0.0
    @State private var pitch = 0.0
    @State private var dragStart: (yaw: Double, pitch: Double)?

    init(viewModel: MoonDetailViewModel) {
        self.viewModel = viewModel
        let info = viewModel.info
        _scene = State(initialValue: MoonScene(
            elongationDegrees: info.elongationDegrees,
            hemisphere: viewModel.hemisphere
        ))
    }

    /// Radians per point of drag: about a half turn across a phone's width.
    private let sensitivity = 0.01

    var body: some View {
        let info = viewModel.info
        let phase = l10n.string(info.phase.labelKey)
        let percent = l10n.string(.moonPercentValue, l10n.string(Int((info.illuminatedFraction * 100).rounded())))

        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    sphere
                    caption(phase: phase, percent: percent)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l10n.string(.moonSceneAccessibility, phase, percent))
                .accessibilityIdentifier("moon.scene")
                .accessibilityAction(named: Text(l10n.string(.moonSceneRotateLeft))) { nudge(-0.5) }
                .accessibilityAction(named: Text(l10n.string(.moonSceneRotateRight))) { nudge(0.5) }
                .accessibilityAction(named: Text(l10n.string(.moonSceneReset))) { reset() }

                controls
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.moonSceneTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: info.elongationDegrees) { _, new in
            scene.update(elongationDegrees: new, hemisphere: viewModel.hemisphere)
        }
    }

    // MARK: Pieces

    private var sphere: some View {
        MoonSceneRepresentable(scene: scene, yaw: yaw, pitch: pitch, animated: dragStart == nil && !reduceMotion)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 360)
            // The gesture lives on this transparent layer rather than on the SceneKit view, so
            // SceneKit never sees a touch and cannot start orbiting the camera.
            .overlay { Color.clear.contentShape(Rectangle()).gesture(drag) }
    }

    private func caption(phase: String, percent: String) -> some View {
        VStack(spacing: 4) {
            Text(phase)
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(DayRamp.Ink.primary.color)
            Text(l10n.string(.moonSceneIlluminated, percent))
                .appFont(.subheadline)
                .foregroundStyle(DayRamp.Ink.primary.color.opacity(DayRamp.Ink.secondaryOpacity))
            Text(l10n.dateString(viewModel.day))
                .appFont(.footnote)
                .foregroundStyle(DayRamp.Ink.primary.color.opacity(DayRamp.Ink.secondaryOpacity))
        }
        .multilineTextAlignment(.center)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Text(l10n.string(.moonSceneHint))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)

            Button(action: reset) {
                Label(l10n.string(.moonSceneReset), systemImage: "arrow.counterclockwise")
                    .appFont(.subheadline, weight: .medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(yaw == 0 && pitch == 0)
            .accessibilityIdentifier("moon.scene.reset")
        }
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStart ?? (yaw, pitch)
                dragStart = start
                yaw = start.yaw + value.translation.width * sensitivity
                pitch = start.pitch + value.translation.height * sensitivity
            }
            .onEnded { _ in dragStart = nil }
    }

    private func nudge(_ radians: Double) {
        yaw += radians
    }

    /// Back to the near side, gliding unless Reduce Motion is on (the representable decides).
    private func reset() {
        yaw = 0
        pitch = 0
    }
}
