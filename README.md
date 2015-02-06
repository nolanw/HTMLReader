# HTMLReader

A [WHATWG-compliant HTML parser][whatwg-spec] with [CSS selectors][selectors-level-3] in Objective-C and Foundation. It parses HTML just like a browser.

[selectors-level-3]: http://www.w3.org/TR/css3-selectors/
[whatwg-spec]: http://whatwg.org/html

## Usage

```objc
#import <HTMLReader/HTMLReader.h>

// Parse a string and find an element.
NSString *markup = @"<p><b>Ahoy there sailor!</b></p>";
HTMLDocument *document = [HTMLDocument documentWithString:markup];
NSLog(@"%@", [document firstNodeMatchingSelector:@"b"].textContent);
// => Ahoy there sailor!

// Wrap one element in another.
HTMLElement *b = [document firstNodeMatchingSelector:@"b"];
NSMutableOrderedSet *children = [b.parentNode mutableChildren];
HTMLElement *wrapper = [[HTMLElement alloc] initWithTagName:@"div"
                                                 attributes:@{@"class": @"special"}];
[children insertObject:wrapper atIndex:[children indexOfObject:b]];
b.parentNode = wrapper;
NSLog(@"%@", [document.rootElement serializedFragment]);
// => <html><head></head><body><p><div class="special"> \
      <b>Ahoy there sailor!</b></div></p></body></html>

// Load a web page.
NSURL *URL = [NSURL URLWithString:@"https://github.com/nolanw/HTMLReader"];
NSURLSession *session = [NSURLSession sharedSession];
[[session dataTaskWithURL:URL completionHandler:
  ^(NSData *data, NSURLResponse *response, NSError *error) {
    NSString *contentType = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
        contentType = headers[@"Content-Type"];
    }
    HTMLDocument *home = [HTMLDocument documentWithData:data
                                      contentTypeHeader:contentType];
    HTMLElement *div = [home firstNodeMatchingSelector:@".repository-description"];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSLog(@"%@", [div.textContent stringByTrimmingCharactersInSet:whitespace]);
    // => A WHATWG-compliant HTML parser in Objective-C.
}] resume];
```

## Installation

You have choices:

* Copy the files in the [Code](Code) folder into your project.
* Add the following line to your [Cartfile][Carthage]:
  
  `github "nolanw/HTMLReader"`
* Add the following line to your [Podfile][CocoaPods]:
   
   `pod "HTMLReader"`
* Clone this repository (perhaps add it as a submodule), add `HTMLReader.xcodeproj` to your project/workspace, and add `libHTMLReader.a` to your iOS target or `HTMLReader.framework` to your OS X target.

HTMLReader has no dependencies other than Foundation.

[Carthage]: https://github.com/Carthage/Carthage#readme
[CocoaPods]: http://docs.cocoapods.org/podfile.html#pod

## Why HTMLReader?

I needed to scrape HTML like a browser. I couldn't find a good choice for iOS.

## The Alternatives

[libxml2][] ships with iOS. It parses a variant of HTML 4 and does not handle broken markup like a modern browser.

Other Objective-C libraries I came across (e.g. [hpple][] and [Ono][]) use libxml2 and inherit its shortcomings.

There are C libraries such as [Gumbo][] or [Hubbub][], but you need to shuffle data to and from Objective-C.

[WebKit][] ships with iOS, but its HTML parsing abilities are considered private API. I consider a round-trip through UIWebView inappropriate for parsing HTML. And I didn't make it very far into building my own copy of WebCore.

[Google Toolbox for Mac][GTMNSString+HTML] will escape and unescape strings for HTML (e.g. `&amp;` ⇔ `&`) but, again, not like a modern browser. For example, GTM will not unescape `&#65` (note the missing semicolon).

[CFStringTransform][kCFStringTransformToXMLHex] does numeric entities via (the reversible) `kCFStringTransformToXMLHex`, but that rules out named entities.

[GTMNSString+HTML]: https://code.google.com/p/google-toolbox-for-mac/source/browse/trunk/Foundation/GTMNSString%2BHTML.h
[Gumbo]: https://github.com/google/gumbo-parser
[hpple]: https://github.com/topfunky/hpple
[Hubbub]: http://www.netsurf-browser.org/projects/hubbub/
[kCFStringTransformToXMLHex]: https://developer.apple.com/library/mac/documentation/corefoundation/Reference/CFMutableStringRef/Reference/reference.html#//apple_ref/doc/uid/20001504-CH2g-DontLinkElementID_46
[libxml2]: http://www.xmlsoft.org/
[Ono]: https://github.com/mattt/Ono
[WebKit]: https://www.webkit.org/building/checkout.html

## Does it work?

HTMLReader continually runs [html5lib][html5lib-tests]'s tokenization and tree construction tests, ignoring the tests for `<template>` (which HTMLReader does not implement).

HTMLReader is continually tested on iOS versions 7.0, 7.1, and 8.1, as well as OS X versions 10.9 and 10.10. It should work on down to iOS 5 and OS X 10.7 but no automated testing is done.

Given all that:  [![Build Status](https://travis-ci.org/nolanw/HTMLReader.png?branch=master)](https://travis-ci.org/nolanw/HTMLReader)

HTMLReader is used by at least [one shipping app][Awful].

[Awful]: https://github.com/Awful/Awful.app
[html5lib-tests]: https://github.com/html5lib/html5lib-tests

## How fast is it?

I'm not sure.

Included in the project is a utility called [Benchmarker][]. It knows how to run three tests:

* Parsing a large HTML file. In this case, the 7MB single-page HTML specification.
* Escaping and unescaping entities in the large HTML file.
* Running a bunch of CSS selectors. Basically copied from [a WebKit performance test][WebKit QuerySelector.html].

Changes to HTMLReader should not cause these benchmarks to run slower. Ideally changes make them run faster!

[Benchmarker]: Utilities/Benchmarker.m
[WebKit QuerySelector.html]: https://trac.webkit.org/browser/trunk/PerformanceTests/CSS/QuerySelector.html

## Bugs and Feature Requests

Bugs can be reported, and features can be requested, using the [issue tracker][Issues]. Or get in touch directly if you'd prefer.

[Issues]: https://github.com/nolanw/HTMLReader/issues

## License

HTMLReader is in the public domain.

## Acknowledgements

HTMLReader is developed by [Nolan Waite](https://github.com/nolanw).

Thanks to [Chris Williams](https://github.com/ultramiraculous/) for contributing the implementation of CSS selectors.
