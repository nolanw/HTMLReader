# HTMLReader TODO

- Understand some tests.
  - test3
    - test0228, test0231, test0232, test0234, test0235, test0237, test0240, test0241, test0243, test0244, test0246, test0258, and test0656 all claim that the DOCTYPE token should have an empty name, but by my reading it should have a nil name.
- Fix lossy conversion from html5lib tests to SenTestCase tests.
  - For example, check domjs test3. The leading U+FEFF and middle U+FEFF both disappear. (With NSJSONSerialization the middle one remains, but the leading one still disappears.)
- Deal with surrogate pairs.
  - I suspect splitting them up messes something up.
