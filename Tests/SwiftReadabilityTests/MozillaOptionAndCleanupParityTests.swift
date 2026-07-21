import Foundation
import SwiftSoup
import Testing
@testable import SwiftReadability

struct MozillaOptionAndCleanupParityTests {
    private let baseURL = URL(string: "https://example.com/story")!

    @Test func negativeTopCandidateCountDoesNotTrap() throws {
        let result = try Readability(
            html: articleHTML("Negative candidate counts are truthy in JavaScript, but the candidate loop simply executes zero times."),
            url: baseURL,
            options: ReadabilityOptions(nbTopCandidates: -1, charThreshold: 1)
        ).parse()

        #expect(result != nil)
    }

    @Test func nanLinkDensityModifierUsesMozillasFalsyZero() throws {
        let html = articleHTML("A NaN link-density modifier must behave exactly like zero throughout conditional cleanup.")
        let nan = try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1, linkDensityModifier: .nan)
        ).parse()
        let zero = try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1, linkDensityModifier: 0)
        ).parse()

        #expect(nan?.content == zero?.content)
        #expect(nan?.textContent == zero?.textContent)
    }

    @Test func ariaModalAndUnlikelyRolesMatchASCIICaseInsensitively() throws {
        let html = """
        <html><body><article>
          <section aria-modal="TrUe" role="DiAlOg"><p>MODAL_CHROME_MARKER must not enter the readable article.</p></section>
          <section role="NAVIGATION"><p>NAVIGATION_CHROME_MARKER must not enter the readable article.</p></section>
          <p>A final ordinary paragraph makes the complete article a stable selection candidate.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.textContent.contains("MODAL_CHROME_MARKER"))
        #expect(!result.textContent.contains("NAVIGATION_CHROME_MARKER"))
        #expect(result.textContent.contains("final ordinary paragraph"))
    }

    @Test func ariaModalCaseFoldingStillAppliesDuringRecallRetries() throws {
        let html = """
        <html><body><article>
          <section aria-modal="TRUE" role="DIALOG"><p>RETRY_MODAL_CHROME_MARKER must not enter the readable article.</p></section>
          <p>An ordinary visible paragraph remains readable while a deliberately high threshold exercises every extraction retry.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 10_000)
        ).parse())

        #expect(!result.textContent.contains("RETRY_MODAL_CHROME_MARKER"))
        #expect(result.textContent.contains("ordinary visible paragraph"))
    }

    @Test func ariaAndRoleMatchingPreservesLookalikeValues() throws {
        let html = """
        <html><body><article>
          <section aria-modal="truthy" role="dialogue"><p>DIALOGUE_PROSE_MARKER is ordinary readable prose despite a role value that merely resembles dialog.</p></section>
          <section role="navigation-main"><p>NAVIGATION_MAIN_PROSE_MARKER is ordinary readable prose despite a role value that merely resembles navigation.</p></section>
          <p>A final ordinary paragraph makes the complete article a stable selection candidate.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.textContent.contains("DIALOGUE_PROSE_MARKER"))
        #expect(result.textContent.contains("NAVIGATION_MAIN_PROSE_MARKER"))
    }

    @Test func presentationTableRoleMatchesCaseWithoutMatchingLookalikesOrFallbackLists() throws {
        let html = """
        <html><body><article>
          <p>A stable article paragraph surrounds several short tables so their explicit roles control conditional cleanup.</p>
          <table role="PRESENTATION" summary="Layout navigation"><tr><th><a href="/layout">PRESENTATION_LAYOUT_CHROME</a></th></tr></table>
          <table role="presentationish" summary="Real tabular data"><tr><th>LOOKALIKE_DATA_MARKER</th><td>42</td></tr></table>
          <table role="table presentation" summary="Real tabular data"><tr><th>LEADING_TABLE_ROLE_MARKER</th><td>43</td></tr></table>
          <p>A second ordinary paragraph keeps extraction deterministic after the layout table is removed.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.textContent.contains("PRESENTATION_LAYOUT_CHROME"))
        #expect(result.textContent.contains("LOOKALIKE_DATA_MARKER"))
        #expect(result.textContent.contains("LEADING_TABLE_ROLE_MARKER"))
    }

    @Test func iframeInnerHTMLDoesNotSatisfyTheVideoAllowlist() throws {
        let html = """
        <html><body><article>
          <p>This article includes an ordinary iframe whose fallback markup mentions a video host without an allowed iframe attribute.</p>
          <iframe><a href="https://www.youtube.com/watch?v=fallback">Fallback video link</a></iframe>
          <p>The iframe itself must still be removed just as Mozilla removes it.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(!result.content.contains("<iframe"))
    }

    @Test func bylineNameSearchStartsAtDescendantsNotTheRoot() throws {
        let html = """
        <html><head><title>A Focused Byline Test</title></head><body><article>
          <div class="byline" itemprop="name author">
            Root prefix <span itemprop="name">Correct Author</span>
          </div>
          <p>This substantial editorial paragraph makes the byline and content extraction behavior deterministic.</p>
          <p>A second paragraph ensures the article remains selected after the byline node is removed.</p>
        </article></body></html>
        """

        let result = try #require(try Readability(
            html: html,
            url: baseURL,
            options: ReadabilityOptions(charThreshold: 1)
        ).parse())

        #expect(result.byline == "Correct Author")
    }

    private func articleHTML(_ marker: String) -> String {
        """
        <html><body><article>
          <p>\(marker)</p>
          <p>A second coherent paragraph supplies additional editorial context and punctuation, making the article selection deterministic.</p>
        </article></body></html>
        """
    }
}
