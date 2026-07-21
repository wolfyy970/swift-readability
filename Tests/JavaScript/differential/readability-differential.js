/* eslint-env node */

const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const { JSDOM, VirtualConsole } = require("jsdom");

const repositoryRoot = path.resolve(__dirname, "../../..");
const fixtureRoot = path.join(
  repositoryRoot,
  "Tests/SwiftReadabilityTests/Fixtures/test-pages"
);
const manifest = JSON.parse(
  fs.readFileSync(
    path.join(repositoryRoot, "Tests/SwiftReadabilityTests/Fixtures/readability-suite.json"),
    "utf8"
  )
);
const Readability = require(
  path.join(
    repositoryRoot,
    "Sources/SwiftReadabilityJavaScriptReference/Resources/Readability"
  )
);
const isProbablyReaderable = require(
  path.join(
    repositoryRoot,
    "Sources/SwiftReadabilityJavaScriptReference/Resources/Readability-readerable"
  )
);
const optionCases = require("./readability-option-cases");
const { canonicalDOMTokens } = require("./semantic-content");
const { removeDOMComments } = require("../support/remove-dom-comments");
const quietVirtualConsole = new VirtualConsole();
const workerFlag = "--compare-batch";
const optionValidationFlag = "--validate-option-cases";
const batchSize = 8;
const scalarFields = [
  "parsed",
  "threw",
  "readerable",
  "title",
  "byline",
  "direction",
  "language",
  "excerpt",
  "siteName",
  "publishedTime",
  "textContent",
  "length",
];

