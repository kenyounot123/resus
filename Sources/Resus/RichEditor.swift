import AppKit
import SwiftUI

@MainActor
struct RichEditor: View {
    let noteID: UUID
    let rtf: Data
    let text: String
    let onChange: (Data, String) -> Void
    @StateObject private var commands = EditorCommands()

    init(noteID: UUID, rtf: Data, text: String, onChange: @escaping (Data, String) -> Void) {
        self.noteID = noteID
        self.rtf = rtf
        self.text = text
        self.onChange = onChange
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Menu {
                    Button("Paragraph") { commands.paragraph(heading: false) }
                    Button("Heading") { commands.paragraph(heading: true) }
                } label: {
                    HStack(spacing: 6) {
                        Text("Paragraph").font(.system(size: 12))
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }.frame(width: 104, height: 28)
                }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Heading")
                Divider().frame(height: 18).padding(.horizontal, 5)
                tool("Bold", symbol: "bold") { commands.trait(.boldFontMask) }
                tool("Italic", symbol: "italic") { commands.trait(.italicFontMask) }
                tool("Highlight", symbol: "highlighter") { commands.highlight() }
                Divider().frame(height: 18).padding(.horizontal, 5)
                tool("Bullet list", symbol: "list.bullet") { commands.list(numbered: false) }
                tool("Numbered list", symbol: "list.number") { commands.list(numbered: true) }
                Spacer(minLength: 8)
                tool("Undo", symbol: "arrow.uturn.backward") { commands.undo() }
                tool("Redo", symbol: "arrow.uturn.forward") { commands.redo() }
            }
            .padding(.horizontal, 15).padding(.vertical, 8)
            .foregroundStyle(Color(nsColor: EditorCommands.ink))
            .background(Color(red: 246 / 255, green: 247 / 255, blue: 243 / 255))
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
            NativeNoteEditor(noteID: noteID, rtf: rtf, text: text, commands: commands, onChange: onChange)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Start writing your notes...")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(nsColor: EditorCommands.ink).opacity(0.4))
                            .padding(.leading, 21).padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .background(Color(nsColor: EditorCommands.paper))
    }

    private func tool(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13)).frame(width: 29, height: 28)
        }
        .buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
}

@MainActor
private final class EditorCommands: ObservableObject {
    weak var textView: NSTextView?
    static let paper = NSColor(srgbRed: 252 / 255, green: 251 / 255, blue: 248 / 255, alpha: 1)
    static let ink = NSColor(srgbRed: 38 / 255, green: 59 / 255, blue: 54 / 255, alpha: 1)

    static let numberedFormat = NSTextList.MarkerFormat(rawValue: "{decimal}.")

