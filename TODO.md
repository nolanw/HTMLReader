# HTMLReader TODO

- Pass all tree construction tests.
  - adoption01
    - test012 requires namespace support.
- During tree construction, add a parse error anytime a start tag token is encountered with an unacknowledged self-closing flag. (This is parially complete.) (It would be awesome if we could do this by calling some kind of `-acknowledgeSelfClosingFlag` method.)
- Look into this `<template>` stuff.
- Pass all tokenizer tests.
  - domjs test12 fails (extra parse error).
  - unicode chars problematic test2 fails (parse error between character tokens).
- Fix lossy conversion from html5lib tests to SenTestCase tests.
  - For example, check domjs test3. The leading U+FEFF and middle U+FEFF both disappear. (With NSJSONSerialization the middle one remains, but the leading one still disappears.)
- Handle CDATA once parser is functional.
- Fragment parsing algorithm (tests and implementation).
- Deal with dispatcher, in foreign content, etc. stuff.
- Deal with SVG/MathML and namespaces.
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
