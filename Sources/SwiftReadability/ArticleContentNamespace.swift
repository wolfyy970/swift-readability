// Materially modified from the inherited Swift port.
// See NOTICE and THIRD_PARTY_NOTICES.md for provenance and license terms.

import SwiftSoup

/// The HTML parser namespace that matters when deciding whether CSS classes
/// and IDs should influence article scoring. SwiftSoup does not retain
/// namespaces, so this reconstructs only HTML-embedded SVG and MathML ancestry.
private enum ArticleContentNamespace {
    case html
    case svg
    case mathML
    case other
}

/// Prevents CSS classes inside diagrams and formulas from being mistaken for
/// article/chrome signals. It intentionally does not emulate browser object
/// brands, generic XML namespaces, or serializer behavior.
final class ArticleContentNamespaceResolver {
    private final class CacheEntry {
        weak var element: Element?
        let namespace: ArticleContentNamespace

        init(element: Element, namespace: ArticleContentNamespace) {
            self.element = element
            self.namespace = namespace
        }
    }

    private var cache: [ObjectIdentifier: CacheEntry] = [:]

    func reset() {
        cache.removeAll(keepingCapacity: true)
    }

    /// Foreign-content classes are commonly internal styling hooks, but IDs
    /// still identify semantic definitions and page controls (for example an
    /// SVG symbol bank containing `share` and `fullscreen`). Keep IDs available
    /// for chrome filtering without letting diagram classes steer scoring.
    func scoringSignals(_ element: Element) -> (className: String, id: String) {
        let className = namespace(of: element) == .html ? element.classNameSafe() : ""
        return (className, element.idSafe())
    }

    func isHTMLContent(_ element: Element) -> Bool {
        namespace(of: element) == .html
    }

    /// Foreign-content classes do not create a sibling relationship between
    /// otherwise unrelated diagrams or formula nodes.
    func classNamesMatchForSiblingBonus(_ lhs: Element, _ rhs: Element) -> Bool {
        guard namespace(of: lhs) == .html, namespace(of: rhs) == .html else {
            return false
        }
        let rhsClass = rhs.classNameSafe()
        return !rhsClass.isEmpty && lhs.classNameSafe() == rhsClass
    }

    /// Resolves an ancestry chain iteratively and caches each result. Deep,
    /// malformed article markup therefore cannot overflow a recursive walk.
    private func namespace(of element: Element) -> ArticleContentNamespace {
        if let cached = cachedNamespace(of: element) { return cached }

        var unresolved: [Element] = []
        var current = element
        var inherited: ArticleContentNamespace

        while true {
            if let cached = cachedNamespace(of: current) {
                inherited = cached
                break
            }

            guard let parent = current.parent() else {
                // Detached article fragments use the same insertion rule as an
                // HTML parser. This is both useful to callers and independent of
                // mutable serializer settings on an owner document.
                inherited = htmlInsertionNamespace(for: current)
                cache(inherited, for: current)
                break
            }

            if parent is Document {
                // A parsed HTML document has an <html> document element. A
                // different root is treated as generic XML; article scoring
                // deliberately makes no broader XML namespace promises.
                inherited = current.tagName().lowercased() == "html" ? .html : .other
                cache(inherited, for: current)
                break
            }

            unresolved.append(current)
            current = parent
        }

        for descendant in unresolved.reversed() {
            guard let parent = descendant.parent() else { continue }
            let resolved = htmlNamespace(
                for: descendant,
                parent: parent,
                parentNamespace: inherited
            )
            cache(resolved, for: descendant)
            inherited = resolved
        }

        return cachedNamespace(of: element) ?? inherited
    }

    private func cachedNamespace(of element: Element) -> ArticleContentNamespace? {
        let identifier = ObjectIdentifier(element)
        guard let entry = cache[identifier] else { return nil }
        guard entry.element === element else {
            cache.removeValue(forKey: identifier)
            return nil
        }
        return entry.namespace
    }

    private func cache(_ namespace: ArticleContentNamespace, for element: Element) {
        cache[ObjectIdentifier(element)] = CacheEntry(element: element, namespace: namespace)
    }
}

private func htmlInsertionNamespace(for element: Element) -> ArticleContentNamespace {
    switch element.tagName().lowercased() {
    case "svg": return .svg
    case "math": return .mathML
    default: return .html
    }
}

private func htmlNamespace(
    for element: Element,
    parent: Element,
    parentNamespace: ArticleContentNamespace
) -> ArticleContentNamespace {
    switch parentNamespace {
    case .html:
        return htmlInsertionNamespace(for: element)
    case .svg:
        return isSVGHTMLIntegrationPoint(parent)
            ? htmlInsertionNamespace(for: element)
            : .svg
    case .mathML:
        if parent.tagName().lowercased() == "annotation-xml",
           element.tagName().lowercased() == "svg" {
            return .svg
        }
        return isMathMLHTMLIntegrationPoint(parent, child: element)
            ? htmlInsertionNamespace(for: element)
            : .mathML
    case .other:
        return .other
    }
}

private func isSVGHTMLIntegrationPoint(_ element: Element) -> Bool {
    switch element.tagName().lowercased() {
    case "foreignobject", "desc", "title": return true
    default: return false
    }
}

private func isMathMLHTMLIntegrationPoint(_ parent: Element, child: Element) -> Bool {
    switch parent.tagName().lowercased() {
    case "mi", "mo", "mn", "ms", "mtext":
        let childName = child.tagName().lowercased()
        return childName != "mglyph" && childName != "malignmark"
    case "annotation-xml":
        let encoding = parent.attrOrEmpty("encoding").lowercased()
        return encoding == "text/html" || encoding == "application/xhtml+xml"
    default:
        return false
    }
}
