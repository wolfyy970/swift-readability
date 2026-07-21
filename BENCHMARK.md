# SwiftReadability benchmark and verification

This document records how SwiftReadability is compared with Mozilla
Readability, what the regression suites establish, and how to run the
performance harness. It deliberately separates semantic output comparison from
speed measurement: matching Mozilla and running quickly are different claims.

## At a glance

| Comparison | Result |
| --- | --- |
| Mozilla Readability | SwiftReadability has no detected semantic output difference across 136/136 frozen inputs and 13 focused option/default cases. This establishes equivalent output on the tested surface, not universal equivalence across the web. |
| Original Lake of Fire Swift port | Its final pre-rewrite manifest listed 27 known fixture failures; the current manifest lists none and adds a direct executable Mozilla differential. This is broader verification, not an apples-to-apples universal quality score. |
| Runtime speed | No defensible head-to-head timing result exists yet against Mozilla or the inherited Swift port. The current harness measures SwiftReadability and checks determinism, but stores no comparative baseline or regression threshold. |

**Bottom line:** tested extraction output is level with pinned Mozilla,
verification is substantially broader than the inherited Swift port, and
comparative runtime performance remains unknown.

## Two kinds of benchmark

| Benchmark | Question answered | Current claim |
| --- | --- | --- |
| Semantic differential | Does native Swift produce the same observable article result as pinned Mozilla on the checked inputs? | No detected difference across 136 frozen inputs and 13 focused option/default cases |
| Performance harness | How long does extraction take in this checkout and environment? | Reproducible local measurements and a deterministic smoke test; no stored performance baseline or pass/fail threshold |

The term *benchmark* in this document does not turn the frozen corpus into an
independent quality survey of the web. It is a repeatable compatibility and
regression benchmark.

## Current verification snapshot

The checked release-candidate state has:

- **136/136** frozen inputs with no detected Swift-versus-Mozilla semantic
  difference in default, extension-free mode;
- **13** focused option/default differential cases;
- **195** native Swift tests across **26** suites, passing in debug and release;
- **168** JavaScript oracle, fixture, differential-support, and failure-path
  tests;
- release builds passing with warnings treated as errors;
- no Swift Package Manager API break diagnosed against release 0.3.2; and
- a deterministic one-fixture release benchmark smoke.

These counts describe the current unreleased checkout and should be updated
when the suites change. The full commands in [Contributing](CONTRIBUTING.md)
are the release gates.

## Corpus provenance

The compatibility corpus contains **136 frozen HTML inputs**. They are checked
repository snapshots, not pages fetched from the live web during each run.

