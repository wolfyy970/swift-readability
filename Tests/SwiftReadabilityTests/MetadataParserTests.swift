import SwiftSoup
import Testing
@testable import SwiftReadability

struct MetadataParserTests {
    @Test(arguments: ["svg", "math"])
    func documentTitleIgnoresForeignNamespaceTitles(_ foreignTag: String) throws {
        let expectedTitle = "Actual Article Title With Enough Words"
        let document = try SwiftSoup.parse(
            """
            <html><body>
              <\(foreignTag)><title>Foreign diagram label</title></\(foreignTag)>
              <title>\(expectedTitle)</title>
              <article><p>Article prose.</p></article>
            </body></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == expectedTitle)
    }

    @Test func documentTitleIsEmptyWhenOnlyForeignTitlesExist() throws {
        let document = try SwiftSoup.parse(
            "<html><body><svg><title>Foreign diagram label</title></svg></body></html>"
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == "")
    }

    @Test func documentTitleIgnoresTitlesInsideSVGHTMLIntegrationPoints() throws {
        let expectedTitle = "Actual Article Title Outside The Diagram"
        let document = try SwiftSoup.parse(
            """
            <html><body>
              <svg><foreignObject><title>Embedded diagram control title</title></foreignObject></svg>
              <title>\(expectedTitle)</title>
              <article><p>Article prose.</p></article>
            </body></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == expectedTitle)
    }

    @Test func unicodeBeforeMatchedMetaPropertyDoesNotCrash() throws {
        let document = try SwiftSoup.parse(
            #"<html><head><meta property="😀 og:title" content="Unicode-safe title"></head></html>"#
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == "Unicode-safe title")
    }

