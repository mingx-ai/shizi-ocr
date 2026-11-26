import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct RecognitionCheck {
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    static func fixture(lines: [String]) throws -> CGImage {
        let width = 960, height = 300
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw Failure("Cannot create fixture context")
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String):
                CTFontCreateWithName("PingFangSC-Regular" as CFString, 52, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 0, alpha: 1)
        ]
        for (index, value) in lines.enumerated() {
            let line = NSAttributedString(string: value, attributes: attributes)
            context.textPosition = CGPoint(x: 36, y: 218 - 80 * index)
            CTLineDraw(CTLineCreateWithAttributedString(line), context)
        }
        guard let image = context.makeImage() else { throw Failure("Cannot render fixture") }
        return image
    }

    static func write(_ image: CGImage, to url: URL, as type: UTType,
                      orientation: CGImagePropertyOrientation = .up) throws {
        guard let target = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw Failure("Cannot create image fixture")
        }
        CGImageDestinationAddImage(target, image, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
        guard CGImageDestinationFinalize(target) else { throw Failure("Cannot save image fixture") }
    }

    static func run() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let image = try fixture(lines: ["Local text capture", "屏幕文字提取", "繁體字與資料"])
        let png = directory.appendingPathComponent("text.png")
        try write(image, to: png, as: .png)
        let loaded = try Recognition.loadImage(at: png)
        guard loaded.width == 960, loaded.height == 300 else { throw Failure("PNG dimensions changed") }
        print("PASS full-resolution PNG")
        let jpeg = directory.appendingPathComponent("rotated.jpg")
        try write(image, to: jpeg, as: .jpeg, orientation: .right)
        let rotated = try Recognition.loadImage(at: jpeg)
        guard rotated.width == 300, rotated.height == 960 else { throw Failure("EXIF orientation was lost") }
        print("PASS EXIF orientation")

        let corrupt = directory.appendingPathComponent("corrupt.png")
        try Data("invalid image".utf8).write(to: corrupt)
        if (try? Recognition.loadImage(at: corrupt)) != nil { throw Failure("Corrupt file was accepted") }
        print("PASS corrupt file")

        let recognized = try Recognition.text(in: loaded)
        let lines = recognized.components(separatedBy: .newlines).map { $0.replacingOccurrences(of: " ", with: "") }
        guard lines == ["Localtextcapture", "屏幕文字提取", "繁體字與資料"] else {
            throw Failure("Unexpected OCR lines: \(recognized.debugDescription)")
        }
        print("PASS bilingual OCR and line order: \(lines)")

        let blank = try fixture(lines: [])
        guard try Recognition.text(in: blank).isEmpty else { throw Failure("Blank image produced text") }
        print("PASS blank image")
    }

    static func main() {
        do {
            try run()
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
