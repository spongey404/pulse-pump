import SwiftUI
import AVFoundation
import Photos

/// Renders the 6-second share card once to an MP4 (1080 × 1920, 30 fps, H.264) and caches it for the same card.
@MainActor
final class ShareVideoExporter {
    static let shared = ShareVideoExporter()
    private var cache: [String: URL] = [:]

    enum ExportError: Error { case writer, geometry }

    static func key(_ m: ShareCardModel) -> String { "\(m.title)|\(m.style.rawValue)|\(m.accentHex)|\(m.member)|\(m.sets)|\(Int(m.volumeKg))|\(m.prCount)|\(m.levels.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value)" }.joined())" }

    func export(_ model: ShareCardModel, weightUnit: UnitPreference, progress: @escaping (Double) -> Void = { _ in }) async throws -> URL {
        let key = Self.key(model)
        if let url = cache[key], FileManager.default.fileExists(atPath: url.path) { progress(1); return url }
        var geometry: [BodyMapSide: BodyFigureGeometry] = [:]
        for side in model.sides { if let g = await BodyMapGeometry.figure(side) { geometry[side] = g } }
        guard !geometry.isEmpty else { throw ExportError.geometry }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ore-\(UUID().uuidString.prefix(8)).mp4")
        let w = Int(ShareCardModel.size.width * 2), h = Int(ShareCardModel.size.height * 2)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        guard writer.canAdd(input) else { throw ExportError.writer }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writer }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<ShareCardModel.frameCount {
            let t = Double(frame) / Double(ShareCardModel.frameRate)
            let renderer = ImageRenderer(content: PostShareCardView(model: model, t: t, geometry: geometry).environment(\.weightUnit, weightUnit))
            renderer.scale = 2
            guard let cg = renderer.uiImage?.cgImage, let pool = adaptor.pixelBufferPool else { throw ExportError.writer }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let buffer = pb else { throw ExportError.writer }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(ShareCardModel.frameRate)))
            progress(Double(frame + 1) / Double(ShareCardModel.frameCount))
            await Task.yield()
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ExportError.writer }
        cache[key] = url
        return url
    }

    /// Adds the video to Photos (needs only add-access).
    static func saveToPhotos(_ url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return (try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }) != nil
    }
}
