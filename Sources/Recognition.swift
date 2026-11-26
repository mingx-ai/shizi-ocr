import Foundation
import ImageIO
import Vision

enum Recognition {
    private enum Failure: LocalizedError {
        case unreadableImage(String)
        case recognition(Error)

        var errorDescription: String? {
            switch self {
            case let .unreadableImage(name):
                return "无法读取图片“\(name)”。请检查文件是否完整，并确认可以打开它。"
            case let .recognition(error):
                return "文字识别失败。\(error.localizedDescription)"
            }
        }
    }

    static func loadImage(at url: URL) throws -> CGImage {
        // Applying the orientation here gives the preview and OCR the same upright pixels.
        // Omitting a maximum thumbnail size keeps small screenshot text at full resolution.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unreadableImage(url.lastPathComponent)
        }
        return image
    }

    static func text(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        do {
            let supported = try request.supportedRecognitionLanguages()
            let preferred = ["zh-Hans", "zh-Hant", "en-US"].filter(supported.contains)
            if !preferred.isEmpty { request.recognitionLanguages = preferred }
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            throw Failure.recognition(error)
        }
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first?.string
        }.joined(separator: "\n")
    }
}
