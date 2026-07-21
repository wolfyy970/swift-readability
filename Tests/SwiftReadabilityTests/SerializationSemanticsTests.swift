import Foundation
import SwiftSoup
import Testing
@testable import SwiftReadability

struct SerializationSemanticsTests {
    private let baseURL = URL(string: "https://example.com/article")!

    @Test(arguments: ["itemscope", "ITEMSCOPE"])
    func htmlSerializationPreservesCanonicalBooleanValues(_ value: String) throws {
        let prose = String(repeating: "Browser serialization preserves source attribute values. ", count: 30)
        let html = """
        <!doctype html>
        <html><body>
          <article itemscope="\(value)" itemtype="https://schema.org/Article">
            <p>\(prose)</p>
          </article>
        </body></html>
        """

        let result = try Readability(html: html, url: baseURL).parse()

        #expect(result?.content.contains("itemscope=\"\(value)\"") == true)
    }

    @Test func htmlSerializationUsesBrowserVoidElementSyntax() throws {
        let prose = String(repeating: "Browser HTML serialization remains directly observable. ", count: 20)
        let html = "<article><p>\(prose)<br>Tail.</p></article>"

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.content.contains("<br>Tail."))
        #expect(!result.content.contains("<br />"))
    }

    @Test func htmlSerializationPreservesEmptyAttributesAndNonbreakingSpaces() throws {
        let prose = String(repeating: "HTML serialization preserves meaningful DOM values. ", count: 20)
        let html = "<article itemscope><p>\(prose)non\u{00A0}breaking.</p></article>"

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1, keepClasses: true)
        ).parse())

        let reparsed = try SwiftSoup.parseBodyFragment(result.content)
        let article = try #require(reparsed.select("article").first())
        let paragraph = try #require(reparsed.select("p").first())
        #expect(article.hasAttr("itemscope"))
        #expect(textContentPreservingWhitespace(of: paragraph).contains("non\u{00A0}breaking"))
    }

    @Test func htmlSerializationPreservesSVGStructureWhenReparsed() throws {
        let prose = String(repeating: "SVG structure is meaningful article content. ", count: 20)
        let html = """
        <article><p>\(prose)</p><svg viewBox="0 0 10 10"><clipPath id="cut"><path d="M0 0"></path></clipPath></svg></article>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1, keepClasses: true)
        ).parse())

        let reparsed = try SwiftSoup.parseBodyFragment(result.content)
        let svg = try #require(reparsed.select("svg").first())
        #expect(try svg.attr("viewbox") == "0 0 10 10")
        #expect(try reparsed.select("clippath#cut").count == 1)
    }

    @Test(arguments: ["\u{0085}", "\u{FEFF}", "\u{200B}"])
    func htmlSerializationPreservesUnicodeInsideBooleanValues(_ scalar: String) throws {
        let prose = String(repeating: "Attribute values remain observable DOM data. ", count: 35)
        let value = scalar + "itemscope" + scalar
        let html = """
        <article itemscope="\(value)" itemtype="https://schema.org/Article">
          <p>\(prose)</p>
        </article>
        """

        let result = try Readability(html: html, url: baseURL).parse()

        #expect(result?.content.contains("itemscope=\"\(value)\"") == true)
    }

    @Test func malformedHTMLIsRepairedWithoutRewritingBooleanValues() throws {
        let prose = String(repeating: "The HTML parser repairs this unclosed paragraph. ", count: 35)
        let html = "<article itemscope=\"itemscope\" itemtype=\"https://schema.org/Article\"><p>\(prose)"

        let result = try Readability(html: html, url: baseURL).parse()

        #expect(result?.content.contains("itemscope=\"itemscope\"") == true)
        #expect(result?.textContent.contains("The HTML parser repairs") == true)
    }

    @Test func xmlSerializationPreservesDocumentSemantics() throws {
        let document = try SwiftSoup.parse(
            """
            <root><article><figure id="target" itemscope="" data-label="A &amp; B"><figcaption>Diagram &amp; explanation.</figcaption></figure></article></root>
            """,
            baseURL.absoluteString,
            Parser.xmlParser()
        )
        let article = try #require(document.select("article").first())
        let reader = Readability(document: document)

        let serialized = reader.serializeArticleContent(
            document: document,
            articleContent: article,
            useXMLSerializer: true,
            isLiveDocument: true
        )

        let reparsed = try SwiftSoup.parse(
            "<root>\(serialized)</root>",
            baseURL.absoluteString,
            Parser.xmlParser()
        )
        let figure = try #require(reparsed.select("figure#target").first())
        let caption = try #require(figure.select("figcaption").first())
        #expect(figure.hasAttr("itemscope"))
        #expect(try figure.attr("itemscope") == "")
        #expect(try figure.attr("data-label") == "A & B")
        #expect(try caption.text() == "Diagram & explanation.")
    }

    @Test func documentExtractionAdoptsDetachedContentIntoXMLSerializerDocument() throws {
        let prose = String(repeating: "XML serialization preserves article document semantics. ", count: 20)
        let document = try SwiftSoup.parse(
            """
            <html><body><article itemscope=""><p>\(prose)<br data-marker="" /></p></article></body></html>
            """,
            baseURL.absoluteString,
            Parser.xmlParser()
        )

        let result = try #require(try Readability(
            document: document,
            options: ReadabilityOptions(charThreshold: 1, useXMLSerializer: true)
        ).parse())

        #expect(result.content.contains("itemscope=\"\""))
        #expect(result.content.contains("<br data-marker=\"\" />"))

        let reparsed = try SwiftSoup.parse(
            "<root>\(result.content)</root>",
            baseURL.absoluteString,
            Parser.xmlParser()
        )
        let article = try #require(reparsed.select("[itemscope]").first())
        let lineBreak = try #require(reparsed.select("br[data-marker]").first())
        #expect(try article.attr("itemscope") == "")
        #expect(try lineBreak.attr("data-marker") == "")
    }
}
