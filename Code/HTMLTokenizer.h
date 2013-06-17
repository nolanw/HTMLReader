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
    HTMLTokenizerDataState,
    HTMLTokenizerCharacterReferenceInDataState,
    HTMLTokenizerRCDATAState,
    HTMLTokenizerCharacterReferenceInRCDATAState,
    HTMLTokenizerRAWTEXTState,
    HTMLTokenizerScriptDataState,
    HTMLTokenizerPLAINTEXTState,
    HTMLTokenizerTagOpenState,
    HTMLTokenizerEndTagOpenState,
    HTMLTokenizerTagNameState,
    HTMLTokenizerRCDATALessThanSignState,
    HTMLTokenizerRCDATAEndTagOpenState,
    HTMLTokenizerRCDATAEndTagNameState,
    HTMLTokenizerRAWTEXTLessThanSignState,
    HTMLTokenizerRAWTEXTEndTagOpenState,
    HTMLTokenizerRAWTEXTEndTagNameState,
    HTMLTokenizerScriptDataLessThanSignState,
    HTMLTokenizerScriptDataEndTagOpenState,
    HTMLTokenizerScriptDataEndTagNameState,
    HTMLTokenizerScriptDataEscapeStartState,
    HTMLTokenizerScriptDataEscapeStartDashState,
    HTMLTokenizerScriptDataEscapedState,
    HTMLTokenizerScriptDataEscapedDashState,
    HTMLTokenizerScriptDataEscapedDashDashState,
    HTMLTokenizerScriptDataEscapedLessThanSignState,
    HTMLTokenizerScriptDataEscapedEndTagOpenState,
    HTMLTokenizerScriptDataEscapedEndTagNameState,
    HTMLTokenizerScriptDataDoubleEscapeStartState,
    HTMLTokenizerScriptDataDoubleEscapedState,
    HTMLTokenizerScriptDataDoubleEscapedDashState,
    HTMLTokenizerScriptDataDoubleEscapedDashDashState,
    HTMLTokenizerScriptDataDoubleEscapedLessThanSignState,
    HTMLTokenizerScriptDataDoubleEscapeEndState,
    HTMLTokenizerBeforeAttributeNameState,
    HTMLTokenizerAttributeNameState,
    HTMLTokenizerAfterAttributeNameState,
    HTMLTokenizerBeforeAttributeValueState,
    HTMLTokenizerAttributeValueDoubleQuotedState,
    HTMLTokenizerAttributeValueSingleQuotedState,
    HTMLTokenizerAttributeValueUnquotedState,
    HTMLTokenizerCharacterReferenceInAttributeValueState,
    HTMLTokenizerAfterAttributeValueQuotedState,
    HTMLTokenizerSelfClosingStartTagState,
    HTMLTokenizerBogusCommentState,
    HTMLTokenizerMarkupDeclarationOpenState,
    HTMLTokenizerCommentStartState,
    HTMLTokenizerCommentStartDashState,
    HTMLTokenizerCommentState,
    HTMLTokenizerCommentEndDashState,
    HTMLTokenizerCommentEndState,
    HTMLTokenizerCommentEndBangState,
    HTMLTokenizerDOCTYPEState,
    HTMLTokenizerBeforeDOCTYPENameState,
    HTMLTokenizerDOCTYPENameState,
    HTMLTokenizerAfterDOCTYPENameState,
    HTMLTokenizerAfterDOCTYPEPublicKeywordState,
    HTMLTokenizerBeforeDOCTYPEPublicIdentifierState,
    HTMLTokenizerDOCTYPEPublicIdentifierDoubleQuotedState,
    HTMLTokenizerDOCTYPEPublicIdentifierSingleQuotedState,
    HTMLTokenizerAfterDOCTYPEPublicIdentifierState,
    HTMLTokenizerBetweenDOCTYPEPublicAndSystemIdentifiersState,
    HTMLTokenizerAfterDOCTYPESystemKeywordState,
    HTMLTokenizerBeforeDOCTYPESystemIdentifierState,
    HTMLTokenizerDOCTYPESystemIdentifierDoubleQuotedState,
    HTMLTokenizerDOCTYPESystemIdentifierSingleQuotedState,
    HTMLTokenizerAfterDOCTYPESystemIdentifierState,
    HTMLTokenizerBogusDOCTYPEState,
    HTMLTokenizerCDATASectionState,
};

@interface HTMLTokenizer : NSEnumerator

// Designated initializer.
- (id)initWithString:(NSString *)string;

@end

@interface HTMLDOCTYPEToken : NSObject

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *publicIdentifier;
@property (readonly, nonatomic) NSString *systemIdentifier;
@property (readonly, nonatomic) BOOL forceQuirks;

@end

@interface HTMLTagToken : NSObject

// Designated initializer.
- (id)initWithTagName:(NSString *)tagName;

- (void)addAttributeWithName:(NSString *)name value:(NSString *)value;

@property (readonly, nonatomic) NSString *tagName;
@property (readonly, nonatomic) BOOL selfClosingFlag;
@property (readonly, nonatomic) NSArray *attributes;

@end

@interface HTMLAttribute : NSObject

// Designated initializer.
- (id)initWithName:(NSString *)name value:(NSString *)value;

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *value;

@end

@interface HTMLStartTagToken : HTMLTagToken

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
- (id)initWithData:(NSString *)data;

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLParseErrorToken : NSObject

@end

@interface HTMLTokenizer (Testing)

- (id)initWithString:(NSString *)string state:(HTMLTokenizerState)state;
- (void)setLastStartTag:(NSString *)tagName;

@end