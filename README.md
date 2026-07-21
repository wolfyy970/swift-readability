# SwiftReadability: Swift article and web page text extraction

**SwiftReadability is a native Swift package for extracting clean article text,
readable HTML, metadata, links, images, and primary content from webpages.** It
is a Swift implementation of [Mozilla Readability](https://github.com/mozilla/readability)
for Reader Mode, read-later apps, offline reading, search indexing,
summarization, and LLM or RAG content pipelines on iOS, macOS, Linux, and
server-side Swift.

Pass it an HTML string or SwiftSoup document plus the page URL. SwiftReadability
identifies the main article and removes navigation, advertisements, sharing
controls, hidden fallbacks, and other boilerplate while preserving useful
headings, paragraphs, lists, tables, formulas, media, and metadata.

The production library is native Swift. It requires no WebKit browser,
JavaScript runtime, Node process, or network service, and it does not fetch the
page for you.

**At a glance:** SwiftReadability matches pinned Mozilla on 136/136 tested
inputs, while the inherited Swift suite previously skipped 27 known failures;
runtime speed has not yet been compared head-to-head. [Benchmark
details](BENCHMARK.md).

## Why SwiftReadability

Use SwiftReadability to:

- extract article text and clean HTML from news, blogs, documentation, and other
  content-heavy pages;
- build a native Swift Reader Mode, reading app, read-later service, or offline
  article view;
- remove menus, ads, related-content rails, social buttons, and repeated site
  chrome without flattening the article structure;
- recover titles, authors, excerpts, site names, publication times, links,
  images, tables, captions, and language metadata; or
- prepare focused webpage content for search, accessibility, summarization,
  embeddings, and retrieval-augmented generation.

SwiftReadability is an article and main-content parser, not a crawler, browser,
general-purpose web scraper, or HTML sanitizer.

## Accuracy against Mozilla Readability

Default, extension-free output is compared directly with Mozilla Readability at
commit [`ab4027a`](https://github.com/mozilla/readability/commit/ab4027a8b37669745016869a37a504727992b2ba).
The current differential finds no semantic result difference across **136/136**
frozen inputs—130 from Mozilla's regression corpus and six captured for this
project—plus 13 focused option/default cases.

The final pre-rewrite suite built on the inherited Swift port listed 27 known
fixture failures; the current manifest lists none. The comparison infrastructure
is also substantially stronger, so this is evidence of broader verification,
not a claim that SwiftReadability is universally better than Mozilla on every
webpage.

See [Benchmark and verification](BENCHMARK.md) for the corpus sources,
comparison contract, current test counts, reproduction commands, performance
harness, and the limits of these claims.

## Authorship and lineage

**ChatGPT 5.6 Sol—the OpenAI GPT-5.6 Sol model operating through Codex—is the
primary engineering author of the post-0.3.2 rewrite.** The repository
maintainer directed and reviewed that work.

[Lake of Fire](https://github.com/lake-of-fire/swift-readability) created the
original Swift Readability port and established this repository's native
foundation. Mozilla supplies the original Readability implementation and pinned
comparison baseline; Readability4J also remains credited implementation lineage.
This is materially derived work, not a clean-room implementation.

See [Authors and implementation lineage](AUTHORS.md) for the complete
attribution and scope.

## Requirements

- Swift 6.2
- iOS 15+, macOS 13+, tvOS 15+, or watchOS 9+
- Linux with Swift 6.2; CI runs on Ubuntu 24.04
- SwiftSoup 2.13.6
- WebURL 0.4.2

Node 22.22.2 or later within the Node 22 release line is needed only for the
optional JavaScript reference and differential tests. Native applications do
not need Node or npm.

## Swift Package Manager installation

Add SwiftReadability to `Package.swift`:

```swift
.package(
    url: "https://github.com/wolfyy970/swift-readability.git",
    .upToNextMinor(from: "0.3.2")
)
```

Then add the native product to your application target:

```swift
.product(name: "SwiftReadability", package: "swift-readability")
```

SwiftReadability is pre-1.0. The range above accepts patch releases in the 0.3
line without automatically admitting a potentially breaking 0.4 release. Use
`exact: "0.3.2"` when reproducible extraction output matters more than
automatically receiving fixes.

The optional `SwiftReadabilityJavaScriptReference` product exists for
integrations and development comparison. Most applications should not link it.

## Extract article text and HTML in Swift

```swift
import SwiftReadability

let reader = Readability(
    html: htmlString,
    url: URL(string: "https://example.com/article")!
)

if let article = try reader.parse() {
    print(article.title ?? "Untitled")
    print(article.contentHTML)
    print(article.textContent)
}
```

Pass the document's actual page URL—normally the final response URL after
redirects. It is used to resolve `<base>`, links, images, and other relative
references. SwiftReadability does not download the page.

`parse()` returns `nil` when no article can be selected and may throw when
parsing fails or a configured element limit rejects the document.

Check whether attempting extraction is likely to be worthwhile:

```swift
let isReaderable = Readability.isProbablyReaderable(html: htmlString)
```

`isProbablyReaderable` is an inexpensive heuristic, not a correctness gate. It
can return false positives and false negatives.

### Extraction options and extensions

Most `ReadabilityOptions` fields correspond to Mozilla Readability options.
Publisher-specific recovery and cleanup remain explicit, opt-in extensions:

```swift
let reader = Readability(
    html: htmlString,
    url: URL(string: "https://example.com/article")!,
    options: ReadabilityOptions(
        extensions: [.imageCarouselRecovery, .publisherChromeCleanup]
    )
)
```

Available flags cover image-carousel recovery, publisher-chrome cleanup,
article-body preservation, significant-media preservation, and ruby
normalization. There is intentionally no aggregate public preset; the consuming
application owns the policy combination it enables.

HTML-backed readers build a fresh DOM for every parse. Readers created with
`Readability(document:)` destructively normalize the supplied SwiftSoup
document and should be treated as single-use. `Readability` is not `Sendable`;
create and use an instance within one task or actor.

Advanced option semantics, serializers, state, and extension boundaries are
documented in [Architecture](ARCHITECTURE.md).

## Architecture

The production pipeline is native Swift: SwiftSoup parses and manipulates the
DOM, WebURL resolves URLs using WHATWG behavior, and SwiftReadability owns
metadata discovery, candidate scoring, article cleanup, and serialization. The
native target neither contains nor depends on the optional Mozilla JavaScript
reference target.

See [Architecture](ARCHITECTURE.md) for the package topology, extraction
pipeline, public API boundary, state model, browser-semantics adapters, quality
priorities, and source map.

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Benchmark and verification](BENCHMARK.md)
- [Authors and implementation lineage](AUTHORS.md)
- [Provenance and licensing](docs/provenance-and-licensing.md)
- [Contributing and release checks](CONTRIBUTING.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Changelog](CHANGELOG.md)

## Testing

Run the native suite:

```sh
swift test
```

Run the complete native, JavaScript reference, and direct differential gates:

```sh
mise run test:parity
```

The unfiltered suites are release evidence. Filtered fixture runs are debugging
aids. See [Benchmark and verification](BENCHMARK.md) to reproduce
individual layers or run the performance harness, and [Contributing](CONTRIBUTING.md)
for the release checklist.

## Security

SwiftReadability extracts article content; it does **not** sanitize untrusted
HTML. Before rendering `article.content`, apply an appropriate HTML sanitizer
and Content Security Policy. The package neither renders nor executes extracted
content.

For attacker-controlled input, enforce input-byte, execution-time, and memory
limits outside SwiftReadability. `maxElemsToParse` is checked after SwiftSoup
parses the HTML, so it is not a parser-resource limit.

## Contributing

Issues, reproducible extraction fixtures, corrections, and pull requests are
welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, change
requirements, required checks, and the release checklist.

## License

This is a multi-license distribution. The inherited Swift implementation and
original Swift contributions use the BSD 3-Clause license in [`LICENSE`](LICENSE).
Apache-derived material, the optional Mozilla oracle, Mozilla-derived fixtures,
SwiftSoup, and WebURL retain their applicable terms.

See [Provenance and licensing](docs/provenance-and-licensing.md) and [Third-party
notices](THIRD_PARTY_NOTICES.md) before redistributing source or binaries.

## Disclosure

**SwiftReadability was vibe-coded with intent.** ChatGPT 5.6 Sol authored the
post-0.3.2 rewrite under human direction and review. It is tested, not presumed
perfect. Issues, corrections, and contributions are welcome.
