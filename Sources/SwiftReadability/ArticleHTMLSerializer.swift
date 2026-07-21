// Materially modified from the inherited Swift port.
// See NOTICE and THIRD_PARTY_NOTICES.md for provenance and license terms.

import SwiftSoup

/// Produces compact HTML without asking SwiftSoup to normalize text-node data.
/// Tag casing, entity spelling, and attribute order are deliberately left to
/// the parsed DOM rather than emulating one browser's `innerHTML` bytes.
struct ArticleHTMLSerializer {
    private static let htmlVoidElements: Set<String> = [
        "area", "base", "basefont", "bgsound", "br", "col", "embed", "hr",
        "img", "input", "link", "meta", "param", "source", "track", "wbr",
    ]

    private static let rawTextElements: Set<String> = [
        "iframe", "noembed", "noframes", "noscript", "plaintext", "script", "style", "xmp",
    ]

    static func innerHTML(of element: Element) -> String {
        var result = ""
        let namespaces = ArticleContentNamespaceResolver()
        let parentIsHTML = namespaces.isHTMLContent(element)
        let parentTag = element.tagName().lowercased()
        for child in element.getChildNodes() {
            append(
                child,
                parentIsHTML: parentIsHTML,
                parentTag: parentTag,
                namespaces: namespaces,
                to: &result
            )
        }
        return result
    }

    private static func append(
        _ node: Node,
        parentIsHTML: Bool,
        parentTag: String,
        namespaces: ArticleContentNamespaceResolver,
        to result: inout String
    ) {
        if let text = node as? TextNode {
            let value = text.getWholeText()
            if parentIsHTML, rawTextElements.contains(parentTag) {
                result += value
            } else {
                appendEscapedText(value, to: &result)
            }
            return
        }

        if let data = node as? DataNode {
            result += data.getWholeData()
            return
        }

        if let comment = node as? Comment {
            result += "<!--"
            result += comment.getData()
            result += "-->"
            return
        }

        guard let element = node as? Element else {
            result += (try? node.outerHtml()) ?? ""
            return
        }

        let tag = element.tagName().lowercased()
        let isHTML = namespaces.isHTMLContent(element)
        result += "<"
        result += tag
        if let attributes = element.getAttributes() {
            for attribute in attributes {
                result += " "
                result += attribute.getKey()
                result += "=\""
                appendEscapedAttribute(attribute.getValue(), to: &result)
                result += "\""
            }
        }
        result += ">"

        if isHTML, htmlVoidElements.contains(tag) { return }

        for child in element.getChildNodes() {
            append(
                child,
                parentIsHTML: isHTML,
                parentTag: tag,
                namespaces: namespaces,
                to: &result
            )
        }
        result += "</"
        result += tag
        result += ">"
    }

    private static func appendEscapedText(_ value: String, to result: inout String) {
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x26: result += "&amp;"
            case 0x3C: result += "&lt;"
            case 0x3E: result += "&gt;"
            default: result.unicodeScalars.append(scalar)
            }
        }
    }

    private static func appendEscapedAttribute(_ value: String, to result: inout String) {
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x22: result += "&quot;"
            case 0x26: result += "&amp;"
            default: result.unicodeScalars.append(scalar)
            }
        }
    }
}
