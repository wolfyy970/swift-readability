/* eslint-env node */

const assert = require("node:assert/strict");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");

const harness = path.resolve(
  __dirname,
  "../differential/readability-differential.js"
);
const optionCases = require("../differential/readability-option-cases");

function runValidation(cases) {
  return spawnSync(process.execPath, [harness, "--validate-option-cases"], {
    encoding: "utf8",
    input: JSON.stringify(cases),
    maxBuffer: 4 * 1024 * 1024,
  });
}

function validCase() {
  return {
    name: "valid-case",
    url: "https://example.com/story",
    html: "<article><p>Valid option case.</p></article>",
    options: { charThreshold: 1 },
    expect: {
      parsed: true,
      textContentIncludes: ["Valid option case"],
      differsWithout: "charThreshold",
    },
  };
}

test("option descriptor validation accepts configured and default cases", () => {
  const configured = validCase();
  configured.options.allowedVideoRegex = { pattern: "//media\\.example/", flags: "im" };
  configured.expect.contentSelectors = ["article > p"];
  configured.expect.differsWithout = "allowedVideoRegex";
  const defaultCase = {
    name: "valid-default-case",
    url: "https://example.com/empty",
    html: "",
    options: {},
    expect: { parsed: false, matchesDefault: true },
  };

  const result = runValidation([configured, defaultCase]);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "ok");
});

test("checked-in differential option cases satisfy the strict descriptor schema", () => {
  const result = runValidation(optionCases);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "ok");
});

test("option descriptor validation rejects malformed intent and field types", async t => {
  const malformed = [
    ["array expectation", testCase => { testCase.expect = []; }, /Expectations .* plain object/],
    ["string selector list", testCase => {
      testCase.expect.contentSelectors = "article";
    }, /contentSelectors .* must be an array/],
    ["empty selector list", testCase => {
      testCase.expect.contentSelectors = [];
    }, /contentSelectors .* must not be empty/],
    ["invalid selector", testCase => {
      testCase.expect.contentSelectors = ["["];
    }, /contentSelectors .* invalid selector/],
    ["removed raw-content marker", testCase => {
      testCase.expect.contentIncludes = ["marker"];
    }, /unknown key contentIncludes/],
    ["removed error message", testCase => {
      testCase.expect.errorMessage = "implementation wording";
    }, /unknown key errorMessage/],
    ["exact content without serializer", testCase => {
      testCase.expect.content = "SERIALIZER_MARKER";
    }, /Exact content expectation .* requires the custom serializer/],
    ["truthy-string relationship", testCase => {
      delete testCase.expect.differsWithout;
      testCase.expect.matchesDefault = "true";
    }, /matchesDefault .* must be true/],
    ["unsafe numeric option", testCase => { testCase.options.charThreshold = 1.5; }, /charThreshold .* safe integer/],
    ["string boolean option", testCase => {
      testCase.options.keepClasses = "true";
    }, /keepClasses .* must be a boolean/],
    ["string boolean result", testCase => { testCase.expect.parsed = "true"; }, /parsed .* must be a boolean/],
    ["non-string preserved class", testCase => {
      testCase.options.classesToPreserve = ["keep", 1];
    }, /classesToPreserve .* array of strings/],
    ["invalid regular expression", testCase => {
      testCase.options.allowedVideoRegex = { pattern: "[", flags: "" };
      testCase.expect.differsWithout = "allowedVideoRegex";
    }, /Regex .* is invalid/],
    ["array regular-expression descriptor", testCase => {
      testCase.options.allowedVideoRegex = [];
      testCase.expect.differsWithout = "allowedVideoRegex";
    }, /Regex .* plain object/],
    ["missing relationship", testCase => {
      delete testCase.expect.differsWithout;
    }, /exactly one behavior relationship/],
    ["multiple relationships", testCase => {
      testCase.expect.matchesDefault = true;
    }, /exactly one behavior relationship/],
    ["array options", testCase => { testCase.options = []; }, /Options .* plain object/],
  ];

  for (const [name, mutate, message] of malformed) {
    await t.test(name, () => {
      const testCase = validCase();
      mutate(testCase);
      const result = runValidation([testCase]);
      assert.notEqual(result.status, 0, "Malformed descriptor unexpectedly passed");
      assert.match(result.stderr, message);
    });
  }
});
