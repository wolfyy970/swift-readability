/* eslint-env node */

module.exports = [
  {
    name: "default-empty-document",
    url: "https://example.com/empty",
    html: "",
    options: {},
    expect: {
      parsed: false,
      threw: false,
      matchesDefault: true,
    },
  },
  {
    name: "default-script-only-document",
    url: "https://example.com/script-only",
    html: "<script>Only script content</script>",
    options: {},
    expect: {
      parsed: false,
      threw: false,
      matchesDefault: true,
    },
  },
  {
    name: "default-crlf-text-content",
    url: "https://example.com/crlf",
    html: `<article><p>${"A".repeat(600)}&#13;&#10;B</p></article>`,
    options: {},
    expect: {
      parsed: true,
      threw: false,
      textContentIncludes: ["\r\nB"],
      matchesDefault: true,
    },
  },
  {
    name: "falsy-character-threshold-default",
    url: "https://example.com/story",
    html: `<!doctype html><html><head><title>Falsy character threshold</title></head><body>
      <div class="comment"><p>RETRY_ONLY_COMMENT ${"Long comment branch text. ".repeat(12)}</p></div>
      <article><p>LOW_THRESHOLD_PRIMARY ${"Ordinary article prose, with punctuation. ".repeat(5)}</p></article>
    </body></html>`,
    options: { charThreshold: 0 },
    expect: {
      parsed: true,
      textContentIncludes: ["LOW_THRESHOLD_PRIMARY", "RETRY_ONLY_COMMENT"],
      matchesDefault: true,
    },
  },
  {
    name: "falsy-top-candidate-count-default",
    url: "https://example.com/story",
    html: `<!doctype html><html><head><title>Falsy top candidate count</title></head><body>
      <div class="article-content">
        <p>TOP_CANDIDATE_PRIMARY ${"Primary prose, with useful detail. ".repeat(8)}</p>
        <p>TOP_CANDIDATE_SECOND ${"More primary prose, with useful detail. ".repeat(8)}</p>
      </div>
      <section><span>ZERO_FALLBACK_ONLY</span></section>
    </body></html>`,
    options: { nbTopCandidates: 0, charThreshold: 1 },
    expect: {
      parsed: true,
      textContentIncludes: ["TOP_CANDIDATE_PRIMARY", "TOP_CANDIDATE_SECOND"],
      textContentExcludes: ["ZERO_FALLBACK_ONLY"],
      matchesWithout: "nbTopCandidates",
    },
  },
  {
    name: "low-character-threshold",
    url: "https://example.com/story",
    html: `<!doctype html><html><head><title>Low character threshold</title></head><body>
      <div class="comment"><p>RETRY_ONLY_COMMENT ${"Long comment branch text. ".repeat(12)}</p></div>
      <article><p>LOW_THRESHOLD_PRIMARY ${"Ordinary article prose, with punctuation. ".repeat(5)}</p></article>
    </body></html>`,
    options: { charThreshold: 1 },
    expect: {
      parsed: true,
      textContentIncludes: ["LOW_THRESHOLD_PRIMARY"],
      textContentExcludes: ["RETRY_ONLY_COMMENT"],
      differsWithout: "charThreshold",
    },
  },
  {
    name: "link-density-modifier",
    url: "https://example.com/story",
    html: `<!doctype html><html><head><title>Link density modifier</title></head><body><article>
      <p>${"Stable primary article prose, with punctuation and detail. ".repeat(8)}</p>
      <div id="linky"><blockquote><a href="/one">LINK_DENSITY_MARKER ${"linked reference text ".repeat(5)}</a> ${"Unlinked contextual article text. ".repeat(8)}</blockquote></div>
    </article></body></html>`,
    options: { charThreshold: 1, linkDensityModifier: 0.6 },
    expect: {
      parsed: true,
      textContentIncludes: ["LINK_DENSITY_MARKER"],
      differsWithout: "linkDensityModifier",
    },
  },
  {
    name: "selected-class-preservation",
    url: "https://example.com/story",
    html: `<!doctype html><html><body><article>
      <p class="keep drop">CLASS_PRESERVATION_MARKER ${"Article prose. ".repeat(12)}</p>
    </article></body></html>`,
    options: { charThreshold: 1, classesToPreserve: ["keep"] },
    expect: {
      parsed: true,
      contentSelectors: ["p[class=\"keep\"]"],
      differsWithout: "classesToPreserve",
    },
  },
  {
    name: "all-class-preservation",
    url: "https://example.com/story",
    html: `<!doctype html><html><body><article>
      <p class="keep drop">KEEP_ALL_CLASSES_MARKER ${"Article prose. ".repeat(12)}</p>
    </article></body></html>`,
    options: { charThreshold: 1, keepClasses: true },
    expect: {
      parsed: true,
      contentSelectors: ["p.keep.drop"],
      differsWithout: "keepClasses",
    },
  },
  {
    name: "disable-json-ld",
    url: "https://example.com/story",
    html: `<!doctype html><html><head>
      <title>Fallback Document Title With Enough Words</title>
      <meta property="og:title" content="Open Graph Option Title">
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","headline":"JSON LD Option Title"}</script>
    </head><body><article><p>${"Metadata option article prose. ".repeat(12)}</p></article></body></html>`,
    options: { charThreshold: 1, disableJSONLD: true },
    expect: {
      parsed: true,
      title: "Open Graph Option Title",
      differsWithout: "disableJSONLD",
    },
  },
  {
    name: "custom-video-allowlist",
    url: "https://example.com/story",
    html: `<!doctype html><html><body><article>
      <p>${"Article prose surrounding a custom embedded video. ".repeat(7)}</p>
      <iframe src="//media.example/embed/allowed"></iframe>
    </article></body></html>`,
    options: {
      charThreshold: 1,
      allowedVideoRegex: { pattern: "//media\\.example/", flags: "" },
    },
    expect: {
      parsed: true,
      contentSelectors: ["iframe[src=\"//media.example/embed/allowed\"]"],
      differsWithout: "allowedVideoRegex",
    },
  },
  {
    name: "serializer-mutation-order",
    url: "https://example.com/story",
    html: `<!doctype html><html><body><article>
      <p>SERIALIZER_ORIGINAL_TEXT ${"Article prose. ".repeat(10)}</p>
    </article></body></html>`,
    options: { charThreshold: 1, serializer: "mutate-and-return-marker" },
    expect: {
      parsed: true,
      content: "SERIALIZER_MARKER",
      textContentIncludes: ["SERIALIZER_ORIGINAL_TEXT"],
      textContentExcludes: ["SERIALIZER_MUTATION"],
      differsWithout: "serializer",
    },
  },
  {
    name: "element-count-cap",
    url: "https://example.com/story",
    html: "<!doctype html><html><head><title>Element cap</title></head><body><article><p>Cap test.</p></article></body></html>",
    options: { maxElemsToParse: 5 },
    expect: {
      parsed: false,
      threw: true,
      differsWithout: "maxElemsToParse",
    },
  },
];
