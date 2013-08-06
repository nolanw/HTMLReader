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

HTMLReader uses [html5lib's tests][html5lib-tests] for tokenization and tree construction. It adds some of its own tests for CSS selectors and sundries.

[html5lib-tests]: https://github.com/html5lib/html5lib-tests
