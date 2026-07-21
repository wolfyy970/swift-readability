/* eslint-env node */

const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
  canonicalDOMTokens,
} = require("../differential/semantic-content");

test("semantic content ignores HTML serializer spelling", () => {
  const first = '<input disabled class="lead" title="one &amp; two"><br>';
  const second = "<input title='one & two' disabled='disabled' class='lead'/><br />";

  assert.deepEqual(canonicalDOMTokens(first), canonicalDOMTokens(second));
});

test("semantic content preserves visible text-node placement", () => {
  assert.notDeepEqual(
    canonicalDOMTokens("<p>a <b>b</b><!--note--></p>"),
    canonicalDOMTokens("<p>a<b> b</b><!--note--></p>")
  );
});

test("semantic content ignores inert comments and comment-split text nodes", () => {
  assert.deepEqual(
    canonicalDOMTokens("<p>a<!--first-->b</p>"),
    canonicalDOMTokens("<p>ab</p>")
  );
});

test("semantic content preserves namespaces and exact attribute values", () => {
  const tokens = canonicalDOMTokens(
    '<svg viewBox="0 0 10 10"><title>icon</title></svg>'
  );

  assert.equal(tokens[0][1], "http://www.w3.org/2000/svg");
  assert.notDeepEqual(
    tokens,
    canonicalDOMTokens('<svg viewBox="0 0 20 20"><title>icon</title></svg>')
  );
});

test("semantic content compares template text, media, and URLs", () => {
  const templateTokens = (text, imageURL, linkURL) => canonicalDOMTokens(
    `<div><template><p>${text}</p><img src="${imageURL}">` +
      `<a href="${linkURL}">Source</a></template></div>`
  );
  const baseline = templateTokens(
    "Preserved fallback text",
    "https://example.com/diagram-a.png",
    "https://example.com/source-a"
  );

  assert.notDeepEqual(
    baseline,
    templateTokens(
      "Different fallback text",
      "https://example.com/diagram-a.png",
      "https://example.com/source-a"
    )
  );
  assert.notDeepEqual(
    baseline,
    templateTokens(
      "Preserved fallback text",
      "https://example.com/diagram-b.png",
      "https://example.com/source-a"
    )
  );
  assert.notDeepEqual(
    baseline,
    templateTokens(
      "Preserved fallback text",
      "https://example.com/diagram-a.png",
      "https://example.com/source-b"
    )
  );
});

test("semantic content models Boolean attributes by presence", () => {
  assert.deepEqual(
    canonicalDOMTokens('<input disabled="false">'),
    canonicalDOMTokens("<input disabled>")
  );
  assert.notDeepEqual(
    canonicalDOMTokens("<input disabled>"),
    canonicalDOMTokens("<input>")
  );
  assert.deepEqual(
    canonicalDOMTokens('<video playsinline="implementation-spelling"></video>'),
    canonicalDOMTokens("<video playsinline></video>")
  );
  assert.deepEqual(
    canonicalDOMTokens('<video disablepictureinpicture="false"></video>'),
    canonicalDOMTokens("<video disablepictureinpicture></video>")
  );
  assert.notDeepEqual(
    canonicalDOMTokens('<div enabled="one"></div>'),
    canonicalDOMTokens('<div enabled="two"></div>')
  );
  assert.notDeepEqual(
    canonicalDOMTokens('<div hidden="until-found"></div>'),
    canonicalDOMTokens("<div hidden></div>")
  );
});
