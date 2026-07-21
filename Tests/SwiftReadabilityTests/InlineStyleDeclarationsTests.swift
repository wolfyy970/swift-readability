import Foundation
import Testing
@testable import SwiftReadability

struct InlineStyleDeclarationsTests {
    private let baseURL = URL(string: "https://example.com/article")!

    @Test func commonVisibilityDeclarationsFollowCSSOrder() {
        let cases: [(style: String, display: String?, visibility: String?)] = [
            ("DISPLAY: NONE", "none", nil),
            ("visibility: HIDDEN", nil, "hidden"),
            ("display:none;display:block", "block", nil),
            ("display:block;display:none", "none", nil),
            ("visibility:hidden;visibility:visible", nil, "visible"),
            ("display:none;display:inline flow-root", "inline flow-root", nil),
            ("display:none;display:block math", "block math", nil),
            ("display:none;display:inline math", "inline math", nil),
            ("display:none;display:var(--article-layout)", "var(--article-layout)", nil),
            ("display:none;display:foo(var(--article-layout))", "foo(var(--article-layout))", nil),
            // Invalid declarations do not participate in cascade order.
            ("display:none;display:none-ish", "none", nil),
            ("display:none;display:masonry", "none", nil),
            ("display:none;display:foo(bar)", "none", nil),
            ("display:none;display:'var(--article-layout)'", "none", nil),
            ("visibility:hidden;visibility:mostly-visible", nil, "hidden"),
        ]

        for testCase in cases {
            let declarations = InlineStyleDeclarations(testCase.style)
            #expect(declarations.value(for: "display") == testCase.display, "style: \(testCase.style)")
            #expect(declarations.value(for: "visibility") == testCase.visibility, "style: \(testCase.style)")
        }
    }

    @Test func importantUsesOrdinaryDeclarationPrecedence() {
        let cases: [(style: String, display: String?)] = [
            ("display:none!important;display:block", "none"),
            ("display:none;display:block ! IMPORTANT", "block"),
            ("display:none!important;display:block!important", "block"),
            ("display:none/**/ !/**/important;display:block", "none"),
            ("display:none!important;display:none-ish!important", "none"),
            ("display:none-ish!important;display:block", "block"),
            // Unknown priorities are invalid, not browser-specific aliases for
            // !important.
            ("display:none!foo;display:block", "block"),
            ("display:none! important extra;display:grid", "grid"),
        ]

        for testCase in cases {
            #expect(
                InlineStyleDeclarations(testCase.style).value(for: "display") == testCase.display,
                "style: \(testCase.style)"
            )
        }
    }

    @Test func stringsFunctionsCommentsAndMalformedBlocksCannotCreatePhantomDeclarations() {
        let styles = [
            "background-image:url('display:none;visibility:hidden')",
            "content:'display:none;visibility:hidden'",
            "/* display:none; visibility:hidden */ color:red",
            "color:red\\;display:none",
            "unknown:[x;display:none;]",
            "unknown:{x;visibility:hidden;}",
            "unknown:func(display:none;visibility:hidden)",
            "display:'none'",
            "display:'var(--article-layout)'",
            "display:n/**/one",
            "visibility:h/**/idden",
            "unknown:\"bad\\\n;display:none",
            "unknown:\"bad\\\r\n;visibility:hidden",
        ]

        for style in styles {
            let declarations = InlineStyleDeclarations(style)
            #expect(declarations.value(for: "display") != "none", "phantom display for \(style)")
            #expect(declarations.value(for: "visibility") != "hidden", "phantom visibility for \(style)")
        }
    }

    @Test func scannerStillFindsRealDeclarationsAfterUnrelatedComplexValues() {
        let styles = [
            "background:url('data:image/svg+xml;x;y');display:none",
            "--theme:func(a;b;c);visibility:hidden",
            "content:'not a ; declaration'; display : none",
            "color:red;/* irrelevant ; display:block */visibility:hidden",
            "unknown:\"bad\n;display:none",
            "unknown:'bad\r;visibility:hidden",
        ]

        for style in styles {
            let declarations = InlineStyleDeclarations(style)
            #expect(
                declarations.value(for: "display") == "none" ||
                    declarations.value(for: "visibility") == "hidden",
                "missed real hidden declaration for \(style)"
            )
        }
    }

    @Test func extractionUsesReaderRelevantInlineVisibility() throws {
        let cases: [(style: String, visible: Bool)] = [
            ("display:none", false),
            ("display:none;display:block", true),
            ("display:none!important;display:block", false),
            ("display:none!important;display:block!important", true),
            ("display:none!foo;display:block", true),
            ("visibility:hidden", false),
            ("visibility:hidden;visibility:visible", true),
            ("background-image:url('display:none')", true),
            ("display:none;display:var(--article-layout)", true),
            ("display:none;display:block math", true),
            ("display:none;display:none-ish", false),
            ("visibility:hidden;visibility:mostly-visible", false),
        ]

        for testCase in cases {
            let marker = "Inline visibility marker for \(testCase.style)"
            let escapedStyle = testCase.style
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            let html = """
            <html><body><article>
              <div style="\(escapedStyle)">
                <p>\(marker)</p>
                <p>A second substantial paragraph keeps this target inside the article candidate.</p>
              </div>
              <p>Visible fallback prose keeps extraction successful when the target is hidden.</p>
            </article></body></html>
            """
            let result = try #require(try Readability(
                html: html,
                url: baseURL,
                options: ReadabilityOptions(charThreshold: 1)
            ).parse())

            #expect(
                result.textContent.contains(marker) == testCase.visible,
                "extraction visibility mismatch for \(testCase.style)"
            )
        }
    }

    @Test func readerabilityUsesDisplayButNotVisibility() {
        let cases: [(style: String, visible: Bool)] = [
            ("display:none", false),
            ("display:none;display:block", true),
            ("display:none!important;display:block", false),
            ("display:none!important;display:block!important", true),
            ("background:url('display:none')", true),
            // Mozilla's lightweight readerability heuristic checks display,
            // while full extraction checks both properties.
            ("visibility:hidden", true),
        ]
        let prose = String(repeating: "Substantive readerability prose with context. ", count: 8)
        let options = Readability.ReaderableOptions(minContentLength: 1, minScore: 0)

        for testCase in cases {
            let html = "<html><body><article style=\"\(testCase.style)\">\(prose)</article></body></html>"
            #expect(
                Readability.isProbablyReaderable(html: html, options: options) == testCase.visible,
                "readerability visibility mismatch for \(testCase.style)"
            )
        }
    }
}
