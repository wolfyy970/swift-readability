/* eslint-env node */

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { JSDOM } = require("jsdom");
const { removeDOMComments } = require("../support/remove-dom-comments");

test("removes only actual DOM Comment nodes", () => {
  const source = `<!doctype html><html><body>
    <!-- outer -->
    <article><p>Jo<!-- split --> contributed.</p></article>
    <template><!-- template --><p>Template text</p></template>
    <script>const marker = "<!-- script data -->";</script>
    <style>.marker::before { content: "<!-- style data -->"; }</style>
    <script type="application/ld+json">{"note":"<!-- JSON-LD data -->"}</script>
  </body></html>`;
  const dom = new JSDOM(source);

  try {
    assert.equal(removeDOMComments(dom.window.document), 3);
    assert.equal(dom.window.document.querySelector("article p").textContent, "Jo contributed.");
    assert.equal(
      dom.window.document.querySelector("template").content.querySelector("p").textContent,
      "Template text"
    );
    assert.ok(dom.window.document.querySelector("script:not([type])").textContent.includes("<!-- script data -->"));
    assert.ok(dom.window.document.querySelector("style").textContent.includes("<!-- style data -->"));
    assert.ok(dom.window.document.querySelector("script[type='application/ld+json']").textContent.includes("<!-- JSON-LD data -->"));
  } finally {
    dom.window.close();
  }
});
