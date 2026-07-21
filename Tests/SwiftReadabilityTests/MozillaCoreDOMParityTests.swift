import Foundation
import SwiftSoup
import Testing
@testable import SwiftReadability

/// Focused extraction regressions where DOM details can change retained article
/// content. These tests prioritize readable output over browser-object identity.
struct MozillaCoreDOMParityTests {
    private let baseURL = URL(string: "https://example.com/articles/story")!

    @Test func linkDensityDoesNotCountTheCandidateAnchorItself() throws {
        let html = """
        <!doctype html><html><head><title>Root anchor density regression</title></head><body><main>
          <a id="article-content" class="article-content"><p>Primary wrapped article prose has many words, several commas, and enough detail to become the strongest candidate. It continues with a substantial explanation, more observations, and a clear concluding sentence. This marker ROOT_ANCHOR_PRIMARY must survive when the wrapped anchor wins.</p></a>
          <aside><p>Short competing material, with enough words to score, but it is not the primary article. COMPETING_ASIDE.</p></aside>
        </main></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("ROOT_ANCHOR_PRIMARY"))
        #expect(!result.textContent.contains("COMPETING_ASIDE"))
    }

    @Test func maximumElementCountExcludesTheDocumentNode() throws {
        // Browser document.getElementsByTagName("*") reports exactly six
        // elements here: html, head, title, body, article, and p.
        let html = """
        <!doctype html><html><head><title>Boundary</title></head><body><article><p>Concise article prose is enough to return content at the exact six-element boundary.</p></article></body></html>
        """

        _ = try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(maxElemsToParse: 6, charThreshold: 1)
        ).parse()

        do {
            _ = try Readability(
                html: html,
                url: baseURL,
                options: ReadabilityOptions(maxElemsToParse: 5, charThreshold: 1)
            ).parse()
            Issue.record("Mozilla rejects this six-element document when the configured maximum is five.")
        } catch {
            let error = error as NSError
            #expect(error.domain == "Readability")
            #expect(error.code == 1)
        }
    }

    @Test func displayNoneRemovesHiddenMathMLContent() throws {
        let html = """
        <!doctype html><html><head><title>MathML style property regression</title></head><body><article>
          <math><mtext style="display:none">MATHML_STYLE_MARKER is hidden formula fallback text and should not enter the readable article.</mtext></math>
          <p>An ordinary visible paragraph keeps the surrounding article selected and makes the result deterministic. It should remain in both implementations.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.textContent.contains("MATHML_STYLE_MARKER"))
    }

    @Test func fallbackImageClassPreservesAnSVGAlternative() throws {
        let html = """
        <!doctype html><html><head><title>SVG className regression</title></head><body><article>
          <svg aria-hidden="true" class="fallback-image"><foreignObject><p>SVG_FALLBACK_MARKER is meaningful fallback content explicitly marked for preservation. This paragraph is intentionally substantial.</p></foreignObject></svg>
          <p>An ordinary visible paragraph keeps the surrounding article selected and makes the output deterministic. It should remain regardless of the SVG subtree decision.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("SVG_FALLBACK_MARKER"))
    }

    @Test func ariaHiddenTrueMatchesCaseWithoutMatchingLookalikes() throws {
        let html = """
        <!doctype html><html><head><title>ARIA hidden token cleanup</title></head><body><article>
          <div aria-hidden="TRUE"><p>UPPERCASE_ARIA_HIDDEN_MARKER is explicitly hidden page chrome and must not enter the reader output.</p></div>
          <div aria-hidden="truthy"><p>ARIA_HIDDEN_LOOKALIKE_MARKER is visible prose because the attribute value is not the true token.</p></div>
          <p>An ordinary visible paragraph keeps the surrounding article selected and makes this extraction deterministic.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.textContent.contains("UPPERCASE_ARIA_HIDDEN_MARKER"))
        #expect(result.textContent.contains("ARIA_HIDDEN_LOOKALIKE_MARKER"))
    }

    @Test(arguments: ["svg", "math"])
    func foreignClassesDoNotTriggerUnlikelyCandidateRemoval(_ foreignTag: String) throws {
        let html = """
        <!doctype html><html><head><title>Foreign content scoring regression</title></head><body><article>
          <\(foreignTag)><text class="share" id="diagram-label">FOREIGN_SCORING_MARKER remains because diagram and formula class hooks must not be treated as page-chrome classification signals.</text></\(foreignTag)>
          <p>An ordinary visible paragraph keeps the surrounding article selected. It contains enough editorial prose and punctuation to make the extraction result stable and deterministic.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("FOREIGN_SCORING_MARKER"))
    }

    @Test func foreignIDsStillRemovePageControlDefinitions() throws {
        let html = """
        <!doctype html><html><head><title>SVG control definition cleanup</title></head><body><article>
          <p>Substantial article prose keeps the candidate stable while an embedded control bank is cleaned.</p>
          <svg><symbol id="share"><path d="M0 0"></path></symbol><symbol id="diagram-node"><path d="M1 1"></path></symbol></svg>
          <p>A second paragraph confirms that useful article content remains after the unused share definition is removed.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.content.contains("id=\"share\""))
        #expect(result.content.contains("id=\"diagram-node\""))
    }

    @Test func mathMLClassNameSupportsTheFallbackImageException() throws {
        let html = """
        <!doctype html><html><head><title>MathML className regression</title></head><body><article>
          <math aria-hidden="true" class="fallback-image"><mtext>MATHML_FALLBACK_MARKER remains because the source explicitly marks it as fallback content. This text is intentionally substantial.</mtext></math>
          <p>An ordinary visible paragraph keeps the surrounding article selected and makes the output deterministic. It should remain alongside the MathML subtree.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("MATHML_FALLBACK_MARKER"))
    }

    @Test func siblingClassBonusUsesOnlyOrdinaryHTMLClasses() throws {
        let document = try SwiftSoup.parse(
            """
            <html><body>
              <div id="html-a" class="shared"></div>
              <div id="html-b" class="shared"></div>
              <math>
                <mrow id="math-a" class="shared"></mrow>
                <mrow id="math-b" class="shared"></mrow>
              </math>
              <svg>
                <g id="svg-a" class="shared"></g>
                <g id="svg-b" class="shared"></g>
              </svg>
            </body></html>
            """
        )
        let htmlA = try #require(document.select("#html-a").first())
        let htmlB = try #require(document.select("#html-b").first())
        let mathA = try #require(document.select("#math-a").first())
        let mathB = try #require(document.select("#math-b").first())
        let svgA = try #require(document.select("#svg-a").first())
        let svgB = try #require(document.select("#svg-b").first())
        let resolver = ArticleContentNamespaceResolver()

        #expect(resolver.classNamesMatchForSiblingBonus(htmlA, htmlB))
        #expect(!resolver.classNamesMatchForSiblingBonus(mathA, mathB))
        #expect(!resolver.classNamesMatchForSiblingBonus(svgA, svgB))
    }

    @Test func displayNoneRemovesNestedForeignContent() throws {
        let html = """
        <!doctype html><html><head><title>Annotation SVG visibility regression</title></head><body><article>
          <math><annotation-xml><svg style="display:none"><text>NESTED_FOREIGN_HIDDEN_MARKER must be removed because the source explicitly hides this formula content.</text></svg></annotation-xml></math>
          <p>An ordinary visible paragraph keeps the surrounding article selected and makes the output deterministic. It should remain after the hidden SVG is removed.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.textContent.contains("NESTED_FOREIGN_HIDDEN_MARKER"))
    }

    @Test func htmlNamespaceResolutionHandlesThousandLevelAncestry() throws {
        let document = try SwiftSoup.parse("<html><body></body></html>")
        var deepest = try #require(document.body())
        // This covers only the resolver's HTML ancestry walk. At several
        // thousand levels SwiftSoup's own tree lifetime becomes unstable on
        // the supported macOS runtime, so keep this boundary narrowly scoped.
        for _ in 0..<1_000 {
            let child = try document.createElement("div")
            _ = try deepest.appendChild(child)
            deepest = child
        }

        _ = try deepest.attr("class", "article-body")
        _ = try deepest.attr("id", "story")
        let signals = ArticleContentNamespaceResolver().scoringSignals(deepest)
        #expect(signals.className == "article-body")
        #expect(signals.id == "story")
    }

    @Test func objectWithAllowlistedVideoFallbackIsPreserved() throws {
        let html = """
        <!doctype html><html><head><title>Object inner video regression</title></head><body><article>
          <p>This substantive article contains an object whose fallback parameter names an allowlisted YouTube video.</p>
          <object><param name="movie" value="https://www.youtube.com/embed/abc"></object>
          <p>A second substantial paragraph keeps extraction deterministic and records the marker OBJECT_INNER_VIDEO_REGRESSION.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("OBJECT_INNER_VIDEO_REGRESSION"))
        #expect(result.content.contains("<object"))
    }

    @Test func executableEmbedsRequireAllowlistedSourceEvidence() throws {
        let html = """
        <!doctype html><html><head><title>Executable media evidence</title></head><body><article>
          <p>This substantive article surrounds executable media whose labels and fallback markup must not authorize an unrelated payload.</p>
          <object data="https://evil.example/payload">
            <param name="movie" value="https://www.youtube.com/embed/not-the-object-source">
            <p>OBJECT_FALLBACK_PROSE_MARKER https://www.youtube.com/watch?v=not-evidence</p>
          </object>
          <object><a href="https://www.youtube.com/watch?v=also-not-evidence">OBJECT_FALLBACK_LINK_MARKER</a></object>
          <iframe src="https://evil.example/frame" title="https://www.youtube.com/watch?v=not-evidence"></iframe>
          <p>A second substantial paragraph keeps extraction deterministic and records the retained marker EXECUTABLE_MEDIA_EVIDENCE_REGRESSION.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("EXECUTABLE_MEDIA_EVIDENCE_REGRESSION"))
        #expect(!result.content.contains("<object"))
        #expect(!result.content.contains("<iframe"))
        #expect(!result.textContent.contains("OBJECT_FALLBACK_PROSE_MARKER"))
        #expect(!result.textContent.contains("OBJECT_FALLBACK_LINK_MARKER"))
    }

    @Test func emptyFirstParagraphProducesAnEmptyExcerptInsteadOfNil() throws {
        let html = """
        <!doctype html><html><head><title>Image excerpt regression</title></head><body><article>
          <p><img src="hero.jpg" alt=""></p>
          <p>This substantive article paragraph follows an image-only paragraph. It contains enough editorial prose, punctuation, and explanatory detail to make extraction deterministic while leaving the first retained paragraph without text.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.excerpt == Optional(""))
    }

    @Test func reactCommentSeparatorsDoNotChangeExtraction() throws {
        func articleHTML(separator: String) -> String {
            """
            <!doctype html><html><head><title>React separator regression</title></head><body><article>
              <p>React\(separator) separators must not change retained prose, scoring, or article structure. This paragraph is deliberately substantial and includes punctuation.</p>
              <p>A second coherent paragraph keeps extraction deterministic and confirms that the surrounding article remains intact.</p>
            </article></body></html>
            """
        }

        let plain = try #require(try Readability(
            html: articleHTML(separator: ""),
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())
        let commented = try #require(try Readability(
            html: articleHTML(separator: "<!-- -->"),
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(commented.textContent == plain.textContent)
        #expect(commented.content == plain.content)
        #expect(!commented.content.contains("<!--"))
    }

    @Test func adjacentReactCommentsPreserveSourceSpacing() throws {
        let html = """
        <!doctype html><html><head><title>Inline comment spacing regression</title></head><body><article>
          <p>Jo<!-- --><!-- --> contributed the primary reporting for this detailed article, and the space before contributed is meaningful readable content.</p>
          <p>A second substantial paragraph keeps the article selection deterministic while verifying the rest of the prose remains available.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("Jo contributed"))
        #expect(!result.textContent.contains("Jocontributed"))
        #expect(!result.content.contains("<!--"))
    }

    @Test func nytStyleCommentSeparatorsStayInOneParagraph() throws {
        let notice = "A version of this article appears in print on, on Page A22 of the New York edition with a detailed explanatory headline and subscription information."
        let html = """
        <!doctype html><html><head><title>Print notice regression</title></head><body><article>
          <div id="print-notice">A version of this article appears in print on<!-- -->, on Page <!-- -->A<!-- -->22<!-- --> of the New York edition<!-- --> with a detailed explanatory headline and subscription information.</div>
          <p>The primary article paragraph contains substantial editorial prose, several clauses, and enough context to keep extraction stable.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())
        let output = try SwiftSoup.parse(result.content)
        let noticeParagraphs = try output.select("p").filter {
            textContentPreservingWhitespace(of: $0).contains("A version of this article")
        }

        #expect(noticeParagraphs.count == 1)
        #expect(textContentPreservingWhitespace(of: try #require(noticeParagraphs.first)) == notice)
        #expect(!result.content.contains("<!--"))
    }

    @Test func commentNormalizationPreservesRawElementData() throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <script id="javascript">const marker = "<!--SCRIPT_MARKER-->";</script>
              <style id="stylesheet">.marker::after { content: "<!--STYLE_MARKER-->"; }</style>
              <script id="json" type="application/ld+json">{"note":"<!--JSON_MARKER-->"}</script>
            </head><body><!--REMOVE_THIS_COMMENT--><p>Visible prose.</p></body></html>
            """
        )

        try removeInertDOMComments(from: document)

        #expect(try document.select("#javascript").first()?.data().contains("<!--SCRIPT_MARKER-->") == true)
        #expect(try document.select("#stylesheet").first()?.data().contains("<!--STYLE_MARKER-->") == true)
        #expect(try document.select("#json").first()?.data().contains("<!--JSON_MARKER-->") == true)
        #expect(!(try document.outerHtml()).contains("REMOVE_THIS_COMMENT"))
    }

    @Test func customSerializerObservesMozillasReadabilityContentRootID() throws {
        let html = """
        <!doctype html><html><body><article>
          <p>Substantial article prose gives the custom serializer a stable extracted root to inspect.</p>
        </article></body></html>
        """
        let options = ReadabilityOptions(
            charThreshold: 1,
            serializer: { $0.id() }
        )

        let result = try #require(try Readability(html: html, url: baseURL, options: options).parse())

        #expect(result.content == "readability-content")
    }
}
