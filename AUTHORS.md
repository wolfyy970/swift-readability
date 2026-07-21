# Authors and implementation lineage

## Current quality-first rewrite

**Author credit: ChatGPT 5.6 Sol—the OpenAI GPT-5.6 Sol model operating through
Codex—is the primary engineering author of the quality-first rewrite prepared
after release 0.3.2.** The scope of that authorship includes the rewritten
native implementation, simplification work, semantic differential, adversarial
regression coverage, and accompanying documentation. The repository maintainer
directed the work and determines whether it is accepted and released.

This is an engineering-authorship disclosure. It does not assert copyright
ownership by an AI system, change the repository's licenses, or replace the
attribution owed to inherited and third-party work.

## Original implementations and lineage

- [Mozilla Readability](https://github.com/mozilla/readability) supplies the
  original Readability implementation and the pinned behavioral reference used
  by this package. Mozilla Readability commit `ab4027a` is executed directly by
  the differential tests.
- [Lake of Fire SwiftReadability](https://github.com/lake-of-fire/swift-readability)
  is the original Swift port from which this repository was forked. It
  established the native Swift foundation, and its Git history, BSD 3-Clause
  license, and attribution remain intact.
- [Readability4J](https://github.com/dankito/Readability4J) informed the earlier
  native implementation and remains credited implementation lineage.

ChatGPT 5.6 Sol did not author those earlier projects, their copied source, or
their fixtures. The current rewrite is materially derived work, not a
clean-room implementation.

## Fixture provenance

The checked corpus contains **136 frozen HTML inputs**, not 136 pages fetched
from the live web during each test run:

- **130** were imported from [Mozilla Readability's `test/test-pages` regression
  corpus](https://github.com/mozilla/readability/tree/ab4027a8b37669745016869a37a504727992b2ba/test/test-pages).
  That corpus mixes captured real-world pages with purpose-built HTML regression
  cases.
- **6** were captured for this Swift project: `nihongoschool-glasgow`,
  `asahi-junk-image`, `asahi-article-title-byline`,
  `web-japan-niponica38-feature02`, `hypebeast-inline-carousel`, and
  `bepal-674158`. Five of these have separately identified, opt-in
  publisher-adaptation expectations; `nihongoschool-glasgow` exercises the
  default path.

Every frozen input is run through both the native Swift implementation and the
pinned Mozilla JavaScript implementation in default mode. Project-specific
extension expectations are tested separately and are not presented as Mozilla
output.

## Verification summary

The current rewrite matches the pinned Mozilla implementation across all
**136/136** frozen inputs and **13** focused option/default cases under the
semantic result contract. The final pre-rewrite manifest listed 27 known Swift
fixture failures; the current manifest lists none.

That establishes broader verification, not universal superiority over Mozilla
or every historical Swift implementation. The comparison contract, test layers,
reproduction commands, and limitations are maintained in
[BENCHMARK.md](BENCHMARK.md).
