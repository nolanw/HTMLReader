# HTMLReader

A [WHATWG-compliant HTML parser][whatwg-spec] in Objective-C.

[whatwg-spec]: http://whatwg.org/html

## Usage

```objc
#import "HTMLReader.h"

NSString *html = @"<p><b>Ahoy there sailor!</b></p>";
HTMLDocument *document = [HTMLDocument documentWithString:html];
HTMLElementNode *body = document.rootNode.childNodes[1];
HTMLTextNode *text = [[body.childNodes[0] childNodes][0] childNodes][0];
NSLog(@"%@", text.data); // => Ahoy there sailor!
```

## Installation

You have choices:

1. Copy the files in the [Code](Code) folder into your project.
2. Add the following line to your [Podfile][CocoaPods]:
   
   `pod "HTMLReader", :git => "https://github.com/nolanw/HTMLReader"`
3. Check out this repository, add `HTMLReader.xcodeproj` to your project/workspace, and add the HTMLReader static library to your target.

[CocoaPods]: http://docs.cocoapods.org/podfile.html#pod

## Why

I needed to scrape HTML like a browser. I couldn't find a good choice for iOS.

## The Alternatives

[libxml2][] ships with iOS. It parses a variant of HTML 4 and does not handle broken markup like a browser.

Other Objective-C libraries I came across (e.g. [hpple][]) use libxml2 and inherit its shortcomings.

There are C libraries such as [Gumbo][] or [Hubbub][], but you need to shuffle data to and from Objective-C.

WebKit ships with iOS, but its HTML parsing abilities are considered private API. I consider a round-trip through UIWebView inappropriate for parsing HTML. And I didn't make it very far into building my own copy of WebCore.

[Gumbo]: https://github.com/google/gumbo-parser
[hpple]: https://github.com/topfunky/hpple
[Hubbub]: http://www.netsurf-browser.org/projects/hubbub/
[libxml2]: http://www.xmlsoft.org/

## Testing

HTMLReader uses [html5lib's tests][html5lib-tests] for tokenization and tree construction. It adds some of its own tests too.

[html5lib-tests]: https://github.com/html5lib/html5lib-tests

## License

HTMLReader is in the public domain.
