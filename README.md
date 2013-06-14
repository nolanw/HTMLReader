# HTMLReader

A [WHATWG-compliant HTML parser][whatwg-spec] in Objective-C.

[whatwg-spec]: http://whatwg.org/html

## Why

I needed to scrape HTML like a browser. I couldn't find a good choice for iOS.

## The Alternatives

libxml2 ships with iOS. It parses a variant of HTML 4 and does not handle broken markup like a browser.

Other Objective-C libraries I came across (e.g. hpple) use libxml2 and inherit its shortcomings.

WebKit ships with iOS, but its HTML parsing abilities are considered private API. I consider a round-trip through UIWebView inappropriate for parsing HTML. And I didn't make it very far into building my own copy of WebCore.

## Testing

HTMLReader directly uses [html5lib's tests][html5lib-tests], by translating them into OCUnit tests and running them through Xcode.

To regenerate the OCUnit tests from the html5lib tests:

```
$ git submodule update --init
$ rake gentests
```

Don't forget to add any newly-created `.m` files (i.e. from tests new to html5lib) to the `HTMLReaderTests` target in Xcode.

Actually running the tests is as usual in Xcode: from the "Product" menu, choose "Test".

[html5lib-tests]: https://github.com/html5lib/html5lib-tests
