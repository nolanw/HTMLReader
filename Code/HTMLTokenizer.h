//  HTMLTokenizer.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLOrderedDictionary.h"
#import "HTMLParser.h"

/**
 * The various states that an HTMLTokenizer moves through as it works. Exposed here for testing purposes.
 */
typedef NS_ENUM(NSInteger, HTMLTokenizerState)
{
    HTMLDataTokenizerState,
    HTMLCharacterReferenceInDataTokenizerState,
    HTMLRCDATATokenizerState,
    HTMLCharacterReferenceInRCDATATokenizerState,
    HTMLRAWTEXTTokenizerState,
    HTMLScriptDataTokenizerState,
    HTMLPLAINTEXTTokenizerState,
    HTMLTagOpenTokenizerState,
    HTMLEndTagOpenTokenizerState,
    HTMLTagNameTokenizerState,
    HTMLRCDATALessThanSignTokenizerState,
    HTMLRCDATAEndTagOpenTokenizerState,
    HTMLRCDATAEndTagNameTokenizerState,
    HTMLRAWTEXTLessThanSignTokenizerState,
    HTMLRAWTEXTEndTagOpenTokenizerState,
    HTMLRAWTEXTEndTagNameTokenizerState,
    HTMLScriptDataLessThanSignTokenizerState,
    HTMLScriptDataEndTagOpenTokenizerState,
    HTMLScriptDataEndTagNameTokenizerState,
    HTMLScriptDataEscapeStartTokenizerState,
    HTMLScriptDataEscapeStartDashTokenizerState,
    HTMLScriptDataEscapedTokenizerState,
    HTMLScriptDataEscapedDashTokenizerState,
    HTMLScriptDataEscapedDashDashTokenizerState,
    HTMLScriptDataEscapedLessThanSignTokenizerState,
    HTMLScriptDataEscapedEndTagOpenTokenizerState,
    HTMLScriptDataEscapedEndTagNameTokenizerState,
    HTMLScriptDataDoubleEscapeStartTokenizerState,
    HTMLScriptDataDoubleEscapedTokenizerState,
    HTMLScriptDataDoubleEscapedDashTokenizerState,
    HTMLScriptDataDoubleEscapedDashDashTokenizerState,
    HTMLScriptDataDoubleEscapedLessThanSignTokenizerState,
    HTMLScriptDataDoubleEscapeEndTokenizerState,
    HTMLBeforeAttributeNameTokenizerState,
    HTMLAttributeNameTokenizerState,
    HTMLAfterAttributeNameTokenizerState,
    HTMLBeforeAttributeValueTokenizerState,
    HTMLAttributeValueDoubleQuotedTokenizerState,
    HTMLAttributeValueSingleQuotedTokenizerState,
    HTMLAttributeValueUnquotedTokenizerState,
    HTMLCharacterReferenceInAttributeValueTokenizerState,
    HTMLAfterAttributeValueQuotedTokenizerState,
    HTMLSelfClosingStartTagTokenizerState,
    HTMLBogusCommentTokenizerState,
    HTMLMarkupDeclarationOpenTokenizerState,
    HTMLCommentStartTokenizerState,
    HTMLCommentStartDashTokenizerState,
    HTMLCommentTokenizerState,
    HTMLCommentEndDashTokenizerState,
    HTMLCommentEndTokenizerState,
    HTMLCommentEndBangTokenizerState,
    HTMLDOCTYPETokenizerState,
    HTMLBeforeDOCTYPENameTokenizerState,
    HTMLDOCTYPENameTokenizerState,
    HTMLAfterDOCTYPENameTokenizerState,
    HTMLAfterDOCTYPEPublicKeywordTokenizerState,
    HTMLBeforeDOCTYPEPublicIdentifierTokenizerState,
    HTMLDOCTYPEPublicIdentifierDoubleQuotedTokenizerState,
    HTMLDOCTYPEPublicIdentifierSingleQuotedTokenizerState,
    HTMLAfterDOCTYPEPublicIdentifierTokenizerState,
    HTMLBetweenDOCTYPEPublicAndSystemIdentifiersTokenizerState,
    HTMLAfterDOCTYPESystemKeywordTokenizerState,
    HTMLBeforeDOCTYPESystemIdentifierTokenizerState,
    HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState,
    HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState,
    HTMLAfterDOCTYPESystemIdentifierTokenizerState,
    HTMLBogusDOCTYPETokenizerState,
    HTMLCDATASectionTokenizerState,
};

/**
 * An HTMLTokenizer emits tokens from a string of HTML.
 */
