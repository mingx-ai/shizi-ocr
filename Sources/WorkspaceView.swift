import AppKit
import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceModel
    @Environment(\.colorScheme) private var scheme

    private var colors: WorkspaceColors { WorkspaceColors(dark: scheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.phase {
                case .ready:
                    welcome
                case .result, .empty:
                    results
                case .recognizing:
                    status(symbol: "text.viewfinder", title: "正在识别文字", detail: "正在读取图像中的文字…", busy: true)
                case .capturing:
                    status(symbol: "viewfinder", title: "框选屏幕区域", detail: "拖动鼠标选择区域，按 Esc 取消。", busy: true)
                case .permission:
                    status(symbol: "macwindow", title: "允许拾字截取屏幕",
                           detail: "请在系统设置中为拾字开启屏幕录制权限，然后重新截屏。")
                case .failed(let reason):
                    status(symbol: "exclamationmark.triangle", title: "未能完成识别", detail: reason)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(colors.background)
        .foregroundStyle(colors.ink)
        .tint(colors.accent)
    }

    private var welcome: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 400
            VStack(spacing: 0) {
                Spacer(minLength: 4)
                ScanIllustration(dark: scheme == .dark)
                    .frame(width: compact ? 290 : 356, height: compact ? 141 : 173)
                    .accessibilityHidden(true)
                Text("框选屏幕，提取文字")
                    .font(.system(size: compact ? 27 : 31, weight: .semibold))
                    .padding(.top, compact ? 9 : 16)
                    .accessibilityAddTraits(.isHeader)
                Text("拖动框选任意屏幕区域，即可选择并复制其中的文字。")
                    .font(.system(size: 14))
                    .foregroundStyle(colors.muted)
                    .padding(.top, 10)
                HStack(spacing: 12) {
                    captureButton()
                    importButton
                }
                .padding(.top, compact ? 21 : 26)
                Spacer(minLength: 14)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 10) {
                Text("识别结果")
                    .font(.system(size: 23, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                importButton
                captureButton("重新截屏")
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    PanelHeading(title: "原图", symbol: "photo", colors: colors) {
                        if !model.source.isEmpty {
                            Text(verbatim: model.source)
                                .font(.system(size: 11))
                                .foregroundStyle(colors.muted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(model.source)
                        }
                    }
                    colors.line.frame(height: 1)
                    ZStack {
                        colors.preview
                        if let image = model.image {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .padding(14)
                                .accessibilityLabel("识别所用的原图")
                        } else {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(colors.muted)
                        }
                    }
                }
                .frame(minWidth: 165, maxWidth: .infinity, maxHeight: .infinity)
                .modifier(WorkspacePanel(colors: colors))

                TextResultPanel(model: model, colors: colors)
                    .id(model.image.map(ObjectIdentifier.init))
                    .frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 21)
        .padding(.bottom, 22)
    }

    private func status(symbol: String, title: String, detail: String, busy: Bool = false) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(colors.accent.opacity(scheme == .dark ? 0.13 : 0.08))
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(colors.accent)
            }
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)

            Text(verbatim: title)
                .font(.system(size: 25, weight: .semibold))
                .padding(.top, 21)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: detail)
                .font(.system(size: 14))
                .foregroundStyle(colors.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)
                .padding(.top, 10)
            if busy {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 22)
            } else {
                HStack(spacing: 12) {
                    if model.phase == .permission {
                        Button {
                            model.openPrivacySettings()
                        } label: {
                            Label("打开系统设置", systemImage: "gearshape")
                        }
                        .buttonStyle(WorkspaceButton(colors: colors, prominent: true))
                        captureButton("重试截屏", prominent: false)
                    } else {
                        captureButton("重新截屏")
                    }
                    importButton
                }
                .padding(.top, 24)
            }
        }
        .padding(24)
    }

    private func captureButton(_ title: String = "截屏取字", prominent: Bool = true) -> some View {
        Button(action: model.capture) {
            Label(title, systemImage: "viewfinder")
        }
        .buttonStyle(WorkspaceButton(colors: colors, prominent: prominent))
    }

    private var importButton: some View {
        Button(action: model.importImage) {
            Label("导入图片", systemImage: "photo")
        }
        .buttonStyle(WorkspaceButton(colors: colors))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            colors.line.frame(height: 1)
            HStack(spacing: 7) {
                Image(systemName: "lock")
                    .foregroundStyle(colors.accent)
                Text("本机识别")
                Spacer()
                if model.hotkeyAvailable {
                    Text("全局截屏")
                    HStack(spacing: 3) {
                        ForEach(["⌘", "⇧", "2"], id: \.self) { key in
                            Text(verbatim: key)
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 20, height: 19)
                                .background(colors.surface, in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.line))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Command Shift 2")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(colors.muted)
            .padding(.horizontal, 24)
            .frame(height: 42)
        }
        .background(colors.footer)
    }
}

