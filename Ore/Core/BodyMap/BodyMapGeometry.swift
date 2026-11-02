import SwiftUI
import CoreGraphics

/// One muscle of a figure: its path in the 1640 × 2360 artwork space, plus what the Stardust needs (area, a pool of random
/// points inside the shape, built once from a coverage bitmap so nothing calls `contains` while drawing).
struct BodyMuscleShape {
    let id: String
    let path: Path
    let bounds: CGRect
    /// Area in artwork units².
    let area: Double
    /// Uniform random points inside the muscle (a prefix of any length is itself uniform).
    let candidates: [CGPoint]
}

/// A front or back figure: silhouette, muscles and the ink (filled line work drawn above the Stardust).
final class BodyFigureGeometry: @unchecked Sendable {
    static let artSize = CGSize(width: 1640, height: 2360)
    let outline: Path
    let muscles: [BodyMuscleShape]
    let ink: [Path]
    init(outline: Path, muscles: [BodyMuscleShape], ink: [Path]) { self.outline = outline; self.muscles = muscles; self.ink = ink }

    /// The muscle under a point given in artwork units (later muscles are on top).
    func muscle(at p: CGPoint) -> BodyMuscleShape? {
        muscles.last { $0.bounds.contains(p) && $0.path.contains(p) }
    }
}

enum BodyMapSide: String, CaseIterable { case front, back }

enum BodyMapGeometry {
    /// Absolute M / L / C / Z, which is all the artwork uses.
    static func parse(_ d: String) -> Path {
        var path = Path()
        var nums: [CGFloat] = []
        nums.reserveCapacity(6)
        var cmd: UInt8 = 0
        var cur = CGPoint.zero
        let bytes = Array(d.utf8)
        var i = 0
        func flush() {
            switch cmd {
            case UInt8(ascii: "M") where nums.count >= 2: cur = CGPoint(x: nums[0], y: nums[1]); path.move(to: cur)
            case UInt8(ascii: "L") where nums.count >= 2: cur = CGPoint(x: nums[0], y: nums[1]); path.addLine(to: cur)
            case UInt8(ascii: "C") where nums.count >= 6:
                cur = CGPoint(x: nums[4], y: nums[5])
                path.addCurve(to: cur, control1: CGPoint(x: nums[0], y: nums[1]), control2: CGPoint(x: nums[2], y: nums[3]))
            default: break
            }
            nums.removeAll(keepingCapacity: true)
        }
        func arity(_ c: UInt8) -> Int { c == UInt8(ascii: "C") ? 6 : (c == UInt8(ascii: "M") || c == UInt8(ascii: "L")) ? 2 : 0 }
        while i < bytes.count {
            let b = bytes[i]
            if b == 32 || b == 44 || b == 10 || b == 13 || b == 9 { i += 1; continue }
            if (b >= 65 && b <= 90) || (b >= 97 && b <= 122) {
                if b == UInt8(ascii: "Z") || b == UInt8(ascii: "z") { path.closeSubpath(); cmd = 0 } else { cmd = b }
                nums.removeAll(keepingCapacity: true)
                i += 1
                continue
            }
            // A number: [-]digits[.digits][e±n]
            var j = i
            if bytes[j] == 45 || bytes[j] == 43 { j += 1 }
            while j < bytes.count, (bytes[j] >= 48 && bytes[j] <= 57) || bytes[j] == 46 { j += 1 }
            if j < bytes.count, bytes[j] == 101 || bytes[j] == 69 {
                j += 1
                if j < bytes.count, bytes[j] == 45 || bytes[j] == 43 { j += 1 }
                while j < bytes.count, bytes[j] >= 48 && bytes[j] <= 57 { j += 1 }
            }
            if j == i { i += 1; continue }
            nums.append(CGFloat(Double(String(decoding: bytes[i..<j], as: UTF8.self)) ?? 0))
            i = j
            if nums.count == arity(cmd) {
                let keep = cmd
                flush()
                // A command letter may be followed by further coordinate sets (implicit repeat; M repeats as L).
                cmd = keep == UInt8(ascii: "M") ? UInt8(ascii: "L") : keep
            }
        }
        return path
    }

    private struct SplitMix: RandomNumberGenerator {
        var s: UInt64
        mutating func next() -> UInt64 {
            s &+= 0x9E3779B97F4A7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    /// Area and uniform interior points, found against a coverage bitmap of the shape (about 160 px on its long side).
    static func sample(_ path: Path, bounds: CGRect, seed: UInt64, count: Int) -> (area: Double, points: [CGPoint]) {
        let scale = 160 / max(bounds.width, bounds.height, 1)
        let w = max(2, Int(ceil(bounds.width * scale))), h = max(2, Int(ceil(bounds.height * scale)))
        var pixels = [UInt8](repeating: 0, count: w * h)
        pixels.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.translateBy(x: 0, y: 0)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
        let covered = pixels.reduce(0) { $0 + ($1 > 127 ? 1 : 0) }
        let area = bounds.width * bounds.height * Double(covered) / Double(w * h)
        var rng = SplitMix(s: seed)
        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        var guardCount = 0
        while pts.count < count, guardCount < count * 60, covered > 0 {
            guardCount += 1
            let fx = Double.random(in: 0..<1, using: &rng), fy = Double.random(in: 0..<1, using: &rng)
            let px = min(w - 1, Int(fx * Double(w))), py = min(h - 1, Int(fy * Double(h)))
            if pixels[py * w + px] > 127 {
                pts.append(CGPoint(x: bounds.minX + fx * bounds.width, y: bounds.minY + fy * bounds.height))
            }
        }
        return (area, pts)
    }

    struct Raw: Decodable {
        struct Muscle: Decodable { var id: String; var d: String }
        struct Side: Decodable { var outline: String; var muscles: [Muscle]; var ink: [String] }
        var front: Side
        var back: Side
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [BodyMapSide: BodyFigureGeometry] = [:]
    nonisolated(unsafe) private static var loading: Task<[BodyMapSide: BodyFigureGeometry], Never>?

    /// Decodes and builds both figures once, off the main thread.
    static func figure(_ side: BodyMapSide, bundle: Bundle = .main) async -> BodyFigureGeometry? {
        if let hit = lock.withLock({ cache[side] }) { return hit }
        let task: Task<[BodyMapSide: BodyFigureGeometry], Never> = lock.withLock {
            if let t = loading { return t }
            let t = Task.detached(priority: .userInitiated) { build(bundle: bundle) }
            loading = t
            return t
        }
        let all = await task.value
        lock.withLock { cache = all }
        return all[side]
    }

    static func build(bundle: Bundle) -> [BodyMapSide: BodyFigureGeometry] {
        guard let url = bundle.url(forResource: "bodymap.geometry", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return [:] }
        return [.front: figure(raw.front, seed: 11), .back: figure(raw.back, seed: 29)]
    }

    private static func figure(_ s: Raw.Side, seed: UInt64) -> BodyFigureGeometry {
        let muscles = s.muscles.enumerated().map { i, m -> BodyMuscleShape in
            let p = parse(m.d)
            let b = p.boundingRect
            let sample = sample(p, bounds: b, seed: seed &* 1000 &+ UInt64(i), count: 2400)
            return BodyMuscleShape(id: m.id, path: p, bounds: b, area: sample.area, candidates: sample.points)
        }
        return BodyFigureGeometry(outline: parse(s.outline), muscles: muscles, ink: s.ink.map(parse))
    }
}
