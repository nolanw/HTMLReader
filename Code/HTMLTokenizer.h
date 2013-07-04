//
//  HTMLTokenizer.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-14.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>

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

// The tokenization stage of parsing HTML.
@interface HTMLTokenizer : NSEnumerator

// Designated initializer.
- (id)initWithString:(NSString *)string;

@property (nonatomic) HTMLTokenizerState state;

@end

@interface HTMLDOCTYPEToken : NSObject

@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *publicIdentifier;
@property (copy, nonatomic) NSString *systemIdentifier;
@property (nonatomic) BOOL forceQuirks;

@end

@interface HTMLTagToken : NSObject

// Designated initializer.
- (id)initWithTagName:(NSString *)tagName;

- (void)addAttributeWithName:(NSString *)name value:(NSString *)value;

@property (readonly, nonatomic) NSString *tagName;
@property (nonatomic) BOOL selfClosingFlag;
@property (readonly, nonatomic) NSArray *attributes;

@end

@interface HTMLStartTagToken : HTMLTagToken

- (id)copyWithTagName:(NSString *)tagName;

@end

@interface HTMLEndTagToken : HTMLTagToken

@end

@interface HTMLCommentToken : NSObject

// Designated initializer.
- (id)initWithData:(NSString *)data;

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLCharacterToken : NSObject

// Designated initializer.
- (id)initWithData:(UTF32Char)data;

@property (readonly, nonatomic) UTF32Char data;

@end

@interface HTMLParseErrorToken : NSObject

@end

@interface HTMLTokenizer (Testing)

- (void)setLastStartTag:(NSString *)tagName;

@end
