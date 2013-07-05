# HTMLReader TODO

- Pass all tree construction tests.
- During tree construction, add a parse error anytime a start tag token is encountered with an unacknowledged self-closing flag. (This is parially complete.) (It would be awesome if we could do this by calling some kind of `-acknowledgeSelfClosingFlag` method.)
- Look into this `<template>` stuff.
- Pass all tokenizer tests.
  - domjs test12 fails (extra parse error).
  - unicode chars problematic test2 fails (parse error between character tokens).
- Fix lossy conversion from html5lib tests to SenTestCase tests.
  - For example, check domjs test3. The leading U+FEFF and middle U+FEFF both disappear. (With NSJSONSerialization the middle one remains, but the leading one still disappears.)
- Handle CDATA once parser is functional.
- Fragment parsing algorithm (tests and implementation).
