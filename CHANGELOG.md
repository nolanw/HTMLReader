# Change Log

## [Unreleased][]

* Add tvos deployment target to podspec.

## [0.9.2][] – 2015-10-25

* Make HTMLTextNode publicly accessible so that instances are usable when enumerating a node's descendants.
* Add `-[HTMLNode textComponents]` for convenient access to a node's direct text contents.

## [0.9.1][] – 2015-10-23

* Export public headers when building static library.
* Add watchos deployment target to podspec.

## [0.9][] – 2015-09-20

* Add selector groups (e.g. `p, span` to find all paragraphs and spans). Works in `:not()` too.

## [0.8.2][] – 2015-09-03

* Fix a crash when a document provides an unhelpful `<meta charset=>`.

## [0.8.1][] – 2015-07-29

* HTMLReader no longer crashes when the `Content-Type` header has the wrong string encoding. Instead, it will pretend that the `Content-Type` had said nothing at all.

## [0.8][] – 2015-06-27

* The public API now has nullability annotations.
* The public API now uses generics where available.
* Some default values have changed when initializing nodes via `init`, in order to conform to the (now explicit) nullability annotations:
	* `HTMLComment` defaults to a `data` of "" (the empty string). Previously its default `data` was `nil`.
	* `HTMLDocumentType` defaults to a `name` of "`html`". Previously its default `name` was `nil`.
	* `HTMLElement` defaults to a `tagName` of "" (the empty string). Previously its default `tagName` was `nil`.
* Nullability annotations for parameters are checked using NSParameterAssert. Some methods which previously returned `nil` when passed a `nil` parameter will now raise an assertion error. If you get assertion errors after upgrading where you previously did not get assertion errors, this may be why.
* `HTMLNode`'s `-nodesMatchingSelector:`, `-firstNodeMatchingSelector`, `-nodesMatchingParsedSelector:`, and `-firstNodeMatchingParsedSelector:` methods now always throw an `NSInvalidArgumentException` if the selector fails to parse. Previously they would raise an assertion, but otherwise fail in other (more poorly-defined) ways.
* Use angle bracket imports (`#import <HTMLReader/…>`) throughout public headers, like a proper framework.

## [0.7.1][] – 2015-04-03

* Selectors can now include escaped characters, allowing for e.g. matching elements like `<some-ns:some-tag>` using a selector like `some-ns\:some-tag`. Supported escapes are `\XXXXXX` for 1-6 hex digits `X`, and `\c` for any other character `c`.

## [0.7][] – 2015-03-16

* Rename `namespace` properties to `htmlNamespace` to support compilation as Objective-C++.

## [0.6.2][] – 2015-03-15

* Update build settings to allow `HTMLReader.framework` use in Swift on OS X.

## [0.6.1][] – 2015-02-06

* Remove private header `HTMLTextNode.h` from the built framework.

## [0.6][] – 2015-02-06

* A new document initializer, `-[HTMLDocument initWithData:contentTypeHeader:]`, detects the character encoding as a browser would. This is the ideal initializer for HTML documents fetched over the network, or any other time when the character encoding isn't previously known. Note that HTML does not blindly use the encoding specified by the HTTP `Content-Type` header, so this initializer is still superior to parsing the `Content-Type` yourself.


[Unreleased]: https://github.com/nolanw/HTMLReader/compare/v0.9.2...HEAD
[0.9.2]: https://github.com/nolanw/HTMLReader/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/nolanw/HTMLReader/compare/v0.9...v0.9.1
[0.9]: https://github.com/nolanw/HTMLReader/compare/v0.8.2...v0.9
[0.8.2]: https://github.com/nolanw/HTMLReader/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/nolanw/HTMLReader/compare/v0.8...v0.8.1
[0.8]: https://github.com/nolanw/HTMLReader/compare/v0.7.1...v0.8
[0.7.1]: https://github.com/nolanw/HTMLReader/compare/v0.7...v0.7.1
[0.7]: https://github.com/nolanw/HTMLReader/compare/v0.6.2...v0.7
[0.6.2]: https://github.com/nolanw/HTMLReader/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/nolanw/HTMLReader/compare/v0.6...v0.6.1
[0.6]: https://github.com/nolanw/HTMLReader/compare/v0.5.9...v0.6
