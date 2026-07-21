/* eslint-env node */

const { JSDOM, VirtualConsole } = require("jsdom");

const quietVirtualConsole = new VirtualConsole();
const htmlNamespace = "http://www.w3.org/1999/xhtml";
const booleanAttributes = new Set([
  "allowfullscreen", "async", "autofocus", "autoplay", "checked", "controls",
  "default", "defer", "disabled", "disablepictureinpicture",
  "disableremoteplayback", "formnovalidate", "inert", "ismap", "itemscope",
  "loop", "multiple", "muted", "nomodule", "novalidate", "open", "playsinline",
  "readonly", "required", "reversed", "selected",
]);

function* nodeTokens(node) {
  if (node.nodeType === node.COMMENT_NODE) {
    return;
  }
  if (node.nodeType === node.TEXT_NODE) {
    yield ["text", node.data];
    return;
  }
  if (node.nodeType === node.ELEMENT_NODE) {
    const attributes = [...node.attributes]
      .map(attribute => {
        const isBoolean =
          node.namespaceURI === htmlNamespace &&
          attribute.namespaceURI === null &&
          booleanAttributes.has(attribute.localName.toLowerCase());
        const isHidden =
          node.namespaceURI === htmlNamespace &&
          attribute.namespaceURI === null &&
          attribute.localName.toLowerCase() === "hidden";
        let value = attribute.value;
        if (isHidden) {
          value = attribute.value.toLowerCase() === "until-found"
            ? "until-found"
            : "hidden";
        } else if (isBoolean) {
          value = true;
        }
        return [
          attribute.namespaceURI,
          attribute.localName,
          value,
        ];
      })
      .sort((left, right) => {
        const leftKey = JSON.stringify(left);
        const rightKey = JSON.stringify(right);
        return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
    });
    yield ["start", node.namespaceURI, node.localName, attributes];
    const children =
      node.namespaceURI === htmlNamespace &&
      node.localName === "template" &&
      node.content
        ? node.content.childNodes
        : node.childNodes;
    for (const child of children) yield* nodeTokens(child);
    yield ["end", node.namespaceURI, node.localName];
    return;
  }
  for (const child of node.childNodes || []) yield* nodeTokens(child);
}

function canonicalDOMTokens(html) {
  if (html === null || html === undefined) return null;

  const dom = new JSDOM(html, { virtualConsole: quietVirtualConsole });
  try {
    const result = [];
    for (const child of dom.window.document.body.childNodes) {
      for (const token of nodeTokens(child)) {
        const previous = result[result.length - 1];
        if (token[0] === "text" && previous?.[0] === "text") {
          previous[1] += token[1];
        } else {
          result.push(token);
        }
      }
    }
    return result;
  } finally {
    dom.window.close();
  }
}

module.exports = { canonicalDOMTokens };