private struct TextResultPanel: View {
    private struct CopyFeedback: Equatable {
        let id = UUID()
        let succeeded: Bool
    }

    @ObservedObject var model: WorkspaceModel
    let colors: WorkspaceColors
    @State private var selection = ""
    @State private var confirmation: CopyFeedback?

    private var copyLabel: String {
        if let confirmation { return confirmation.succeeded ? "已复制" : "复制失败" }
        return selection.isEmpty ? "复制全文" : "复制选中"
    }

    private var copyIcon: String {
        if let confirmation { return confirmation.succeeded ? "checkmark" : "exclamationmark.circle" }
        return "doc.on.doc"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeading(title: "文字", symbol: "text.alignleft", colors: colors) {
                if model.phase == .result && !model.text.isEmpty {
                    Button {
                        copy(selection.isEmpty ? model.text : selection)
                    } label: {
                        Label(copyLabel, systemImage: copyIcon)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(WorkspaceButton(colors: colors, small: true))
                }
            }
            colors.line.frame(height: 1)
            if model.phase == .empty || model.text.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 25))
                        .foregroundStyle(colors.muted)
                        .padding(.bottom, 3)
                    Text("未识别到文字")
                        .font(.system(size: 15, weight: .medium))
                    Text("试试框选更清晰的文字区域。")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SelectableResultText(value: model.text, selectionChanged: { text in
                    if selection != text {
                        selection = text
                    }
                    confirmation = nil
                }, copy: copy)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .modifier(WorkspacePanel(colors: colors))
        .onChange(of: model.text) { _ in
            selection = ""
            confirmation = nil
        }
        .task(id: confirmation) {
            guard let current = confirmation else { return }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled && confirmation == current {
                confirmation = nil
            }
        }
    }

    private func copy(_ value: String) {
        guard !value.isEmpty else { return }
        confirmation = CopyFeedback(succeeded: model.copyText(value))
    }
}

private struct PanelHeading<Accessory: View>: View {
    let title: String
    let symbol: String
    let colors: WorkspaceColors
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(colors.accent)
            Text(verbatim: title).fontWeight(.semibold).fixedSize()
            Spacer(minLength: 4)
            accessory()
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}

private struct WorkspacePanel: ViewModifier {
    let colors: WorkspaceColors

    func body(content: Content) -> some View {
        content
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.line))
    }
}

private struct WorkspaceButton: ButtonStyle {
    let colors: WorkspaceColors
    var prominent = false
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 14, weight: .medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, small ? 9 : 16)
            .frame(height: small ? 27 : 37)
            .foregroundStyle(prominent ? Color.white : (small ? colors.accent : colors.ink))
            .background(prominent ? colors.button : (small ? colors.preview : colors.surface),
                        in: RoundedRectangle(cornerRadius: small ? 6 : 8))
            .overlay {
                RoundedRectangle(cornerRadius: small ? 6 : 8)
                    .strokeBorder(prominent ? Color.black.opacity(0.08) : colors.line)
            }
            .contentShape(RoundedRectangle(cornerRadius: small ? 6 : 8))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct WorkspaceColors {
    let dark: Bool
    var background: Color { dark ? Color(white: 0.113) : Color(red: 0.976, green: 0.978, blue: 0.966) }
    var footer: Color { dark ? Color(white: 0.126) : Color(red: 0.957, green: 0.962, blue: 0.948) }
    var surface: Color { dark ? Color(white: 0.154) : Color(white: 1) }
    var preview: Color { dark ? Color(white: 0.125) : Color(red: 0.948, green: 0.958, blue: 0.945) }
    var ink: Color { dark ? Color(white: 0.94) : Color(red: 0.105, green: 0.158, blue: 0.142) }
    var muted: Color { dark ? Color(white: 0.73) : Color(red: 0.32, green: 0.37, blue: 0.34) }
    var line: Color { dark ? Color.white.opacity(0.14) : Color(red: 0.84, green: 0.86, blue: 0.83) }
    var accent: Color { dark ? Color(red: 0.44, green: 0.82, blue: 0.69) : button }
    var button: Color { Color(red: 0.105, green: 0.369, blue: 0.309) }
}
