# Provenance and licensing

SwiftReadability is a native Swift implementation in an established Readability lineage. It is not a clean-room rewrite, and the pinned behavioral specification does not erase the provenance or license of earlier work. This document records which components inform or enter each shipped product so maintainers and downstream distributors can preserve the correct notices.

## Executable comparison baseline versus implementation lineage

Mozilla Readability commit [`ab4027a8b37669745016869a37a504727992b2ba`](https://github.com/mozilla/readability/commit/ab4027a8b37669745016869a37a504727992b2ba) is the pinned executable and semantic comparison baseline. Default Swift behavior is judged against that exact revision through a byte-verified JavaScript oracle and a full result differential. This pin defines compatibility; it does not imply that Mozilla sponsors this package or that the package may discard Mozilla's Apache-2.0 terms.

The Git history begins with the Lake of Fire SwiftReadability port. That implementation established the native Swift foundation and itself identifies Mozilla Readability and Readability4J as sources. Current work preserves that history and BSD-3-Clause notice while aligning default behavior with the pinned Mozilla reference. Readability4J and Mozilla remain credited as Apache-2.0 lineage. No part of this history is described as clean-room work.

## Current rewrite authorship

ChatGPT 5.6 Sol—the OpenAI GPT-5.6 Sol model operating through Codex under the
repository maintainer's direction—is the primary engineering author of the
quality-first rewrite prepared after release 0.3.2. Its work covers the
rewritten native implementation, simplification, semantic differential,
adversarial regression coverage, and accompanying documentation.

This is an engineering-authorship disclosure, not a copyright assignment or a
license change. ChatGPT 5.6 Sol is not presented as the author of Mozilla
Readability, Readability4J, the original Lake of Fire Swift port, copied
reference sources, or inherited fixtures. See [`AUTHORS.md`](../AUTHORS.md) for
the full scope and quality evidence.

## Fixture provenance

The test corpus has 136 frozen HTML inputs. It consists of 130 fixtures imported
from Mozilla Readability's `test/test-pages` corpus and six pages captured for
this Swift project: `nihongoschool-glasgow`, `asahi-junk-image`,
`asahi-article-title-byline`, `web-japan-niponica38-feature02`,
`hypebeast-inline-carousel`, and `bepal-674158`. Five of the six project
captures have separately identified publisher-adaptation profiles; all 136 run
against pinned Mozilla with empty extensions in the direct differential.

The comparison contract, current result, relationship to the inherited Swift
port, and limits of the evidence are maintained in
[`BENCHMARK.md`](../BENCHMARK.md). This document retains the fixture split
because it determines source and redistribution provenance.

## Component map

| Component | Enters which product | Provenance and license |
| --- | --- | --- |
| `Sources/SwiftReadability` | `SwiftReadability`, and executables which depend on it | Materially modified native Swift implementation descended from the Lake of Fire port and informed by Mozilla Readability and Readability4J. BSD-3-Clause applies to the inherited/original Swift material as described in `LICENSE`; Apache-derived material remains subject to Apache-2.0. |
| `Sources/SwiftReadabilityJavaScriptReference/Resources` | Optional `SwiftReadabilityJavaScriptReference` only | Byte-identical Mozilla Readability sources at `ab4027a`; Apache-2.0, copyright Arc90 Inc. They are a test/reference oracle and are not linked by the production library. |
| Fixture corpus | Test target only | 130 fixture sets imported from Mozilla retain Mozilla's applicable Apache-2.0 terms. Six project-captured source snapshots and their project-maintained assertions are separately identified and are not represented as Mozilla-originated fixtures or expectations. Underlying publisher content retains its applicable rights. Native and reference runs normalize actual DOM Comment nodes before extraction, so the repository no longer carries generated raw-input overlay fixtures. |
| SwiftSoup 2.13.6 | Production `SwiftReadability` target | HTML parser and DOM implementation, MIT. Exact revision `ead56133a693d0184d8c2db1a6d6394410cacfd6`. |
| WebURL 0.4.2 | Production `SwiftReadability` target | WHATWG URL parser/resolver, Apache-2.0. Exact revision `9306a962396a50d7d88e924afcd7ec67226763db`; upstream NOTICE: “swift-url (WebURL) / Copyright Karl Wagner, and the swift-url Contributors.” |
| Swift System 1.7.4 | Resolved package graph only | Apache-2.0 with Runtime Library Exception, exact revision `b5544ba79a70a0cb3563e75bf26dc198d6b40ed3`. WebURL declares it for the separate `WebURLSystemExtras` product. `SwiftReadability` selects only `WebURL`, whose target closure is `WebURL` → `IDNA` → `UnicodeDataStructures`; therefore Swift System is not linked into this package's production product. |

SwiftPM resolves dependencies at package granularity, which is why Swift System appears in `Package.resolved` even though the selected WebURL product does not use `SystemPackage`. A future target that selects `WebURLSystemExtras` must repeat the target-closure review instead of relying on the current conclusion.

The linkage conclusion was verified against the exact revisions in `Package.resolved`, `swift package describe --type json`, and the checked-out 0.4.2 swift-url manifest. The package manifest makes `SwiftReadability` depend on the `WebURL` product; that product's targets name only `IDNA` and `UnicodeDataStructures`. The separate `WebURLSystemExtras` target is the only production swift-url target which names `SystemPackage`.

## Runtime boundary

An application that selects only the `SwiftReadability` product links native SwiftReadability, SwiftSoup, and WebURL code. It does not link the optional Mozilla JavaScript resource product, Node packages, JSDOM, or Swift System. Node and npm are development tools for the differential runner, not runtime requirements.

`useXMLSerializer` is also a native Swift serialization convenience, not a Mozilla Readability option. It asks SwiftSoup for XML syntax only when the supplied document is XML. Default HTML behavior and the extension-free Mozilla differential do not depend on it.

## Redistribution checklist

Source distributions should retain the repository history, `AUTHORS.md`,
`LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`, and the files under `LICENSES/`.
They should also retain the copyright and license headers in the unmodified
Mozilla JavaScript reference files.

A binary application which embeds the production `SwiftReadability` product should reproduce the SwiftReadability BSD notice, the Apache-2.0 license and Readability attributions applicable to the derived native implementation, the SwiftSoup MIT notice and license, and WebURL's Apache-2.0 license plus its upstream NOTICE text in the application's third-party acknowledgements or accompanying documentation. Swift System need not be listed as shipped while the app selects only `WebURL`, because it is not in that product's target closure.

An application which deliberately embeds `SwiftReadabilityJavaScriptReference` must additionally identify the Mozilla JavaScript resources as shipped Apache-2.0 content. Most production clients should not select that product.

This inventory documents the repository's engineering evidence and is not legal advice. When dependency products or source provenance change, re-run the target-closure audit and update the notices before publishing an artifact.
