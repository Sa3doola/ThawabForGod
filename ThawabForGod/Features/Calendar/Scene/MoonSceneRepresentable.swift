//
//  MoonSceneRepresentable.swift
//  ThawabForGod
//

import SceneKit
import SwiftUI

/// Hosts the moon scene's `SCNView` in SwiftUI — a `UIViewRepresentable` on iOS and iPadOS, an
/// `NSViewRepresentable` on the Mac, over one shared configuration.
///
/// **It does not draw unless something changes.** `rendersContinuously` and `isPlaying` are both
/// off, so an idle moon, or one on a screen that has been covered, costs no frames: SceneKit
/// redraws when the scene graph changes, which is when the reader drags or the phase moves.
///
/// The view takes no touches (`allowsCameraControl` is off, and the representable is not hit-
/// tested): the screen puts its own drag gesture over it, because SceneKit's camera control would
/// orbit the *camera* and drag the light's frame along with it.
struct MoonSceneRepresentable {
    let scene: MoonScene
    let yaw: Double
    let pitch: Double

    /// Whether this change should glide. `false` while dragging — the finger is the animation —
    /// and under Reduce Motion.
    let animated: Bool

    private func makeSceneView() -> SCNView {
        let view = SCNView()
        view.scene = scene.scene
        view.rendersContinuously = false
        view.isPlaying = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 30
        return view
    }

    private func apply(to view: SCNView) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.35 : 0
        scene.setRotation(yaw: yaw, pitch: pitch)
        SCNTransaction.commit()
    }
}

#if canImport(UIKit)
extension MoonSceneRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = makeSceneView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        apply(to: view)
    }
}
#else
extension MoonSceneRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> SCNView {
        let view = makeSceneView()
        view.backgroundColor = .clear
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        apply(to: view)
    }
}
#endif