function fixtureNames() {
  const filter = process.env.SWIFT_READABILITY_DIFFERENTIAL_FILTER;
  const names = fs
    .readdirSync(fixtureRoot, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .filter(name => !filter || name.includes(filter))
    .sort();
  assert.ok(names.length > 0, "Differential corpus is empty");
  return names;
}

function javascriptResult(name) {
  // FixtureCorpus performs the same UTF-8 transport without trimming. The two
  // parsers must receive identical source text before their DOM work begins.
  const source = fs.readFileSync(path.join(fixtureRoot, name, "source.html"), "utf8");
  const dom = new JSDOM(source, {
    url: manifest.baseURL || "http://fakehost/test/page.html",
    virtualConsole: quietVirtualConsole,
  });
  try {
    removeDOMComments(dom.window.document);
    const readerable = isProbablyReaderable(dom.window.document);
    const result = new Readability(dom.window.document).parse();
    return {
      name,
      parsed: result !== null,
      threw: false,
      readerable,
      title: result?.title ?? null,
      byline: result?.byline ?? null,
      direction: result?.dir ?? null,
      language: result?.lang ?? null,
      excerpt: result?.excerpt ?? null,
      siteName: result?.siteName ?? null,
      publishedTime: result?.publishedTime ?? null,
      content: result?.content ?? null,
      textContent: result?.textContent ?? null,
      length: result?.length ?? null,
    };
  } finally {
    // JSDOM windows retain a complete browsing context until explicitly closed.
    // Closing each fixture is essential because the upstream corpus contains
    // several megabyte-scale pages and the differential gate runs all of them.
    dom.window.close();
  }
}

function javascriptOptionResult(testCase) {
  const dom = new JSDOM(testCase.html, {
    url: testCase.url,
    virtualConsole: quietVirtualConsole,
  });
  try {
    removeDOMComments(dom.window.document);
    const readerable = isProbablyReaderable(dom.window.document);
    const descriptor = testCase.options || {};
    const options = { ...descriptor };
    if (descriptor.allowedVideoRegex) {
      options.allowedVideoRegex = new RegExp(
        descriptor.allowedVideoRegex.pattern,
        descriptor.allowedVideoRegex.flags
      );
    }
    if (descriptor.serializer === "mutate-and-return-marker") {
      options.serializer = element => {
        element.textContent = "SERIALIZER_MUTATION";
        return "SERIALIZER_MARKER";
      };
    }

    try {
      const result = new Readability(dom.window.document, options).parse();
      return {
        name: testCase.name,
        parsed: result !== null,
        threw: false,
        readerable,
        title: result?.title ?? null,
        byline: result?.byline ?? null,
        direction: result?.dir ?? null,
        language: result?.lang ?? null,
        excerpt: result?.excerpt ?? null,
        siteName: result?.siteName ?? null,
        publishedTime: result?.publishedTime ?? null,
        content: result?.content ?? null,
        textContent: result?.textContent ?? null,
        length: result?.length ?? null,
      };
    } catch (error) {
      return {
        name: testCase.name,
        parsed: false,
        threw: true,
        readerable,
        title: null,
        byline: null,
        direction: null,
        language: null,
        excerpt: null,
        siteName: null,
        publishedTime: null,
        content: null,
        textContent: null,
        length: null,
      };
    }
  } finally {
    dom.window.close();
  }
}

function swiftResults() {
  const arguments = [
    "run", "--disable-sandbox", "-c", "release", "SwiftReadabilityContract",
    "--fixtures", fixtureRoot,
  ];
  if (process.env.SWIFT_READABILITY_DIFFERENTIAL_FILTER) {
    arguments.push("--filter", process.env.SWIFT_READABILITY_DIFFERENTIAL_FILTER);
  }
  const command = spawnSync(
    "swift",
    arguments,
    {
      cwd: repositoryRoot,
      encoding: "utf8",
      env: {
        ...process.env,
        CLANG_MODULE_CACHE_PATH:
          process.env.CLANG_MODULE_CACHE_PATH || path.join(os.tmpdir(), "swift-readability-differential-clang"),
        SWIFTPM_MODULECACHE_OVERRIDE:
          process.env.SWIFTPM_MODULECACHE_OVERRIDE || path.join(os.tmpdir(), "swift-readability-differential-spm"),
      },
      maxBuffer: 128 * 1024 * 1024,
    }
  );
  if (command.status !== 0) {
    throw new Error(`Native contract runner failed:\n${command.stderr}`);
  }
  return JSON.parse(command.stdout);
}

function swiftOptionResults() {
  const command = spawnSync(
    "swift",
    ["run", "--disable-sandbox", "-c", "release", "SwiftReadabilityContract", "--cases-stdin"],
    {
      cwd: repositoryRoot,
      encoding: "utf8",
      input: JSON.stringify(optionCases),
      env: {
        ...process.env,
        CLANG_MODULE_CACHE_PATH:
          process.env.CLANG_MODULE_CACHE_PATH || path.join(os.tmpdir(), "swift-readability-differential-clang"),
        SWIFTPM_MODULECACHE_OVERRIDE:
          process.env.SWIFTPM_MODULECACHE_OVERRIDE || path.join(os.tmpdir(), "swift-readability-differential-spm"),
      },
      maxBuffer: 16 * 1024 * 1024,
    }
  );
  if (command.status !== 0) {
    throw new Error(`Native option contract runner failed:\n${command.stderr}`);
  }
  return JSON.parse(command.stdout);
}

function compareCanonicalDOM(actualHTML, expectedHTML) {
  assert.deepEqual(
    canonicalDOMTokens(actualHTML),
    canonicalDOMTokens(expectedHTML),
    "content DOM differs"
  );
}

function semanticResult(result) {
  return {
    fields: Object.fromEntries(
      scalarFields.map(field => [field, result[field] ?? null])
    ),
    content: canonicalDOMTokens(result.content),
  };
}

function compareResults(name, actual, expected) {
  for (const field of scalarFields) {
    assert.deepEqual(actual[field] ?? null, expected[field] ?? null, `${field} differs`);
  }
  compareCanonicalDOM(actual.content, expected.content);
}

function compareFixture(name, actual) {
  // Keep the JSDOM-backed Mozilla result inside this function so references do
  // not escape the short-lived worker that owns this fixture batch.
  compareResults(name, actual, javascriptResult(name));
}

function assertOptionExpectation(testCase, result) {
  const expectation = testCase.expect || {};
  for (const field of ["parsed", "threw", "title", "content"]) {
    if (Object.hasOwn(expectation, field)) {
      assert.deepEqual(result[field], expectation[field], `${field} did not exercise the intended option`);
    }
  }
  for (const value of expectation.textContentIncludes || []) {
    assert.ok(result.textContent?.includes(value), `textContent is missing option marker ${value}`);
  }
  for (const value of expectation.textContentExcludes || []) {
    assert.ok(!result.textContent?.includes(value), `textContent unexpectedly contains option marker ${value}`);
  }
  if (expectation.contentSelectors || expectation.contentExcludedSelectors) {
    assert.equal(typeof result.content, "string", "DOM expectations require parsed content");
    const dom = new JSDOM(result.content, { virtualConsole: quietVirtualConsole });
    try {
      for (const selector of expectation.contentSelectors || []) {
        assert.ok(
          dom.window.document.body.querySelector(selector),
          `content DOM is missing selector ${selector}`
        );
      }
      for (const selector of expectation.contentExcludedSelectors || []) {
        assert.equal(
          dom.window.document.body.querySelector(selector),
          null,
          `content DOM unexpectedly matches selector ${selector}`
        );
      }
    } finally {
      dom.window.close();
    }
  }
  if (expectation.matchesDefault || expectation.differsFromDefault) {
    const defaultResult = javascriptOptionResult({ ...testCase, options: {} });
    if (expectation.matchesDefault) {
      compareResults(testCase.name, result, defaultResult);
    } else {
      assert.notDeepEqual(
        semanticResult(result),
        semanticResult(defaultResult),
        "option case does not differ semantically from Mozilla defaults"
      );
    }
  }
  if (expectation.matchesWithout || expectation.differsWithout) {
    const omittedKey = expectation.matchesWithout || expectation.differsWithout;
    const baselineOptions = { ...testCase.options };
    delete baselineOptions[omittedKey];
    const baselineResult = javascriptOptionResult({ ...testCase, options: baselineOptions });
    if (expectation.matchesWithout) {
      compareResults(testCase.name, result, baselineResult);
    } else {
      assert.notDeepEqual(
        semanticResult(result),
        semanticResult(baselineResult),
        `option ${omittedKey} does not affect its case semantically`
      );
    }
  }
}

function isPlainObject(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function validateOptionCases(cases) {
  const allowedCaseKeys = new Set(["name", "url", "html", "options", "expect"]);
  const allowedOptionKeys = new Set([
    "maxElemsToParse", "nbTopCandidates", "charThreshold", "classesToPreserve",
    "keepClasses", "disableJSONLD", "allowedVideoRegex", "linkDensityModifier",
    "serializer",
  ]);
  const allowedExpectationKeys = new Set([
    "parsed", "threw", "title", "content", "contentSelectors", "contentExcludedSelectors",
    "textContentIncludes", "textContentExcludes", "matchesDefault",
    "differsFromDefault", "matchesWithout", "differsWithout",
  ]);
  const integerOptionKeys = ["maxElemsToParse", "nbTopCandidates", "charThreshold"];
  const booleanOptionKeys = ["keepClasses", "disableJSONLD"];
  const booleanExpectationKeys = ["parsed", "threw"];
  const nullableStringExpectationKeys = ["title", "content"];
  const stringArrayExpectationKeys = [
    "contentSelectors", "contentExcludedSelectors", "textContentIncludes", "textContentExcludes",
  ];
  const relationshipKeys = [
    "matchesDefault", "differsFromDefault", "matchesWithout", "differsWithout",
  ];
  const names = new Set();

  function rejectUnknownKeys(object, allowed, context) {
    for (const key of Object.keys(object)) {
      assert.ok(allowed.has(key), `${context} contains unknown key ${key}`);
    }
  }

  function assertStringArray(value, context) {
    assert.ok(Array.isArray(value), `${context} must be an array`);
    assert.ok(value.length > 0, `${context} must not be empty`);
    assert.ok(value.every(item => typeof item === "string"), `${context} must contain only strings`);
  }

  assert.ok(Array.isArray(cases), "Option cases must be an array");
  assert.ok(cases.length > 0, "Option differential case set is empty");

  for (const [index, testCase] of cases.entries()) {
    assert.ok(isPlainObject(testCase), `Option case at index ${index} must be a plain object`);
    const caseLabel = typeof testCase.name === "string" && testCase.name.length > 0
      ? testCase.name
      : "<unnamed>";
    rejectUnknownKeys(testCase, allowedCaseKeys, `Option case ${caseLabel}`);
    assert.equal(typeof testCase.name, "string", "Option case name must be a string");
    assert.ok(testCase.name.trim().length > 0, "Option case name is empty");
    assert.ok(!names.has(testCase.name), `Duplicate option case name ${testCase.name}`);
    names.add(testCase.name);
    assert.equal(typeof testCase.html, "string", `Option case ${testCase.name} HTML must be a string`);
    assert.equal(typeof testCase.url, "string", `Option case ${testCase.name} URL must be a string`);
    assert.ok(testCase.url.trim().length > 0, `Option case ${testCase.name} URL is empty`);
    assert.doesNotThrow(() => new URL(testCase.url), `Option case ${testCase.name} URL is invalid`);
    assert.ok(isPlainObject(testCase.options), `Options for ${testCase.name} must be a plain object`);
    assert.ok(isPlainObject(testCase.expect), `Expectations for ${testCase.name} must be a plain object`);
    rejectUnknownKeys(testCase.options, allowedOptionKeys, `Options for ${testCase.name}`);
    rejectUnknownKeys(testCase.expect, allowedExpectationKeys, `Expectations for ${testCase.name}`);

    for (const key of integerOptionKeys) {
      if (Object.hasOwn(testCase.options, key)) {
        assert.ok(Number.isSafeInteger(testCase.options[key]), `Option ${key} for ${testCase.name} must be a safe integer`);
      }
    }
    if (Object.hasOwn(testCase.options, "linkDensityModifier")) {
      assert.ok(
        Number.isFinite(testCase.options.linkDensityModifier),
        `Option linkDensityModifier for ${testCase.name} must be a finite number`
      );
    }
    if (Object.hasOwn(testCase.options, "classesToPreserve")) {
      assert.ok(
        Array.isArray(testCase.options.classesToPreserve) &&
          testCase.options.classesToPreserve.every(value => typeof value === "string"),
        `Option classesToPreserve for ${testCase.name} must be an array of strings`
      );
    }
    for (const key of booleanOptionKeys) {
      if (Object.hasOwn(testCase.options, key)) {
        assert.equal(typeof testCase.options[key], "boolean", `Option ${key} for ${testCase.name} must be a boolean`);
      }
    }

    for (const key of booleanExpectationKeys) {
      if (Object.hasOwn(testCase.expect, key)) {
        assert.equal(typeof testCase.expect[key], "boolean", `Expectation ${key} for ${testCase.name} must be a boolean`);
      }
    }
    for (const key of nullableStringExpectationKeys) {
      if (Object.hasOwn(testCase.expect, key)) {
        assert.ok(
          testCase.expect[key] === null || typeof testCase.expect[key] === "string",
          `Expectation ${key} for ${testCase.name} must be a string or null`
        );
      }
    }
    for (const key of stringArrayExpectationKeys) {
      if (Object.hasOwn(testCase.expect, key)) {
        assertStringArray(testCase.expect[key], `Expectation ${key} for ${testCase.name}`);
      }
    }
    for (const key of ["contentSelectors", "contentExcludedSelectors"]) {
      for (const selector of testCase.expect[key] || []) {
        assert.doesNotThrow(
          () => JSDOM.fragment("").querySelector(selector),
          `Expectation ${key} for ${testCase.name} contains an invalid selector`
        );
      }
    }
    if (Object.hasOwn(testCase.expect, "content")) {
      assert.equal(
        testCase.options.serializer,
        "mutate-and-return-marker",
        `Exact content expectation for ${testCase.name} requires the custom serializer`
      );
    }
    for (const key of ["matchesDefault", "differsFromDefault"]) {
      if (Object.hasOwn(testCase.expect, key)) {
        assert.equal(testCase.expect[key], true, `Expectation ${key} for ${testCase.name} must be true`);
      }
    }
    for (const key of ["matchesWithout", "differsWithout"]) {
      if (Object.hasOwn(testCase.expect, key)) {
        assert.ok(
          typeof testCase.expect[key] === "string" && testCase.expect[key].length > 0,
          `Expectation ${key} for ${testCase.name} must be a nonempty string`
        );
      }
    }
    const relationships = relationshipKeys.filter(key => Object.hasOwn(testCase.expect, key));
    assert.equal(
      relationships.length,
      1,
      `Option case ${testCase.name} must define exactly one behavior relationship`
    );

    const hasConfiguredOptions = Object.keys(testCase.options).length > 0;
    assert.ok(
      hasConfiguredOptions || testCase.expect.matchesDefault === true,
      `Default-options case ${testCase.name} must explicitly match defaults`
    );
    const omittedKey = testCase.expect.matchesWithout || testCase.expect.differsWithout;
    if (omittedKey) {
      assert.ok(
        allowedOptionKeys.has(omittedKey) && Object.hasOwn(testCase.options, omittedKey),
        `Option case ${testCase.name} cannot omit unknown option ${omittedKey}`
      );
    }

    if (Object.hasOwn(testCase.options, "allowedVideoRegex")) {
      const descriptor = testCase.options.allowedVideoRegex;
      assert.ok(isPlainObject(descriptor), `Regex for ${testCase.name} must be a plain object`);
      rejectUnknownKeys(descriptor, new Set(["pattern", "flags"]), `Regex for ${testCase.name}`);
      assert.equal(typeof descriptor.pattern, "string", `Regex pattern for ${testCase.name} must be a string`);
      assert.equal(typeof descriptor.flags, "string", `Regex flags for ${testCase.name} must be a string`);
      assert.match(descriptor.flags, /^(?!.*(.).*\1)[ims]*$/, `Regex flags for ${testCase.name} are unsupported`);
      assert.doesNotThrow(
        () => new RegExp(descriptor.pattern, descriptor.flags),
        `Regex for ${testCase.name} is invalid`
      );
    }
    if (Object.hasOwn(testCase.options, "serializer")) {
      assert.equal(
        testCase.options.serializer,
        "mutate-and-return-marker",
        `Serializer strategy for ${testCase.name} is unsupported`
      );
    }
  }
}

function compareOptionCases() {
  validateOptionCases(optionCases);
  const swift = swiftOptionResults();
  assert.deepEqual(
    swift.map(result => result.name),
    optionCases.map(testCase => testCase.name),
    "Native option case order differs"
  );

  const failures = [];
  for (let index = 0; index < optionCases.length; index += 1) {
    const testCase = optionCases[index];
    try {
      const expected = javascriptOptionResult(testCase);
      assertOptionExpectation(testCase, expected);
      compareResults(testCase.name, swift[index], expected);
      if (Object.hasOwn(testCase.expect, "content")) {
        assert.deepEqual(
          swift[index].content,
          testCase.expect.content,
          "native custom serializer output differs"
        );
      }
    } catch (error) {
      failures.push(`${testCase.name}: ${error.message}`);
    }
  }
  return failures;
}

function validateOptionCasesWorker() {
  const payload = JSON.parse(fs.readFileSync(0, "utf8"));
  validateOptionCases(payload);
  process.stdout.write("ok");
}

function compareBatchWorker() {
  const payload = JSON.parse(fs.readFileSync(0, "utf8"));
  assert.ok(Array.isArray(payload.names), "Worker fixture names are missing");
  assert.ok(Array.isArray(payload.actual), "Worker native results are missing");
  assert.equal(payload.actual.length, payload.names.length, "Worker batch lengths differ");

  const failures = [];
  for (let index = 0; index < payload.names.length; index += 1) {
    try {
      compareFixture(payload.names[index], payload.actual[index]);
    } catch (error) {
      failures.push(`${payload.names[index]}: ${error.message}`);
    }
  }
  process.stdout.write(JSON.stringify(failures));
}

function compareBatch(names, actual) {
  // JSDOM VM realms are not always reclaimed promptly even after window.close().
  // A short-lived worker process gives every batch a hard memory lifetime while
  // retaining exact field and DOM comparisons against the Mozilla oracle.
  const command = spawnSync(
    process.execPath,
    ["--max-old-space-size=512", __filename, workerFlag],
    {
      cwd: repositoryRoot,
      encoding: "utf8",
      input: JSON.stringify({ names, actual }),
      maxBuffer: 128 * 1024 * 1024,
    }
  );
  if (command.error) {
    throw new Error(`Could not start Mozilla comparison worker: ${command.error.message}`);
  }
  if (command.status !== 0) {
    throw new Error(
      `Mozilla comparison worker failed for ${names.join(", ")} ` +
      `(status ${command.status}, signal ${command.signal ?? "none"}):\n${command.stderr}`
    );
  }
  return JSON.parse(command.stdout);
}

function compare() {
  const names = fixtureNames();
  const swift = swiftResults();
  assert.deepEqual(swift.map(result => result.name), names, "Native fixture order differs");

  const failures = [];

  for (let start = 0; start < names.length; start += batchSize) {
    const batchNames = names.slice(start, start + batchSize);
    if (process.env.SWIFT_READABILITY_DIFFERENTIAL_PROGRESS) {
      process.stderr.write(
        `[${start + 1}-${start + batchNames.length}/${names.length}] ${batchNames.join(", ")}\n`
      );
    }
    failures.push(...compareBatch(batchNames, swift.slice(start, start + batchSize)));
  }

  failures.push(...compareOptionCases());

  if (failures.length > 0) {
    throw new Error(`Swift/Mozilla differential failures (${failures.length}):\n${failures.join("\n")}`);
  }
  process.stdout.write(
    `Swift and Mozilla match across ${names.length} fixtures, ` +
    `${optionCases.length} option cases, and all observable fields.\n`
  );
}

if (process.argv.includes(workerFlag)) {
  compareBatchWorker();
} else if (process.argv.includes(optionValidationFlag)) {
  validateOptionCasesWorker();
} else {
  compare();
}