    static var defaults: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 9
        return [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: ink, .paragraphStyle: paragraph]
    }

    func undo() { textView?.undoManager?.undo(); focus() }
    func redo() { textView?.undoManager?.redo(); focus() }
    private func focus() { if let view = textView { view.window?.makeFirstResponder(view) } }

    private func edit(_ range: NSRange, name: String, transform: (NSMutableAttributedString) -> Void) {
        guard let view = textView, let storage = view.textStorage else { return }
        let selected = view.selectedRange()
        let replacement = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: range))
        transform(replacement)
        guard view.shouldChangeText(in: range, replacementString: replacement.string) else { return }
        view.undoManager?.beginUndoGrouping()
        storage.replaceCharacters(in: range, with: replacement)
        view.didChangeText()
        let delta = replacement.length - range.length
        let start = min(selected.location + (selected.length == 0 ? max(0, delta) : 0), storage.length)
        view.setSelectedRange(NSRange(location: start, length: selected.length == 0 ? 0 : min(max(0, selected.length + delta), storage.length - start)))
        view.undoManager?.setActionName(name)
        view.undoManager?.endUndoGrouping()
        focus()
    }

    func trait(_ trait: NSFontTraitMask) {
        guard let view = textView else { return }
        let range = view.selectedRange()
        let font = (view.typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
        let remove = NSFontManager.shared.traits(of: font).contains(trait)
        if range.length == 0 {
            view.typingAttributes[.font] = remove
                ? NSFontManager.shared.convert(font, toNotHaveTrait: trait)
                : NSFontManager.shared.convert(font, toHaveTrait: trait)
            focus()
            return
        }
        edit(range, name: trait == .boldFontMask ? "Bold" : "Italic") { value in
            value.enumerateAttribute(.font, in: NSRange(location: 0, length: value.length)) { attribute, run, _ in
                let current = (attribute as? NSFont) ?? font
                value.addAttribute(.font, value: remove
                    ? NSFontManager.shared.convert(current, toNotHaveTrait: trait)
                    : NSFontManager.shared.convert(current, toHaveTrait: trait), range: run)
            }
        }
    }

    func highlight() {
        guard let view = textView else { return }
        let range = view.selectedRange()
        let remove = view.typingAttributes[.backgroundColor] != nil
        let color = NSColor(srgbRed: 0.94, green: 0.88, blue: 0.60, alpha: 1)
        if range.length == 0 {
            if remove { view.typingAttributes.removeValue(forKey: .backgroundColor) }
            else { view.typingAttributes[.backgroundColor] = color }
            focus()
            return
        }
        edit(range, name: "Highlight") { value in
            let all = NSRange(location: 0, length: value.length)
            if remove { value.removeAttribute(.backgroundColor, range: all) }
            else { value.addAttribute(.backgroundColor, value: color, range: all) }
        }
    }

    func paragraph(heading: Bool) {
        guard let view = textView else { return }
        let range = (view.string as NSString).paragraphRange(for: view.selectedRange())
        if range.length == 0 {
            view.typingAttributes[.font] = heading ? NSFont.systemFont(ofSize: 24, weight: .semibold) : NSFont.systemFont(ofSize: 16)
            focus()
            return
        }
        edit(range, name: heading ? "Heading" : "Paragraph") { value in
            value.enumerateAttribute(.font, in: NSRange(location: 0, length: value.length)) { attribute, run, _ in
                let current = (attribute as? NSFont) ?? NSFont.systemFont(ofSize: 16)
                let resized = NSFontManager.shared.convert(current, toSize: heading ? 24 : 16)
                let font = heading ? NSFontManager.shared.convert(resized, toHaveTrait: .boldFontMask) : NSFontManager.shared.convert(resized, toNotHaveTrait: .boldFontMask)
                value.addAttribute(.font, value: font, range: run)
            }
        }
    }

    func list(numbered: Bool) {
        guard let view = textView else { return }
        let range = (view.string as NSString).paragraphRange(for: view.selectedRange())
        let existing = range.length > 0 ? (view.textStorage?.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first : nil
        let remove = existing?.markerFormat == (numbered ? Self.numberedFormat : .disc)
        let list = NSTextList(markerFormat: numbered ? Self.numberedFormat : .disc, options: 0)
        edit(range, name: numbered ? "Numbered list" : "Bullet list") { value in
            let result = NSMutableAttributedString()
            var location = 0
            var number = 1
            repeat {
                let paragraph = (value.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
                let part = NSMutableAttributedString(attributedString: value.attributedSubstring(from: paragraph))
                var attributes = part.length > 0 ? part.attributes(at: 0, effectiveRange: nil) : view.typingAttributes
                let style = ((attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                if !style.textLists.isEmpty, part.string.hasPrefix("\t"), let end = part.string.dropFirst().firstIndex(of: "\t") {
                    let prefix = String(part.string[...end])
                    part.deleteCharacters(in: NSRange(location: 0, length: (prefix as NSString).length))
                }
                style.textLists = remove ? [] : [list]
                style.headIndent = remove ? 0 : 30
                style.firstLineHeadIndent = 0
                style.tabStops = remove ? [] : [NSTextTab(textAlignment: .left, location: 30)]
                style.lineSpacing = 5
                style.paragraphSpacing = 9
                attributes[.paragraphStyle] = style
                if !remove { part.insert(NSAttributedString(string: "\t\(list.marker(forItemNumber: number))\t", attributes: attributes), at: 0) }
                part.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: part.length))
                result.append(part)
                location = NSMaxRange(paragraph)
                number += 1
            } while location < value.length
            value.setAttributedString(result)
        }
    }
}

@MainActor
private struct NativeNoteEditor: NSViewRepresentable {
    let noteID: UUID
    let rtf: Data
    let text: String
    let commands: EditorCommands
    let onChange: (Data, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = EditorCommands.paper
        let view = NSTextView(frame: scroll.bounds)
        view.isRichText = true
        view.importsGraphics = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        view.textContainerInset = NSSize(width: 16, height: 16)
        view.backgroundColor = EditorCommands.paper
        view.textColor = EditorCommands.ink
        view.insertionPointColor = NSColor(srgbRed: 40 / 255, green: 117 / 255, blue: 106 / 255, alpha: 1)
        view.font = NSFont.systemFont(ofSize: 16)
        view.typingAttributes = EditorCommands.defaults
        view.setAccessibilityIdentifier("noteBody")
        view.setAccessibilityLabel("Note body")
        view.delegate = context.coordinator
        scroll.documentView = view
        commands.textView = view
        context.coordinator.load(noteID: noteID, rtf: rtf, text: text, into: view)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
        guard let view = scroll.documentView as? NSTextView else { return }
        commands.textView = view
        if context.coordinator.noteID != noteID {
            context.coordinator.load(noteID: noteID, rtf: rtf, text: text, into: view)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let history = UndoManager()
        var noteID: UUID?
        var onChange: (Data, String) -> Void
        init(onChange: @escaping (Data, String) -> Void) { self.onChange = onChange }

        func undoManager(for textView: NSTextView) -> UndoManager? { history }

        func load(noteID: UUID, rtf: Data, text: String, into view: NSTextView) {
            self.noteID = noteID
            let content = (try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))
                ?? NSAttributedString(string: text, attributes: EditorCommands.defaults)
            let normalized = NSMutableAttributedString(attributedString: content)
            var location = 0
            var number = 0
            var previousFormat: NSTextList.MarkerFormat?
            while location < normalized.length {
                let paragraph = (normalized.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
                let style = normalized.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
                if let list = style?.textLists.first {
                    number = previousFormat == list.markerFormat ? number + 1 : 1
                    let line = (normalized.string as NSString).substring(with: paragraph)
                    if !line.hasPrefix("\t") {
                        let prefix = NSAttributedString(string: "\t\(list.marker(forItemNumber: number))\t", attributes: normalized.attributes(at: location, effectiveRange: nil))
                        normalized.insert(prefix, at: location)
                        location += prefix.length
                    }
                    previousFormat = list.markerFormat
                } else {
                    previousFormat = nil
                    number = 0
                }
                location += paragraph.length
            }
            view.textStorage?.setAttributedString(normalized)
            view.typingAttributes = EditorCommands.defaults
            view.undoManager?.removeAllActions()
            view.setSelectedRange(NSRange(location: 0, length: 0))
            view.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacementString else { return true }
            let next = (textView.string as NSString).replacingCharacters(in: affectedCharRange, with: replacementString)
            guard next.utf8.count <= 2_000_000 else { NSSound.beep(); return false }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView,
                  let data = view.rtf(from: NSRange(location: 0, length: (view.string as NSString).length)) else { return }
            let canonical = (try? RichTextCodec.text(RichTextCodec.decode(data))) ?? view.string
            onChange(data, canonical)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText(),
                  textView.selectedRange().length == 0, let storage = textView.textStorage, storage.length > 0 else { return false }
            let caret = textView.selectedRange().location
            let paragraph = (textView.string as NSString).paragraphRange(for: NSRange(location: caret, length: 0))
            guard paragraph.length > 0,
                  let style = storage.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle,
                  let list = style.textLists.first else { return false }
            let line = (textView.string as NSString).substring(with: paragraph)
            guard line.hasPrefix("\t"), let end = line.dropFirst().firstIndex(of: "\t") else { return false }
            let prefix = String(line[...end])
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == prefix.trimmingCharacters(in: .whitespacesAndNewlines) {
                let plain = (style.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                plain.textLists = []
                plain.headIndent = 0
                plain.tabStops = []
                var attributes = textView.typingAttributes
                attributes[.paragraphStyle] = plain
                textView.insertText(NSAttributedString(string: "", attributes: attributes), replacementRange: NSRange(location: paragraph.location, length: (prefix as NSString).length))
                textView.typingAttributes = attributes
                return true
            }
            var number = 1
            var location = paragraph.location
            while location > 0 {
                let previous = (textView.string as NSString).paragraphRange(for: NSRange(location: location - 1, length: 0))
                guard let previousStyle = storage.attribute(.paragraphStyle, at: previous.location, effectiveRange: nil) as? NSParagraphStyle,
                      previousStyle.textLists.first?.markerFormat == list.markerFormat else { break }
                number += 1
                location = previous.location
            }
            textView.insertText(NSAttributedString(string: "\n\t\(list.marker(forItemNumber: number + 1))\t", attributes: textView.typingAttributes), replacementRange: textView.selectedRange())
            return true
        }
    }
}
