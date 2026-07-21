# Contributing to SwiftReadability

SwiftReadability treats reader-visible extraction quality as the governing
goal and the pinned Mozilla implementation as its strongest executable
baseline. Contributions should preserve the semantic corpus contract, explain
intentional quality-driven differences, keep publisher-specific policy behind
explicit extensions, and avoid weakening the fail-closed test infrastructure.
See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the production design and
[`BENCHMARK.md`](BENCHMARK.md) for the comparison contract and evidence model.

## Development setup

Install Swift 6.2 or later and Node 22.22.2 or later within the Node 22
release line, then resolve the locked native and reference-test dependencies:

```sh
swift package resolve
npm --prefix Tests/JavaScript ci
```

Do not update `Package.resolved`, `package-lock.json`, the copied Mozilla
sources, fixture snapshots, or their integrity digests incidentally. Changes to
those files require an explicit dependency, authority, or corpus update with
the corresponding provenance review.

## Change requirements

- Default-mode behavior changes need a focused regression and either evidence
  from the pinned Mozilla oracle or a plausible, common HTML pattern showing a
  reader-visible improvement. Intentional Mozilla differences must be stated in
  the test and changelog rather than disguised as parity. If a pinned corpus
  case is affected, add a narrowly named reviewed exception; do not weaken the
  shared semantic comparator.
- Extension changes need focused positive and false-positive coverage while
  the complete default differential remains green.
- Do not add browser-object, JSDOM, generic-XML, serializer-spelling, or error-
  wording emulation solely for implementation identity. A substantial
  compatibility shim needs a real-world fixture or similarly credible evidence
  that it preserves article content, metadata, URLs, or meaningful media.
- The direct differential treats ordinary HTML output semantically: metadata,
  extracted text, UTF-16 length, DOM nodes, namespaces, and meaningful
  attribute states are contractual. DOM comments are normalized away before
  extraction; HTML spelling and
  localized error prose are not; deliberate custom-serializer return values
  remain exact.
- Option cases that carry a custom regular expression must stay within the
  reviewed syntax and flags shared by Foundation and ECMAScript. The production
  Swift API intentionally retains Foundation `NSRegularExpression` semantics.
- Public API and observable output changes must be documented in the
  changelog. User-facing behavior or setup changes also require a README
  review.
- Code derived from another implementation must retain the applicable license,
  attribution, and provenance. Review `NOTICE`, `THIRD_PARTY_NOTICES.md`, and
  `docs/provenance-and-licensing.md` when relevant.
- Preserve the authorship boundaries in `AUTHORS.md`: ChatGPT 5.6 Sol authored
  the post-0.3.2 quality-first rewrite; Mozilla supplies the pinned original
  implementation; Lake of Fire supplies the original Swift port. Material AI
  authorship or assistance in future changes must be disclosed and reviewed by
  an accountable maintainer. Do not turn engineering attribution into a
  copyright, endorsement, or relicensing claim.
- Extraction is not sanitization. Changes must not describe normalized output
  as safe to render without a separate sanitizer and Content Security Policy.

## Required checks

Run the complete, unfiltered gates before requesting review:

```sh
swift test -c release -Xswiftc -warnings-as-errors
swift build -c release --target SwiftReadabilityContract -Xswiftc -warnings-as-errors
npm --prefix Tests/JavaScript ci
npm --prefix Tests/JavaScript test
npm --prefix Tests/JavaScript run test:differential
swift run -c release SwiftReadabilityBench --iterations 1 --warmup 0 --filter qq --summary-only
git diff --check
```

Filtered fixture runs are debugging aids, not release evidence. The Linux gate
uses the Swift 6.2 container to run both the release tests and the explicit
`SwiftReadabilityContract` release build above; it must be green alongside the
macOS gates.

## Release checklist

- Run every required check above from the release-candidate checkout without
  fixture filters.
- Confirm native Linux compatibility is green on Swift 6.2, including the
  explicit `SwiftReadabilityContract` build.
- Confirm `Package.resolved` and `package-lock.json` are intentional and update
  license notices and provenance for dependency or authority changes.
- Re-verify the pinned Mozilla commit, the final reported semantic match count,
  the 130-plus-6 fixture provenance split, and every documented intentional
  default difference.
- Confirm `AUTHORS.md`, `README.md`, `NOTICE`, and the provenance document agree
  on current rewrite authorship and inherited implementation lineage.
- Review every documentation claim against the current code. Update suite
  counts, installation versions, changelog dates, and comparison links where
  applicable.
- Confirm the public API and observable-output changes match the planned
  version number.
- Create the release tag only after all CI gates pass.
