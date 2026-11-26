import AppKit
import SwiftUI

@main
enum ShiziApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let model = WorkspaceModel()
    private var window: NSWindow?
    private var shortcut: GlobalShortcut?
    private var statusItem: NSStatusItem?
    private var windowWasVisible = false
    private var applicationWasHidden = false
    private var previousApplication: NSRunningApplication?

    func applicationWillFinishLaunching(_ notification: Notification) {
        model.showWindow = { [weak self] in self?.showWindow() }
        model.prepareForCapture = { [weak self] in self?.hideForCapture() }
        model.restoreAfterCancellation = { [weak self] in self?.restoreAfterCancellation() }
        installMenus()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        shortcut = GlobalShortcut { [weak self] in self?.model.capture() }
        model.hotkeyAvailable = shortcut != nil
        installStatusItem()
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model.phase != .capturing { showWindow() }
        return false
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        model.openImage(at: URL(fileURLWithPath: filename))
    }

    @objc private func showWindow() {
        if window == nil {
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 530),
                                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                   backing: .buffered, defer: false)
            created.title = "拾字"
            created.isReleasedWhenClosed = false
            created.isRestorable = false
            created.contentView = NSHostingView(rootView: WorkspaceView(model: model))
            created.contentMinSize = NSSize(width: 680, height: 430)
            created.collectionBehavior = [.moveToActiveSpace, .fullScreenNone]
            created.center()
            created.setFrameAutosaveName("ShiziWorkspace")
            window = created
        }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func hideForCapture() {
        applicationWasHidden = NSApp.isHidden
        previousApplication = NSWorkspace.shared.frontmostApplication
        if applicationWasHidden { NSApp.unhideWithoutActivation() }
        windowWasVisible = window?.isVisible == true && window?.isMiniaturized == false
        if window?.isMiniaturized == false { window?.orderOut(nil) }
    }

    private func restoreAfterCancellation() {
        if applicationWasHidden {
            if windowWasVisible { window?.orderBack(nil) }
            NSApp.hide(nil)
        } else if previousApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            if windowWasVisible { showWindow() }
        } else {
            if windowWasVisible { window?.orderBack(nil) }
            previousApplication?.activate(options: [])
        }
        previousApplication = nil
    }

    @objc private func capture() { model.capture() }
    @objc private func importImage() { model.importImage() }

    private func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(capture), #selector(importImage): return model.canStart
        case #selector(showWindow): return model.phase != .capturing
        default: return true
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "拾字")
            button.toolTip = "拾字 · 截屏取字"
        }
        let menu = NSMenu()
        let captureItem = actionItem("截屏取字", #selector(capture))
        if model.hotkeyAvailable {
            captureItem.keyEquivalent = "2"
            captureItem.keyEquivalentModifierMask = [.command, .shift]
        }
        menu.addItem(captureItem)
        menu.addItem(actionItem("打开图片…", #selector(importImage)))
        menu.addItem(actionItem("显示拾字窗口", #selector(showWindow)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出拾字", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }

    private func installMenus() {
        let main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            item.submenu = menu
            main.addItem(item)
            return menu
        }
        let app = submenu("拾字")
        app.addItem(withTitle: "关于拾字", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "隐藏拾字", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "退出拾字", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = submenu("文件")
        file.addItem(actionItem("截屏取字", #selector(capture), key: "n"))
        file.addItem(actionItem("打开图片…", #selector(importImage), key: "o"))
        file.addItem(.separator())
        file.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = submenu("编辑")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let windows = submenu("窗口")
        windows.addItem(actionItem("显示拾字窗口", #selector(showWindow)))
        windows.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = windows
        NSApp.mainMenu = main
    }
}
