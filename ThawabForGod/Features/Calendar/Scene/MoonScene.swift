//
//  MoonScene.swift
//  ThawabForGod
//

import simd
import SceneKit

#if canImport(UIKit)
import UIKit
typealias MoonPlatformImage = UIImage
typealias MoonPlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias MoonPlatformImage = NSImage
typealias MoonPlatformColor = NSColor
#endif

/// A lit sphere wearing the Moon's near side: the scene behind the 3D moon screen.
///
/// **Camera-fixed light, spinning Moon.** The Sun's direction comes from the phase (see
/// `MoonLighting`) and never changes with the reader's dragging; what drags is the Moon itself,
/// through `yaw` and `pitch`. So turning the Moon shows its other faces under the light the phase
/// calls for, and "reset" puts the near side back toward the viewer.
///
/// Three nested nodes, each with one job: `rollNode` turns the face over for a southern viewer,
/// `spinNode` carries the reader's drag, and `moonNode` is the sphere with the texture aligned so
/// that, at rest, the near side faces the camera.
///
/// SceneKit is used because it is on all three platforms this app builds for. Nothing here is
/// compiled into the widgets or `Shared/`.
@MainActor
final class MoonScene {

    let scene = SCNScene()

    private let rollNode = SCNNode()
    private let spinNode = SCNNode()
    private let moonNode = SCNNode()
    private let sunNode = SCNNode()

    /// How far from the Moon the light sits. Directional lights have no position that matters;
    /// this only has to be outside the sphere for `look(at:)` to have something to aim along.
    private static let sunDistance = 10.0

    /// The camera's distance, for a unit sphere, chosen so the Moon fills most of the frame.
    private static let cameraDistance = 4.4

    /// Whether the texture was found. A build without the asset still gets a (grey) lit sphere.
    private(set) var hasTexture = false

    init(elongationDegrees: Double, hemisphere: MoonHemisphere) {
        scene.background.contents = MoonPlatformColor.clear

        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .lambert
        if let image = Self.texture() {
            material.diffuse.contents = image
            hasTexture = true
        } else {
            material.diffuse.contents = MoonPlatformColor.gray
        }
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        sphere.firstMaterial = material
        moonNode.geometry = sphere
        spinNode.addChildNode(moonNode)
        rollNode.addChildNode(spinNode)
        scene.rootNode.addChildNode(rollNode)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 30
        camera.position = vector(0, 0, Self.cameraDistance)
        scene.rootNode.addChildNode(camera)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1000
        sunNode.light = sun
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 1000 * MoonLighting.earthshine
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        update(elongationDegrees: elongationDegrees, hemisphere: hemisphere)
    }

    /// Re-aims the light and the roll for a new phase or hemisphere.
    func update(elongationDegrees: Double, hemisphere: MoonHemisphere) {
        let sun = MoonLighting.sunDirection(elongationDegrees: elongationDegrees, hemisphere: hemisphere)
        sunNode.position = vector(sun.x * Self.sunDistance, sun.y * Self.sunDistance, sun.z * Self.sunDistance)
        // A directional light shines along its own −z axis. Turn that axis to point from the Sun
        // at the Moon — set directly, because `look(at:)` mishandles the one case where the Sun is
        // exactly behind the Moon (a new moon), which left the near side lit.
        let travel = simd_normalize(SIMD3<Float>(-Float(sun.x), -Float(sun.y), -Float(sun.z)))
        sunNode.simdOrientation = Self.rotation(from: SIMD3<Float>(0, 0, -1), to: travel)

        let roll = MoonLighting.viewRollDegrees(hemisphere: hemisphere) * .pi / 180
        rollNode.eulerAngles = vector(0, 0, roll)
    }

    /// The reader's rotation, in radians. Zero for both is the near side facing the viewer.
    func setRotation(yaw: Double, pitch: Double) {
        spinNode.eulerAngles = vector(pitch, yaw, 0)
    }

    /// The way the light travels, in the camera's frame — the opposite of `SunDirection`.
    var lightTravelDirection: SunDirection {
        let front = sunNode.simdWorldFront
        return SunDirection(x: Double(front.x), y: Double(front.y), z: Double(front.z))
    }

    /// The shortest turn taking one unit vector to another; for opposite vectors, half a turn
    /// about the vertical, which is as good as any axis perpendicular to them.
    private static func rotation(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        if simd_dot(from, to) < -0.9999 {
            return simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
        }
        return simd_quatf(from: from, to: to)
    }

    var sunPosition: SunDirection {
        SunDirection(x: Double(sunNode.position.x), y: Double(sunNode.position.y), z: Double(sunNode.position.z))
    }

    var ambientIntensity: Double {
        Double(scene.rootNode.childNodes.compactMap(\.light).first { $0.type == .ambient }?.intensity ?? 0)
    }

    // MARK: Platform

    private static func texture() -> MoonPlatformImage? {
        MoonPlatformImage(named: "MoonColorMap")
    }

    /// `SCNVector3` takes `Float` on iOS and `CGFloat` on the Mac.
    private func vector(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
        #if canImport(UIKit)
        SCNVector3(Float(x), Float(y), Float(z))
        #else
        SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #endif
    }
}
