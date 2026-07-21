/* eslint-env node */

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { assertDOMEqual } = require("../support/dom-comparator");

test("fixture comparison ignores inert comments and their text-node splits", () => {
  assert.doesNotThrow(() => {
    assertDOMEqual(
      "<div><!-- retained --><p>Text</p></div>",
      "<div><p>Text</p></div>"
    );
  });
  assert.doesNotThrow(() => {
    assertDOMEqual(
      "<p>Jo<!-- first --><!-- second --> contributed.</p>",
      "<p>Jo contributed.</p>"
    );
  });
  assert.throws(() => {
    assertDOMEqual(
      "<p>Jo<!-- separator -->contributed.</p>",
      "<p>Jo contributed.</p>"
    );
  });
});
