# HTMLReader

A [WHATWG-compliant HTML parser][whatwg-spec] with [CSS selectors][selectors-level-3] in Objective-C and Foundation.

[selectors-level-3]: http://www.w3.org/TR/css3-selectors/
[whatwg-spec]: http://whatwg.org/html

## Usage

```objc
#import <HTMLReader/HTMLReader.h>

NSString *html = @"<p><b>Ahoy there sailor!</b></p>";
HTMLDocument *document = [HTMLDocument documentWithString:html];
NSLog(@"%@", [document firstNodeMatchingSelector:@"b"].innerHTML); // => Ahoy there sailor!
```

## Installation

You have choices:

* Copy the files in the [Code](Code) folder into your project.
* Add the following line to your [Podfile][CocoaPods]:
   
   `pod "HTMLReader", :git => "https://github.com/nolanw/HTMLReader"`
* Clone this repository (perhaps add it as a submodule), add `HTMLReader.xcodeproj` to your project/workspace, and add `libHTMLReader.a` to your iOS target or `HTMLReader.framework` to your OS X target.

HTMLReader has no dependencies other than Foundation. It is set to deploy on iOS 5 and OS X 10.7, though it's only tested regularly on iOS 7 and OS X 10.9.

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

## Acknowledgements

HTMLReader is developed by [Nolan Waite](https://github.com/nolanw).

Thanks to [Chris Williams](https://github.com/ultramiraculous/) for contributing the implementation of CSS selectors.
