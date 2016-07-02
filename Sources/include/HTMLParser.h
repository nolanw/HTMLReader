//  HTMLParser.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLDocument.h"
#import "HTMLElement.h"
#import "HTMLEncoding.h"

/**
    An HTMLParser turns a string into an HTMLDocument.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/tree-construction.html
 
    @see HTMLTokenizer
 */
@interface HTMLParser : NSObject

/**
    Initializes a parser with what appears to be some HTML.
 
    @param string   A string of HTML.
    @param encoding The (possibly presumed) string encoding of the document. May change during parsing, causing this parser to be irrelevant.
    @param context  A context element used for parsing a fragment of HTML, or nil if the fragment parsing algorithm is not to be used.
 
    For more information on the context parameter, see http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#parsing-html-fragments
 */
- (instancetype)initWithString:(NSString *)string encoding:(HTMLStringEncoding)encoding context:(HTMLElement *)context NS_DESIGNATED_INITIALIZER;

/// The HTML being parsed.
@property (readonly, copy, nonatomic) NSString *string;

/// The document's presumed string encoding.
@property (readonly, assign, nonatomic) HTMLStringEncoding encoding;

/// Instances of NSString representing the errors encountered while parsing the document.
@property (readonly, copy, nonatomic) NSArray *errors;

/// The parsed document. Lazily created on first access.
@property (readonly, strong, nonatomic) HTMLDocument *document;

/// A block called when the string encoding has changed, making this parser useless.
@property (copy, nonatomic) void (^changeEncoding)(HTMLStringEncoding newEncoding);

@end

/**
    Returns a parser suitable for some data of an unknown string encoding.
 
    @param contentType The value of the HTTP Content-Type header associated with the data, if any.
 */
extern HTMLParser * ParserWithDataAndContentType(NSData *data, NSString *contentType);
