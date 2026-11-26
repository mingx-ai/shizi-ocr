import AppKit
import Combine
import UniformTypeIdentifiers

enum WorkspacePhase: Equatable {
    case ready, capturing, recognizing, result, empty, permission, failed(String)
}

final class WorkspaceModel: ObservableObject {
    @Published var image: NSImage?
    @Published var text = ""
    @Published var phase = WorkspacePhase.ready
    @Published var source = ""
    @Published var hotkeyAvailable = false

    var showWindow: () -> Void = {}
    var prepareForCapture: () -> Void = {}
    var restoreAfterCancellation: () -> Void = {}

    private let screenCapture = ScreenCapture()
    private let recognitionQueue = DispatchQueue(label: "studio.shizi.recognition", qos: .userInitiated)
    private var isChoosingFile = false

    var canStart: Bool {
        !isChoosingFile && phase != .capturing && phase != .recognizing
    }

    func capture() {
        guard canStart else { return }
        let previousPhase = phase
        phase = .capturing
        prepareForCapture()
        // Give the window server time to remove our window before the picker opens.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [self] in
            screenCapture.start { [self] result in
                switch result {
                case .image(let captured):
                    beginRecognition(sourceName: "屏幕截图")
                    recognize(captured)
                case .cancelled:
                    phase = previousPhase
                    restoreAfterCancellation()
                case .permissionRequired:
                    phase = .permission
                    showWindow()
                case .failure(let message):
                    phase = .failed(message)
                    showWindow()
                }
            }
        }
    }

    func importImage() {
        guard canStart else { return }
        showWindow()
        let panel = NSOpenPanel()
        panel.title = "打开图片"
        panel.prompt = "识别文字"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        isChoosingFile = true
        let response = panel.runModal()
        isChoosingFile = false
        if response == .OK, let url = panel.url {
            openImage(at: url)
        }
    }

    @discardableResult
    func openImage(at url: URL) -> Bool {
        guard canStart else { return false }
        beginRecognition(sourceName: url.lastPathComponent)
        recognitionQueue.async { [self] in
            do {
                let loaded = try Recognition.loadImage(at: url)
                DispatchQueue.main.async { self.recognize(loaded) }
            } catch {
                DispatchQueue.main.async { self.phase = .failed(error.localizedDescription) }
            }
        }
        return true
    }

    private func beginRecognition(sourceName: String) {
        phase = .recognizing
        source = sourceName
        text = ""
        image = nil
        showWindow()
    }

    private func recognize(_ captured: CGImage) {
        image = NSImage(cgImage: captured, size: .zero)
        recognitionQueue.async { [self] in
            do {
                let recognized = try Recognition.text(in: captured)
                DispatchQueue.main.async {
                    self.text = recognized
                    self.phase = recognized.isEmpty ? .empty : .result
                }
            } catch {
                DispatchQueue.main.async { self.phase = .failed(error.localizedDescription) }
            }
        }
    }

    @discardableResult
    func copyText(_ value: String, to pasteboard: NSPasteboard = .general) -> Bool {
        guard !value.isEmpty else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(value, forType: .string)
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