    // Source map: Mozilla Readability._textSimilarity splits on `/\W+/g`.
    // In JavaScript that expression recognizes only ASCII letters, digits, and
    // underscore as word characters; Unicode letters are separators.
    @Test func jsonLDTitleSimilarityUsesMozillaASCIIWordTokens() throws {
        let htmlTitle = "猫 猫 猫 猫 猫 猫 猫 猫 alpha"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(htmlTitle)</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "NewsArticle",
                  "name": "猫",
                  "headline": "\(htmlTitle)"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == htmlTitle)
    }

    // Source map: Mozilla Readability._getArticleTitle compares an H1/H2's
    // raw DOM `textContent.trim()`, not a rendered/normalized text projection.
    @Test func colonTitleHeadingMatchUsesRawDOMTextContent() throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Brand: A Thorough Article Title About Native Swift</title>
            </head><body>
              <h1>Brand:\n A Thorough Article Title About Native Swift</h1>
            </body></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == "A Thorough Article Title About Native Swift")
    }

    // Source map: in Mozilla Readability._getJSONLD, the branch where both
    // `name` and `headline` exist deliberately assigns the selected raw value.
    @Test(
        arguments: [
            (
                title: "Canonical Article Title With Enough Words",
                name: "  Publisher Label  ",
                headline: "An Unrelated Headline",
                expected: "  Publisher Label  "
            ),
            (
                title: "Canonical Article Title With Enough Words",
                name: "Publisher Label",
                headline: "  Canonical Article Title With Enough Words  ",
                expected: "  Canonical Article Title With Enough Words  "
            ),
        ]
    )
    func bothPresentJSONLDTitleBranchesPreserveWhitespace(
        example: (title: String, name: String, headline: String, expected: String)
    ) throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(example.title)</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "NewsArticle",
                  "name": "\(example.name)",
                  "headline": "\(example.headline)"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == example.expected)
    }

    @Test func jsonLDAuthorArraySkipsMalformedAndUnnamedEntries() throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Article Title With Several Useful Words</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "NewsArticle",
                  "headline": "Article Title With Several Useful Words",
                  "author": [
                    null,
                    {"@type": "Organization"},
                    "Unstructured Author",
                    {"name": "  First Named Author  "},
                    {"name": false},
                    {"name": "Second Named Author"}
                  ]
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.byline == "First Named Author, Second Named Author")
    }

    @Test(arguments: [
        (
            json: #"[null,{"@context":"https://schema.org","@type":"NewsArticle","headline":"Accepted"}]"#,
            expected: "Accepted"
        ),
        (
            json: #"[{"@type":true},{"@context":"https://schema.org","@type":"NewsArticle","headline":"Accepted"}]"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@graph":[null,{"@type":"NewsArticle","headline":"Accepted"}]}"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@graph":[{"@type":{}},{"@type":"NewsArticle","headline":"Accepted"}]}"#,
            expected: "Accepted"
        ),
        (
            json: #"[{"@type":0},{"@context":"https://schema.org","@type":"NewsArticle","headline":"Accepted"}]"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@graph":[{"@type":0},{"@type":"NewsArticle","headline":"Accepted"}]}"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@type":"WebPage","@graph":[{"@type":"NewsArticle","headline":"Accepted"}]}"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@type":"WebPage","@graph":[{"@context":"https://schema.org","@type":"NewsArticle","headline":"Accepted"}]}"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@type":"WebPage","@graph":[{"@context":{"custom":"https://example.com/custom"},"@type":"NewsArticle","headline":"Accepted"}]}"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@type":"WebPage","@graph":[{"@context":"https://evil.example/vocab","@type":"NewsArticle","headline":"Wrong"}]}"#,
            expected: "Fallback Document Title With Enough Words"
        ),
        (
            json: #"[{"@context":"https://example.com/not-schema","@type":"NewsArticle","headline":"Wrong"},{"@context":"https://schema.org","@type":"NewsArticle","headline":"Accepted"}]"#,
            expected: "Accepted"
        ),
        (
            json: #"{"@context":"https://schema.org","@type":[null,true,"Person","NewsArticle"],"headline":"Accepted"}"#,
            expected: "Accepted"
        ),
        (
            json: #"[null,{"@type":true},{"@context":"https://schema.org","@type":"BreadcrumbList","headline":"Wrong"}]"#,
            expected: "Fallback Document Title With Enough Words"
        ),
        (
            json: #"{"@context":"https://schema.org","@type":[null,true,"Person","BreadcrumbList"],"headline":"Wrong"}"#,
            expected: "Fallback Document Title With Enough Words"
        ),
    ])
    func jsonLDArticleSearchSkipsMalformedNeighborsButRequiresAnArticleType(
        example: (json: String, expected: String)
    ) throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <script type="application/ld+json">\(example.json)</script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == example.expected)
    }

    @Test func jsonLDGraphChildCannotReplaceSchemaContext() throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Trusted Document Title With Enough Words</title>
              <meta name="author" content="Trusted Author">
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "WebPage",
                  "@graph": [{
                    "@context": "https://evil.example/vocab",
                    "@type": "NewsArticle",
                    "headline": "Unrelated Graph Title",
                    "author": {"name": "Wrong Author"}
                  }]
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == "Trusted Document Title With Enough Words")
        #expect(metadata.byline == "Trusted Author")
    }

    @Test func jsonLDSchemaContextURLUsesNormalizedSchemeAndHostCasing() throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <script type="application/ld+json">
                {
                  "@context": "https://SCHEMA.ORG",
                  "@type": "NewsArticle",
                  "headline": "Recovered JSON LD Title"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == "Recovered JSON LD Title")
    }

    @Test func jsonLDSchemaContextArraySkipsMalformedNeighbors() throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <script type="application/ld+json">
                {
                  "@context": [null, {"unrelated": "value"}, {"@vocab": "HTTPS://SCHEMA.ORG/"}],
                  "@type": "NewsArticle",
                  "headline": "Recovered Context Array Title"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == "Recovered Context Array Title")
    }

    @Test(arguments: [
        (
            context: #"[{"@vocab":"https://schema.org/"},{"@vocab":"https://evil.example/vocab"}]"#,
            title: "Fallback Document Title With Enough Words",
            byline: "Trusted Meta Author"
        ),
        (
            context: #"[{"@vocab":"https://evil.example/vocab"},{"@vocab":"https://schema.org/"}]"#,
            title: "Ordered Context Article Title",
            byline: "JSON LD Author"
        ),
    ])
    func jsonLDContextArrayUsesTheFinalEffectiveVocabulary(
        example: (context: String, title: String, byline: String)
    ) throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <meta name="author" content="Trusted Meta Author">
              <script type="application/ld+json">
                {
                  "@context": \(example.context),
                  "@type": "NewsArticle",
                  "headline": "Ordered Context Article Title",
                  "author": {"name": "JSON LD Author"}
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == example.title)
        #expect(metadata.byline == example.byline)
    }

    @Test(
        arguments: [
            "https://schema.org.evil.example/",
            "https://schema.org/Article",
            "https://user@schema.org/",
            "https://schema.org/?context=Article",
        ]
    )
    func jsonLDSchemaContextRejectsLookalikeURLs(context: String) throws {
        let fallback = "Fallback Document Title With Enough Words"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(fallback)</title>
              <script type="application/ld+json">
                {
                  "@context": "\(context)",
                  "@type": "NewsArticle",
                  "headline": "Wrong Context Title"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == fallback)
    }

    // A context must be the Schema.org origin itself, not that URL followed by
    // an otherwise invisible non-URL character.
    @Test func jsonLDSchemaContextRejectsInvalidTrailingCharacters() throws {
        let nextLine = "\u{0085}"
        let fallback = "Fallback Document Title With Enough Words"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(fallback)</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org\(nextLine)",
                  "@type": "NewsArticle",
                  "headline": "JSON LD Title With An Invalid Context"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == fallback)
    }

    // `APIReference` is the only final alternative anchored with `$` in
    // Mozilla's intentionally asymmetric JSON-LD type expression.
    @Test func jsonLDAPIReferenceTypeRequiresTheECMAScriptEndOfInput() throws {
        let nextLine = "\u{0085}"
        let fallback = "Fallback Document Title With Enough Words"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(fallback)</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "APIReference\(nextLine)",
                  "headline": "JSON LD Title That Mozilla Rejects"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == fallback)
    }

    @Test(
        arguments: [
            "APPLICATION/LD+JSON",
            " application/ld+json ",
            "Application/Ld+Json; charset=utf-8",
        ]
    )
    func jsonLDScriptTypeMatchesMIMEEssenceCaseInsensitively(type: String) throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <script type="\(type)">
                {
                  "@context": "https://schema.org",
                  "@type": "NewsArticle",
                  "headline": "Recovered JSON LD Title"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == "Recovered JSON LD Title")
    }

    @Test(arguments: ["application/ld+jsonish", "text/ld+json", "application/json"])
    func jsonLDScriptTypeRejectsDifferentMIMEEssences(type: String) throws {
        let fallback = "Fallback Document Title With Enough Words"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(fallback)</title>
              <script type="\(type)">
                {
                  "@context": "https://schema.org",
                  "@type": "NewsArticle",
                  "headline": "Wrong MIME Title"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == fallback)
    }

    // Source map: Mozilla Readability._isUrl uses the browser's one-argument
    // WHATWG `new URL(value)`. Foundation.URL accepts incomplete values such as
    // `http://`, which incorrectly suppresses them as article-author URLs.
    @Test func articleAuthorURLDetectionUsesWHATWGParsing() throws {
        let incompleteURLDocument = try SwiftSoup.parse(
            """
            <html><head>
              <title>Article Title With Several Useful Words</title>
              <meta property="article:author" content="http://">
            </head></html>
            """
        )
        let validURLDocument = try SwiftSoup.parse(
            """
            <html><head>
              <title>Article Title With Several Useful Words</title>
              <meta property="article:author" content="https://example.com/author">
            </head></html>
            """
        )

        let parser = MetadataParser()
        let incomplete = parser.getArticleMetadata(incompleteURLDocument, disableJSONLD: true)
        let valid = parser.getArticleMetadata(validURLDocument, disableJSONLD: true)

        #expect(incomplete.byline == "http://")
        #expect(valid.byline == nil)
    }

    // Mozilla's metadata `trim()` sites follow ECMAScript whitespace, which
    // removes U+FEFF but preserves U+0085 and U+200B.
    @Test(arguments: [
        ("\u{FEFF}Metadata Title\u{FEFF}", "Metadata Title"),
        ("\u{0085}Metadata Title\u{0085}", "\u{0085}Metadata Title\u{0085}"),
        ("\u{200B}Metadata Title\u{200B}", "\u{200B}Metadata Title\u{200B}"),
    ])
    func metaContentUsesECMAScriptTrim(example: (input: String, expected: String)) throws {
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <meta property="og:title" content="\(example.input)">
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == example.expected)
    }

    // Mozilla's metadata key patterns and subsequent `replace(/\s/g, "")`
    // share ECMAScript's whitespace table. U+FEFF is whitespace there, while
    // U+0085 and U+200B are literal characters and must prevent a key match.
    @Test(arguments: [
        (attribute: "property", whitespace: "\u{FEFF}", matches: true),
        (attribute: "property", whitespace: "\u{0085}", matches: false),
        (attribute: "property", whitespace: "\u{200B}", matches: false),
        (attribute: "name", whitespace: "\u{FEFF}", matches: true),
        (attribute: "name", whitespace: "\u{0085}", matches: false),
        (attribute: "name", whitespace: "\u{200B}", matches: false),
    ])
    func metaKeyPatternsUseECMAScriptWhitespace(
        example: (attribute: String, whitespace: String, matches: Bool)
    ) throws {
        let fallback = "Fallback Document Title With Enough Words"
        let key = "og\(example.whitespace):\(example.whitespace)title"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(fallback)</title>
              <meta \(example.attribute)="\(key)" content="Structured Metadata Title">
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == (example.matches ? "Structured Metadata Title" : fallback))
    }

    // The separators in Mozilla `_getArticleTitle` are surrounded by JS `\s`,
    // not Foundation/ICU whitespace. This is observable before the short-title
    // fallback because the retained left side contains more than four words.
    @Test(arguments: [
        (whitespace: "\u{FEFF}", separates: true),
        (whitespace: "\u{0085}", separates: false),
        (whitespace: "\u{200B}", separates: false),
    ])
    func titleSeparatorsUseECMAScriptWhitespace(
        example: (whitespace: String, separates: Bool)
    ) throws {
        let articleTitle = "Long Article Title With Enough Words"
        let fullTitle =
            "\(articleTitle)\(example.whitespace)|\(example.whitespace)Publisher Name"
        let document = try SwiftSoup.parse("<html><head><title>\(fullTitle)</title></head></html>")

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == (example.separates ? articleTitle : fullTitle))
    }

    // Mozilla strips JSON-LD CDATA sentinels using
    // `/^\s*<!\[CDATA\[|\]\]>\s*$/g`; both anchors therefore use the same
    // ECMAScript whitespace table as `trim()`.
    @Test(arguments: [
        (whitespace: "\u{FEFF}", stripsMarkers: true),
        (whitespace: "\u{0085}", stripsMarkers: false),
        (whitespace: "\u{200B}", stripsMarkers: false),
    ])
    func jsonLDCDATABoundariesUseECMAScriptWhitespace(
        example: (whitespace: String, stripsMarkers: Bool)
    ) throws {
        let fallback = "Fallback Document Title With Enough Words"
        let json =
            #"{"@context":"https://schema.org","@type":"NewsArticle","headline":"CDATA Article Title"}"#
        let document = try SwiftSoup.parse(
            """
            <html><head><title>\(fallback)</title><script type="application/ld+json">\(example.whitespace)<![CDATA[\(json)]]>\(example.whitespace)</script></head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == (example.stripsMarkers ? "CDATA Article Title" : fallback))
    }

    @Test func singleJSONLDTitleAndFieldsUseECMAScriptTrim() throws {
        let nextLine = "\u{0085}"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>Fallback Document Title With Enough Words</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "NewsArticle",
                  "headline": "\(nextLine)Structured Title\(nextLine)",
                  "author": {"name": "\(nextLine)Author Name\(nextLine)"},
                  "description": "\(nextLine)Description\(nextLine)",
                  "publisher": {"name": "\(nextLine)Publisher\(nextLine)"},
                  "datePublished": "\(nextLine)2026-07-20\(nextLine)"
                }
              </script>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: false)

        #expect(metadata.title == "\(nextLine)Structured Title\(nextLine)")
        #expect(metadata.byline == "\(nextLine)Author Name\(nextLine)")
        #expect(metadata.excerpt == "\(nextLine)Description\(nextLine)")
        #expect(metadata.siteName == "\(nextLine)Publisher\(nextLine)")
        #expect(metadata.publishedTime == "\(nextLine)2026-07-20\(nextLine)")
    }

    // The DOM `document.title` getter collapses only HTML ASCII whitespace;
    // Readability then applies ECMAScript trim. SwiftSoup's convenience getter
    // uses a broader whitespace definition, so the port must not delegate here.
    @Test func documentTitlePreservesNonHTMLWhitespaceLikeMozilla() throws {
        let nextLine = "\u{0085}"
        let document = try SwiftSoup.parse(
            """
            <html><head>
              <title>\(nextLine)Alpha   Beta   Gamma   Delta   Epsilon\(nextLine)</title>
            </head></html>
            """
        )

        let metadata = MetadataParser().getArticleMetadata(document, disableJSONLD: true)

        #expect(metadata.title == "\(nextLine)Alpha Beta Gamma Delta Epsilon\(nextLine)")
    }
}
