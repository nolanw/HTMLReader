# HTMLReader TODO

- Fix lossy conversion from html5lib tests to SenTestCase tests.
  - For example, check domjs test3. The leading U+FEFF and middle U+FEFF both disappear. (With NSJSONSerialization the middle one remains, but the leading one still disappears.)
