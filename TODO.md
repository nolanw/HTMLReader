# HTMLReader TODO

- Generate html5lib-tests Tree Construction tests at runtime (like the tokenizer tests are done).
- Index/range info for parse errors, tokens. (Nodes?)
- Implement `<template>`
  - Don't forget to add it to lists of special nodes.
  - Don't forget to add it to any states that mention it in conjunction with other nodes.
- Acknowledge self-closing tags (i.e. throw a parse error when unacknowledged).
- Don't return 0 parse errors if parsing hasn't happened yet.
- Character encoding detection.
- Serialization.
- CSS selectors for finding nodes.
- Make fast.
- Make thoughtful API.
- Expose HTML entity parsing. (So I can "unescape" HTML entities in an NSString.)
