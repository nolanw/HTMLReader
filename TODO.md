# HTMLReader TODO

- Switch tokenizer away from giant switch.
- Fix lossy conversion from html5lib tests to SenTestCase tests.
  - For example, check tokenizer domjs test3. The leading U+FEFF and middle U+FEFF both disappear. (With NSJSONSerialization the middle one remains, but the leading one still disappears.)
- Clarify spec with tree construction test adoption02 test001.
  - By my reading of the spec, here's what should happen:
    1. Get to the `<style>` start tag token.
    2. Process it using the rules for the "in head" insertion mode.
    3. Follow the generic raw text parsing algorithm. The original insertion mode is set to "in head", and the insertion mode switches to "text".
    4. Since using the rules for another insertion mode changed the insertion mode, it is not reset as a result of "using the rules".
    5. Get to the `</style>` end tag token.
    6. The insertion mode switches to the original insertion mode, "in head".
    7. The `<address>` start tag token is also processed according to the rules of the "in head" insertion mode.
  - However, what's clearly intended is for the insertion mode to revert to "in body" once the `</style>` end tag token is encountered.
- Pass or fix remaining tokenizer tests.
  - domjs test12 fails (extra parse error).
  - unicode chars problematic test2 fails (parse error between character tokens).
- Implement `<template>`
  - Don't forget to add it to lists of special nodes.
  - Don't forget to add it to any states that mention it in conjunction with other nodes.
- Acknowledge self-closing tags (i.e. throw a parse error when unacknowledged).
- I cannot find reference to the "command" element in the spec.
  - Tree generation tests25 test007 seems to treat it as a self-closing tag. I think the spec now treats it as an ordinary element.
- Clarify spec with `<select>` context node in fragment parsing algorithm.
  - As part of the fragment parsing algorithm, we are to reset the insertion mode appropriately before consuming any tokens. In doing so, the stack has a single element, and so we set `node` to the `context` element. Then, if `node` is a `<select>`, we get to substep 3 "let ancestor be the node before ancestor in the stack of open elements". There is none, as `node` is not in the stack of open elements.
- Apparently the DOM specifies various restrictions on some nodes' children. Implement (and test?) those.
  - It's mentioned that a Document node cannot have multiple element children.
  - It's mentioned that a Document node cannot have Text node children.
- Implement scripting flag.
- Clarify spec regarding inserting a foreign element for `<math>` or `<svg>`.
  - For example, given `<table><math>`, foster parenting wouldn't occur because we "insert a foreign element" for the `<math>` token. Yet the description of "insert a foreign element" suggests that "the current node, when the insert a foreign element algorithm is invoked, is always itself a non-HTML element". This is patently untrue in this example; when processing the `<math>` token, the current node is the HTML element `<table>`.
  - This affects:
    - tests09 test006, test007, test008, test009, test010, test016
    - tests10 test005, test006, test007, test008, test009, test015, test040