@interface HTMLTokenizer : NSEnumerator

/**
 * Returns an initialized HTMLTokenizer.
 *
 * @param string The string to split into tokens.
 */
- (id)initWithString:(NSString *)string;

/**
 * The current state of the tokenizer. Can be changed by the parser.
 */
@property (nonatomic) HTMLTokenizerState state;

/**
 * The HTMLParser that is consuming the tokens from this tokenizer. Tokenization can change depending on the parser's state.
 */
@property (weak, nonatomic) HTMLParser *parser;

@end

/**
 * An HTMLDOCTYPEToken represents a <!DOCTYPE> tag.
 */
@interface HTMLDOCTYPEToken : NSObject

/**
 * The name of the DOCTYPE, or nil if it has none.
 */
@property (copy, nonatomic) NSString *name;

/**
 * The public identifier of the DOCTYPE, or nil if it has none.
 */
@property (copy, nonatomic) NSString *publicIdentifier;

/**
 * The system identifier of the DOCTYPE, or nil if it has none.
 */
@property (copy, nonatomic) NSString *systemIdentifier;

/**
 * YES if the parsed HTMLDocument's quirks mode should be set, or NO if other indicators should be used.
 */
@property (nonatomic) BOOL forceQuirks;

@end

/**
 * An HTMLTagToken abstractly represents opening (<p>) and closing (</p>) HTML tags with optional attributes.
 */
@interface HTMLTagToken : NSObject

/**
 * Returns an initialized HTMLTagToken. This is the designated initializer.
 *
 * @param tagName The name of this tag.
 */
- (id)initWithTagName:(NSString *)tagName;

/**
 * The name of this tag.
 */
@property (copy, nonatomic) NSString *tagName;

/**
 * A dictionary mapping HTMLAttributeName keys to NSString values.
 */
@property (copy, nonatomic) HTMLOrderedDictionary *attributes;

/**
 * YES if this tag is a self-closing tag (<br/>), or NO otherwise (<br> or </br>).
 */
@property (nonatomic) BOOL selfClosingFlag;

@end

/**
 * An HTMLStartTagToken represents a start tag like <p>.
 */
@interface HTMLStartTagToken : HTMLTagToken

/**
 * Returns an initialized copy of this start tag token with a new tag name.
 *
 * @param tagName The tag name of the copied token.
 */
- (id)copyWithTagName:(NSString *)tagName;

@end

/**
 * An HTMLEndTagToken represents an end tag like </p>.
 */
@interface HTMLEndTagToken : HTMLTagToken

@end

/**
 * An HTMLCommentToken represents a comment <!-- like this -->.
 */
@interface HTMLCommentToken : NSObject

/**
 * Returns an initialized HTMLCommentToken. This is the designated initializer.
 *
 * @param data The comment's data.
 */
- (id)initWithData:(NSString *)data;

/**
 * The comment's data.
 */
@property (readonly, copy, nonatomic) NSString *data;

@end

/**
 * An HTMLCharacterToken represents a single code point as text in an HTML document.
 */
@interface HTMLCharacterToken : NSObject

/**
 * Returns an initialized HTMLCharacterToken. This is the designated initializer.
 */
- (id)initWithString:(NSString *)string;

/**
 * The code points represented by this token.
 */
@property (readonly, copy, nonatomic) NSString *string;

/**
 * Returns a token for the leading whitespace, or nil if there is no leading whitespace.
 */
- (instancetype)leadingWhitespaceToken;

/**
 * Returns a token for the characters after leading whitespace, or nil if the token is entirely whitespace.
 */
- (instancetype)afterLeadingWhitespaceToken;

@end

/**
 * An HTMLParseErrorToken represents a parse error during tokenization. It's emitted as a parse error to give context to the error with respect to the tokens parsed before and after.
 */
@interface HTMLParseErrorToken : NSObject

/**
 * Returns an initialized HTMLParseErrorToken.
 *
 * @param error The reason for the parse error.
 */
- (id)initWithError:(NSString *)error;

/**
 * The reason for the parse error.
 */
@property (readonly, copy, nonatomic) NSString *error;

@end

/**
 * A single HTMLEOFToken is emitted when the end of the file is parsed and no further tokens will be emitted.
 */
@interface HTMLEOFToken : NSObject

@end

/**
 * A category exposing methods used for testing the tokenizer.
 */
@interface HTMLTokenizer (Testing)

/**
 * Sets the name of the last start tag, which is used at certain steps of tokenization.
 *
 * @param tagName The name of the pretend last start tag.
 */
- (void)setLastStartTag:(NSString *)tagName;

@end