- **130** came from [Mozilla Readability's `test/test-pages`
  corpus](https://github.com/mozilla/readability/tree/ab4027a8b37669745016869a37a504727992b2ba/test/test-pages).
  Mozilla's corpus combines captured publisher pages with synthetic regression
  documents.
- **6** were captured for this Swift project:
  `nihongoschool-glasgow`, `asahi-junk-image`,
  `asahi-article-title-byline`, `web-japan-niponica38-feature02`,
  `hypebeast-inline-carousel`, and `bepal-674158`.

Five project snapshots also have opt-in publisher-adaptation expectations.
`nihongoschool-glasgow` exercises the default path. All 136 original inputs are
still compared with Mozilla using an empty extension set; enhanced extension
expectations never redefine Mozilla's output.

See [Provenance and licensing](docs/provenance-and-licensing.md) for fixture rights
and redistribution terms.

## Pinned Mozilla oracle

Default compatibility is measured against Mozilla Readability commit
[`ab4027a`](https://github.com/mozilla/readability/commit/ab4027a8b37669745016869a37a504727992b2ba).
The official `Readability.js` and `Readability-readerable.js` files are packaged
in the optional `SwiftReadabilityJavaScriptReference` product.

Tests pin both files by SHA-256. An oracle edit therefore fails independently
of behavioral fixture results and requires an explicit digest and upstream-
revision review. The production `SwiftReadability` product does not contain or
depend on these JavaScript resources.

## Semantic result contract

The direct differential runs each original input through native Swift and the
pinned Mozilla JavaScript, then compares:

- parse success, `nil`, and throw outcomes;
- the readerability heuristic;
- nullable title, byline, direction, language, excerpt, site name, and
  publication time;
- exact extracted DOM text without newline normalization;
- JavaScript-compatible UTF-16 text length;
- HTML namespace, local name, child ordering, and text-node placement;
- meaningful attribute presence and values, including resolved URLs; and
- deliberately returned custom-serializer markers.

Normal article HTML is compared as a browser-parsed tree. Attribute order,
quote style, equivalent entity spelling, and void-element syntax are not
treated as extraction differences. Boolean attributes are represented by
presence, while meaningful enumerated states such as `hidden="until-found"`
remain distinct.

Both runners remove actual DOM Comment nodes before readerability, metadata, and
extraction work. Comment-like text inside `script`, `style`, and JSON-LD remains
untouched. This matches Mozilla's fixture policy and prevents framework
separator comments from fragmenting otherwise continuous prose.

Option cases cover representative non-default candidate and threshold values,
class policy, metadata, custom video allowlists, serializer mutation, and
element-limit errors. Cross-runtime regular-expression cases use only the
reviewed subset shared by Foundation and ECMAScript; they do not claim that the
two regex dialects are interchangeable.

## Evidence layers

The repository uses several complementary gates:

| Evidence | What it establishes |
| --- | --- |
| Native expected-output fixtures | Swift output satisfies checked article and metadata expectations, including separately profiled extensions |
| Focused native regressions | Named API, state, malformed-input, URL, metadata, serialization, and adversarial cases satisfy their assertions |
| JavaScript reference tests | The copied oracle, fixture loader, comparator, normalization, option validation, and injected-failure paths behave as asserted |
| Direct semantic differential | No detected native-versus-Mozilla output difference on the inputs and options inside its contract |
| Warnings-as-errors release builds | The library and standalone contract target compile cleanly in the checked release configuration |
| API compatibility diagnosis | Swift Package Manager detects no public API break against the selected 0.3.2 baseline |
| Performance smoke | Repeated extraction is nonempty and deterministic and the benchmark harness fails on gross errors |

The fixture loaders fail closed. Missing or malformed manifests, unknown
fixtures or profiles, invalid regular expressions, missing sources, and zero
selected fixtures are errors rather than silent passes. The direct differential
also treats malformed option descriptors, malformed result batches, injected
mismatches, and worker failures as failures.

## Comparison with the inherited Swift port

The final pre-rewrite manifest built on the inherited Lake of Fire port listed
**27 known Swift fixture failures**. The current manifest lists none, and the
current project additionally runs the executable Mozilla differential, option
cases, fail-closed fixture infrastructure, and focused malformed/adversarial
regressions.

That is objective evidence of substantially broader verification. It is not a
universal head-to-head quality ranking: the harness and semantic contract were
also strengthened, and neither implementation has been scored on a separate,
blinded, human-labeled web corpus.

## What the results prove

On the frozen default corpus, native Swift is level with the pinned Mozilla
revision under the documented semantic contract. The comparator found no
observable difference inside that surface across 136/136 inputs. Focused tests
also protect intended quality-driven behavior for named edge cases and opt-in
extensions.

The evidence is stronger than byte-for-byte HTML comparison because it checks
reader-visible text, metadata, DOM meaning, and resolved attributes without
failing on irrelevant serializer spelling.

## What the results do not prove

- They do not cover every webpage, publisher redesign, language, malformed
  document, or browser behavior.
- They compare one pinned Mozilla revision, not every earlier or later release.
- The corpus is a regression set, not a random or blinded sample of the web.
- Six inputs were added by this project, and focused cases were often written
  while developing the behavior they protect.
- The default differential does not judge opt-in extensions as Mozilla output,
  arbitrary cross-dialect regular expressions, or generic XML namespace
  behavior.
- Passing extraction tests does not make returned HTML safe to render and does
  not prove the absence of security vulnerabilities.
- The performance smoke does not establish that SwiftReadability is faster or
  slower than Mozilla or the inherited Swift port.

A defensible superiority claim would require an independent, human-labeled
evaluation corpus with explicit measures for retained article content, leaked
page chrome, metadata accuracy, and meaningful media preservation.

## Reproduce the semantic benchmark

Run the native, JavaScript, and direct differential suites together:

```sh
mise run test:parity
```

Or run the layers directly:

```sh
swift test
npm --prefix Tests/JavaScript ci
npm --prefix Tests/JavaScript test
npm --prefix Tests/JavaScript run test:differential
```

The locked JavaScript graph requires Node 22.22.2 or later within the Node 22
release line. Node is needed only for development comparison; applications
using the native product do not need it.

Filter native and expected-output fixture runners with an exact comma-separated
selection or regular expression:

```sh
SWIFT_READABILITY_FIXTURES=nytimes-3,qq mise run test:parity
SWIFT_READABILITY_FIXTURE_REGEX='^(mathjax|videos-2)$' mise run test:parity
```

Filter the direct differential by fixture-name substring:

```sh
SWIFT_READABILITY_DIFFERENTIAL_FILTER=guardian-1 \
  npm --prefix Tests/JavaScript run test:differential
```

Filtered runs are debugging aids. Only the complete unfiltered gates are
release evidence.

## Run the performance harness

Run all fixtures in release mode:

```sh
swift run -c release SwiftReadabilityBench --iterations 5 --warmup 1
```

Inspect a single fixture with internal stage timings, or print only an aggregate
summary:

```sh
swift run -c release SwiftReadabilityBench \
  --filter guardian-1 --iterations 10 --warmup 2 --timings

swift run -c release SwiftReadabilityBench \
  --iterations 5 --warmup 1 --summary-only
```

Use `--fixtures PATH` and, when necessary, `--manifest PATH` for another
Mozilla-format corpus. Other flags are `--xml` and `--help`.

The harness rejects unknown or malformed arguments, missing or empty corpora,
missing sources, parse failures, empty output, invalid UTF-16 lengths,
nondeterministic repeated output, invalid timing samples, and zero-duration
measurements. Every warmup and measured iteration creates a fresh reader.

Output includes per-fixture and aggregate p50, p95, and mean latency, input and
article throughput, and a deterministic result checksum. `--timings` adds
distributions for internal pipeline stages.

CI runs a one-fixture release-mode smoke to ensure the harness remains
deterministic and fail-closed. Because the project stores no baseline or
threshold, benchmark timings are observations for a particular machine and
checkout, not a performance-regression guarantee.
