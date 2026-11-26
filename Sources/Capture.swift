import AppKit
import ScreenCaptureKit

enum CaptureResult {
    case image(CGImage)
    case cancelled
    case permissionRequired
    case failure(String)
}

// The picker view is flipped, so its local coordinates already have the
// top-left origin used by ScreenCaptureKit's display source rectangle.
struct CaptureRegion {
    let points: CGRect
    let pixels: CGSize

    init?(from start: CGPoint, to end: CGPoint, bounds: CGRect, scale: CGFloat) {
        let drag = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(start.x - end.x), height: abs(start.y - end.y))
        let clipped = drag.intersection(bounds)
        guard clipped.width >= 1, clipped.height >= 1, !clipped.isNull, scale > 0 else { return nil }
        let pixelRect = clipped.applying(CGAffineTransform(scaleX: scale, y: scale)).integral
        points = pixelRect.applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        pixels = pixelRect.size
    }

    func quartzRect(on displayBounds: CGRect) -> CGRect {
        points.offsetBy(dx: displayBounds.minX, dy: displayBounds.minY)
    }
}

private final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

private final class CaptureSelectionView: NSView {
    var selected: ((CaptureRegion) -> Void)?
    var cancelled: (() -> Void)?
    private var start: CGPoint?
    private var end: CGPoint?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    private var region: CaptureRegion? {
        guard let start, let end, let window else { return nil }
        return CaptureRegion(from: start, to: end, bounds: bounds, scale: window.backingScaleFactor)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)
        let shade = NSBezierPath(rect: bounds)
        if let selection = region?.points { shade.appendRect(selection) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.26).setFill()
        shade.fill()

        if let selection = region?.points {
            let outline = NSBezierPath(rect: selection)
            NSColor.white.setStroke()
            outline.lineWidth = 1
            outline.stroke()
        } else if start == nil {
            let hint = NSAttributedString(string: "拖动框选区域  ·  Esc 取消", attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white
            ])
            let size = hint.size()
            let label = CGRect(x: bounds.midX - size.width / 2, y: 44, width: size.width, height: size.height)
            NSColor.black.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: label.insetBy(dx: -14, dy: -7), xRadius: 8, yRadius: 8).fill()
            hint.draw(in: label)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        start = convert(event.locationInWindow, from: nil)
        end = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        end = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        end = convert(event.locationInWindow, from: nil)
        if let region { selected?(region) } else { cancelled?() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancelled?() } else { super.keyDown(with: event) }
    }

    override func cancelOperation(_ sender: Any?) { cancelled?() }
    override func rightMouseDown(with event: NSEvent) { cancelled?() }
}

final class ScreenCapture {
    private var panels = [CapturePanel]()
    private var displayObserver: NSObjectProtocol?
    private var completion: ((CaptureResult) -> Void)?

    func start(completion: @escaping (CaptureResult) -> Void) {
        precondition(Thread.isMainThread)
        guard self.completion == nil else {
            completion(.failure("正在截取屏幕区域。"))
            return
        }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            completion(.permissionRequired)
            return
        }
        self.completion = completion

        var hoveredPanel: CapturePanel?
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { continue }
            let panel = CapturePanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .none
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.setFrame(screen.frame, display: false)

            let view = CaptureSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.selected = { [weak self, weak panel] region in
                guard let self, let panel else { return }
                self.capture(region, displayID: number.uint32Value, panelID: CGWindowID(panel.windowNumber))
            }
            view.cancelled = { [weak self] in self?.finish(.cancelled) }
            panel.contentView = view
            panel.makeFirstResponder(view)
            panels.append(panel)
            panel.orderFrontRegardless()
            if screen.frame.contains(NSEvent.mouseLocation) { hoveredPanel = panel }
        }
        guard let keyPanel = hoveredPanel ?? panels.first else {
            finish(.failure("找不到可截取的显示器。"))
            return
        }
        keyPanel.makeKey()
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.finish(.cancelled) }
    }

    private func capture(_ region: CaptureRegion, displayID: CGDirectDisplayID, panelID: CGWindowID) {
        if #available(macOS 14.0, *) {
            dismissPicker()
            captureWithScreenCaptureKit(region, displayID: displayID)
        } else {
            // On Ventura, limit the window list to the layers beneath the
            // picker and translate display-local points into Quartz global space.
            let rect = region.quartzRect(on: CGDisplayBounds(displayID))
            let image = CGWindowListCreateImage(rect, .optionOnScreenBelowWindow, panelID, [.bestResolution])
            finish(image.map(CaptureResult.image) ?? .failure("未能读取所选屏幕区域。"))
        }
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(_ region: CaptureRegion, displayID: CGDirectDisplayID) {
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    finish(.failure("所选显示器已断开。"))
                    return
                }
                let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.sourceRect = region.points
                config.width = Int(region.pixels.width)
                config.height = Int(region.pixels.height)
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                finish(.image(image))
            } catch {
                let error = error as NSError
                if !CGPreflightScreenCaptureAccess() ||
                    (error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue) {
                    finish(.permissionRequired)
                } else {
                    finish(.failure("未能截取屏幕区域。\(error.localizedDescription)"))
                }
            }
        }
    }

    private func dismissPicker() {
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        displayObserver = nil
        for panel in panels {
            panel.contentView = nil
            panel.close()
        }
        panels.removeAll()
    }

    private func finish(_ result: CaptureResult) {
        dismissPicker()
        let callback = completion
        completion = nil
        callback?(result)
    }
}
