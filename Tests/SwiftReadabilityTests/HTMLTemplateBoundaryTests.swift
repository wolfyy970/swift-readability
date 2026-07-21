import Foundation
import SwiftSoup
import Testing
@testable import SwiftReadability

struct HTMLTemplateBoundaryTests {
    private let baseURL = URL(string: "https://example.com/articles/story")!

    @Test func templateOnlyProseIsNotReaderableOrExtractable() throws {
        let inertProse = String(
            repeating: "This substantial prose exists only in an inert HTML template. ",
            count: 40
        )
        let html = """
        <!doctype html><html><body>
          <template><article><p>\(inertProse)</p></article></template>
        </body></html>
        """

        let document = try SwiftSoup.parse(html)
        #expect(Readability.isProbablyReaderable(document: document) == false)
        // Standalone readerability is observational: it must not strip or move
        // template payloads from a caller-owned document.
        #expect(try document.select("template article p").count == 1)

        let result = try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse()
        #expect(result == nil)
    }

    @Test func inertTemplatePayloadIsStrippedWithoutURLRewriting() throws {
        let visibleProse = String(
            repeating: "Visible article prose keeps this surrounding story selected. ",
            count: 6
        )
        let html = """
        <!doctype html><html><body><article>
          <p>\(visibleProse)</p>
          <template data-source-marker="retained">
            <a href="/must-stay-relative">INERT_TEMPLATE_TEXT</a>
            <img src="images/must-stay-relative.png">
            <!-- INERT_TEMPLATE_COMMENT -->
          </template>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(keepClasses: true)
        ).parse())

        #expect(!result.content.contains("<template"))
        #expect(!result.content.contains("INERT_TEMPLATE_TEXT"))
        #expect(!result.content.contains("/must-stay-relative"))
        #expect(!result.content.contains("images/must-stay-relative.png"))
        #expect(!result.content.contains("https://example.com/must-stay-relative"))
        #expect(!result.content.contains("INERT_TEMPLATE_COMMENT"))
        #expect(!result.textContent.contains("INERT_TEMPLATE_TEXT"))
        #expect(result.textContent.contains("Visible article prose"))
        #expect(result.length == result.textContent.utf16.count)
    }

    @Test func templateContentsDoNotAffectMetadataTitleOrElementLimit() throws {
        let visibleProse = String(
            repeating: "The visible story supplies enough ordinary prose for deterministic extraction. ",
            count: 5
        )
        let inertElements = (0..<30)
            .map { "<span>INERT_LIMIT_\($0)</span>" }
            .joined()
        let html = """
        <!doctype html><html><body><article>
          <h1>Visible heading has enough meaningful words</h1>
          <p>\(visibleProse)</p>
          <template>
            <title>INERT TEMPLATE TITLE</title>
            <script type="application/ld+json">
              {"@context":"https://schema.org","@type":"Article","headline":"INERT JSONLD TITLE","author":{"@type":"Person","name":"INERT AUTHOR"}}
            </script>
            \(inertElements)
          </template>
        </article></body></html>
        """

        // html, head, body, article, h1, p, and template. Browser tag queries
        // do not count the template DocumentFragment's descendants.
        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(maxElemsToParse: 7, charThreshold: 1)
        ).parse())

        #expect(result.title == "Visible heading has enough meaningful words")
        #expect(result.byline == nil)
        #expect(!result.content.contains("<template"))
        #expect(!result.textContent.contains("INERT TEMPLATE TITLE"))
        #expect(!result.textContent.contains("INERT_LIMIT_"))
    }

    @Test func templateBoundaryAppliesOnlyToHTMLTemplateElements() throws {
        let htmlDocument = try SwiftSoup.parse("""
        <!doctype html><html><body>
          <template id="html-template"><span>HTML_TEMPLATE_TEXT</span></template>
          <svg><template id="svg-template"><text>SVG_TEMPLATE_TEXT</text></template></svg>
          <svg><foreignObject><template id="integration-template">INTEGRATION_TEMPLATE_TEXT</template></foreignObject></svg>
          <math><template id="math-template"><mtext>MATH_TEMPLATE_TEXT</mtext></template></math>
        </body></html>
        """)

        let htmlTemplate = try #require(htmlDocument.select("#html-template").first())
        let svgTemplate = try #require(htmlDocument.select("#svg-template").first())
        let integrationTemplate = try #require(htmlDocument.select("#integration-template").first())
        let mathTemplate = try #require(htmlDocument.select("#math-template").first())

        #expect(isHTMLTemplateElement(htmlTemplate))
        #expect(textContentPreservingWhitespace(of: htmlTemplate) == "")
        #expect(!isHTMLTemplateElement(svgTemplate))
        #expect(textContentPreservingWhitespace(of: svgTemplate) == "SVG_TEMPLATE_TEXT")
        #expect(isHTMLTemplateElement(integrationTemplate))
        #expect(textContentPreservingWhitespace(of: integrationTemplate) == "")
        #expect(!isHTMLTemplateElement(mathTemplate))
        #expect(textContentPreservingWhitespace(of: mathTemplate) == "MATH_TEMPLATE_TEXT")

        // The 13 visible-tree elements include both HTML templates themselves;
        // the span beneath the first HTML template is not counted.
        #expect(browserStyleElementCount(in: htmlDocument) == 13)
        try removeHTMLTemplateElements(from: htmlDocument)
        #expect(try htmlDocument.select("#html-template, #integration-template").isEmpty())
        #expect(try htmlDocument.select("#svg-template, #math-template").count == 2)

        let xmlDocument = try SwiftSoup.parse(
            "<root><template id=\"xml-template\">XML_TEMPLATE_TEXT</template></root>",
            baseURL.absoluteString,
            Parser.xmlParser()
        )
        let xmlTemplate = try #require(xmlDocument.select("#xml-template").first())
        #expect(!isHTMLTemplateElement(xmlTemplate))
        #expect(textContentPreservingWhitespace(of: xmlTemplate) == "XML_TEMPLATE_TEXT")
        #expect(browserStyleElementCount(in: xmlDocument) == 2)
        try removeHTMLTemplateElements(from: xmlDocument)
        #expect(try xmlDocument.select("#xml-template").count == 1)
    }
}
