import AppKit

@MainActor enum RichTextCodec {
    static func decode(_ data: Data) throws -> NSAttributedString {
        try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }
    static func text(_ content: NSAttributedString) -> String {
        let raw = content.string as NSString
        var result = ""
        var location = 0
        while location < content.length {
            let range = raw.paragraphRange(for: NSRange(location: location, length: 0))
            var line = raw.substring(with: range)
            let style = content.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            if style?.textLists.isEmpty == false, line.hasPrefix("\t"), let end = line.dropFirst().firstIndex(of: "\t") {
                line = String(line[line.index(after: end)...])
            }
            result += line
            location = NSMaxRange(range)
        }
        return result
    }
}
