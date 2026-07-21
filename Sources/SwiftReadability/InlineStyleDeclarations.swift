/// Extraction-oriented parsing for the two inline styles Readability uses.
///
/// This is intentionally not a browser CSSOM. It finds real declaration
/// boundaries so text inside strings, comments, and functions cannot become a
/// phantom hidden declaration. Only compact, known property grammar (or a real
/// `var()` substitution) participates in the cascade, so an invalid later value
/// cannot override an explicit `none` or `hidden` declaration.
struct InlineStyleDeclarations {
    private struct Declaration {
        let value: String
        let important: Bool
    }

    private struct Segment {
        let text: String
        let isBalanced: Bool
    }

    private enum LexicalValue {
        case empty
        case identifiers([String])
        case complex
    }

    private var declarations: [String: Declaration] = [:]

    private static let globalKeywords: Set<String> = [
        "inherit", "initial", "revert", "revert-layer", "unset",
    ]
    private static let displayOutsideKeywords: Set<String> = [
        "block", "inline", "run-in",
    ]
    private static let displayInsideKeywords: Set<String> = [
        "flow", "flow-root", "table", "flex", "grid", "ruby",
    ]
    private static let displayFlowKeywords: Set<String> = ["flow", "flow-root"]
    private static let singleDisplayKeywords: Set<String> = [
        "block", "inline", "run-in",
        "flow", "flow-root", "table", "flex", "grid", "ruby", "math",
        "list-item",
        "table-row-group", "table-header-group", "table-footer-group",
        "table-row", "table-cell", "table-column-group", "table-column", "table-caption",
        "ruby-base", "ruby-text", "ruby-base-container", "ruby-text-container",
        "contents", "none",
        "inline-block", "inline-list-item", "inline-table", "inline-flex", "inline-grid",
        "-ms-inline-flexbox", "-ms-grid", "-ms-inline-grid",
        "-webkit-flex", "-webkit-inline-flex", "-webkit-box", "-webkit-inline-box",
        "-moz-inline-stack", "-moz-box", "-moz-inline-box",
        "grid-lanes", "inline-grid-lanes",
    ]
    private static let visibilityKeywords: Set<String> = [
        "visible", "hidden", "force-hidden", "collapse",
    ]

    init(_ source: String) {
        for segment in Self.splitTopLevel(source, on: 0x3B) where segment.isBalanced { // ;
            guard let (rawName, rawValue) = Self.nameAndValue(in: segment.text),
                  case let .identifiers(names) = Self.lexicalValue(of: rawName),
                  names.count == 1,
                  let name = names.first,
                  name == "display" || name == "visibility",
                  let (valueSource, important) = Self.valueAndPriority(from: rawValue),
                  let value = Self.normalizedValue(valueSource, for: name)
            else {
                continue
            }

            if declarations[name]?.important == true, !important {
                continue
            }
            // Later declarations win at equal priority; important declarations
            // beat normal declarations.
            declarations[name] = Declaration(value: value, important: important)
        }
    }

    func value(for property: String) -> String? {
        declarations[Self.asciiLowercased(property)]?.value
    }

    private static func normalizedValue(_ source: String, for property: String) -> String? {
        // A declaration containing a real var() function remains valid until
        // custom-property substitution. It therefore participates in cascade
        // order even when its eventual value is unknown. Strings and comments
        // that merely contain "var(" do not qualify.
        if containsVarFunction(in: source) {
            return source
        }

        switch lexicalValue(of: source) {
        case .empty:
            return nil
        case .identifiers(let tokens):
            guard property == "display"
                    ? displayGrammarAccepts(tokens)
                    : visibilityGrammarAccepts(tokens)
            else { return nil }
            return tokens.joined(separator: " ")
        case .complex:
            return nil
        }
    }

