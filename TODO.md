# HTMLReader TODO

- Implement MathML, SVG, namespace, and CDATA support.
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
- Pass tests relating to unimplemented features.
  - adoption01
    - test012 requires namespace support.
  - domjsUnsafe
    - test000, test001, test002, test043, test044, test045, test046, test047, test048 require namespace/SVG/CDATA support.
  - html5TestCom
    - test022 requires SVG support.
    - test023 requires MathML support.
  - pendingSpecChanges
    - test001, test002 require SVG support.
  - plainTextUnsafe
    - test010, test013, test014, test015, test016, test017, test020, test026, test027, test028, test029, test030, test031, test032 require MathML/SVG/CDATA support.
  - tables01
    - test016 requires SVG support.
  - template requires `<template>` support.
  - tests07
    - test023 requires fragment parsing support.
  - tests09 requires MathML support.
  - tests10 requires SVG support.
  - tests11 requires MathML/SVG support.
  - tests12 requires MathML support.
  - tests18
    - test019 requires SVG support.
  - tests19
    - test000, test018, test019, test031, test032, test033, test034, test035, test076, test082, test083, test084 require MathML/SVG support.
  - tests20
    - test022, test028, test029, test032, test033, test034, test035, test036, test037, test038 require SVG/MathML support.
  - tests21 requires SVG/MathML/CDATA support.
  - tests26
    - test010, test011, test012, test013 require SVG/MathML support.
  - webkit01
    - test038, test039, test040, test043, test044, test045 require SVG/MathML support.
- I cannot find reference to the "command" element in the spec.
  - Tree generation tests25 test007 seems to treat it as a self-closing tag. I think the spec now treats it as an ordinary element.
- Clarify spec with `<select>` context node in fragment parsing algorithm.
  - As part of the fragment parsing algorithm, we are to reset the insertion mode appropriately before consuming any tokens. In doing so, the stack has a single element, and so we set `node` to the `context` element. Then, if `node` is a `<select>`, we get to substep 3 "let ancestor be the node before ancestor in the stack of open elements". There is none, as `node` is not in the stack of open elements.
- Apparently the DOM specifies various restrictions on some nodes' children. Implement (and test?) those.
  - It's mentioned that a Document node cannot have multiple element children.
  - It's mentioned that a Document node cannot have Text node children.
- Implement scripting tag.
