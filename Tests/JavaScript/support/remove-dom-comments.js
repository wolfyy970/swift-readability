/* eslint-env node */

/**
 * Remove inert DOM Comment nodes without rewriting source text.
 *
 * Script, style, and JSON-LD bodies are text nodes, so comment-looking data in
 * those elements remains untouched. Template contents live in a separate
 * DocumentFragment and need to be traversed explicitly.
 */
function removeDOMComments(root) {
  let removed = 0;
  const stack = [root];

  while (stack.length > 0) {
    const node = stack.pop();
    if (node.nodeType === 8) {
      node.parentNode?.removeChild(node);
      removed += 1;
      continue;
    }

    const children = Array.from(node.childNodes || []);
    if (node.content?.nodeType === 11) {
      children.push(node.content);
    }
    for (let index = children.length - 1; index >= 0; index -= 1) {
      stack.push(children[index]);
    }
  }

  return removed;
}

module.exports = { removeDOMComments };