    private static func displayGrammarAccepts(_ tokens: [String]) -> Bool {
        if tokens.count == 1 {
            return globalKeywords.contains(tokens[0]) || singleDisplayKeywords.contains(tokens[0])
        }
        if tokens.count == 2 {
            let first = tokens[0]
            let second = tokens[1]
            let outsideAndInside =
                (displayOutsideKeywords.contains(first) && displayInsideKeywords.contains(second)) ||
                (displayOutsideKeywords.contains(second) && displayInsideKeywords.contains(first))
            let outsideAndMath =
                (displayOutsideKeywords.contains(first) && second == "math") ||
                (displayOutsideKeywords.contains(second) && first == "math")
            let listItemPair =
                (first == "list-item" &&
                    (displayOutsideKeywords.contains(second) || displayFlowKeywords.contains(second))) ||
                (second == "list-item" &&
                    (displayOutsideKeywords.contains(first) || displayFlowKeywords.contains(first)))
            return outsideAndInside || outsideAndMath || listItemPair
        }
        if tokens.count == 3 {
            return tokens.filter { $0 == "list-item" }.count == 1 &&
                tokens.filter { displayOutsideKeywords.contains($0) }.count == 1 &&
                tokens.filter { displayFlowKeywords.contains($0) }.count == 1
        }
        return false
    }

    private static func visibilityGrammarAccepts(_ tokens: [String]) -> Bool {
        tokens.count == 1 &&
            (globalKeywords.contains(tokens[0]) || visibilityKeywords.contains(tokens[0]))
    }

    private static func nameAndValue(in declaration: String) -> (String, String)? {
        let parts = splitTopLevel(declaration, on: 0x3A) // :
        guard parts.count == 2, parts.allSatisfy(\.isBalanced) else { return nil }
        return (parts[0].text, parts[1].text)
    }

    private static func valueAndPriority(from source: String) -> (String, Bool)? {
        let parts = splitTopLevel(source, on: 0x21) // !
        guard parts.allSatisfy(\.isBalanced) else { return nil }
        switch parts.count {
        case 1:
            return (parts[0].text, false)
        case 2:
            guard case let .identifiers(priority) = lexicalValue(of: parts[1].text),
                  priority == ["important"]
            else {
                return nil
            }
            return (parts[0].text, true)
        default:
            return nil
        }
    }

    /// Splits only outside quoted strings, comments, and (), [], or {} blocks.
    /// Unbalanced parts are rejected so malformed values cannot expose nested
    /// property-like text as declarations.
    private static func splitTopLevel(_ source: String, on delimiter: UInt32) -> [Segment] {
        let scalars = Array(source.unicodeScalars)
        var result: [Segment] = []
        var start = 0
        var index = 0
        var quote: UInt32?
        var closers: [UInt32] = []
        var malformed = false

        func finish(at end: Int, balanced: Bool) {
            result.append(Segment(
                text: string(from: scalars[start..<end]),
                isBalanced: balanced
            ))
        }

        while index < scalars.count {
            let value = scalars[index].value

            if let activeQuote = quote {
                if value == 0x5C { // escape
                    index = indexAfterEscape(in: scalars, from: index)
                } else if value == 0x0A || value == 0x0C || value == 0x0D {
                    // CSS turns an unescaped newline into a bad-string token and
                    // resumes tokenization. Mark this declaration malformed but
                    // recover so a later real declaration is still observable.
                    quote = nil
                    malformed = true
                    index += 1
                } else {
                    if value == activeQuote { quote = nil }
                    index += 1
                }
                continue
            }
            if startsComment(in: scalars, at: index) {
                index = indexAfterComment(in: scalars, from: index)
                continue
            }
            if value == 0x5C {
                index = indexAfterEscape(in: scalars, from: index)
                continue
            }
            if value == 0x22 || value == 0x27 { // " or '
                quote = value
                index += 1
                continue
            }
            if let closer = matchingCloser(for: value) {
                closers.append(closer)
                index += 1
                continue
            }
            if isCloser(value) {
                if closers.last == value {
                    closers.removeLast()
                } else {
                    malformed = true
                }
                index += 1
                continue
            }
            if value == delimiter, closers.isEmpty {
                finish(at: index, balanced: !malformed)
                start = index + 1
                malformed = false
            }
            index += 1
        }

        finish(
            at: scalars.count,
            balanced: !malformed && quote == nil && closers.isEmpty
        )
        return result
    }

