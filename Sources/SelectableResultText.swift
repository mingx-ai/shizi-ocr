import AppKit
import SwiftUI

struct SelectableResultText: NSViewRepresentable {
    let value: String
    let selectionChanged: (String) -> Void
    let copy: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let reader = CopyableTextView(frame: scroll.contentView.bounds)
        reader.isEditable = false
        reader.isSelectable = true
        reader.isRichText = false
        reader.drawsBackground = false
        reader.font = .systemFont(ofSize: 15)
        reader.textColor = .labelColor
        reader.textContainerInset = NSSize(width: 13, height: 14)
        reader.isHorizontallyResizable = false
        reader.isVerticallyResizable = true
        reader.autoresizingMask = [.width]
        reader.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        reader.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        reader.textContainer?.widthTracksTextView = true

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        reader.defaultParagraphStyle = paragraph
        reader.setAccessibilityLabel("识别文字")
        reader.copyHandler = copy
        reader.string = value
        reader.delegate = context.coordinator
        scroll.documentView = reader
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let reader = scroll.documentView as? CopyableTextView else { return }
        context.coordinator.parent = self
        reader.copyHandler = copy
        guard reader.string != value else { return }
        reader.delegate = nil
        reader.string = value
        reader.setSelectedRange(NSRange(location: 0, length: 0))
        reader.scrollToBeginningOfDocument(nil)
        reader.delegate = context.coordinator
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableResultText
        init(_ parent: SelectableResultText) { self.parent = parent }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let reader = notification.object as? CopyableTextView else { return }
            parent.selectionChanged(reader.selectedContent)
        }
    }
}

private final class CopyableTextView: NSTextView {
    var copyHandler: ((String) -> Void)?

    var selectedContent: String {
        let source = string as NSString
        return selectedRanges.compactMap { rangeValue -> String? in
            let range = rangeValue.rangeValue
            guard range.length > 0, range.location != NSNotFound, NSMaxRange(range) <= source.length else { return nil }
            return source.substring(with: range)
        }.joined(separator: "\n")
    }

    override func copy(_ sender: Any?) {
        let selected = selectedContent
        guard !selected.isEmpty else { return }
        copyHandler?(selected)
    }
}
