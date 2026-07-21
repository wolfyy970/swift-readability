import SwiftSoup

@inline(__always)
func isHTMLTemplateElement(
    _ element: Element,
    documentUsesHTMLSyntax: Bool? = nil,
    namespaces: ArticleContentNamespaceResolver? = nil
) -> Bool {
    guard element.tagName().lowercased() == "template" else { return false }

    let usesHTMLSyntax = documentUsesHTMLSyntax
        ?? element.ownerDocument().map { $0.outputSettings().syntax() == .html }
        ?? false
    guard usesHTMLSyntax else { return false }

    return (namespaces ?? ArticleContentNamespaceResolver()).isHTMLContent(element)
}

/// Browser element queries count an HTML `<template>` element itself but do not
/// enter its separate, inert `DocumentFragment`. SwiftSoup stores that fragment
/// as ordinary children, so enforce the boundary explicitly and iteratively.
func browserStyleElementCount(in document: Document) -> Int {
    let usesHTMLSyntax = document.outputSettings().syntax() == .html
    let namespaces = ArticleContentNamespaceResolver()
    var count = 0
    var stack = Array(document.getChildNodes().reversed())

    while let node = stack.popLast() {
        if let element = node as? Element {
            count += 1
            if isHTMLTemplateElement(
                element,
                documentUsesHTMLSyntax: usesHTMLSyntax,
                namespaces: namespaces
            ) {
                continue
            }
        }

        let children = node.getChildNodes()
        if !children.isEmpty {
            stack.append(contentsOf: children.reversed())
        }
    }
    return count
}

/// Removes reader-inert HTML template payloads before metadata and extraction.
/// XML and SVG/MathML elements named `template` remain ordinary content.
func removeHTMLTemplateElements(from document: Document) throws {
    guard document.outputSettings().syntax() == .html else { return }

    let namespaces = ArticleContentNamespaceResolver()
    var stack = Array(document.getChildNodes().reversed())
    while let node = stack.popLast() {
        if let element = node as? Element,
           isHTMLTemplateElement(
            element,
            documentUsesHTMLSyntax: true,
            namespaces: namespaces
           ) {
            try element.remove()
            continue
        }

        let children = node.getChildNodes()
        if !children.isEmpty {
            stack.append(contentsOf: children.reversed())
        }
    }
}

/// Removes parsed DOM comment nodes without inspecting text or raw-data nodes.
///
/// Working at the DOM layer is important: comment-like bytes inside script,
/// style, and JSON-LD elements are represented as data and remain untouched.
func removeInertDOMComments(from root: Node) throws {
    var stack = Array(root.getChildNodes().reversed())
    while let node = stack.popLast() {
        if node is Comment {
            try node.remove()
            continue
        }

        let children = node.getChildNodes()
        if !children.isEmpty {
            stack.append(contentsOf: children.reversed())
        }
    }
}

extension Element {
    func attrOrEmpty(_ key: String) -> String {
        (try? attr(key)) ?? ""
    }
    func attrOrEmptyUTF8(_ key: [UInt8]) -> [UInt8] {
        (try? attr(key)) ?? []
    }
    func classNameSafe() -> String {
        String(
            decoding: attrOrEmptyUTF8(ReadabilityUTF8Arrays.class_),
            as: UTF8.self
        )
    }
    func idSafe() -> String {
        id()
    }
    func tagNameSafe() -> String {
        tagName()
    }

}

extension Elements {
    var firstSafe: Element? { first() }
}

extension Array where Element == UInt8 {
    @inline(__always)
    func equalsIgnoreCaseASCII(_ other: [UInt8]) -> Bool {
        guard self.count == other.count else { return false }
        for (byte1, byte2) in zip(self.lazy, other.lazy) {
            let lower1 = (byte1 >= 65 && byte1 <= 90) ? byte1 + 32 : byte1
            let lower2 = (byte2 >= 65 && byte2 <= 90) ? byte2 + 32 : byte2
            if lower1 != lower2 { return false }
        }
        return true
    }
}

@inline(__always)
func textContentPreservingWhitespace(of node: Node) -> String {
    if let text = node as? TextNode {
        return text.getWholeText()
    }
    if let data = node as? DataNode {
        return data.getWholeData()
    }
    if let element = node as? Element {
        let usesHTMLTemplateSemantics = element.ownerDocument()
            .map { $0.outputSettings().syntax() == .html }
            ?? false
        return collectTextPreservingWhitespace(
            from: element,
            usingHTMLTemplateSemantics: usesHTMLTemplateSemantics
        )
    }
    return ""
}

private func collectTextPreservingWhitespace(
    from element: Element,
    usingHTMLTemplateSemantics: Bool
) -> String {
    let namespaces = usingHTMLTemplateSemantics
        ? ArticleContentNamespaceResolver()
        : nil
    if isHTMLTemplateElement(
        element,
        documentUsesHTMLSyntax: usingHTMLTemplateSemantics,
        namespaces: namespaces
    ) {
        return ""
    }

    var output: [String] = []
    output.reserveCapacity(8)
    var stack = Array(element.getChildNodes().reversed())
    while let node = stack.popLast() {
        if let text = node as? TextNode {
            output.append(text.getWholeText())
        } else if let data = node as? DataNode {
            output.append(data.getWholeData())
        } else if let el = node as? Element {
            if isHTMLTemplateElement(
                el,
                documentUsesHTMLSyntax: usingHTMLTemplateSemantics,
                namespaces: namespaces
            ) {
                continue
            }
            let children = el.getChildNodes()
            if !children.isEmpty {
                stack.append(contentsOf: children.reversed())
            }
        }
    }
    if output.isEmpty { return "" }
    return output.joined()
}