    /// Tokenizes plain CSS identifiers, using comments and CSS whitespace as
    /// boundaries. Escapes and other CSS syntax remain deliberately complex.
    private static func lexicalValue(of source: String) -> LexicalValue {
        let scalars = Array(source.unicodeScalars)
        var tokens: [String] = []
        var current = String.UnicodeScalarView()
        var index = 0

        func finishToken() {
            guard !current.isEmpty else { return }
            tokens.append(asciiLowercased(String(current)))
            current.removeAll(keepingCapacity: true)
        }

        while index < scalars.count {
            if isWhitespace(scalars[index].value) {
                finishToken()
                index += 1
            } else if startsComment(in: scalars, at: index) {
                finishToken()
                index = indexAfterComment(in: scalars, from: index)
            } else if isIdentifierScalar(scalars[index].value) {
                current.append(scalars[index])
                index += 1
            } else {
                return .complex
            }
        }
        finishToken()
        return tokens.isEmpty ? .empty : .identifiers(tokens)
    }

    private static func containsVarFunction(in source: String) -> Bool {
        let scalars = Array(source.unicodeScalars)
        var index = 0
        var quote: UInt32?

        while index < scalars.count {
            let value = scalars[index].value
            if let activeQuote = quote {
                if value == 0x5C {
                    index = indexAfterEscape(in: scalars, from: index)
                } else {
                    if value == activeQuote { quote = nil }
                    index += 1
                }
                continue
            }
            if startsComment(in: scalars, at: index) {
                index = indexAfterComment(in: scalars, from: index)
                continue
            }
            if value == 0x5C {
                index = indexAfterEscape(in: scalars, from: index)
                continue
            }
            if value == 0x22 || value == 0x27 {
                quote = value
                index += 1
                continue
            }
            if value == 0x76, // v
               index + 3 < scalars.count,
               scalars[index + 1].value == 0x61, // a
               scalars[index + 2].value == 0x72, // r
               scalars[index + 3].value == 0x28, // (
               index == 0 || !isIdentifierContinuation(scalars[index - 1].value) {
                return true
            }
            index += 1
        }
        return false
    }

    private static func startsComment(in scalars: [Unicode.Scalar], at index: Int) -> Bool {
        index + 1 < scalars.count &&
            scalars[index].value == 0x2F && scalars[index + 1].value == 0x2A
    }

    private static func indexAfterEscape(in scalars: [Unicode.Scalar], from index: Int) -> Int {
        if index + 2 < scalars.count,
           scalars[index + 1].value == 0x0D,
           scalars[index + 2].value == 0x0A {
            return index + 3
        }
        return min(index + 2, scalars.count)
    }

    private static func indexAfterComment(in scalars: [Unicode.Scalar], from start: Int) -> Int {
        var index = start + 2
        while index + 1 < scalars.count {
            if scalars[index].value == 0x2A, scalars[index + 1].value == 0x2F {
                return index + 2
            }
            index += 1
        }
        return scalars.count
    }

    private static func matchingCloser(for value: UInt32) -> UInt32? {
        switch value {
        case 0x28: return 0x29
        case 0x5B: return 0x5D
        case 0x7B: return 0x7D
        default: return nil
        }
    }

    private static func isCloser(_ value: UInt32) -> Bool {
        value == 0x29 || value == 0x5D || value == 0x7D
    }

    private static func isIdentifierScalar(_ value: UInt32) -> Bool {
        value == 0x2D || value == 0x5F ||
            (0x30...0x39).contains(value) ||
            (0x41...0x5A).contains(value) ||
            (0x61...0x7A).contains(value)
    }

    private static func isIdentifierContinuation(_ value: UInt32) -> Bool {
        isIdentifierScalar(value) || value == 0x5C || value >= 0x80
    }

    private static func isWhitespace(_ value: UInt32) -> Bool {
        value == 0x09 || value == 0x0A || value == 0x0C || value == 0x0D || value == 0x20
    }

    private static func asciiLowercased(_ source: String) -> String {
        let scalars = source.unicodeScalars.map { scalar in
            let value = scalar.value
            return Unicode.Scalar((0x41...0x5A).contains(value) ? value + 0x20 : value)!
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func string<C: Collection>(from scalars: C) -> String
    where C.Element == Unicode.Scalar {
        String(String.UnicodeScalarView(scalars))
    }
}
