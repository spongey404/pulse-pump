import SwiftUI
import SceneKit
import UIKit

/// Renders FinalBaseMesh.obj in a SceneKit view with per-vertex heatmap coloring.
/// SceneKit's built-in camera control handles orbit, pinch-to-zoom, and two-finger pan.
/// The model stays fixed; the camera moves around it. Tap to identify a muscle group.
struct Body3DSceneView: UIViewRepresentable {
    let muscleIntensities: [MuscleGroup: Double]
    let colorScheme: HeatmapColorScheme
    let onMuscleTap: (MuscleGroup?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMuscleTap: onMuscleTap)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        // Built-in: single-finger orbit, pinch zoom, two-finger pan
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.minimumVerticalAngle = -80
        scnView.defaultCameraController.maximumVerticalAngle = 80

        let coordinator = context.coordinator
        let capturedIntensities = muscleIntensities
        let capturedScheme = colorScheme

        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = Bundle.main.url(forResource: "FinalBaseMesh", withExtension: "obj"),
                  let loaded = try? SCNScene(url: url, options: [
                    SCNSceneSource.LoadingOption.flattenScene: false,
                    SCNSceneSource.LoadingOption.checkConsistency: false
                  ]) else { return }

            DispatchQueue.main.async {
                let scene = SCNScene()
                for child in loaded.rootNode.childNodes {
                    scene.rootNode.addChildNode(child)
                }
                scene.rootNode.addChildNode(Self.makeAmbientLight())
                scene.rootNode.addChildNode(Self.makeDirectionalLight())

                // Camera starts at front, orbiting target is model centre
                let cam = SCNCamera()
                cam.fieldOfView = 50
                cam.zFar = 300
                let camNode = SCNNode()
                camNode.camera = cam
                camNode.position = SCNVector3(0, 10.3, 35)
                camNode.look(at: SCNVector3(0, 10.3, 0))
                scene.rootNode.addChildNode(camNode)

                scnView.scene = scene
                scnView.pointOfView = camNode

                // Point the camera controller at the model's vertical centre
                scnView.defaultCameraController.target = SCNVector3(0, 10.3, 0)

                coordinator.scene = scene

                // Cache vertex positions once for coloring and tap mapping
                scene.rootNode.enumerateChildNodes { node, stop in
                    guard coordinator.meshNode == nil,
                          let geo = node.geometry,
                          let src = geo.sources(for: .vertex).first else { return }
                    coordinator.meshNode = node
                    coordinator.cachedVertices = Coordinator.extractVertices(from: src)
                    stop.pointee = true
                }

                coordinator.applyColors(intensities: capturedIntensities, colorScheme: capturedScheme)
            }
        }

        // Tap to select muscle — works alongside SceneKit's built-in gestures
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        scnView.addGestureRecognizer(tap)
        coordinator.scnView = scnView

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        context.coordinator.applyColors(intensities: muscleIntensities, colorScheme: colorScheme)
    }

    // MARK: - Scene helpers

    private static func makeAmbientLight() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 500
        light.color = UIColor.white
        let node = SCNNode()
        node.light = light
        return node
    }

    private static func makeDirectionalLight() -> SCNNode {
        let light = SCNLight()
        light.type = .directional
        light.intensity = 700
        light.color = UIColor.white
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(5, 20, 15)
        node.look(at: SCNVector3(0, 10.3, 0))
        return node
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        weak var scnView: SCNView?
        var scene: SCNScene?
        var meshNode: SCNNode?
        var cachedVertices: [SCNVector3] = []
        let onMuscleTap: (MuscleGroup?) -> Void

        init(onMuscleTap: @escaping (MuscleGroup?) -> Void) {
            self.onMuscleTap = onMuscleTap
        }

        // MARK: Tap

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scnView else { return }
            let pt = recognizer.location(in: scnView)
            let hits = scnView.hitTest(pt, options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            guard let hit = hits.first else { return }
            let localPos = hit.node.convertPosition(hit.worldCoordinates, from: nil)
            onMuscleTap(Self.muscleGroup(at: localPos))
        }

        // MARK: Vertex coloring

        func applyColors(intensities: [MuscleGroup: Double], colorScheme: HeatmapColorScheme) {
            guard let node = meshNode,
                  let geometry = node.geometry,
                  !cachedVertices.isEmpty else { return }

            let baseSkin = UIColor(red: 0.80, green: 0.71, blue: 0.65, alpha: 1)
            var floats = [Float]()
            floats.reserveCapacity(cachedVertices.count * 4)

            for v in cachedVertices {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if let muscle = Self.muscleGroup(at: v),
                   let intensity = intensities[muscle], intensity > 0 {
                    UIColor(colorScheme.color(for: intensity)).getRed(&r, green: &g, blue: &b, alpha: &a)
                } else {
                    baseSkin.getRed(&r, green: &g, blue: &b, alpha: &a)
                }
                floats.append(Float(r)); floats.append(Float(g))
                floats.append(Float(b)); floats.append(Float(a))
            }

            let data = Data(bytes: floats, count: floats.count * MemoryLayout<Float>.size)
            let colorSource = SCNGeometrySource(
                data: data,
                semantic: .color,
                vectorCount: cachedVertices.count,
                usesFloatComponents: true,
                componentsPerVector: 4,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: 4 * MemoryLayout<Float>.size
            )

            let nonColorSources = geometry.sources.filter { $0.semantic != .color }
            let newGeo = SCNGeometry(sources: nonColorSources + [colorSource], elements: geometry.elements)
            let mat = SCNMaterial()
            mat.lightingModel = .lambert
            mat.diffuse.contents = UIColor.white
            mat.isDoubleSided = false
            newGeo.materials = [mat]
            node.geometry = newGeo
        }

        // MARK: Vertex extraction

        static func extractVertices(from source: SCNGeometrySource) -> [SCNVector3] {
            let count = source.vectorCount
            let stride = source.dataStride
            let offset = source.dataOffset
            let bpc = source.bytesPerComponent
            return source.data.withUnsafeBytes { raw -> [SCNVector3] in
                var result = [SCNVector3]()
                result.reserveCapacity(count)
                for i in 0..<count {
                    let base = offset + i * stride
                    let x = raw.load(fromByteOffset: base, as: Float.self)
                    let y = raw.load(fromByteOffset: base + bpc, as: Float.self)
                    let z = raw.load(fromByteOffset: base + 2 * bpc, as: Float.self)
                    result.append(SCNVector3(x, y, z))
                }
                return result
            }
        }

        // MARK: Muscle zone mapping
        //
        // Mesh bounding box: X ±5.84, Y 0–20.68 (feet→head), Z −1.85–+1.92 (back→front)

        static func muscleGroup(at v: SCNVector3) -> MuscleGroup? {
            let x = v.x, y = v.y, z = v.z
            let absX = abs(x)

            if y > 18.5 { return nil }  // head

            // Traps
            if y > 17.0 && z < 0 && absX < 4 { return .traps }

            // Side delts
            if y > 14.5 && y < 18 && absX > 4.5 { return .sideDelts }

            // Front / rear delts
            if y > 14.5 && y < 18 && absX > 2.5 && absX <= 4.5 {
                return z >= 0 ? .frontDelts : .rearDelts
            }

            // Chest
            if y > 13.5 && y < 17 && z > 0.3 && absX < 4.0 { return .chest }

            // Upper back / rhomboids
            if y > 14.0 && y < 18 && z < -0.2 && absX < 2.5 { return .upperBack }

            // Lats
            if y > 11.0 && y < 16 && z < -0.1 && absX > 2.0 { return .lats }

            // Biceps / triceps
            if y > 10.0 && y < 15 && absX > 3.5 {
                return z >= 0 ? .biceps : .triceps
            }

            // Forearms
            if y > 6.0 && y < 10.5 && absX > 3.0 { return .forearms }

            // Abs
            if y > 10.0 && y < 14 && z > 0.4 && absX < 2.0 { return .abs }

            // Obliques
            if y > 9.0 && y < 14 && z > 0.1 && absX >= 2.0 && absX < 4.0 { return .obliques }

            // Lower back
            if y > 9.5 && y < 13 && z < -0.2 && absX < 2.5 { return .lowerBack }

            // Glutes
            if y > 8.0 && y < 11.5 && z < -0.1 { return .glutes }

            // Thighs
            if y > 4.0 && y < 9.5 {
                if absX < 1.5 { return .adductors }
                return z >= 0 ? .quads : .hamstrings
            }

            // Calves
            if y > 0.5 && y < 4.5 { return .calves }

            return nil
        }
    }
}
