# Changelog

Notable changes to SwiftReadability are documented here. The project follows
[Semantic Versioning](https://semver.org/) while its public API matures.

## [Unreleased]

### Added

- Added a fail-closed direct Mozilla differential for representative non-default
  options, including serializer mutation ordering and thrown element limits.
- Added adopter lifecycle, URL, readerability, resource-limit, compatibility,
  contribution, and release guidance.
- Added root-level `ARCHITECTURE.md` and `BENCHMARK.md` documents and reduced the
  README to a project overview, installation guide, quick start, and concise
  evidence summary.
- Added a durable authorship and lineage record identifying ChatGPT 5.6 Sol
  (OpenAI GPT-5.6 Sol through Codex) as the primary engineering author of the
  post-0.3.2 quality-first rewrite, Mozilla as the pinned comparison baseline,
  and Lake of Fire as the original Swift Readability port.
- Documented that the 136-input corpus contains 130 Mozilla fixtures and six
  project-captured pages, and qualified the measured quality comparison against
  both the pinned Mozilla implementation and the inherited Swift port.
- Reworked the README title, opening summary, headings, and use cases so Swift
  developers searching for article extraction, web-page text extraction,
  Reader Mode, HTML-to-clean-text, or main-content parsing can find and assess
  the package without keyword stuffing.
- Added the project's concise “vibe-coded with intent” disclosure, identifying
  authorship and human review while welcoming issues, corrections, and
  contributions.
- Added an explicit account of what each test layer proves, where the current
  output matches pinned Mozilla, and why the frozen corpus, security checks,
  and benchmark smoke do not justify universal quality or performance claims.

### Changed

- Changed the differential output gate from serializer bytes, inert comments,
  and error prose to a canonical browser-parsed DOM, exact extracted text,
  metadata, URL-bearing attributes, meaningful Boolean/enumerated attribute
  states, outcomes, and UTF-16 length.
- Normalized actual DOM Comment nodes before extraction, matching Mozilla's
  fixture policy and preventing framework separator comments from fragmenting
  readable prose. The generated 33-fixture raw-comment overlay system is gone.
- Replaced browser-byte HTML serialization emulation with a compact serializer
  that preserves text and DOM meaning without hard-coding browser entity,
  attribute-order, SVG-casing, or error-spelling accidents.
- Replaced the pinned-JSDOM inline CSSOM replica with a bounded declaration
  scanner that recognizes explicit `display: none` and `visibility: hidden`
  while failing open on unfamiliar or malformed values to protect article prose.
- Removed source-wide XML reparsing and heuristic Boolean-attribute spelling
  reconstruction; XML output remains valid SwiftSoup XML and is tested by
  semantic round trip.
- Kept caller-supplied video regular expressions in Foundation's native dialect
  instead of maintaining a partial JavaScript-regex interpreter.
- Stripped inert HTML `<template>` payloads from reader-facing output instead of
  preserving hidden browser-serialization data. The template element still
  counts toward resource limits; its fragment does not. XML and foreign-content
  elements with the same local name remain ordinary content.

### Fixed

- Preserved the supplied SwiftSoup document location through WHATWG URL
  resolution instead of first normalizing it with Foundation URL rules.
- Captured serializer text content and UTF-16 length before invoking a
  potentially mutating serializer, matching Mozilla's observable ordering.
- Prevented integer overflow when readerability is configured with the minimum
  representable Swift content-length threshold.
- Applied explicit hidden styles consistently to formula and diagram content
  while preserving source-marked fallback images and allowlisted `<object>`
  video fallbacks.
- Required allowlisted executable-media evidence to come from source-bearing
  attributes rather than fallback prose, links, labels, or unrelated metadata.
- Kept current MathML `display: block math` and `display: inline math` content
  visible and recovered hidden declarations after malformed CSS strings.
- Prevented SVG and MathML class styling hooks from steering article scoring
  and sibling grouping while retaining IDs for page-control definition cleanup.
- Ignored `<title>` labels anywhere inside SVG diagrams or MathML formulas when
  selecting the article title.
- Preserved direct prose around a sole nested section or division even when the
  prose text node ends in whitespace.
- Unwrapped every anchor whose resolved URL has the `javascript` scheme,
  including mixed-case and control-prefixed spellings, while retaining its
  readable children and preserving safe lookalike paths.
- Made JSON-LD metadata recovery tolerant of malformed neighboring entries,
  valid `@type` and context arrays, and MIME or Schema.org URL casing while
  honoring the final effective vocabulary and rejecting unsupported types,
  lookalike contexts, and graph children that explicitly replace inherited
  Schema.org context.
- Treated hidden-state, modal, unlikely-role, and presentation-table ARIA
  tokens ASCII-case-insensitively while preserving lookalikes and fallback
  role lists.
- Kept the legacy mutable `Article` container's text and length projections in
  sync with in-place DOM mutations.
- Kept HTML-embedded SVG and MathML scoring classification iterative and cached
  without emulating generic XML namespaces or mutable serializer settings.
- Enforced element limits before preflight readerability work.

## [0.3.2] - 2026-07-20

### Security

- Replaced a credential-shaped Google browser API key copied into the upstream
  BuzzFeed compatibility fixture with a non-secret placeholder. Extraction
  expectations and runtime behavior are unchanged.

### Changed

- Removed obsolete development-only comparison trees and local workflow
  material from the maintained standalone ancestry. Production sources, public
  API, and library behavior are unchanged from 0.3.1.

## [0.3.1] - 2026-07-20

### Changed

- Refined package documentation and synthetic DOM regression fixture names;
  library behavior is unchanged.

## [0.3.0] - 2026-07-20

### Changed

- Removed the client-specific aggregate extension preset. Consumers now compose
  the granular recovery and cleanup flags they need, keeping application policy
  outside the reusable library.
- Renamed the internal enhanced-fixture profile and implementation identifiers
  around their neutral publisher-adaptation responsibilities.

## [0.2.0] - 2026-07-20

### Changed

- Made Mozilla Readability commit `ab4027a` the executable behavioral authority;
  the inherited Lake of Fire port remains credited provenance and scaffolding,
  not the compatibility specification.
- Reworked default extraction, metadata, DOM cleanup, serialization, JavaScript
  string/number/regular-expression semantics, and readerability behavior around
  focused pinned-oracle regressions.
- Pinned SwiftSoup 2.13.6 and WebURL 0.4.2; browser-style URL resolution no longer
  relies on Foundation URL heuristics.
- Moved Mozilla JavaScript sources out of the production library and into an
  optional, byte-verified reference product.

### Added

- A fail-closed 136-fixture Swift-versus-Mozilla result differential under true
  default options, with exact serialized output, a supplemental canonical-DOM
  diagnostic, strict raw-input comment overlays, CSSOM oracle cases, and
  focused edge-case tests.
- Explicit opt-in `ReadabilityExtensions` for isolated publisher cleanup,
  content recovery, media handling, and ruby normalization while keeping
  default behavior extension-free.
- Release-mode benchmark, immutable dependency, provenance, license, and native
  Linux compatibility gates.

### Fixed

- Unicode range crashes, cross-run mutable state, falsy option handling, HTML
  document traversal, language/direction discovery, link density, lazy image and
  URL property semantics, table span parsing, structured metadata edge cases,
  comment preservation, and browser serialization differences.

[Unreleased]: https://github.com/wolfyy970/swift-readability/compare/0.3.2...HEAD
[0.3.2]: https://github.com/wolfyy970/swift-readability/compare/0.3.1...0.3.2
[0.3.1]: https://github.com/wolfyy970/swift-readability/compare/0.3.0...0.3.1
[0.3.0]: https://github.com/wolfyy970/swift-readability/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/wolfyy970/swift-readability/compare/0.1.0...0.2.0
