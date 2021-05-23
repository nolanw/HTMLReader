//  HTMLTokenizer.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLOrderedDictionary.h"
#import "HTMLParser.h"
#import "HTMLTokenizerState.h"

/**
    An HTMLTokenizer emits tokens derived from a string of HTML.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/tokenization.html
 */
@interface HTMLTokenizer : NSEnumerator

/// Initializes a tokenizer.
- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;

/// The string where tokens come from.
@property (readonly, copy, nonatomic) NSString *string;

/// The current state of the tokenizer. Sometimes the parser needs to change this.
@property (assign, nonatomic) HTMLTokenizerState state;

/// The parser that is consuming the tokenizer's tokens. Sometimes the tokenizer needs to know the parser's state.
@property (weak, nonatomic) HTMLParser *parser;

@end

/// An HTMLDOCTYPEToken represents a `<!DOCTYPE>` tag.
@interface HTMLDOCTYPEToken : NSObject

/// The name of the DOCTYPE, or nil if it has none.
@property (copy, nonatomic) NSString *name;

/// The public identifier of the DOCTYPE, or nil if it has none.
@property (copy, nonatomic) NSString *publicIdentifier;

/// The system identifier of the DOCTYPE, or nil if it has none.
@property (copy, nonatomic) NSString *systemIdentifier;

/// YES if the parsed HTMLDocument's quirks mode should be set, or NO if other indicators should be used.
@property (assign, nonatomic) BOOL forceQuirks;

@end

#pragma mark - Tokens

/// An HTMLTagToken abstractly represents opening (\<p\>) and closing (\</p\>) HTML tags with optional attributes.
@interface HTMLTagToken : NSObject

/// Initializes a token with a tag name.
- (instancetype)initWithTagName:(NSString *)tagName NS_DESIGNATED_INITIALIZER;

/// The name of this tag.
@property (copy, nonatomic) NSString *tagName;

/// A dictionary mapping HTMLAttributeName keys to NSString values.
@property (copy, nonatomic) HTMLOrderedDictionary *attributes;

/// YES if this tag is a self-closing tag (\<br/\>), or NO otherwise (\<br\> or \</br\>).
@property (assign, nonatomic) BOOL selfClosingFlag;

@end

/// An HTMLStartTagToken represents a start tag like `<p>`.
@interface HTMLStartTagToken : HTMLTagToken

/**
    Returns an initialized copy of this start tag token with a new tag name.
 
    @param tagName The tag name of the copied token.
 */
- (instancetype)copyWithTagName:(NSString *)tagName;

@end

/// An HTMLEndTagToken represents an end tag like \</p\>.
@interface HTMLEndTagToken : HTMLTagToken

@end

/// An HTMLCommentToken represents a comment \<!-- like this --\>.
@interface HTMLCommentToken : NSObject

/// @param data The comment's data.
- (instancetype)initWithData:(NSString *)data NS_DESIGNATED_INITIALIZER;

/// The comment's data.
@property (readonly, copy, nonatomic) NSString *data;

@end

/// An HTMLCharacterToken represents a series of code points as text in an HTML document.
@interface HTMLCharacterToken : NSObject

/// Initializes a character token with some characters.
- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;

/// The code points represented by this token.
@property (readonly, copy, nonatomic) NSString *string;

/// Returns a token for the leading whitespace, or nil if there is no leading whitespace.
- (instancetype)leadingWhitespaceToken;

/// Returns a token for the characters after leading whitespace, or nil if the token is entirely whitespace.
- (instancetype)afterLeadingWhitespaceToken;

@end

/**
    An HTMLParseErrorToken represents a parse error during tokenization.
 
    Parse errors are emitted as tokens to provide context.
 */
@interface HTMLParseErrorToken : NSObject

/// @param error The reason for the parse error.
- (instancetype)initWithError:(NSString *)error NS_DESIGNATED_INITIALIZER;

/// The reason for the parse error.
@property (readonly, copy, nonatomic) NSString *error;

@end

/// A single HTMLEOFToken is emitted when the end of the file is parsed and no further tokens will be emitted.
@interface HTMLEOFToken : NSObject

@end

@interface HTMLTokenizer (Testing)

/**
    Sets the name of the last start tag, which is used at certain steps of tokenization.
 
    @param tagName The name of the pretend last start tag.
 */
- (void)setLastStartTag:(NSString *)tagName;

@end
