import Foundation
import SwiftSoup
import Testing
@testable import SwiftReadability

struct ReadabilityTests {
    struct ExpectedMetadata: Decodable {
        let title: String?
        let byline: String?
        let dir: String?
        let lang: String?
        let excerpt: String?
        let siteName: String?
        let publishedTime: String?
        let readerable: Bool?
    }

    @Test(arguments: fixtureTestCases())
    func parsesFixture(_ testCase: FixtureTestCase) throws {
        let fixture = try testCase.requireFixture()
        let readability = Readability(
            html: fixture.source,
            url: fixture.url,
            options: ReadabilityOptions(
                classesToPreserve: ["caption"],
                useXMLSerializer: true,
                extensions: fixture.extensionProfile?.readabilityExtensions ?? []
            )
        )
        guard let result = try readability.parse() else {
            #expect(Bool(false), "Expected readability to return a result for \(fixture.name)")
            return
        }

        if let expectedMetadata = fixture.expectedMetadata {
            #expect(result.title == expectedMetadata.title)
            #expect(result.byline == expectedMetadata.byline)
            #expect(result.dir == expectedMetadata.dir)
            #expect(result.lang == expectedMetadata.lang)
            #expect(result.excerpt == expectedMetadata.excerpt)
            #expect(result.siteName == expectedMetadata.siteName)
            #expect(result.publishedTime == expectedMetadata.publishedTime)
            if let readerable = expectedMetadata.readerable {
                #expect(result.readerable == readerable)
            }
        }
        if let assertions = fixture.assertions {
            for excludedText in assertions.textExcludes ?? [] {
                #expect(!result.textContent.contains(excludedText), "Fixture \(fixture.name) should not include text \(excludedText)")
            }
            for excludedContent in assertions.contentExcludes ?? [] {
                #expect(!result.content.contains(excludedContent), "Fixture \(fixture.name) should not include content \(excludedContent)")
            }
            for includedContent in assertions.contentIncludes ?? [] {
                #expect(result.content.contains(includedContent), "Fixture \(fixture.name) should include content \(includedContent)")
            }
        }

        if ProcessInfo.processInfo.environment["SWIFT_READABILITY_DUMP_RAW"] == "1" {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("swift-readability-fixture-dumps-raw", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let rawURL = tempDir.appendingPathComponent("\(fixture.name)-raw.html")
            try? result.contentHTML.write(to: rawURL, atomically: true, encoding: .utf8)
        }

        if let expectedHTML = fixture.expectedHTML {
            // DOMComparator parses both documents and normalizes text whitespace, so
            // formatting either string with Node's js-beautify is unnecessary. Keeping
            // this path native also makes `swift test` work without Node or npm.
            let actualHTML = result.contentHTML
            let comparison = DOMComparator.compare(
                actualHTML: actualHTML,
                expectedHTML: expectedHTML
            )
            if !comparison.isEqual,
               ProcessInfo.processInfo.environment["SWIFT_READABILITY_DUMP_ACTUAL"] == "1" {
                let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                    .appendingPathComponent("swift-readability-fixture-dumps", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let actualURL = tempDir.appendingPathComponent("\(fixture.name)-actual.html")
                let expectedURL = tempDir.appendingPathComponent("\(fixture.name)-expected.html")
                try? actualHTML.write(to: actualURL, atomically: true, encoding: .utf8)
                try? expectedHTML.write(to: expectedURL, atomically: true, encoding: .utf8)
            }
            #expect(comparison.isEqual, "\(comparison)")
        }
    }
}

// MARK: - Debugging helpers

struct DOMComparison: Sendable, CustomStringConvertible {
    let isEqual: Bool
    let mismatchDescription: String?

    var description: String {
        if isEqual { return "DOMComparison(equal)" }
        return mismatchDescription ?? "DOMComparison(not equal)"
    }
}

enum DOMComparator {
    private static let comparisonLock = NSLock()

    static func compare(actualHTML: String, expectedHTML: String) -> DOMComparison {
        // The parameterized fixture cases intentionally exercise extraction in
        // parallel. SwiftSoup's parser/query caches can, however, make concurrent
        // test-only reparsing nondeterministic. Serialize only this comparison pass;
        // the native extraction work remains concurrent and therefore stress-tested.
        comparisonLock.lock()
        defer { comparisonLock.unlock() }

        guard let actualDoc = try? SwiftSoup.parse(actualHTML),
              let expectedDoc = try? SwiftSoup.parse(expectedHTML) else {
            return DOMComparison(isEqual: false, mismatchDescription: "Failed to parse HTML into DOM")
        }

        func startNode(for doc: Document) -> Node? {
            // Match jsdom: start at documentElement (<html>) if present.
            if let html = doc.children().first() { return html }
            return doc.getChildNodes().first
        }

        var actualNode = startNode(for: actualDoc)
        var expectedNode = startNode(for: expectedDoc)

        while actualNode != nil || expectedNode != nil {
            guard let a = actualNode, let e = expectedNode else {
                let aDesc = nodeStr(actualNode)
                let eDesc = nodeStr(expectedNode)
                return DOMComparison(isEqual: false, mismatchDescription: "Node missing. actual=\(aDesc) expected=\(eDesc)")
            }

            let aDesc = nodeStr(a)
            let eDesc = nodeStr(e)
            if aDesc != eDesc {
                return DOMComparison(isEqual: false, mismatchDescription: "Node mismatch. actual=\(aDesc) expected=\(eDesc)")
            }

            var actualAdvanceNode = a
            var expectedAdvanceNode = e
            if let aText = a as? TextNode, let eText = e as? TextNode {
                let actualRun = comparableTextRun(startingAt: aText)
                let expectedRun = comparableTextRun(startingAt: eText)
                let actualText = actualRun.text
                let expectedText = expectedRun.text
                actualAdvanceNode = actualRun.lastNode
                expectedAdvanceNode = expectedRun.lastNode
                if actualText != expectedText {
                    return DOMComparison(
                        isEqual: false,
                        mismatchDescription: "Text mismatch. actual=\(actualText.debugDescription) expected=\(expectedText.debugDescription)"
                    )
                }
            } else if let aEl = a as? Element, let eEl = e as? Element {
                let actualAttrs = filteredAttributes(for: aEl)
                let expectedAttrs = filteredAttributes(for: eEl)
                if actualAttrs != expectedAttrs {
                    return DOMComparison(
                        isEqual: false,
                        mismatchDescription: "Attributes mismatch for \(aDesc). actual=\(actualAttrs) expected=\(expectedAttrs)"
                    )
                }
            }

            actualNode = inOrderIgnoringInertNodes(from: actualAdvanceNode)
            expectedNode = inOrderIgnoringInertNodes(from: expectedAdvanceNode)
        }

        return DOMComparison(isEqual: true, mismatchDescription: nil)
    }

    private static func filteredAttributes(for element: Element) -> [String] {
        var attrs: [String] = []
        if let attributes = element.getAttributes() {
            for attribute in attributes {
                let key = attribute.getKey()
                let value = attribute.getValue()
                attrs.append("\(key)=\(normalizedAttributeValue(key: key, value: value))")
            }
        }
        return attrs.sorted()
    }

    private static func normalizedAttributeValue(key: String, value: String) -> String {
        let booleanAttributes: Set<String> = [
            "allowfullscreen", "async", "autofocus", "autoplay", "checked",
            "controls", "default", "defer", "disabled", "disablepictureinpicture",
            "disableremoteplayback", "formnovalidate", "inert", "ismap", "itemscope",
            "loop", "multiple", "muted", "nomodule", "novalidate", "open",
            "playsinline", "readonly", "required", "reversed", "selected",
        ]
        let lowercaseKey = key.lowercased()
        if booleanAttributes.contains(lowercaseKey) { return lowercaseKey }
        if lowercaseKey == "hidden" {
            return value.lowercased() == "until-found" ? "until-found" : "hidden"
        }
        return value
    }

    private static func nodeStr(_ node: Node?) -> String {
        guard let node else { return "(no node)" }
        if node is TextNode { return "#text" }
        if let element = node as? Element {
            var result = element.tagName().lowercased()
            let id = element.idSafe()
            if !id.isEmpty { result += "#\(id)" }
            let className = element.attrOrEmpty("class")
            if !className.isEmpty { result += ".(\(className))" }
            return result
        }
        return "some other node type"
    }

    private static func htmlTransform(_ str: String) -> String {
        // Preserve leading/trailing collapsed spaces: spaces at inline element
        // boundaries affect rendered text and are significant to the JS oracle.
        javaScriptCollapseWhitespaceRuns(str)
    }

    private static func comparableTextRun(startingAt node: TextNode) -> (text: String, lastNode: Node) {
        var rawText = node.getWholeText()
        var lastNode: Node = node
        var next = node.nextSibling()
        while let candidate = next {
            if candidate is SwiftSoup.Comment {
                lastNode = candidate
                next = candidate.nextSibling()
                continue
            }
            guard let text = candidate as? TextNode else { break }
            rawText += text.getWholeText()
            lastNode = text
            next = text.nextSibling()
        }

        let transformed = htmlTransform(rawText)
        guard lastNode.nextSibling() == nil else { return (transformed, lastNode) }

        // The JavaScript oracle beautifies both strings before parsing them.
        // That normalizes indentation immediately before a closing tag, so the
        // native comparator ignores only that terminal formatting whitespace.
        return (javaScriptTrimEnd(transformed), lastNode)
    }

    private static func inOrderTraverse(from node: Node) -> Node? {
        if let element = node as? Element, let firstChild = element.getChildNodes().first {
            return firstChild
        }
        var current: Node? = node
        while let cur = current, cur.nextSibling() == nil {
            current = cur.parent()
        }
        return current?.nextSibling()
    }

    private static func inOrderIgnoringInertNodes(from node: Node) -> Node? {
        var current = inOrderTraverse(from: node)
        while let cur = current {
            if cur is SwiftSoup.Comment {
                current = inOrderTraverse(from: cur)
                continue
            }
            if let text = cur as? TextNode {
                if javaScriptIsWhitespaceOnly(text.getWholeText()) {
                    current = inOrderTraverse(from: cur)
                    continue
                }
            }
            return cur
        }
        return nil
    }
}
