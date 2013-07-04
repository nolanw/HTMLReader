//
//  HTMLTokenizer.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-14.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTokenizer.h"
#import "HTMLAttribute.h"
#import "HTMLString.h"

@interface HTMLTagToken ()

- (void)appendLongCharacterToTagName:(UTF32Char)character;

- (void)addNewAttribute;
- (BOOL)removeLastAttributeIfDuplicateName;

@end

@interface HTMLDOCTYPEToken ()

- (void)appendLongCharacterToName:(UTF32Char)character;
- (void)appendLongCharacterToPublicIdentifier:(UTF32Char)character;
- (void)appendLongCharacterToSystemIdentifier:(UTF32Char)character;

@end

@interface HTMLCommentToken ()

- (void)appendString:(NSString *)string;
- (void)appendLongCharacter:(UTF32Char)character;

@end


@implementation HTMLTokenizer
{
    NSScanner *_scanner;
    HTMLTokenizerState _state;
    NSMutableArray *_tokenQueue;
    NSMutableString *_characterBuffer;
    id _currentToken;
    HTMLTokenizerState _sourceAttributeValueState;
    HTMLAttribute *_currentAttribute;
    NSMutableString *_temporaryBuffer;
    int _additionalAllowedCharacter;
    NSString *_mostRecentEmittedStartTagName;
    int _reconsume;
    BOOL _done;
}

- (id)initWithString:(NSString *)string
{
    if (!(self = [super init])) return nil;
    _scanner = [NSScanner scannerWithString:string];
    _scanner.charactersToBeSkipped = nil;
    _scanner.caseSensitive = YES;
    self.state = HTMLDataTokenizerState;
    _tokenQueue = [NSMutableArray new];
    _characterBuffer = [NSMutableString new];
    _reconsume = NSNotFound;
    return self;
}

- (void)setLastStartTag:(NSString *)tagName
{
    _mostRecentEmittedStartTagName = [tagName copy];
}

- (void)resume
{
    int currentInputCharacter;
    switch (self.state) {
        case HTMLDataTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '&':
                    [self switchToState:HTMLCharacterReferenceInDataTokenizerState];
                    break;
                case '<':
                    [self switchToState:HTMLTagOpenTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:currentInputCharacter];
                    break;
                case EOF:
                    _done = YES;
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLCharacterReferenceInDataTokenizerState: {
            [self switchToState:HTMLDataTokenizerState];
            _additionalAllowedCharacter = NSNotFound;
            NSString *data = [self attemptToConsumeCharacterReference];
            if (data) {
                [self emitCharacterTokensWithString:data];
            } else {
                [self emitCharacterToken:'&'];
            }
            break;
        }
            
        case HTMLRCDATATokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '&':
                    [self switchToState:HTMLCharacterReferenceInRCDATATokenizerState];
                    break;
                case '<':
                    [self switchToState:HTMLRCDATALessThanSignTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    _done = YES;
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLCharacterReferenceInRCDATATokenizerState: {
            [self switchToState:HTMLRCDATATokenizerState];
            _additionalAllowedCharacter = NSNotFound;
            NSString *data = [self attemptToConsumeCharacterReference];
            if (data) {
                [self emitCharacterTokensWithString:data];
            } else {
                [self emitCharacterToken:'&'];
            }
            break;
        }
            
        case HTMLRAWTEXTTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '<':
                    [self switchToState:HTMLRAWTEXTLessThanSignTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    _done = YES;
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '<':
                    [self switchToState:HTMLScriptDataLessThanSignTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    _done = YES;
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLPLAINTEXTTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    _done = YES;
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLTagOpenTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '!':
                    [self switchToState:HTMLMarkupDeclarationOpenTokenizerState];
                    break;
                case '/':
                    [self switchToState:HTMLEndTagOpenTokenizerState];
                    break;
                case '?':
                    [self emitParseError];
                    [self switchToState:HTMLBogusCommentTokenizerState];
                    _scanner.scanLocation--;
                    break;
                default:
                    if (isupper(currentInputCharacter) || islower(currentInputCharacter)) {
                        _currentToken = [HTMLStartTagToken new];
                        unichar toAppend = currentInputCharacter + (isupper(currentInputCharacter) ? 0x0020 : 0);
                        [_currentToken appendLongCharacterToTagName:toAppend];
                        [self switchToState:HTMLTagNameTokenizerState];
                    } else {
                        [self emitParseError];
                        [self switchToState:HTMLDataTokenizerState];
                        [self emitCharacterToken:'<'];
                        [self reconsume:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLEndTagOpenTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '>':
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCharacterToken:'<'];
                    [self emitCharacterToken:'/'];
                    [self reconsume:currentInputCharacter];
                    break;
                default:
                    if (isupper(currentInputCharacter) || islower(currentInputCharacter)) {
                        _currentToken = [HTMLEndTagToken new];
                        unichar toAppend = currentInputCharacter + (isupper(currentInputCharacter) ? 0x0020 : 0);
                        [_currentToken appendLongCharacterToTagName:toAppend];
                        [self switchToState:HTMLTagNameTokenizerState];
                    } else {
                        [self emitParseError];
                        [self switchToState:HTMLBogusCommentTokenizerState];
                        // SPEC The spec doesn't say to reconsume the input character. Instead, it says the bogus comment state is responsible for starting the comment at the character that caused a transition into the bogus comment state. But then we duplicate parse errors for invalid Unicode code points. Effectively what we want is to reconsume.
                        [self reconsume:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLTagNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                    break;
                case '/':
                    [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacterToTagName:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    break;
                default:
                    if (isupper(currentInputCharacter)) {
                        [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                    } else {
                        [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLRCDATALessThanSignTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '/':
                    _temporaryBuffer = [NSMutableString new];
                    [self switchToState:HTMLRCDATAEndTagOpenTokenizerState];
                    break;
                default:
                    [self switchToState:HTMLRCDATATokenizerState];
                    [self emitCharacterToken:'<'];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLRCDATAEndTagOpenTokenizerState:
            if (isupper(currentInputCharacter = [self consumeNextInputCharacter])) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLRCDATAEndTagNameTokenizerState];
            } else if (islower(currentInputCharacter)) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLRCDATAEndTagNameTokenizerState];
            } else {
                [self switchToState:HTMLRCDATATokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self reconsume:currentInputCharacter];
            }
            break;
            
        case HTMLRCDATAEndTagNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                        goto doneRCDATAEndTagNameState;
                    }
                    break;
                case '/':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                        goto doneRCDATAEndTagNameState;
                    }
                    break;
                case '>':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLDataTokenizerState];
                        [self emitCurrentToken];
                        goto doneRCDATAEndTagNameState;
                    }
                    break;
            }
            if (isupper(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else if (islower(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else {
                [self switchToState:HTMLRCDATATokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self emitCharacterTokensWithString:_temporaryBuffer];
                [self reconsume:currentInputCharacter];
            }
        doneRCDATAEndTagNameState:
            break;
            
        case HTMLRAWTEXTLessThanSignTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '/':
                    _temporaryBuffer = [NSMutableString new];
                    [self switchToState:HTMLRAWTEXTEndTagOpenTokenizerState];
                    break;
                default:
                    [self switchToState:HTMLRAWTEXTTokenizerState];
                    [self emitCharacterToken:'<'];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLRAWTEXTEndTagOpenTokenizerState:
            if (isupper(currentInputCharacter = [self consumeNextInputCharacter])) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLRAWTEXTEndTagNameTokenizerState];
            } else if (islower(currentInputCharacter)) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLRAWTEXTEndTagNameTokenizerState];
            } else {
                [self switchToState:HTMLRAWTEXTTokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self reconsume:currentInputCharacter];
            }
            break;
            
        case HTMLRAWTEXTEndTagNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                        goto doneRAWTEXTEndTagNameState;
                    }
                    break;
                case '/':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                        goto doneRAWTEXTEndTagNameState;
                    }
                    break;
                case '>':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLDataTokenizerState];
                        [self emitCurrentToken];
                        goto doneRAWTEXTEndTagNameState;
                    }
                    break;
            }
            if (isupper(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else if (islower(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else {
                [self switchToState:HTMLRAWTEXTTokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self emitCharacterTokensWithString:_temporaryBuffer];
                [self reconsume:currentInputCharacter];
            }
        doneRAWTEXTEndTagNameState:
            break;
            
        case HTMLScriptDataLessThanSignTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '/':
                    _temporaryBuffer = [NSMutableString new];
                    [self switchToState:HTMLScriptDataEndTagOpenTokenizerState];
                    break;
                case '!':
                    [self switchToState:HTMLScriptDataEscapeStartTokenizerState];
                    [self emitCharacterToken:'<'];
                    [self emitCharacterToken:'!'];
                    break;
                default:
                    [self switchToState:HTMLScriptDataTokenizerState];
                    [self emitCharacterToken:'<'];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataEndTagOpenTokenizerState:
            if (isupper(currentInputCharacter = [self consumeNextInputCharacter])) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLScriptDataEndTagNameTokenizerState];
            } else if (islower(currentInputCharacter)) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLScriptDataEndTagNameTokenizerState];
            } else {
                [self switchToState:HTMLScriptDataTokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self reconsume:currentInputCharacter];
            }
            break;
            
        case HTMLScriptDataEndTagNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                        goto doneScriptDataEndTagNameState;
                    }
                    break;
                case '/':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                        goto doneScriptDataEndTagNameState;
                    }
                    break;
                case '>':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLDataTokenizerState];
                        [self emitCurrentToken];
                        goto doneScriptDataEndTagNameState;
                    }
                    break;
            }
            if (isupper(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else if (islower(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else {
                [self switchToState:HTMLScriptDataTokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self emitCharacterTokensWithString:_temporaryBuffer];
                [self reconsume:currentInputCharacter];
            }
        doneScriptDataEndTagNameState:
            break;
            
        case HTMLScriptDataEscapeStartTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLScriptDataEscapeStartDashTokenizerState];
                    [self emitCharacterToken:'-'];
                    break;
                default:
                    [self switchToState:HTMLScriptDataTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
        
        case HTMLScriptDataEscapeStartDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLScriptDataEscapedDashDashTokenizerState];
                    [self emitCharacterToken:'-'];
                    break;
                default:
                    [self switchToState:HTMLScriptDataTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataEscapedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLScriptDataEscapedDashTokenizerState];
                    [self emitCharacterToken:'-'];
                    break;
                case '<':
                    [self switchToState:HTMLScriptDataEscapedLessThanSignTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitParseError];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataEscapedDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLScriptDataEscapedDashDashTokenizerState];
                    [self emitCharacterToken:'-'];
                    break;
                case '<':
                    [self switchToState:HTMLScriptDataEscapedLessThanSignTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [self switchToState:HTMLScriptDataEscapedTokenizerState];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self switchToState:HTMLScriptDataEscapedTokenizerState];
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataEscapedDashDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self emitCharacterToken:'-'];
                    break;
                case '<':
                    [self switchToState:HTMLScriptDataEscapedLessThanSignTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLScriptDataTokenizerState];
                    [self emitCharacterToken:'>'];
                    break;
                case '\0':
                    [self emitParseError];
                    [self switchToState:HTMLScriptDataEscapedTokenizerState];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self switchToState:HTMLScriptDataEscapedTokenizerState];
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataEscapedLessThanSignTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '/':
                    _temporaryBuffer = [NSMutableString new];
                    [self switchToState:HTMLScriptDataEscapedEndTagOpenTokenizerState];
                    break;
                default:
                    if (isupper(currentInputCharacter)) {
                        _temporaryBuffer = [NSMutableString new];
                        AppendLongCharacter(_temporaryBuffer, currentInputCharacter + 0x0020);
                        [self switchToState:HTMLScriptDataDoubleEscapeStartTokenizerState];
                        [self emitCharacterToken:'<'];
                        [self emitCharacterToken:currentInputCharacter];
                    } else if (islower(currentInputCharacter)) {
                        _temporaryBuffer = [NSMutableString new];
                        AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                        [self switchToState:HTMLScriptDataDoubleEscapeStartTokenizerState];
                        [self emitCharacterToken:'<'];
                        [self emitCharacterToken:currentInputCharacter];
                    } else {
                        [self switchToState:HTMLScriptDataEscapedTokenizerState];
                        [self emitCharacterToken:'<'];
                        [self reconsume:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLScriptDataEscapedEndTagOpenTokenizerState:
            if (isupper(currentInputCharacter = [self consumeNextInputCharacter])) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLScriptDataEscapedEndTagNameTokenizerState];
            } else if (islower(currentInputCharacter)) {
                _currentToken = [HTMLEndTagToken new];
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                [self switchToState:HTMLScriptDataEscapedEndTagNameTokenizerState];
            } else {
                [self switchToState:HTMLScriptDataEscapedTokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self reconsume:currentInputCharacter];
            }
            break;
    
        case HTMLScriptDataEscapedEndTagNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                        goto doneScriptDataEscapedEndTagNameState;
                    }
                    break;
                case '/':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                        goto doneScriptDataEscapedEndTagNameState;
                    }
                    break;
                case '>':
                    if ([self currentTagIsAppropriateEndTagToken]) {
                        [self switchToState:HTMLDataTokenizerState];
                        [self emitCurrentToken];
                        goto doneScriptDataEscapedEndTagNameState;
                    }
                    break;
            }
            if (isupper(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter + 0x0020];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else if (islower(currentInputCharacter)) {
                [_currentToken appendLongCharacterToTagName:currentInputCharacter];
                AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
            } else {
                [self switchToState:HTMLScriptDataEscapedTokenizerState];
                [self emitCharacterToken:'<'];
                [self emitCharacterToken:'/'];
                [self emitCharacterTokensWithString:_temporaryBuffer];
                [self reconsume:currentInputCharacter];
            }
        doneScriptDataEscapedEndTagNameState:
            break;
            
        case HTMLScriptDataDoubleEscapeStartTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                case '/':
                case '>':
                    if ([_temporaryBuffer isEqualToString:@"script"]) {
                        [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    } else {
                        [self switchToState:HTMLScriptDataEscapedTokenizerState];
                    }
                    [self emitCharacterToken:currentInputCharacter];
                    break;
                default:
                    if (isupper(currentInputCharacter)) {
                        AppendLongCharacter(_temporaryBuffer, currentInputCharacter + 0x0020);
                        [self emitCharacterToken:currentInputCharacter];
                    } else if (islower(currentInputCharacter)) {
                        AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                        [self emitCharacterToken:currentInputCharacter];
                    } else {
                        [self switchToState:HTMLScriptDataEscapedTokenizerState];
                        [self reconsume:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLScriptDataDoubleEscapedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLScriptDataDoubleEscapedDashTokenizerState];
                    [self emitCharacterToken:'-'];
                    break;
                case '<':
                    [self switchToState:HTMLScriptDataDoubleEscapedLessThanSignTokenizerState];
                    [self emitCharacterToken:'<'];
                    break;
                case '\0':
                    [self emitParseError];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataDoubleEscapedDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLScriptDataDoubleEscapedDashDashTokenizerState];
                    [self emitCharacterToken:'-'];
                    break;
                case '<':
                    [self switchToState:HTMLScriptDataDoubleEscapedLessThanSignTokenizerState];
                    [self emitCharacterToken:'<'];
                    break;
                case '\0':
                    [self emitParseError];
                    [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataDoubleEscapedDashDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self emitCharacterToken:'-'];
                    break;
                case '<':
                    [self switchToState:HTMLScriptDataDoubleEscapedLessThanSignTokenizerState];
                    [self emitCharacterToken:'<'];
                    break;
                case '>':
                    [self switchToState:HTMLScriptDataTokenizerState];
                    [self emitCharacterToken:'>'];
                    break;
                case '\0':
                    [self emitParseError];
                    [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    [self emitCharacterToken:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    [self emitCharacterToken:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataDoubleEscapedLessThanSignTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '/':
                    _temporaryBuffer = [NSMutableString new];
                    [self switchToState:HTMLScriptDataDoubleEscapeEndTokenizerState];
                    [self emitCharacterToken:'/'];
                    break;
                default:
                    [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLScriptDataDoubleEscapeEndTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                case '/':
                case '>':
                    if ([_temporaryBuffer isEqualToString:@"script"]) {
                        [self switchToState:HTMLScriptDataEscapedTokenizerState];
                    } else {
                        [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                    }
                    [self emitCharacterToken:currentInputCharacter];
                    break;
                default:
                    if (isupper(currentInputCharacter)) {
                        AppendLongCharacter(_temporaryBuffer, currentInputCharacter + 0x0020);
                        [self emitCharacterToken:currentInputCharacter];
                    } else if (islower(currentInputCharacter)) {
                        AppendLongCharacter(_temporaryBuffer, currentInputCharacter);
                        [self emitCharacterToken:currentInputCharacter];
                    } else {
                        [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                        [self reconsume:currentInputCharacter];
                    }
                    break;
            }
            break;
    
        case HTMLBeforeAttributeNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '/':
                    [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken addNewAttribute];
                    _currentAttribute = [_currentToken attributes].lastObject;
                    [_currentAttribute appendLongCharacterToName:0xFFFD];
                    [self switchToState:HTMLAttributeNameTokenizerState];
                    break;
                case '"':
                case '\'':
                case '<':
                case '=':
                    [self emitParseError];
                    goto anythingElseBeforeAttributeNameState;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                anythingElseBeforeAttributeNameState:
                    [_currentToken addNewAttribute];
                    _currentAttribute = [_currentToken attributes].lastObject;
                    if (isupper(currentInputCharacter)) {
                        [_currentAttribute appendLongCharacterToName:currentInputCharacter + 0x0020];
                    } else {
                        [_currentAttribute appendLongCharacterToName:currentInputCharacter];
                    }
                    [self switchToState:HTMLAttributeNameTokenizerState];
                    break;
            }
            break;
            
        case HTMLAttributeNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLAfterAttributeNameTokenizerState];
                    break;
                case '/':
                    [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                    break;
                case '=':
                    [self switchToState:HTMLBeforeAttributeValueTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentAttribute appendLongCharacterToName:0xFFFD];
                    break;
                case '"':
                case '\'':
                case '<':
                    [self emitParseError];
                    goto anythingElseAttributeNameState;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                anythingElseAttributeNameState:
                    if (isupper(currentInputCharacter)) {
                        [_currentAttribute appendLongCharacterToName:currentInputCharacter + 0x0020];
                    } else {
                        [_currentAttribute appendLongCharacterToName:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLAfterAttributeNameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '/':
                    [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                    break;
                case '=':
                    [self switchToState:HTMLBeforeAttributeValueTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken addNewAttribute];
                    _currentAttribute = [_currentToken attributes].lastObject;
                    [_currentAttribute appendLongCharacterToName:0xFFFD];
                    [self switchToState:HTMLAttributeNameTokenizerState];
                    break;
                case '"':
                case '\'':
                case '<':
                    [self emitParseError];
                    goto anythingElseAfterAttributeNameState;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                anythingElseAfterAttributeNameState:
                    [_currentToken addNewAttribute];
                    _currentAttribute = [_currentToken attributes].lastObject;
                    if (isupper(currentInputCharacter)) {
                        [_currentAttribute appendLongCharacterToName:currentInputCharacter + 0x0020];
                    } else {
                        [_currentAttribute appendLongCharacterToName:currentInputCharacter];
                    }
                    [self switchToState:HTMLAttributeNameTokenizerState];
                    break;
            }
            break;
            
        case HTMLBeforeAttributeValueTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '"':
                    [self switchToState:HTMLAttributeValueDoubleQuotedTokenizerState];
                    break;
                case '&':
                    [self switchToState:HTMLAttributeValueUnquotedTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
                case '\'':
                    [self switchToState:HTMLAttributeValueSingleQuotedTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentAttribute appendLongCharacterToValue:0xFFFD];
                    [self switchToState:HTMLAttributeValueUnquotedTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '<':
                case '=':
                case '`':
                    [self emitParseError];
                    goto anythingElseBeforeAttributeValueState;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                anythingElseBeforeAttributeValueState:
                    [_currentAttribute appendLongCharacterToValue:currentInputCharacter];
                    [self switchToState:HTMLAttributeValueUnquotedTokenizerState];
                    break;
            }
            break;
            
        case HTMLAttributeValueDoubleQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '"':
                    [self switchToState:HTMLAfterAttributeValueQuotedTokenizerState];
                    break;
                case '&':
                    [self switchToState:HTMLCharacterReferenceInAttributeValueTokenizerState];
                    _additionalAllowedCharacter = '"';
                    _sourceAttributeValueState = HTMLAttributeValueDoubleQuotedTokenizerState;
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentAttribute appendLongCharacterToValue:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentAttribute appendLongCharacterToValue:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLAttributeValueSingleQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\'':
                    [self switchToState:HTMLAfterAttributeValueQuotedTokenizerState];
                    break;
                case '&':
                    [self switchToState:HTMLCharacterReferenceInAttributeValueTokenizerState];
                    _additionalAllowedCharacter = '\'';
                    _sourceAttributeValueState = HTMLAttributeValueSingleQuotedTokenizerState;
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentAttribute appendLongCharacterToValue:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentAttribute appendLongCharacterToValue:currentInputCharacter];
                    break;
            }
            break;
    
        case HTMLAttributeValueUnquotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                    break;
                case '&':
                    [self switchToState:HTMLCharacterReferenceInAttributeValueTokenizerState];
                    _additionalAllowedCharacter = '>';
                    _sourceAttributeValueState = HTMLAttributeValueUnquotedTokenizerState;
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentAttribute appendLongCharacterToValue:0xFFFD];
                    break;
                case '"':
                case '\'':
                case '<':
                case '=':
                case '`':
                    [self emitParseError];
                    goto anythingElseAttributeValueUnquotedState;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                anythingElseAttributeValueUnquotedState:
                    [_currentAttribute appendLongCharacterToValue:currentInputCharacter];
                    break;
            }
            break;
    
        case HTMLCharacterReferenceInAttributeValueTokenizerState: {
            NSString *characters = [self attemptToConsumeCharacterReferenceAsPartOfAnAttribute];
            if (characters) {
                [_currentAttribute appendStringToValue:characters];
            } else {
                [_currentAttribute appendLongCharacterToValue:'&'];
            }
            [self switchToState:_sourceAttributeValueState];
            break;
        }
    
        case HTMLAfterAttributeValueQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                    break;
                case '/':
                    [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
    
        case HTMLSelfClosingStartTagTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '>':
                    [_currentToken setSelfClosingFlag:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLBogusCommentTokenizerState:
            _currentToken = [HTMLCommentToken new];
            while (true) {
                switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                    case EOF:
                        [self reconsume:EOF];
                        goto doneBogusCommentState;
                    case '>':
                        goto doneBogusCommentState;
                    case '\0':
                        [_currentToken appendLongCharacter:0xFFFD];
                        break;
                    default:
                        [_currentToken appendLongCharacter:currentInputCharacter];
                        break;
                }
            }
        doneBogusCommentState:
            [self emitCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            break;
            
        case HTMLMarkupDeclarationOpenTokenizerState:
            if ([_scanner scanString:@"--" intoString:nil]) {
                _currentToken = [[HTMLCommentToken alloc] initWithData:@""];
                [self switchToState:HTMLCommentStartTokenizerState];
                break;
            }
            _scanner.caseSensitive = NO;
            if ([_scanner scanString:@"DOCTYPE" intoString:nil]) {
                [self switchToState:HTMLDOCTYPETokenizerState];
                goto doneMarkupDeclarationOpenState;
            }
            // TODO handle CDATA once tree construction is up
            [self emitParseError];
            [self switchToState:HTMLBogusCommentTokenizerState];
        doneMarkupDeclarationOpenState:
            _scanner.caseSensitive = YES;
            break;
            
        case HTMLCommentStartTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLCommentStartDashTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacter:0xFFFD];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacter:currentInputCharacter];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
            }
            break;
            
        case HTMLCommentStartDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLCommentEndTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacter:'-'];
                    [_currentToken appendLongCharacter:0xFFFD];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacter:'-'];
                    [_currentToken appendLongCharacter:currentInputCharacter];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
            }
            break;
            
        case HTMLCommentTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLCommentEndDashTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacter:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacter:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLCommentEndDashTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [self switchToState:HTMLCommentEndTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacter:'-'];
                    [_currentToken appendLongCharacter:0xFFFD];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacter:'-'];
                    [_currentToken appendLongCharacter:currentInputCharacter];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
            }
            break;
            
        case HTMLCommentEndTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendString:@"--"];
                    [_currentToken appendLongCharacter:0xFFFD];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
                case '!':
                    [self emitParseError];
                    [self switchToState:HTMLCommentEndBangTokenizerState];
                    break;
                case '-':
                    [self emitParseError];
                    [_currentToken appendLongCharacter:'-'];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken appendString:@"--"];
                    [_currentToken appendLongCharacter:currentInputCharacter];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
            }
            break;
            
        case HTMLCommentEndBangTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '-':
                    [_currentToken appendString:@"--!"];
                    [self switchToState:HTMLCommentEndDashTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendString:@"--!\uFFFD"];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendString:@"--!"];
                    [_currentToken appendLongCharacter:currentInputCharacter];
                    [self switchToState:HTMLCommentTokenizerState];
                    break;
            }
            break;
            
        case HTMLDOCTYPETokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBeforeDOCTYPENameTokenizerState];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    _currentToken = [HTMLDOCTYPEToken new];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [self switchToState:HTMLBeforeDOCTYPENameTokenizerState];
                    [self reconsume:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLBeforeDOCTYPENameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '\0':
                    [self emitParseError];
                    _currentToken = [HTMLDOCTYPEToken new];
                    [_currentToken appendLongCharacterToName:0xFFFD];
                    [self switchToState:HTMLDOCTYPENameTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    _currentToken = [HTMLDOCTYPEToken new];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    _currentToken = [HTMLDOCTYPEToken new];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    _currentToken = [HTMLDOCTYPEToken new];
                    if (isupper(currentInputCharacter)) {
                        [_currentToken appendLongCharacterToName:currentInputCharacter + 0x0020];
                    } else {
                        [_currentToken appendLongCharacterToName:currentInputCharacter];
                    }
                    [self switchToState:HTMLDOCTYPENameTokenizerState];
                    break;
            }
            break;
            
        case HTMLDOCTYPENameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLAfterDOCTYPENameTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacterToName:0xFFFD];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    if (isupper(currentInputCharacter)) {
                        [_currentToken appendLongCharacterToName:currentInputCharacter + 0x0020];
                    } else {
                        [_currentToken appendLongCharacterToName:currentInputCharacter];
                    }
                    break;
            }
            break;
            
        case HTMLAfterDOCTYPENameTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    if (!_scanner.isAtEnd) _scanner.scanLocation--;
                    _scanner.caseSensitive = NO;
                    if ([_scanner scanString:@"PUBLIC" intoString:nil]) {
                        [self switchToState:HTMLAfterDOCTYPEPublicKeywordTokenizerState];
                    } else if ([_scanner scanString:@"SYSTEM" intoString:nil]) {
                        [self switchToState:HTMLAfterDOCTYPESystemKeywordTokenizerState];
                    } else {
                        if (!_scanner.isAtEnd) _scanner.scanLocation++;
                        [self emitParseError];
                        [_currentToken setForceQuirks:YES];
                        [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    }
                    _scanner.caseSensitive = YES;
                    break;
            }
            break;
            
        case HTMLAfterDOCTYPEPublicKeywordTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBeforeDOCTYPEPublicIdentifierTokenizerState];
                    break;
                case '"':
                    [self emitParseError];
                    [_currentToken setPublicIdentifier:@""];
                    [self switchToState:HTMLDOCTYPEPublicIdentifierDoubleQuotedTokenizerState];
                    break;
                case '\'':
                    [self emitParseError];
                    [_currentToken setPublicIdentifier:@""];
                    [self switchToState:HTMLDOCTYPEPublicIdentifierSingleQuotedTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLBeforeDOCTYPEPublicIdentifierTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '"':
                    [_currentToken setPublicIdentifier:@""];
                    [self switchToState:HTMLDOCTYPEPublicIdentifierDoubleQuotedTokenizerState];
                    break;
                case '\'':
                    [_currentToken setPublicIdentifier:@""];
                    [self switchToState:HTMLDOCTYPEPublicIdentifierSingleQuotedTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLDOCTYPEPublicIdentifierDoubleQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '"':
                    [self switchToState:HTMLAfterDOCTYPEPublicIdentifierTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacterToPublicIdentifier:0xFFFD];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacterToPublicIdentifier:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLDOCTYPEPublicIdentifierSingleQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\'':
                    [self switchToState:HTMLAfterDOCTYPEPublicIdentifierTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacterToPublicIdentifier:0xFFFD];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacterToPublicIdentifier:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLAfterDOCTYPEPublicIdentifierTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBetweenDOCTYPEPublicAndSystemIdentifiersTokenizerState];
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '"':
                    [self emitParseError];
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState];
                    break;
                case '\'':
                    [self emitParseError];
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLBetweenDOCTYPEPublicAndSystemIdentifiersTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case '"':
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState];
                    break;
                case '\'':
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLAfterDOCTYPESystemKeywordTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    [self switchToState:HTMLBeforeDOCTYPESystemIdentifierTokenizerState];
                    break;
                case '"':
                    [self emitParseError];
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState];
                    break;
                case '\'':
                    [self emitParseError];
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLBeforeDOCTYPESystemIdentifierTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '"':
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState];
                    break;
                case '\'':
                    [_currentToken setSystemIdentifier:@""];
                    [self switchToState:HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '"':
                    [self switchToState:HTMLAfterDOCTYPESystemIdentifierTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacterToSystemIdentifier:0xFFFD];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacterToSystemIdentifier:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\'':
                    [self switchToState:HTMLAfterDOCTYPESystemIdentifierTokenizerState];
                    break;
                case '\0':
                    [self emitParseError];
                    [_currentToken appendLongCharacterToSystemIdentifier:0xFFFD];
                    break;
                case '>':
                    [self emitParseError];
                    [_currentToken setForceQuirks:YES];
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [_currentToken appendLongCharacterToSystemIdentifier:currentInputCharacter];
                    break;
            }
            break;
            
        case HTMLAfterDOCTYPESystemIdentifierTokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '\t':
                case '\n':
                case '\f':
                case ' ':
                    break;
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self emitParseError];
                    [self switchToState:HTMLDataTokenizerState];
                    [_currentToken setForceQuirks:YES];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    [self emitParseError];
                    [self switchToState:HTMLBogusDOCTYPETokenizerState];
                    break;
            }
            break;
            
        case HTMLBogusDOCTYPETokenizerState:
            switch (currentInputCharacter = [self consumeNextInputCharacter]) {
                case '>':
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    break;
                case EOF:
                    [self switchToState:HTMLDataTokenizerState];
                    [self emitCurrentToken];
                    [self reconsume:EOF];
                    break;
                default:
                    break;
            }
            break;
            
        case HTMLCDATASectionTokenizerState:
            NSLog(@"unimplemented state");
            _done = YES;
            break;
    }
}

- (int)consumeNextInputCharacter
{
    if (_reconsume != NSNotFound) {
        int character = _reconsume;
        _reconsume = NSNotFound;
        return character;
    } else if (_scanner.isAtEnd) {
        return EOF;
    } else {
        int32_t character = [_scanner.string characterAtIndex:_scanner.scanLocation++];
        if (CFStringIsSurrogateHighCharacter(character)) {
            // Got a lead surrogate. Check for trail.
            unichar trail = _scanner.isAtEnd ? 0xFFFD : [_scanner.string characterAtIndex:_scanner.scanLocation];
            if (CFStringIsSurrogateLowCharacter(trail)) {
                // Got a trail surrogate.
                _scanner.scanLocation++;
                character = CFStringGetLongCharacterForSurrogatePair(character, trail);
            } else {
                // Lead surrogate with no trail.
                [self emitParseError];
                return 0xFFFD;
            }
        } else if (CFStringIsSurrogateLowCharacter(character)) {
            // Trail surrogate with no lead.
            [self emitParseError];
            return 0xFFFD;
        }
        #define InRange(a, b) (character >= (a) && character <= (b))
        if (InRange(0x0001, 0x0008) ||
            InRange(0x000E, 0x001F) ||
            InRange(0x007F, 0x009F) ||
            InRange(0xFDD0, 0xFDEF) ||
            character == 0x000B ||
            InRange(0xFFFE, 0xFFFF) ||
            InRange(0x1FFFE, 0x1FFFF) ||
            InRange(0x2FFFE, 0x2FFFF) ||
            InRange(0x3FFFE, 0x3FFFF) ||
            InRange(0x4FFFE, 0x4FFFF) ||
            InRange(0x5FFFE, 0x5FFFF) ||
            InRange(0x6FFFE, 0x6FFFF) ||
            InRange(0x7FFFE, 0x7FFFF) ||
            InRange(0x8FFFE, 0x8FFFF) ||
            InRange(0x9FFFE, 0x9FFFF) ||
            InRange(0xAFFFE, 0xAFFFF) ||
            InRange(0xBFFFE, 0xBFFFF) ||
            InRange(0xCFFFE, 0xCFFFF) ||
            InRange(0xDFFFE, 0xDFFFF) ||
            InRange(0xEFFFE, 0xEFFFF) ||
            InRange(0xFFFFE, 0xFFFFF) ||
            InRange(0x10FFFE, 0x10FFFF))
        {
            [self emitParseError];
        }
        if (character == '\r') {
            if (!_scanner.isAtEnd && [_scanner.string characterAtIndex:_scanner.scanLocation] == '\n') {
                _scanner.scanLocation++;
            }
            return '\n';
        }
        return character;
    }
}

- (void)switchToState:(HTMLTokenizerState)state
{
    if (self.state == HTMLAttributeNameTokenizerState) {
        if ([_currentToken removeLastAttributeIfDuplicateName]) {
            [self emitParseError];
        }
    }
    self.state = state;
}

- (void)reconsume:(int)character
{
    _reconsume = character;
}

- (void)emit:(id)token
{
    if ([token isKindOfClass:[HTMLStartTagToken class]]) {
        _mostRecentEmittedStartTagName = [token tagName];
    }
    if ([token isKindOfClass:[HTMLEndTagToken class]]) {
        HTMLEndTagToken *endTag = token;
        if (endTag.attributes.count > 0 || endTag.selfClosingFlag) {
            [self emitParseError];
        }
    }
    [self emitCore:token];
}

- (void)emitCore:(id)token
{
    [_tokenQueue addObject:token];
}

- (void)emitParseError
{
    [self emit:[HTMLParseErrorToken new]];
}

- (void)emitCharacterToken:(UTF32Char)character
{
    [self emit:[[HTMLCharacterToken alloc] initWithData:character]];
}

- (void)emitCharacterTokensWithString:(NSString *)string
{
    EnumerateLongCharacters(string, ^(UTF32Char character) {
        [self emitCharacterToken:character];
    });
}

- (void)emitCurrentToken
{
    [self emit:_currentToken];
    _currentToken = nil;
}

- (BOOL)currentTagIsAppropriateEndTagToken
{
    HTMLEndTagToken *token = _currentToken;
    return ([token isKindOfClass:[HTMLEndTagToken class]] &&
            [token.tagName isEqualToString:_mostRecentEmittedStartTagName]);
}

- (NSString *)attemptToConsumeCharacterReference
{
    return [self attemptToConsumeCharacterReferenceIsPartOfAnAttribute:NO];
}

- (NSString *)attemptToConsumeCharacterReferenceAsPartOfAnAttribute
{
    return [self attemptToConsumeCharacterReferenceIsPartOfAnAttribute:YES];
}

- (NSString *)attemptToConsumeCharacterReferenceIsPartOfAnAttribute:(BOOL)partOfAnAttribute
{
    if (_scanner.isAtEnd) return nil;
    NSUInteger initialScanLocation = _scanner.scanLocation;
    unichar nextInputCharacter = [_scanner.string characterAtIndex:_scanner.scanLocation];
    if (_additionalAllowedCharacter != NSNotFound && nextInputCharacter == _additionalAllowedCharacter) {
        return nil;
    }
    switch (nextInputCharacter) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
        case '<':
        case '&':
            return nil;
        case '#': {
            [_scanner scanString:@"#" intoString:nil];
            _scanner.caseSensitive = NO;
            BOOL hex = [_scanner scanString:@"x" intoString:nil];
            _scanner.caseSensitive = YES;
            unsigned int number;
            BOOL ok;
            if (hex) {
                ok = [_scanner scanHexInt:&number];
            } else {
                int scannedNumber;
                ok = [_scanner scanInt:&scannedNumber];
                if (ok) {
                    number = scannedNumber;
                }
            }
            if (!ok) {
                _scanner.scanLocation = initialScanLocation;
                [self emitParseError];
                return nil;
            }
            ok = [_scanner scanString:@";" intoString:nil];
            if (!ok) {
                [self emitParseError];
            }
            for (size_t i = 0; i < sizeof(ReplacementTable) / sizeof(ReplacementTable[0]); i++) {
                if (ReplacementTable[i].number == number) {
                    [self emitParseError];
                    return [NSString stringWithFormat:@"%C", ReplacementTable[i].replacement];
                }
            }
            if ((number >= 0xD800 && number <= 0xDFFF) || number > 0x10FFFF) {
                [self emitParseError];
                return @"\uFFFD";
            }
            if ((number >= 0x0001 && number <= 0x0008) ||
                (number >= 0x000E && number <= 0x001F) ||
                (number >= 0x007F && number <= 0x009F) ||
                (number >= 0xFDD0 && number <= 0xFDEF)) {
                [self emitParseError];
            }
            if (number == 0x000B ||
                number == 0xFFFE || number == 0xFFFF ||
                number == 0x1FFFE || number == 0x1FFFF ||
                number == 0x2FFFE || number == 0x2FFFF ||
                number == 0x3FFFE || number == 0x3FFFF ||
                number == 0x4FFFE || number == 0x4FFFF ||
                number == 0x5FFFE || number == 0x5FFFF ||
                number == 0x6FFFE || number == 0x6FFFF ||
                number == 0x7FFFE || number == 0x7FFFF ||
                number == 0x8FFFE || number == 0x8FFFF ||
                number == 0x9FFFE || number == 0x9FFFF ||
                number == 0xAFFFE || number == 0xAFFFF ||
                number == 0xBFFFE || number == 0xBFFFF ||
                number == 0xCFFFE || number == 0xCFFFF ||
                number == 0xDFFFE || number == 0xDFFFF ||
                number == 0xEFFFE || number == 0xEFFFF ||
                number == 0xFFFFE || number == 0xFFFFF ||
                number == 0x10FFFE || number == 0x10FFFF)
            {
                [self emitParseError];
            }
            unichar surrogates[2];
            if (CFStringGetSurrogatePairForLongCharacter(number, surrogates)) {
                return [NSString stringWithFormat:@"%C%C", surrogates[0], surrogates[1]];
            } else {
                return [NSString stringWithFormat:@"%C", surrogates[0]];
            }
        }
        default: {
            NSString *longestScanned;
            NSString *characters;
            for (size_t i = 0; i < sizeof(NamedCharacterReferences) / sizeof(NamedCharacterReferences[0]); i++) {
                NSString *scan;
                if ([_scanner scanString:NamedCharacterReferences[i].name intoString:&scan]) {
                    if (scan.length > longestScanned.length) {
                        longestScanned = scan;
                        characters = NamedCharacterReferences[i].characters;
                    }
                    _scanner.scanLocation = initialScanLocation;
                }
            }
            if (!characters) {
                NSCharacterSet *alphanumeric = [NSCharacterSet alphanumericCharacterSet];
                if ([_scanner scanCharactersFromSet:alphanumeric intoString:nil] &&
                    [_scanner scanString:@";" intoString:nil])
                {
                    [self emitParseError];
                }
                _scanner.scanLocation = initialScanLocation;
            } else {
                [_scanner scanString:longestScanned intoString:nil];
                if ([_scanner.string characterAtIndex:(_scanner.scanLocation - 1)] != ';') {
                    if (partOfAnAttribute) {
                        if (!_scanner.isAtEnd) {
                            unichar next = [_scanner.string characterAtIndex:_scanner.scanLocation];
                            if (next == '=' || [[NSCharacterSet alphanumericCharacterSet] characterIsMember:next]) {
                                _scanner.scanLocation = initialScanLocation;
                                if (next == '=') [self emitParseError];
                                return nil;
                            }
                        }
                    }
                    [self emitParseError];
                }
            }
            return characters;
        }
    }
}

static const struct {
    unichar number;
    unichar replacement;
} ReplacementTable[] = {
    { 0x00, 0xFFFD },
    { 0x0D, 0x000D },
    { 0x80, 0x20AC },
    { 0x81, 0x0081 },
    { 0x82, 0x201A },
    { 0x83, 0x0192 },
    { 0x84, 0x201E },
    { 0x85, 0x2026 },
    { 0x86, 0x2020 },
    { 0x87, 0x2021 },
    { 0x88, 0x02C6 },
    { 0x89, 0x2030 },
    { 0x8A, 0x0160 },
    { 0x8B, 0x2039 },
    { 0x8C, 0x0152 },
    { 0x8D, 0x008D },
    { 0x8E, 0x017D },
    { 0x8F, 0x008F },
    { 0x90, 0x0090 },
    { 0x91, 0x2018 },
    { 0x92, 0x2019 },
    { 0x93, 0x201C },
    { 0x94, 0x201D },
    { 0x95, 0x2022 },
    { 0x96, 0x2013 },
    { 0x97, 0x2014 },
    { 0x98, 0x02DC },
    { 0x99, 0x2122 },
    { 0x9A, 0x0161 },
    { 0x9B, 0x203A },
    { 0x9C, 0x0153 },
    { 0x9D, 0x009D },
    { 0x9E, 0x017E },
    { 0x9F, 0x0178 },
};

static const struct {
    __unsafe_unretained NSString *name;
    __unsafe_unretained NSString *characters;
} NamedCharacterReferences[] = {
    { @"Aacute;", @"\U000000C1" },
    { @"Aacute", @"\U000000C1" },
    { @"aacute;", @"\U000000E1" },
    { @"aacute", @"\U000000E1" },
    { @"Abreve;", @"\U00000102" },
    { @"abreve;", @"\U00000103" },
    { @"ac;", @"\U0000223E" },
    { @"acd;", @"\U0000223F" },
    { @"acE;", @"\U0000223E\U00000333" },
    { @"Acirc;", @"\U000000C2" },
    { @"Acirc", @"\U000000C2" },
    { @"acirc;", @"\U000000E2" },
    { @"acirc", @"\U000000E2" },
    { @"acute;", @"\U000000B4" },
    { @"acute", @"\U000000B4" },
    { @"Acy;", @"\U00000410" },
    { @"acy;", @"\U00000430" },
    { @"AElig;", @"\U000000C6" },
    { @"AElig", @"\U000000C6" },
    { @"aelig;", @"\U000000E6" },
    { @"aelig", @"\U000000E6" },
    { @"af;", @"\U00002061" },
    { @"Afr;", @"\U0001D504" },
    { @"afr;", @"\U0001D51E" },
    { @"Agrave;", @"\U000000C0" },
    { @"Agrave", @"\U000000C0" },
    { @"agrave;", @"\U000000E0" },
    { @"agrave", @"\U000000E0" },
    { @"alefsym;", @"\U00002135" },
    { @"aleph;", @"\U00002135" },
    { @"Alpha;", @"\U00000391" },
    { @"alpha;", @"\U000003B1" },
    { @"Amacr;", @"\U00000100" },
    { @"amacr;", @"\U00000101" },
    { @"amalg;", @"\U00002A3F" },
    { @"AMP;", @"&" },
    { @"AMP", @"&" },
    { @"amp;", @"&" },
    { @"amp", @"&" },
    { @"And;", @"\U00002A53" },
    { @"and;", @"\U00002227" },
    { @"andand;", @"\U00002A55" },
    { @"andd;", @"\U00002A5C" },
    { @"andslope;", @"\U00002A58" },
    { @"andv;", @"\U00002A5A" },
    { @"ang;", @"\U00002220" },
    { @"ange;", @"\U000029A4" },
    { @"angle;", @"\U00002220" },
    { @"angmsd;", @"\U00002221" },
    { @"angmsdaa;", @"\U000029A8" },
    { @"angmsdab;", @"\U000029A9" },
    { @"angmsdac;", @"\U000029AA" },
    { @"angmsdad;", @"\U000029AB" },
    { @"angmsdae;", @"\U000029AC" },
    { @"angmsdaf;", @"\U000029AD" },
    { @"angmsdag;", @"\U000029AE" },
    { @"angmsdah;", @"\U000029AF" },
    { @"angrt;", @"\U0000221F" },
    { @"angrtvb;", @"\U000022BE" },
    { @"angrtvbd;", @"\U0000299D" },
    { @"angsph;", @"\U00002222" },
    { @"angst;", @"\U000000C5" },
    { @"angzarr;", @"\U0000237C" },
    { @"Aogon;", @"\U00000104" },
    { @"aogon;", @"\U00000105" },
    { @"Aopf;", @"\U0001D538" },
    { @"aopf;", @"\U0001D552" },
    { @"ap;", @"\U00002248" },
    { @"apacir;", @"\U00002A6F" },
    { @"apE;", @"\U00002A70" },
    { @"ape;", @"\U0000224A" },
    { @"apid;", @"\U0000224B" },
    { @"apos;", @"'" },
    { @"ApplyFunction;", @"\U00002061" },
    { @"approx;", @"\U00002248" },
    { @"approxeq;", @"\U0000224A" },
    { @"Aring;", @"\U000000C5" },
    { @"Aring", @"\U000000C5" },
    { @"aring;", @"\U000000E5" },
    { @"aring", @"\U000000E5" },
    { @"Ascr;", @"\U0001D49C" },
    { @"ascr;", @"\U0001D4B6" },
    { @"Assign;", @"\U00002254" },
    { @"ast;", @"*" },
    { @"asymp;", @"\U00002248" },
    { @"asympeq;", @"\U0000224D" },
    { @"Atilde;", @"\U000000C3" },
    { @"Atilde", @"\U000000C3" },
    { @"atilde;", @"\U000000E3" },
    { @"atilde", @"\U000000E3" },
    { @"Auml;", @"\U000000C4" },
    { @"Auml", @"\U000000C4" },
    { @"auml;", @"\U000000E4" },
    { @"auml", @"\U000000E4" },
    { @"awconint;", @"\U00002233" },
    { @"awint;", @"\U00002A11" },
    { @"backcong;", @"\U0000224C" },
    { @"backepsilon;", @"\U000003F6" },
    { @"backprime;", @"\U00002035" },
    { @"backsim;", @"\U0000223D" },
    { @"backsimeq;", @"\U000022CD" },
    { @"Backslash;", @"\U00002216" },
    { @"Barv;", @"\U00002AE7" },
    { @"barvee;", @"\U000022BD" },
    { @"Barwed;", @"\U00002306" },
    { @"barwed;", @"\U00002305" },
    { @"barwedge;", @"\U00002305" },
    { @"bbrk;", @"\U000023B5" },
    { @"bbrktbrk;", @"\U000023B6" },
    { @"bcong;", @"\U0000224C" },
    { @"Bcy;", @"\U00000411" },
    { @"bcy;", @"\U00000431" },
    { @"bdquo;", @"\U0000201E" },
    { @"becaus;", @"\U00002235" },
    { @"Because;", @"\U00002235" },
    { @"because;", @"\U00002235" },
    { @"bemptyv;", @"\U000029B0" },
    { @"bepsi;", @"\U000003F6" },
    { @"bernou;", @"\U0000212C" },
    { @"Bernoullis;", @"\U0000212C" },
    { @"Beta;", @"\U00000392" },
    { @"beta;", @"\U000003B2" },
    { @"beth;", @"\U00002136" },
    { @"between;", @"\U0000226C" },
    { @"Bfr;", @"\U0001D505" },
    { @"bfr;", @"\U0001D51F" },
    { @"bigcap;", @"\U000022C2" },
    { @"bigcirc;", @"\U000025EF" },
    { @"bigcup;", @"\U000022C3" },
    { @"bigodot;", @"\U00002A00" },
    { @"bigoplus;", @"\U00002A01" },
    { @"bigotimes;", @"\U00002A02" },
    { @"bigsqcup;", @"\U00002A06" },
    { @"bigstar;", @"\U00002605" },
    { @"bigtriangledown;", @"\U000025BD" },
    { @"bigtriangleup;", @"\U000025B3" },
    { @"biguplus;", @"\U00002A04" },
    { @"bigvee;", @"\U000022C1" },
    { @"bigwedge;", @"\U000022C0" },
    { @"bkarow;", @"\U0000290D" },
    { @"blacklozenge;", @"\U000029EB" },
    { @"blacksquare;", @"\U000025AA" },
    { @"blacktriangle;", @"\U000025B4" },
    { @"blacktriangledown;", @"\U000025BE" },
    { @"blacktriangleleft;", @"\U000025C2" },
    { @"blacktriangleright;", @"\U000025B8" },
    { @"blank;", @"\U00002423" },
    { @"blk12;", @"\U00002592" },
    { @"blk14;", @"\U00002591" },
    { @"blk34;", @"\U00002593" },
    { @"block;", @"\U00002588" },
    { @"bne;", @"=\U000020E5" },
    { @"bnequiv;", @"\U00002261\U000020E5" },
    { @"bNot;", @"\U00002AED" },
    { @"bnot;", @"\U00002310" },
    { @"Bopf;", @"\U0001D539" },
    { @"bopf;", @"\U0001D553" },
    { @"bot;", @"\U000022A5" },
    { @"bottom;", @"\U000022A5" },
    { @"bowtie;", @"\U000022C8" },
    { @"boxbox;", @"\U000029C9" },
    { @"boxDL;", @"\U00002557" },
    { @"boxDl;", @"\U00002556" },
    { @"boxdL;", @"\U00002555" },
    { @"boxdl;", @"\U00002510" },
    { @"boxDR;", @"\U00002554" },
    { @"boxDr;", @"\U00002553" },
    { @"boxdR;", @"\U00002552" },
    { @"boxdr;", @"\U0000250C" },
    { @"boxH;", @"\U00002550" },
    { @"boxh;", @"\U00002500" },
    { @"boxHD;", @"\U00002566" },
    { @"boxHd;", @"\U00002564" },
    { @"boxhD;", @"\U00002565" },
    { @"boxhd;", @"\U0000252C" },
    { @"boxHU;", @"\U00002569" },
    { @"boxHu;", @"\U00002567" },
    { @"boxhU;", @"\U00002568" },
    { @"boxhu;", @"\U00002534" },
    { @"boxminus;", @"\U0000229F" },
    { @"boxplus;", @"\U0000229E" },
    { @"boxtimes;", @"\U000022A0" },
    { @"boxUL;", @"\U0000255D" },
    { @"boxUl;", @"\U0000255C" },
    { @"boxuL;", @"\U0000255B" },
    { @"boxul;", @"\U00002518" },
    { @"boxUR;", @"\U0000255A" },
    { @"boxUr;", @"\U00002559" },
    { @"boxuR;", @"\U00002558" },
    { @"boxur;", @"\U00002514" },
    { @"boxV;", @"\U00002551" },
    { @"boxv;", @"\U00002502" },
    { @"boxVH;", @"\U0000256C" },
    { @"boxVh;", @"\U0000256B" },
    { @"boxvH;", @"\U0000256A" },
    { @"boxvh;", @"\U0000253C" },
    { @"boxVL;", @"\U00002563" },
    { @"boxVl;", @"\U00002562" },
    { @"boxvL;", @"\U00002561" },
    { @"boxvl;", @"\U00002524" },
    { @"boxVR;", @"\U00002560" },
    { @"boxVr;", @"\U0000255F" },
    { @"boxvR;", @"\U0000255E" },
    { @"boxvr;", @"\U0000251C" },
    { @"bprime;", @"\U00002035" },
    { @"Breve;", @"\U000002D8" },
    { @"breve;", @"\U000002D8" },
    { @"brvbar;", @"\U000000A6" },
    { @"brvbar", @"\U000000A6" },
    { @"Bscr;", @"\U0000212C" },
    { @"bscr;", @"\U0001D4B7" },
    { @"bsemi;", @"\U0000204F" },
    { @"bsim;", @"\U0000223D" },
    { @"bsime;", @"\U000022CD" },
    { @"bsol;", @"\\" },
    { @"bsolb;", @"\U000029C5" },
    { @"bsolhsub;", @"\U000027C8" },
    { @"bull;", @"\U00002022" },
    { @"bullet;", @"\U00002022" },
    { @"bump;", @"\U0000224E" },
    { @"bumpE;", @"\U00002AAE" },
    { @"bumpe;", @"\U0000224F" },
    { @"Bumpeq;", @"\U0000224E" },
    { @"bumpeq;", @"\U0000224F" },
    { @"Cacute;", @"\U00000106" },
    { @"cacute;", @"\U00000107" },
    { @"Cap;", @"\U000022D2" },
    { @"cap;", @"\U00002229" },
    { @"capand;", @"\U00002A44" },
    { @"capbrcup;", @"\U00002A49" },
    { @"capcap;", @"\U00002A4B" },
    { @"capcup;", @"\U00002A47" },
    { @"capdot;", @"\U00002A40" },
    { @"CapitalDifferentialD;", @"\U00002145" },
    { @"caps;", @"\U00002229\U0000FE00" },
    { @"caret;", @"\U00002041" },
    { @"caron;", @"\U000002C7" },
    { @"Cayleys;", @"\U0000212D" },
    { @"ccaps;", @"\U00002A4D" },
    { @"Ccaron;", @"\U0000010C" },
    { @"ccaron;", @"\U0000010D" },
    { @"Ccedil;", @"\U000000C7" },
    { @"Ccedil", @"\U000000C7" },
    { @"ccedil;", @"\U000000E7" },
    { @"ccedil", @"\U000000E7" },
    { @"Ccirc;", @"\U00000108" },
    { @"ccirc;", @"\U00000109" },
    { @"Cconint;", @"\U00002230" },
    { @"ccups;", @"\U00002A4C" },
    { @"ccupssm;", @"\U00002A50" },
    { @"Cdot;", @"\U0000010A" },
    { @"cdot;", @"\U0000010B" },
    { @"cedil;", @"\U000000B8" },
    { @"cedil", @"\U000000B8" },
    { @"Cedilla;", @"\U000000B8" },
    { @"cemptyv;", @"\U000029B2" },
    { @"cent;", @"\U000000A2" },
    { @"cent", @"\U000000A2" },
    { @"CenterDot;", @"\U000000B7" },
    { @"centerdot;", @"\U000000B7" },
    { @"Cfr;", @"\U0000212D" },
    { @"cfr;", @"\U0001D520" },
    { @"CHcy;", @"\U00000427" },
    { @"chcy;", @"\U00000447" },
    { @"check;", @"\U00002713" },
    { @"checkmark;", @"\U00002713" },
    { @"Chi;", @"\U000003A7" },
    { @"chi;", @"\U000003C7" },
    { @"cir;", @"\U000025CB" },
    { @"circ;", @"\U000002C6" },
    { @"circeq;", @"\U00002257" },
    { @"circlearrowleft;", @"\U000021BA" },
    { @"circlearrowright;", @"\U000021BB" },
    { @"circledast;", @"\U0000229B" },
    { @"circledcirc;", @"\U0000229A" },
    { @"circleddash;", @"\U0000229D" },
    { @"CircleDot;", @"\U00002299" },
    { @"circledR;", @"\U000000AE" },
    { @"circledS;", @"\U000024C8" },
    { @"CircleMinus;", @"\U00002296" },
    { @"CirclePlus;", @"\U00002295" },
    { @"CircleTimes;", @"\U00002297" },
    { @"cirE;", @"\U000029C3" },
    { @"cire;", @"\U00002257" },
    { @"cirfnint;", @"\U00002A10" },
    { @"cirmid;", @"\U00002AEF" },
    { @"cirscir;", @"\U000029C2" },
    { @"ClockwiseContourIntegral;", @"\U00002232" },
    { @"CloseCurlyDoubleQuote;", @"\U0000201D" },
    { @"CloseCurlyQuote;", @"\U00002019" },
    { @"clubs;", @"\U00002663" },
    { @"clubsuit;", @"\U00002663" },
    { @"Colon;", @"\U00002237" },
    { @"colon;", @":" },
    { @"Colone;", @"\U00002A74" },
    { @"colone;", @"\U00002254" },
    { @"coloneq;", @"\U00002254" },
    { @"comma;", @"," },
    { @"commat;", @"\U00000040" },
    { @"comp;", @"\U00002201" },
    { @"compfn;", @"\U00002218" },
    { @"complement;", @"\U00002201" },
    { @"complexes;", @"\U00002102" },
    { @"cong;", @"\U00002245" },
    { @"congdot;", @"\U00002A6D" },
    { @"Congruent;", @"\U00002261" },
    { @"Conint;", @"\U0000222F" },
    { @"conint;", @"\U0000222E" },
    { @"ContourIntegral;", @"\U0000222E" },
    { @"Copf;", @"\U00002102" },
    { @"copf;", @"\U0001D554" },
    { @"coprod;", @"\U00002210" },
    { @"Coproduct;", @"\U00002210" },
    { @"COPY;", @"\U000000A9" },
    { @"COPY", @"\U000000A9" },
    { @"copy;", @"\U000000A9" },
    { @"copy", @"\U000000A9" },
    { @"copysr;", @"\U00002117" },
    { @"CounterClockwiseContourIntegral;", @"\U00002233" },
    { @"crarr;", @"\U000021B5" },
    { @"Cross;", @"\U00002A2F" },
    { @"cross;", @"\U00002717" },
    { @"Cscr;", @"\U0001D49E" },
    { @"cscr;", @"\U0001D4B8" },
    { @"csub;", @"\U00002ACF" },
    { @"csube;", @"\U00002AD1" },
    { @"csup;", @"\U00002AD0" },
    { @"csupe;", @"\U00002AD2" },
    { @"ctdot;", @"\U000022EF" },
    { @"cudarrl;", @"\U00002938" },
    { @"cudarrr;", @"\U00002935" },
    { @"cuepr;", @"\U000022DE" },
    { @"cuesc;", @"\U000022DF" },
    { @"cularr;", @"\U000021B6" },
    { @"cularrp;", @"\U0000293D" },
    { @"Cup;", @"\U000022D3" },
    { @"cup;", @"\U0000222A" },
    { @"cupbrcap;", @"\U00002A48" },
    { @"CupCap;", @"\U0000224D" },
    { @"cupcap;", @"\U00002A46" },
    { @"cupcup;", @"\U00002A4A" },
    { @"cupdot;", @"\U0000228D" },
    { @"cupor;", @"\U00002A45" },
    { @"cups;", @"\U0000222A\U0000FE00" },
    { @"curarr;", @"\U000021B7" },
    { @"curarrm;", @"\U0000293C" },
    { @"curlyeqprec;", @"\U000022DE" },
    { @"curlyeqsucc;", @"\U000022DF" },
    { @"curlyvee;", @"\U000022CE" },
    { @"curlywedge;", @"\U000022CF" },
    { @"curren;", @"\U000000A4" },
    { @"curren", @"\U000000A4" },
    { @"curvearrowleft;", @"\U000021B6" },
    { @"curvearrowright;", @"\U000021B7" },
    { @"cuvee;", @"\U000022CE" },
    { @"cuwed;", @"\U000022CF" },
    { @"cwconint;", @"\U00002232" },
    { @"cwint;", @"\U00002231" },
    { @"cylcty;", @"\U0000232D" },
    { @"Dagger;", @"\U00002021" },
    { @"dagger;", @"\U00002020" },
    { @"daleth;", @"\U00002138" },
    { @"Darr;", @"\U000021A1" },
    { @"dArr;", @"\U000021D3" },
    { @"darr;", @"\U00002193" },
    { @"dash;", @"\U00002010" },
    { @"Dashv;", @"\U00002AE4" },
    { @"dashv;", @"\U000022A3" },
    { @"dbkarow;", @"\U0000290F" },
    { @"dblac;", @"\U000002DD" },
    { @"Dcaron;", @"\U0000010E" },
    { @"dcaron;", @"\U0000010F" },
    { @"Dcy;", @"\U00000414" },
    { @"dcy;", @"\U00000434" },
    { @"DD;", @"\U00002145" },
    { @"dd;", @"\U00002146" },
    { @"ddagger;", @"\U00002021" },
    { @"ddarr;", @"\U000021CA" },
    { @"DDotrahd;", @"\U00002911" },
    { @"ddotseq;", @"\U00002A77" },
    { @"deg;", @"\U000000B0" },
    { @"deg", @"\U000000B0" },
    { @"Del;", @"\U00002207" },
    { @"Delta;", @"\U00000394" },
    { @"delta;", @"\U000003B4" },
    { @"demptyv;", @"\U000029B1" },
    { @"dfisht;", @"\U0000297F" },
    { @"Dfr;", @"\U0001D507" },
    { @"dfr;", @"\U0001D521" },
    { @"dHar;", @"\U00002965" },
    { @"dharl;", @"\U000021C3" },
    { @"dharr;", @"\U000021C2" },
    { @"DiacriticalAcute;", @"\U000000B4" },
    { @"DiacriticalDot;", @"\U000002D9" },
    { @"DiacriticalDoubleAcute;", @"\U000002DD" },
    { @"DiacriticalGrave;", @"\U00000060" },
    { @"DiacriticalTilde;", @"\U000002DC" },
    { @"diam;", @"\U000022C4" },
    { @"Diamond;", @"\U000022C4" },
    { @"diamond;", @"\U000022C4" },
    { @"diamondsuit;", @"\U00002666" },
    { @"diams;", @"\U00002666" },
    { @"die;", @"\U000000A8" },
    { @"DifferentialD;", @"\U00002146" },
    { @"digamma;", @"\U000003DD" },
    { @"disin;", @"\U000022F2" },
    { @"div;", @"\U000000F7" },
    { @"divide;", @"\U000000F7" },
    { @"divide", @"\U000000F7" },
    { @"divideontimes;", @"\U000022C7" },
    { @"divonx;", @"\U000022C7" },
    { @"DJcy;", @"\U00000402" },
    { @"djcy;", @"\U00000452" },
    { @"dlcorn;", @"\U0000231E" },
    { @"dlcrop;", @"\U0000230D" },
    { @"dollar;", @"\U00000024" },
    { @"Dopf;", @"\U0001D53B" },
    { @"dopf;", @"\U0001D555" },
    { @"Dot;", @"\U000000A8" },
    { @"dot;", @"\U000002D9" },
    { @"DotDot;", @"\U000020DC" },
    { @"doteq;", @"\U00002250" },
    { @"doteqdot;", @"\U00002251" },
    { @"DotEqual;", @"\U00002250" },
    { @"dotminus;", @"\U00002238" },
    { @"dotplus;", @"\U00002214" },
    { @"dotsquare;", @"\U000022A1" },
    { @"doublebarwedge;", @"\U00002306" },
    { @"DoubleContourIntegral;", @"\U0000222F" },
    { @"DoubleDot;", @"\U000000A8" },
    { @"DoubleDownArrow;", @"\U000021D3" },
    { @"DoubleLeftArrow;", @"\U000021D0" },
    { @"DoubleLeftRightArrow;", @"\U000021D4" },
    { @"DoubleLeftTee;", @"\U00002AE4" },
    { @"DoubleLongLeftArrow;", @"\U000027F8" },
    { @"DoubleLongLeftRightArrow;", @"\U000027FA" },
    { @"DoubleLongRightArrow;", @"\U000027F9" },
    { @"DoubleRightArrow;", @"\U000021D2" },
    { @"DoubleRightTee;", @"\U000022A8" },
    { @"DoubleUpArrow;", @"\U000021D1" },
    { @"DoubleUpDownArrow;", @"\U000021D5" },
    { @"DoubleVerticalBar;", @"\U00002225" },
    { @"DownArrow;", @"\U00002193" },
    { @"Downarrow;", @"\U000021D3" },
    { @"downarrow;", @"\U00002193" },
    { @"DownArrowBar;", @"\U00002913" },
    { @"DownArrowUpArrow;", @"\U000021F5" },
    { @"DownBreve;", @"\U00000311" },
    { @"downdownarrows;", @"\U000021CA" },
    { @"downharpoonleft;", @"\U000021C3" },
    { @"downharpoonright;", @"\U000021C2" },
    { @"DownLeftRightVector;", @"\U00002950" },
    { @"DownLeftTeeVector;", @"\U0000295E" },
    { @"DownLeftVector;", @"\U000021BD" },
    { @"DownLeftVectorBar;", @"\U00002956" },
    { @"DownRightTeeVector;", @"\U0000295F" },
    { @"DownRightVector;", @"\U000021C1" },
    { @"DownRightVectorBar;", @"\U00002957" },
    { @"DownTee;", @"\U000022A4" },
    { @"DownTeeArrow;", @"\U000021A7" },
    { @"drbkarow;", @"\U00002910" },
    { @"drcorn;", @"\U0000231F" },
    { @"drcrop;", @"\U0000230C" },
    { @"Dscr;", @"\U0001D49F" },
    { @"dscr;", @"\U0001D4B9" },
    { @"DScy;", @"\U00000405" },
    { @"dscy;", @"\U00000455" },
    { @"dsol;", @"\U000029F6" },
    { @"Dstrok;", @"\U00000110" },
    { @"dstrok;", @"\U00000111" },
    { @"dtdot;", @"\U000022F1" },
    { @"dtri;", @"\U000025BF" },
    { @"dtrif;", @"\U000025BE" },
    { @"duarr;", @"\U000021F5" },
    { @"duhar;", @"\U0000296F" },
    { @"dwangle;", @"\U000029A6" },
    { @"DZcy;", @"\U0000040F" },
    { @"dzcy;", @"\U0000045F" },
    { @"dzigrarr;", @"\U000027FF" },
    { @"Eacute;", @"\U000000C9" },
    { @"Eacute", @"\U000000C9" },
    { @"eacute;", @"\U000000E9" },
    { @"eacute", @"\U000000E9" },
    { @"easter;", @"\U00002A6E" },
    { @"Ecaron;", @"\U0000011A" },
    { @"ecaron;", @"\U0000011B" },
    { @"ecir;", @"\U00002256" },
    { @"Ecirc;", @"\U000000CA" },
    { @"Ecirc", @"\U000000CA" },
    { @"ecirc;", @"\U000000EA" },
    { @"ecirc", @"\U000000EA" },
    { @"ecolon;", @"\U00002255" },
    { @"Ecy;", @"\U0000042D" },
    { @"ecy;", @"\U0000044D" },
    { @"eDDot;", @"\U00002A77" },
    { @"Edot;", @"\U00000116" },
    { @"eDot;", @"\U00002251" },
    { @"edot;", @"\U00000117" },
    { @"ee;", @"\U00002147" },
    { @"efDot;", @"\U00002252" },
    { @"Efr;", @"\U0001D508" },
    { @"efr;", @"\U0001D522" },
    { @"eg;", @"\U00002A9A" },
    { @"Egrave;", @"\U000000C8" },
    { @"Egrave", @"\U000000C8" },
    { @"egrave;", @"\U000000E8" },
    { @"egrave", @"\U000000E8" },
    { @"egs;", @"\U00002A96" },
    { @"egsdot;", @"\U00002A98" },
    { @"el;", @"\U00002A99" },
    { @"Element;", @"\U00002208" },
    { @"elinters;", @"\U000023E7" },
    { @"ell;", @"\U00002113" },
    { @"els;", @"\U00002A95" },
    { @"elsdot;", @"\U00002A97" },
    { @"Emacr;", @"\U00000112" },
    { @"emacr;", @"\U00000113" },
    { @"empty;", @"\U00002205" },
    { @"emptyset;", @"\U00002205" },
    { @"EmptySmallSquare;", @"\U000025FB" },
    { @"emptyv;", @"\U00002205" },
    { @"EmptyVerySmallSquare;", @"\U000025AB" },
    { @"emsp;", @"\U00002003" },
    { @"emsp13;", @"\U00002004" },
    { @"emsp14;", @"\U00002005" },
    { @"ENG;", @"\U0000014A" },
    { @"eng;", @"\U0000014B" },
    { @"ensp;", @"\U00002002" },
    { @"Eogon;", @"\U00000118" },
    { @"eogon;", @"\U00000119" },
    { @"Eopf;", @"\U0001D53C" },
    { @"eopf;", @"\U0001D556" },
    { @"epar;", @"\U000022D5" },
    { @"eparsl;", @"\U000029E3" },
    { @"eplus;", @"\U00002A71" },
    { @"epsi;", @"\U000003B5" },
    { @"Epsilon;", @"\U00000395" },
    { @"epsilon;", @"\U000003B5" },
    { @"epsiv;", @"\U000003F5" },
    { @"eqcirc;", @"\U00002256" },
    { @"eqcolon;", @"\U00002255" },
    { @"eqsim;", @"\U00002242" },
    { @"eqslantgtr;", @"\U00002A96" },
    { @"eqslantless;", @"\U00002A95" },
    { @"Equal;", @"\U00002A75" },
    { @"equals;", @"=" },
    { @"EqualTilde;", @"\U00002242" },
    { @"equest;", @"\U0000225F" },
    { @"Equilibrium;", @"\U000021CC" },
    { @"equiv;", @"\U00002261" },
    { @"equivDD;", @"\U00002A78" },
    { @"eqvparsl;", @"\U000029E5" },
    { @"erarr;", @"\U00002971" },
    { @"erDot;", @"\U00002253" },
    { @"Escr;", @"\U00002130" },
    { @"escr;", @"\U0000212F" },
    { @"esdot;", @"\U00002250" },
    { @"Esim;", @"\U00002A73" },
    { @"esim;", @"\U00002242" },
    { @"Eta;", @"\U00000397" },
    { @"eta;", @"\U000003B7" },
    { @"ETH;", @"\U000000D0" },
    { @"ETH", @"\U000000D0" },
    { @"eth;", @"\U000000F0" },
    { @"eth", @"\U000000F0" },
    { @"Euml;", @"\U000000CB" },
    { @"Euml", @"\U000000CB" },
    { @"euml;", @"\U000000EB" },
    { @"euml", @"\U000000EB" },
    { @"euro;", @"\U000020AC" },
    { @"excl;", @"!" },
    { @"exist;", @"\U00002203" },
    { @"Exists;", @"\U00002203" },
    { @"expectation;", @"\U00002130" },
    { @"ExponentialE;", @"\U00002147" },
    { @"exponentiale;", @"\U00002147" },
    { @"fallingdotseq;", @"\U00002252" },
    { @"Fcy;", @"\U00000424" },
    { @"fcy;", @"\U00000444" },
    { @"female;", @"\U00002640" },
    { @"ffilig;", @"\U0000FB03" },
    { @"fflig;", @"\U0000FB00" },
    { @"ffllig;", @"\U0000FB04" },
    { @"Ffr;", @"\U0001D509" },
    { @"ffr;", @"\U0001D523" },
    { @"filig;", @"\U0000FB01" },
    { @"FilledSmallSquare;", @"\U000025FC" },
    { @"FilledVerySmallSquare;", @"\U000025AA" },
    { @"fjlig;", @"fj" },
    { @"flat;", @"\U0000266D" },
    { @"fllig;", @"\U0000FB02" },
    { @"fltns;", @"\U000025B1" },
    { @"fnof;", @"\U00000192" },
    { @"Fopf;", @"\U0001D53D" },
    { @"fopf;", @"\U0001D557" },
    { @"ForAll;", @"\U00002200" },
    { @"forall;", @"\U00002200" },
    { @"fork;", @"\U000022D4" },
    { @"forkv;", @"\U00002AD9" },
    { @"Fouriertrf;", @"\U00002131" },
    { @"fpartint;", @"\U00002A0D" },
    { @"frac12;", @"\U000000BD" },
    { @"frac12", @"\U000000BD" },
    { @"frac13;", @"\U00002153" },
    { @"frac14;", @"\U000000BC" },
    { @"frac14", @"\U000000BC" },
    { @"frac15;", @"\U00002155" },
    { @"frac16;", @"\U00002159" },
    { @"frac18;", @"\U0000215B" },
    { @"frac23;", @"\U00002154" },
    { @"frac25;", @"\U00002156" },
    { @"frac34;", @"\U000000BE" },
    { @"frac34", @"\U000000BE" },
    { @"frac35;", @"\U00002157" },
    { @"frac38;", @"\U0000215C" },
    { @"frac45;", @"\U00002158" },
    { @"frac56;", @"\U0000215A" },
    { @"frac58;", @"\U0000215D" },
    { @"frac78;", @"\U0000215E" },
    { @"frasl;", @"\U00002044" },
    { @"frown;", @"\U00002322" },
    { @"Fscr;", @"\U00002131" },
    { @"fscr;", @"\U0001D4BB" },
    { @"gacute;", @"\U000001F5" },
    { @"Gamma;", @"\U00000393" },
    { @"gamma;", @"\U000003B3" },
    { @"Gammad;", @"\U000003DC" },
    { @"gammad;", @"\U000003DD" },
    { @"gap;", @"\U00002A86" },
    { @"Gbreve;", @"\U0000011E" },
    { @"gbreve;", @"\U0000011F" },
    { @"Gcedil;", @"\U00000122" },
    { @"Gcirc;", @"\U0000011C" },
    { @"gcirc;", @"\U0000011D" },
    { @"Gcy;", @"\U00000413" },
    { @"gcy;", @"\U00000433" },
    { @"Gdot;", @"\U00000120" },
    { @"gdot;", @"\U00000121" },
    { @"gE;", @"\U00002267" },
    { @"ge;", @"\U00002265" },
    { @"gEl;", @"\U00002A8C" },
    { @"gel;", @"\U000022DB" },
    { @"geq;", @"\U00002265" },
    { @"geqq;", @"\U00002267" },
    { @"geqslant;", @"\U00002A7E" },
    { @"ges;", @"\U00002A7E" },
    { @"gescc;", @"\U00002AA9" },
    { @"gesdot;", @"\U00002A80" },
    { @"gesdoto;", @"\U00002A82" },
    { @"gesdotol;", @"\U00002A84" },
    { @"gesl;", @"\U000022DB\U0000FE00" },
    { @"gesles;", @"\U00002A94" },
    { @"Gfr;", @"\U0001D50A" },
    { @"gfr;", @"\U0001D524" },
    { @"Gg;", @"\U000022D9" },
    { @"gg;", @"\U0000226B" },
    { @"ggg;", @"\U000022D9" },
    { @"gimel;", @"\U00002137" },
    { @"GJcy;", @"\U00000403" },
    { @"gjcy;", @"\U00000453" },
    { @"gl;", @"\U00002277" },
    { @"gla;", @"\U00002AA5" },
    { @"glE;", @"\U00002A92" },
    { @"glj;", @"\U00002AA4" },
    { @"gnap;", @"\U00002A8A" },
    { @"gnapprox;", @"\U00002A8A" },
    { @"gnE;", @"\U00002269" },
    { @"gne;", @"\U00002A88" },
    { @"gneq;", @"\U00002A88" },
    { @"gneqq;", @"\U00002269" },
    { @"gnsim;", @"\U000022E7" },
    { @"Gopf;", @"\U0001D53E" },
    { @"gopf;", @"\U0001D558" },
    { @"grave;", @"\U00000060" },
    { @"GreaterEqual;", @"\U00002265" },
    { @"GreaterEqualLess;", @"\U000022DB" },
    { @"GreaterFullEqual;", @"\U00002267" },
    { @"GreaterGreater;", @"\U00002AA2" },
    { @"GreaterLess;", @"\U00002277" },
    { @"GreaterSlantEqual;", @"\U00002A7E" },
    { @"GreaterTilde;", @"\U00002273" },
    { @"Gscr;", @"\U0001D4A2" },
    { @"gscr;", @"\U0000210A" },
    { @"gsim;", @"\U00002273" },
    { @"gsime;", @"\U00002A8E" },
    { @"gsiml;", @"\U00002A90" },
    { @"GT;", @">" },
    { @"GT", @">" },
    { @"Gt;", @"\U0000226B" },
    { @"gt;", @">" },
    { @"gt", @">" },
    { @"gtcc;", @"\U00002AA7" },
    { @"gtcir;", @"\U00002A7A" },
    { @"gtdot;", @"\U000022D7" },
    { @"gtlPar;", @"\U00002995" },
    { @"gtquest;", @"\U00002A7C" },
    { @"gtrapprox;", @"\U00002A86" },
    { @"gtrarr;", @"\U00002978" },
    { @"gtrdot;", @"\U000022D7" },
    { @"gtreqless;", @"\U000022DB" },
    { @"gtreqqless;", @"\U00002A8C" },
    { @"gtrless;", @"\U00002277" },
    { @"gtrsim;", @"\U00002273" },
    { @"gvertneqq;", @"\U00002269\U0000FE00" },
    { @"gvnE;", @"\U00002269\U0000FE00" },
    { @"Hacek;", @"\U000002C7" },
    { @"hairsp;", @"\U0000200A" },
    { @"half;", @"\U000000BD" },
    { @"hamilt;", @"\U0000210B" },
    { @"HARDcy;", @"\U0000042A" },
    { @"hardcy;", @"\U0000044A" },
    { @"hArr;", @"\U000021D4" },
    { @"harr;", @"\U00002194" },
    { @"harrcir;", @"\U00002948" },
    { @"harrw;", @"\U000021AD" },
    { @"Hat;", @"^" },
    { @"hbar;", @"\U0000210F" },
    { @"Hcirc;", @"\U00000124" },
    { @"hcirc;", @"\U00000125" },
    { @"hearts;", @"\U00002665" },
    { @"heartsuit;", @"\U00002665" },
    { @"hellip;", @"\U00002026" },
    { @"hercon;", @"\U000022B9" },
    { @"Hfr;", @"\U0000210C" },
    { @"hfr;", @"\U0001D525" },
    { @"HilbertSpace;", @"\U0000210B" },
    { @"hksearow;", @"\U00002925" },
    { @"hkswarow;", @"\U00002926" },
    { @"hoarr;", @"\U000021FF" },
    { @"homtht;", @"\U0000223B" },
    { @"hookleftarrow;", @"\U000021A9" },
    { @"hookrightarrow;", @"\U000021AA" },
    { @"Hopf;", @"\U0000210D" },
    { @"hopf;", @"\U0001D559" },
    { @"horbar;", @"\U00002015" },
    { @"HorizontalLine;", @"\U00002500" },
    { @"Hscr;", @"\U0000210B" },
    { @"hscr;", @"\U0001D4BD" },
    { @"hslash;", @"\U0000210F" },
    { @"Hstrok;", @"\U00000126" },
    { @"hstrok;", @"\U00000127" },
    { @"HumpDownHump;", @"\U0000224E" },
    { @"HumpEqual;", @"\U0000224F" },
    { @"hybull;", @"\U00002043" },
    { @"hyphen;", @"\U00002010" },
    { @"Iacute;", @"\U000000CD" },
    { @"Iacute", @"\U000000CD" },
    { @"iacute;", @"\U000000ED" },
    { @"iacute", @"\U000000ED" },
    { @"ic;", @"\U00002063" },
    { @"Icirc;", @"\U000000CE" },
    { @"Icirc", @"\U000000CE" },
    { @"icirc;", @"\U000000EE" },
    { @"icirc", @"\U000000EE" },
    { @"Icy;", @"\U00000418" },
    { @"icy;", @"\U00000438" },
    { @"Idot;", @"\U00000130" },
    { @"IEcy;", @"\U00000415" },
    { @"iecy;", @"\U00000435" },
    { @"iexcl;", @"\U000000A1" },
    { @"iexcl", @"\U000000A1" },
    { @"iff;", @"\U000021D4" },
    { @"Ifr;", @"\U00002111" },
    { @"ifr;", @"\U0001D526" },
    { @"Igrave;", @"\U000000CC" },
    { @"Igrave", @"\U000000CC" },
    { @"igrave;", @"\U000000EC" },
    { @"igrave", @"\U000000EC" },
    { @"ii;", @"\U00002148" },
    { @"iiiint;", @"\U00002A0C" },
    { @"iiint;", @"\U0000222D" },
    { @"iinfin;", @"\U000029DC" },
    { @"iiota;", @"\U00002129" },
    { @"IJlig;", @"\U00000132" },
    { @"ijlig;", @"\U00000133" },
    { @"Im;", @"\U00002111" },
    { @"Imacr;", @"\U0000012A" },
    { @"imacr;", @"\U0000012B" },
    { @"image;", @"\U00002111" },
    { @"ImaginaryI;", @"\U00002148" },
    { @"imagline;", @"\U00002110" },
    { @"imagpart;", @"\U00002111" },
    { @"imath;", @"\U00000131" },
    { @"imof;", @"\U000022B7" },
    { @"imped;", @"\U000001B5" },
    { @"Implies;", @"\U000021D2" },
    { @"in;", @"\U00002208" },
    { @"incare;", @"\U00002105" },
    { @"infin;", @"\U0000221E" },
    { @"infintie;", @"\U000029DD" },
    { @"inodot;", @"\U00000131" },
    { @"Int;", @"\U0000222C" },
    { @"int;", @"\U0000222B" },
    { @"intcal;", @"\U000022BA" },
    { @"integers;", @"\U00002124" },
    { @"Integral;", @"\U0000222B" },
    { @"intercal;", @"\U000022BA" },
    { @"Intersection;", @"\U000022C2" },
    { @"intlarhk;", @"\U00002A17" },
    { @"intprod;", @"\U00002A3C" },
    { @"InvisibleComma;", @"\U00002063" },
    { @"InvisibleTimes;", @"\U00002062" },
    { @"IOcy;", @"\U00000401" },
    { @"iocy;", @"\U00000451" },
    { @"Iogon;", @"\U0000012E" },
    { @"iogon;", @"\U0000012F" },
    { @"Iopf;", @"\U0001D540" },
    { @"iopf;", @"\U0001D55A" },
    { @"Iota;", @"\U00000399" },
    { @"iota;", @"\U000003B9" },
    { @"iprod;", @"\U00002A3C" },
    { @"iquest;", @"\U000000BF" },
    { @"iquest", @"\U000000BF" },
    { @"Iscr;", @"\U00002110" },
    { @"iscr;", @"\U0001D4BE" },
    { @"isin;", @"\U00002208" },
    { @"isindot;", @"\U000022F5" },
    { @"isinE;", @"\U000022F9" },
    { @"isins;", @"\U000022F4" },
    { @"isinsv;", @"\U000022F3" },
    { @"isinv;", @"\U00002208" },
    { @"it;", @"\U00002062" },
    { @"Itilde;", @"\U00000128" },
    { @"itilde;", @"\U00000129" },
    { @"Iukcy;", @"\U00000406" },
    { @"iukcy;", @"\U00000456" },
    { @"Iuml;", @"\U000000CF" },
    { @"Iuml", @"\U000000CF" },
    { @"iuml;", @"\U000000EF" },
    { @"iuml", @"\U000000EF" },
    { @"Jcirc;", @"\U00000134" },
    { @"jcirc;", @"\U00000135" },
    { @"Jcy;", @"\U00000419" },
    { @"jcy;", @"\U00000439" },
    { @"Jfr;", @"\U0001D50D" },
    { @"jfr;", @"\U0001D527" },
    { @"jmath;", @"\U00000237" },
    { @"Jopf;", @"\U0001D541" },
    { @"jopf;", @"\U0001D55B" },
    { @"Jscr;", @"\U0001D4A5" },
    { @"jscr;", @"\U0001D4BF" },
    { @"Jsercy;", @"\U00000408" },
    { @"jsercy;", @"\U00000458" },
    { @"Jukcy;", @"\U00000404" },
    { @"jukcy;", @"\U00000454" },
    { @"Kappa;", @"\U0000039A" },
    { @"kappa;", @"\U000003BA" },
    { @"kappav;", @"\U000003F0" },
    { @"Kcedil;", @"\U00000136" },
    { @"kcedil;", @"\U00000137" },
    { @"Kcy;", @"\U0000041A" },
    { @"kcy;", @"\U0000043A" },
    { @"Kfr;", @"\U0001D50E" },
    { @"kfr;", @"\U0001D528" },
    { @"kgreen;", @"\U00000138" },
    { @"KHcy;", @"\U00000425" },
    { @"khcy;", @"\U00000445" },
    { @"KJcy;", @"\U0000040C" },
    { @"kjcy;", @"\U0000045C" },
    { @"Kopf;", @"\U0001D542" },
    { @"kopf;", @"\U0001D55C" },
    { @"Kscr;", @"\U0001D4A6" },
    { @"kscr;", @"\U0001D4C0" },
    { @"lAarr;", @"\U000021DA" },
    { @"Lacute;", @"\U00000139" },
    { @"lacute;", @"\U0000013A" },
    { @"laemptyv;", @"\U000029B4" },
    { @"lagran;", @"\U00002112" },
    { @"Lambda;", @"\U0000039B" },
    { @"lambda;", @"\U000003BB" },
    { @"Lang;", @"\U000027EA" },
    { @"lang;", @"\U000027E8" },
    { @"langd;", @"\U00002991" },
    { @"langle;", @"\U000027E8" },
    { @"lap;", @"\U00002A85" },
    { @"Laplacetrf;", @"\U00002112" },
    { @"laquo;", @"\U000000AB" },
    { @"laquo", @"\U000000AB" },
    { @"Larr;", @"\U0000219E" },
    { @"lArr;", @"\U000021D0" },
    { @"larr;", @"\U00002190" },
    { @"larrb;", @"\U000021E4" },
    { @"larrbfs;", @"\U0000291F" },
    { @"larrfs;", @"\U0000291D" },
    { @"larrhk;", @"\U000021A9" },
    { @"larrlp;", @"\U000021AB" },
    { @"larrpl;", @"\U00002939" },
    { @"larrsim;", @"\U00002973" },
    { @"larrtl;", @"\U000021A2" },
    { @"lat;", @"\U00002AAB" },
    { @"lAtail;", @"\U0000291B" },
    { @"latail;", @"\U00002919" },
    { @"late;", @"\U00002AAD" },
    { @"lates;", @"\U00002AAD\U0000FE00" },
    { @"lBarr;", @"\U0000290E" },
    { @"lbarr;", @"\U0000290C" },
    { @"lbbrk;", @"\U00002772" },
    { @"lbrace;", @"{" },
    { @"lbrack;", @"[" },
    { @"lbrke;", @"\U0000298B" },
    { @"lbrksld;", @"\U0000298F" },
    { @"lbrkslu;", @"\U0000298D" },
    { @"Lcaron;", @"\U0000013D" },
    { @"lcaron;", @"\U0000013E" },
    { @"Lcedil;", @"\U0000013B" },
    { @"lcedil;", @"\U0000013C" },
    { @"lceil;", @"\U00002308" },
    { @"lcub;", @"{" },
    { @"Lcy;", @"\U0000041B" },
    { @"lcy;", @"\U0000043B" },
    { @"ldca;", @"\U00002936" },
    { @"ldquo;", @"\U0000201C" },
    { @"ldquor;", @"\U0000201E" },
    { @"ldrdhar;", @"\U00002967" },
    { @"ldrushar;", @"\U0000294B" },
    { @"ldsh;", @"\U000021B2" },
    { @"lE;", @"\U00002266" },
    { @"le;", @"\U00002264" },
    { @"LeftAngleBracket;", @"\U000027E8" },
    { @"LeftArrow;", @"\U00002190" },
    { @"Leftarrow;", @"\U000021D0" },
    { @"leftarrow;", @"\U00002190" },
    { @"LeftArrowBar;", @"\U000021E4" },
    { @"LeftArrowRightArrow;", @"\U000021C6" },
    { @"leftarrowtail;", @"\U000021A2" },
    { @"LeftCeiling;", @"\U00002308" },
    { @"LeftDoubleBracket;", @"\U000027E6" },
    { @"LeftDownTeeVector;", @"\U00002961" },
    { @"LeftDownVector;", @"\U000021C3" },
    { @"LeftDownVectorBar;", @"\U00002959" },
    { @"LeftFloor;", @"\U0000230A" },
    { @"leftharpoondown;", @"\U000021BD" },
    { @"leftharpoonup;", @"\U000021BC" },
    { @"leftleftarrows;", @"\U000021C7" },
    { @"LeftRightArrow;", @"\U00002194" },
    { @"Leftrightarrow;", @"\U000021D4" },
    { @"leftrightarrow;", @"\U00002194" },
    { @"leftrightarrows;", @"\U000021C6" },
    { @"leftrightharpoons;", @"\U000021CB" },
    { @"leftrightsquigarrow;", @"\U000021AD" },
    { @"LeftRightVector;", @"\U0000294E" },
    { @"LeftTee;", @"\U000022A3" },
    { @"LeftTeeArrow;", @"\U000021A4" },
    { @"LeftTeeVector;", @"\U0000295A" },
    { @"leftthreetimes;", @"\U000022CB" },
    { @"LeftTriangle;", @"\U000022B2" },
    { @"LeftTriangleBar;", @"\U000029CF" },
    { @"LeftTriangleEqual;", @"\U000022B4" },
    { @"LeftUpDownVector;", @"\U00002951" },
    { @"LeftUpTeeVector;", @"\U00002960" },
    { @"LeftUpVector;", @"\U000021BF" },
    { @"LeftUpVectorBar;", @"\U00002958" },
    { @"LeftVector;", @"\U000021BC" },
    { @"LeftVectorBar;", @"\U00002952" },
    { @"lEg;", @"\U00002A8B" },
    { @"leg;", @"\U000022DA" },
    { @"leq;", @"\U00002264" },
    { @"leqq;", @"\U00002266" },
    { @"leqslant;", @"\U00002A7D" },
    { @"les;", @"\U00002A7D" },
    { @"lescc;", @"\U00002AA8" },
    { @"lesdot;", @"\U00002A7F" },
    { @"lesdoto;", @"\U00002A81" },
    { @"lesdotor;", @"\U00002A83" },
    { @"lesg;", @"\U000022DA\U0000FE00" },
    { @"lesges;", @"\U00002A93" },
    { @"lessapprox;", @"\U00002A85" },
    { @"lessdot;", @"\U000022D6" },
    { @"lesseqgtr;", @"\U000022DA" },
    { @"lesseqqgtr;", @"\U00002A8B" },
    { @"LessEqualGreater;", @"\U000022DA" },
    { @"LessFullEqual;", @"\U00002266" },
    { @"LessGreater;", @"\U00002276" },
    { @"lessgtr;", @"\U00002276" },
    { @"LessLess;", @"\U00002AA1" },
    { @"lesssim;", @"\U00002272" },
    { @"LessSlantEqual;", @"\U00002A7D" },
    { @"LessTilde;", @"\U00002272" },
    { @"lfisht;", @"\U0000297C" },
    { @"lfloor;", @"\U0000230A" },
    { @"Lfr;", @"\U0001D50F" },
    { @"lfr;", @"\U0001D529" },
    { @"lg;", @"\U00002276" },
    { @"lgE;", @"\U00002A91" },
    { @"lHar;", @"\U00002962" },
    { @"lhard;", @"\U000021BD" },
    { @"lharu;", @"\U000021BC" },
    { @"lharul;", @"\U0000296A" },
    { @"lhblk;", @"\U00002584" },
    { @"LJcy;", @"\U00000409" },
    { @"ljcy;", @"\U00000459" },
    { @"Ll;", @"\U000022D8" },
    { @"ll;", @"\U0000226A" },
    { @"llarr;", @"\U000021C7" },
    { @"llcorner;", @"\U0000231E" },
    { @"Lleftarrow;", @"\U000021DA" },
    { @"llhard;", @"\U0000296B" },
    { @"lltri;", @"\U000025FA" },
    { @"Lmidot;", @"\U0000013F" },
    { @"lmidot;", @"\U00000140" },
    { @"lmoust;", @"\U000023B0" },
    { @"lmoustache;", @"\U000023B0" },
    { @"lnap;", @"\U00002A89" },
    { @"lnapprox;", @"\U00002A89" },
    { @"lnE;", @"\U00002268" },
    { @"lne;", @"\U00002A87" },
    { @"lneq;", @"\U00002A87" },
    { @"lneqq;", @"\U00002268" },
    { @"lnsim;", @"\U000022E6" },
    { @"loang;", @"\U000027EC" },
    { @"loarr;", @"\U000021FD" },
    { @"lobrk;", @"\U000027E6" },
    { @"LongLeftArrow;", @"\U000027F5" },
    { @"Longleftarrow;", @"\U000027F8" },
    { @"longleftarrow;", @"\U000027F5" },
    { @"LongLeftRightArrow;", @"\U000027F7" },
    { @"Longleftrightarrow;", @"\U000027FA" },
    { @"longleftrightarrow;", @"\U000027F7" },
    { @"longmapsto;", @"\U000027FC" },
    { @"LongRightArrow;", @"\U000027F6" },
    { @"Longrightarrow;", @"\U000027F9" },
    { @"longrightarrow;", @"\U000027F6" },
    { @"looparrowleft;", @"\U000021AB" },
    { @"looparrowright;", @"\U000021AC" },
    { @"lopar;", @"\U00002985" },
    { @"Lopf;", @"\U0001D543" },
    { @"lopf;", @"\U0001D55D" },
    { @"loplus;", @"\U00002A2D" },
    { @"lotimes;", @"\U00002A34" },
    { @"lowast;", @"\U00002217" },
    { @"lowbar;", @"_" },
    { @"LowerLeftArrow;", @"\U00002199" },
    { @"LowerRightArrow;", @"\U00002198" },
    { @"loz;", @"\U000025CA" },
    { @"lozenge;", @"\U000025CA" },
    { @"lozf;", @"\U000029EB" },
    { @"lpar;", @"(" },
    { @"lparlt;", @"\U00002993" },
    { @"lrarr;", @"\U000021C6" },
    { @"lrcorner;", @"\U0000231F" },
    { @"lrhar;", @"\U000021CB" },
    { @"lrhard;", @"\U0000296D" },
    { @"lrm;", @"\U0000200E" },
    { @"lrtri;", @"\U000022BF" },
    { @"lsaquo;", @"\U00002039" },
    { @"Lscr;", @"\U00002112" },
    { @"lscr;", @"\U0001D4C1" },
    { @"Lsh;", @"\U000021B0" },
    { @"lsh;", @"\U000021B0" },
    { @"lsim;", @"\U00002272" },
    { @"lsime;", @"\U00002A8D" },
    { @"lsimg;", @"\U00002A8F" },
    { @"lsqb;", @"[" },
    { @"lsquo;", @"\U00002018" },
    { @"lsquor;", @"\U0000201A" },
    { @"Lstrok;", @"\U00000141" },
    { @"lstrok;", @"\U00000142" },
    { @"LT;", @"<" },
    { @"LT", @"<" },
    { @"Lt;", @"\U0000226A" },
    { @"lt;", @"<" },
    { @"lt", @"<" },
    { @"ltcc;", @"\U00002AA6" },
    { @"ltcir;", @"\U00002A79" },
    { @"ltdot;", @"\U000022D6" },
    { @"lthree;", @"\U000022CB" },
    { @"ltimes;", @"\U000022C9" },
    { @"ltlarr;", @"\U00002976" },
    { @"ltquest;", @"\U00002A7B" },
    { @"ltri;", @"\U000025C3" },
    { @"ltrie;", @"\U000022B4" },
    { @"ltrif;", @"\U000025C2" },
    { @"ltrPar;", @"\U00002996" },
    { @"lurdshar;", @"\U0000294A" },
    { @"luruhar;", @"\U00002966" },
    { @"lvertneqq;", @"\U00002268\U0000FE00" },
    { @"lvnE;", @"\U00002268\U0000FE00" },
    { @"macr;", @"\U000000AF" },
    { @"macr", @"\U000000AF" },
    { @"male;", @"\U00002642" },
    { @"malt;", @"\U00002720" },
    { @"maltese;", @"\U00002720" },
    { @"Map;", @"\U00002905" },
    { @"map;", @"\U000021A6" },
    { @"mapsto;", @"\U000021A6" },
    { @"mapstodown;", @"\U000021A7" },
    { @"mapstoleft;", @"\U000021A4" },
    { @"mapstoup;", @"\U000021A5" },
    { @"marker;", @"\U000025AE" },
    { @"mcomma;", @"\U00002A29" },
    { @"Mcy;", @"\U0000041C" },
    { @"mcy;", @"\U0000043C" },
    { @"mdash;", @"\U00002014" },
    { @"mDDot;", @"\U0000223A" },
    { @"measuredangle;", @"\U00002221" },
    { @"MediumSpace;", @"\U0000205F" },
    { @"Mellintrf;", @"\U00002133" },
    { @"Mfr;", @"\U0001D510" },
    { @"mfr;", @"\U0001D52A" },
    { @"mho;", @"\U00002127" },
    { @"micro;", @"\U000000B5" },
    { @"micro", @"\U000000B5" },
    { @"mid;", @"\U00002223" },
    { @"midast;", @"*" },
    { @"midcir;", @"\U00002AF0" },
    { @"middot;", @"\U000000B7" },
    { @"middot", @"\U000000B7" },
    { @"minus;", @"\U00002212" },
    { @"minusb;", @"\U0000229F" },
    { @"minusd;", @"\U00002238" },
    { @"minusdu;", @"\U00002A2A" },
    { @"MinusPlus;", @"\U00002213" },
    { @"mlcp;", @"\U00002ADB" },
    { @"mldr;", @"\U00002026" },
    { @"mnplus;", @"\U00002213" },
    { @"models;", @"\U000022A7" },
    { @"Mopf;", @"\U0001D544" },
    { @"mopf;", @"\U0001D55E" },
    { @"mp;", @"\U00002213" },
    { @"Mscr;", @"\U00002133" },
    { @"mscr;", @"\U0001D4C2" },
    { @"mstpos;", @"\U0000223E" },
    { @"Mu;", @"\U0000039C" },
    { @"mu;", @"\U000003BC" },
    { @"multimap;", @"\U000022B8" },
    { @"mumap;", @"\U000022B8" },
    { @"nabla;", @"\U00002207" },
    { @"Nacute;", @"\U00000143" },
    { @"nacute;", @"\U00000144" },
    { @"nang;", @"\U00002220\U000020D2" },
    { @"nap;", @"\U00002249" },
    { @"napE;", @"\U00002A70\U00000338" },
    { @"napid;", @"\U0000224B\U00000338" },
    { @"napos;", @"\U00000149" },
    { @"napprox;", @"\U00002249" },
    { @"natur;", @"\U0000266E" },
    { @"natural;", @"\U0000266E" },
    { @"naturals;", @"\U00002115" },
    { @"nbsp;", @"\U000000A0" },
    { @"nbsp", @"\U000000A0" },
    { @"nbump;", @"\U0000224E\U00000338" },
    { @"nbumpe;", @"\U0000224F\U00000338" },
    { @"ncap;", @"\U00002A43" },
    { @"Ncaron;", @"\U00000147" },
    { @"ncaron;", @"\U00000148" },
    { @"Ncedil;", @"\U00000145" },
    { @"ncedil;", @"\U00000146" },
    { @"ncong;", @"\U00002247" },
    { @"ncongdot;", @"\U00002A6D\U00000338" },
    { @"ncup;", @"\U00002A42" },
    { @"Ncy;", @"\U0000041D" },
    { @"ncy;", @"\U0000043D" },
    { @"ndash;", @"\U00002013" },
    { @"ne;", @"\U00002260" },
    { @"nearhk;", @"\U00002924" },
    { @"neArr;", @"\U000021D7" },
    { @"nearr;", @"\U00002197" },
    { @"nearrow;", @"\U00002197" },
    { @"nedot;", @"\U00002250\U00000338" },
    { @"NegativeMediumSpace;", @"\U0000200B" },
    { @"NegativeThickSpace;", @"\U0000200B" },
    { @"NegativeThinSpace;", @"\U0000200B" },
    { @"NegativeVeryThinSpace;", @"\U0000200B" },
    { @"nequiv;", @"\U00002262" },
    { @"nesear;", @"\U00002928" },
    { @"nesim;", @"\U00002242\U00000338" },
    { @"NestedGreaterGreater;", @"\U0000226B" },
    { @"NestedLessLess;", @"\U0000226A" },
    { @"NewLine;", @"\n" },
    { @"nexist;", @"\U00002204" },
    { @"nexists;", @"\U00002204" },
    { @"Nfr;", @"\U0001D511" },
    { @"nfr;", @"\U0001D52B" },
    { @"ngE;", @"\U00002267\U00000338" },
    { @"nge;", @"\U00002271" },
    { @"ngeq;", @"\U00002271" },
    { @"ngeqq;", @"\U00002267\U00000338" },
    { @"ngeqslant;", @"\U00002A7E\U00000338" },
    { @"nges;", @"\U00002A7E\U00000338" },
    { @"nGg;", @"\U000022D9\U00000338" },
    { @"ngsim;", @"\U00002275" },
    { @"nGt;", @"\U0000226B\U000020D2" },
    { @"ngt;", @"\U0000226F" },
    { @"ngtr;", @"\U0000226F" },
    { @"nGtv;", @"\U0000226B\U00000338" },
    { @"nhArr;", @"\U000021CE" },
    { @"nharr;", @"\U000021AE" },
    { @"nhpar;", @"\U00002AF2" },
    { @"ni;", @"\U0000220B" },
    { @"nis;", @"\U000022FC" },
    { @"nisd;", @"\U000022FA" },
    { @"niv;", @"\U0000220B" },
    { @"NJcy;", @"\U0000040A" },
    { @"njcy;", @"\U0000045A" },
    { @"nlArr;", @"\U000021CD" },
    { @"nlarr;", @"\U0000219A" },
    { @"nldr;", @"\U00002025" },
    { @"nlE;", @"\U00002266\U00000338" },
    { @"nle;", @"\U00002270" },
    { @"nLeftarrow;", @"\U000021CD" },
    { @"nleftarrow;", @"\U0000219A" },
    { @"nLeftrightarrow;", @"\U000021CE" },
    { @"nleftrightarrow;", @"\U000021AE" },
    { @"nleq;", @"\U00002270" },
    { @"nleqq;", @"\U00002266\U00000338" },
    { @"nleqslant;", @"\U00002A7D\U00000338" },
    { @"nles;", @"\U00002A7D\U00000338" },
    { @"nless;", @"\U0000226E" },
    { @"nLl;", @"\U000022D8\U00000338" },
    { @"nlsim;", @"\U00002274" },
    { @"nLt;", @"\U0000226A\U000020D2" },
    { @"nlt;", @"\U0000226E" },
    { @"nltri;", @"\U000022EA" },
    { @"nltrie;", @"\U000022EC" },
    { @"nLtv;", @"\U0000226A\U00000338" },
    { @"nmid;", @"\U00002224" },
    { @"NoBreak;", @"\U00002060" },
    { @"NonBreakingSpace;", @"\U000000A0" },
    { @"Nopf;", @"\U00002115" },
    { @"nopf;", @"\U0001D55F" },
    { @"Not;", @"\U00002AEC" },
    { @"not;", @"\U000000AC" },
    { @"not", @"\U000000AC" },
    { @"NotCongruent;", @"\U00002262" },
    { @"NotCupCap;", @"\U0000226D" },
    { @"NotDoubleVerticalBar;", @"\U00002226" },
    { @"NotElement;", @"\U00002209" },
    { @"NotEqual;", @"\U00002260" },
    { @"NotEqualTilde;", @"\U00002242\U00000338" },
    { @"NotExists;", @"\U00002204" },
    { @"NotGreater;", @"\U0000226F" },
    { @"NotGreaterEqual;", @"\U00002271" },
    { @"NotGreaterFullEqual;", @"\U00002267\U00000338" },
    { @"NotGreaterGreater;", @"\U0000226B\U00000338" },
    { @"NotGreaterLess;", @"\U00002279" },
    { @"NotGreaterSlantEqual;", @"\U00002A7E\U00000338" },
    { @"NotGreaterTilde;", @"\U00002275" },
    { @"NotHumpDownHump;", @"\U0000224E\U00000338" },
    { @"NotHumpEqual;", @"\U0000224F\U00000338" },
    { @"notin;", @"\U00002209" },
    { @"notindot;", @"\U000022F5\U00000338" },
    { @"notinE;", @"\U000022F9\U00000338" },
    { @"notinva;", @"\U00002209" },
    { @"notinvb;", @"\U000022F7" },
    { @"notinvc;", @"\U000022F6" },
    { @"NotLeftTriangle;", @"\U000022EA" },
    { @"NotLeftTriangleBar;", @"\U000029CF\U00000338" },
    { @"NotLeftTriangleEqual;", @"\U000022EC" },
    { @"NotLess;", @"\U0000226E" },
    { @"NotLessEqual;", @"\U00002270" },
    { @"NotLessGreater;", @"\U00002278" },
    { @"NotLessLess;", @"\U0000226A\U00000338" },
    { @"NotLessSlantEqual;", @"\U00002A7D\U00000338" },
    { @"NotLessTilde;", @"\U00002274" },
    { @"NotNestedGreaterGreater;", @"\U00002AA2\U00000338" },
    { @"NotNestedLessLess;", @"\U00002AA1\U00000338" },
    { @"notni;", @"\U0000220C" },
    { @"notniva;", @"\U0000220C" },
    { @"notnivb;", @"\U000022FE" },
    { @"notnivc;", @"\U000022FD" },
    { @"NotPrecedes;", @"\U00002280" },
    { @"NotPrecedesEqual;", @"\U00002AAF\U00000338" },
    { @"NotPrecedesSlantEqual;", @"\U000022E0" },
    { @"NotReverseElement;", @"\U0000220C" },
    { @"NotRightTriangle;", @"\U000022EB" },
    { @"NotRightTriangleBar;", @"\U000029D0\U00000338" },
    { @"NotRightTriangleEqual;", @"\U000022ED" },
    { @"NotSquareSubset;", @"\U0000228F\U00000338" },
    { @"NotSquareSubsetEqual;", @"\U000022E2" },
    { @"NotSquareSuperset;", @"\U00002290\U00000338" },
    { @"NotSquareSupersetEqual;", @"\U000022E3" },
    { @"NotSubset;", @"\U00002282\U000020D2" },
    { @"NotSubsetEqual;", @"\U00002288" },
    { @"NotSucceeds;", @"\U00002281" },
    { @"NotSucceedsEqual;", @"\U00002AB0\U00000338" },
    { @"NotSucceedsSlantEqual;", @"\U000022E1" },
    { @"NotSucceedsTilde;", @"\U0000227F\U00000338" },
    { @"NotSuperset;", @"\U00002283\U000020D2" },
    { @"NotSupersetEqual;", @"\U00002289" },
    { @"NotTilde;", @"\U00002241" },
    { @"NotTildeEqual;", @"\U00002244" },
    { @"NotTildeFullEqual;", @"\U00002247" },
    { @"NotTildeTilde;", @"\U00002249" },
    { @"NotVerticalBar;", @"\U00002224" },
    { @"npar;", @"\U00002226" },
    { @"nparallel;", @"\U00002226" },
    { @"nparsl;", @"\U00002AFD\U000020E5" },
    { @"npart;", @"\U00002202\U00000338" },
    { @"npolint;", @"\U00002A14" },
    { @"npr;", @"\U00002280" },
    { @"nprcue;", @"\U000022E0" },
    { @"npre;", @"\U00002AAF\U00000338" },
    { @"nprec;", @"\U00002280" },
    { @"npreceq;", @"\U00002AAF\U00000338" },
    { @"nrArr;", @"\U000021CF" },
    { @"nrarr;", @"\U0000219B" },
    { @"nrarrc;", @"\U00002933\U00000338" },
    { @"nrarrw;", @"\U0000219D\U00000338" },
    { @"nRightarrow;", @"\U000021CF" },
    { @"nrightarrow;", @"\U0000219B" },
    { @"nrtri;", @"\U000022EB" },
    { @"nrtrie;", @"\U000022ED" },
    { @"nsc;", @"\U00002281" },
    { @"nsccue;", @"\U000022E1" },
    { @"nsce;", @"\U00002AB0\U00000338" },
    { @"Nscr;", @"\U0001D4A9" },
    { @"nscr;", @"\U0001D4C3" },
    { @"nshortmid;", @"\U00002224" },
    { @"nshortparallel;", @"\U00002226" },
    { @"nsim;", @"\U00002241" },
    { @"nsime;", @"\U00002244" },
    { @"nsimeq;", @"\U00002244" },
    { @"nsmid;", @"\U00002224" },
    { @"nspar;", @"\U00002226" },
    { @"nsqsube;", @"\U000022E2" },
    { @"nsqsupe;", @"\U000022E3" },
    { @"nsub;", @"\U00002284" },
    { @"nsubE;", @"\U00002AC5\U00000338" },
    { @"nsube;", @"\U00002288" },
    { @"nsubset;", @"\U00002282\U000020D2" },
    { @"nsubseteq;", @"\U00002288" },
    { @"nsubseteqq;", @"\U00002AC5\U00000338" },
    { @"nsucc;", @"\U00002281" },
    { @"nsucceq;", @"\U00002AB0\U00000338" },
    { @"nsup;", @"\U00002285" },
    { @"nsupE;", @"\U00002AC6\U00000338" },
    { @"nsupe;", @"\U00002289" },
    { @"nsupset;", @"\U00002283\U000020D2" },
    { @"nsupseteq;", @"\U00002289" },
    { @"nsupseteqq;", @"\U00002AC6\U00000338" },
    { @"ntgl;", @"\U00002279" },
    { @"Ntilde;", @"\U000000D1" },
    { @"Ntilde", @"\U000000D1" },
    { @"ntilde;", @"\U000000F1" },
    { @"ntilde", @"\U000000F1" },
    { @"ntlg;", @"\U00002278" },
    { @"ntriangleleft;", @"\U000022EA" },
    { @"ntrianglelefteq;", @"\U000022EC" },
    { @"ntriangleright;", @"\U000022EB" },
    { @"ntrianglerighteq;", @"\U000022ED" },
    { @"Nu;", @"\U0000039D" },
    { @"nu;", @"\U000003BD" },
    { @"num;", @"#" },
    { @"numero;", @"\U00002116" },
    { @"numsp;", @"\U00002007" },
    { @"nvap;", @"\U0000224D\U000020D2" },
    { @"nVDash;", @"\U000022AF" },
    { @"nVdash;", @"\U000022AE" },
    { @"nvDash;", @"\U000022AD" },
    { @"nvdash;", @"\U000022AC" },
    { @"nvge;", @"\U00002265\U000020D2" },
    { @"nvgt;", @">\U000020D2" },
    { @"nvHarr;", @"\U00002904" },
    { @"nvinfin;", @"\U000029DE" },
    { @"nvlArr;", @"\U00002902" },
    { @"nvle;", @"\U00002264\U000020D2" },
    { @"nvlt;", @"<\U000020D2" },
    { @"nvltrie;", @"\U000022B4\U000020D2" },
    { @"nvrArr;", @"\U00002903" },
    { @"nvrtrie;", @"\U000022B5\U000020D2" },
    { @"nvsim;", @"\U0000223C\U000020D2" },
    { @"nwarhk;", @"\U00002923" },
    { @"nwArr;", @"\U000021D6" },
    { @"nwarr;", @"\U00002196" },
    { @"nwarrow;", @"\U00002196" },
    { @"nwnear;", @"\U00002927" },
    { @"Oacute;", @"\U000000D3" },
    { @"Oacute", @"\U000000D3" },
    { @"oacute;", @"\U000000F3" },
    { @"oacute", @"\U000000F3" },
    { @"oast;", @"\U0000229B" },
    { @"ocir;", @"\U0000229A" },
    { @"Ocirc;", @"\U000000D4" },
    { @"Ocirc", @"\U000000D4" },
    { @"ocirc;", @"\U000000F4" },
    { @"ocirc", @"\U000000F4" },
    { @"Ocy;", @"\U0000041E" },
    { @"ocy;", @"\U0000043E" },
    { @"odash;", @"\U0000229D" },
    { @"Odblac;", @"\U00000150" },
    { @"odblac;", @"\U00000151" },
    { @"odiv;", @"\U00002A38" },
    { @"odot;", @"\U00002299" },
    { @"odsold;", @"\U000029BC" },
    { @"OElig;", @"\U00000152" },
    { @"oelig;", @"\U00000153" },
    { @"ofcir;", @"\U000029BF" },
    { @"Ofr;", @"\U0001D512" },
    { @"ofr;", @"\U0001D52C" },
    { @"ogon;", @"\U000002DB" },
    { @"Ograve;", @"\U000000D2" },
    { @"Ograve", @"\U000000D2" },
    { @"ograve;", @"\U000000F2" },
    { @"ograve", @"\U000000F2" },
    { @"ogt;", @"\U000029C1" },
    { @"ohbar;", @"\U000029B5" },
    { @"ohm;", @"\U000003A9" },
    { @"oint;", @"\U0000222E" },
    { @"olarr;", @"\U000021BA" },
    { @"olcir;", @"\U000029BE" },
    { @"olcross;", @"\U000029BB" },
    { @"oline;", @"\U0000203E" },
    { @"olt;", @"\U000029C0" },
    { @"Omacr;", @"\U0000014C" },
    { @"omacr;", @"\U0000014D" },
    { @"Omega;", @"\U000003A9" },
    { @"omega;", @"\U000003C9" },
    { @"Omicron;", @"\U0000039F" },
    { @"omicron;", @"\U000003BF" },
    { @"omid;", @"\U000029B6" },
    { @"ominus;", @"\U00002296" },
    { @"Oopf;", @"\U0001D546" },
    { @"oopf;", @"\U0001D560" },
    { @"opar;", @"\U000029B7" },
    { @"OpenCurlyDoubleQuote;", @"\U0000201C" },
    { @"OpenCurlyQuote;", @"\U00002018" },
    { @"operp;", @"\U000029B9" },
    { @"oplus;", @"\U00002295" },
    { @"Or;", @"\U00002A54" },
    { @"or;", @"\U00002228" },
    { @"orarr;", @"\U000021BB" },
    { @"ord;", @"\U00002A5D" },
    { @"order;", @"\U00002134" },
    { @"orderof;", @"\U00002134" },
    { @"ordf;", @"\U000000AA" },
    { @"ordf", @"\U000000AA" },
    { @"ordm;", @"\U000000BA" },
    { @"ordm", @"\U000000BA" },
    { @"origof;", @"\U000022B6" },
    { @"oror;", @"\U00002A56" },
    { @"orslope;", @"\U00002A57" },
    { @"orv;", @"\U00002A5B" },
    { @"oS;", @"\U000024C8" },
    { @"Oscr;", @"\U0001D4AA" },
    { @"oscr;", @"\U00002134" },
    { @"Oslash;", @"\U000000D8" },
    { @"Oslash", @"\U000000D8" },
    { @"oslash;", @"\U000000F8" },
    { @"oslash", @"\U000000F8" },
    { @"osol;", @"\U00002298" },
    { @"Otilde;", @"\U000000D5" },
    { @"Otilde", @"\U000000D5" },
    { @"otilde;", @"\U000000F5" },
    { @"otilde", @"\U000000F5" },
    { @"Otimes;", @"\U00002A37" },
    { @"otimes;", @"\U00002297" },
    { @"otimesas;", @"\U00002A36" },
    { @"Ouml;", @"\U000000D6" },
    { @"Ouml", @"\U000000D6" },
    { @"ouml;", @"\U000000F6" },
    { @"ouml", @"\U000000F6" },
    { @"ovbar;", @"\U0000233D" },
    { @"OverBar;", @"\U0000203E" },
    { @"OverBrace;", @"\U000023DE" },
    { @"OverBracket;", @"\U000023B4" },
    { @"OverParenthesis;", @"\U000023DC" },
    { @"par;", @"\U00002225" },
    { @"para;", @"\U000000B6" },
    { @"para", @"\U000000B6" },
    { @"parallel;", @"\U00002225" },
    { @"parsim;", @"\U00002AF3" },
    { @"parsl;", @"\U00002AFD" },
    { @"part;", @"\U00002202" },
    { @"PartialD;", @"\U00002202" },
    { @"Pcy;", @"\U0000041F" },
    { @"pcy;", @"\U0000043F" },
    { @"percnt;", @"%" },
    { @"period;", @"." },
    { @"permil;", @"\U00002030" },
    { @"perp;", @"\U000022A5" },
    { @"pertenk;", @"\U00002031" },
    { @"Pfr;", @"\U0001D513" },
    { @"pfr;", @"\U0001D52D" },
    { @"Phi;", @"\U000003A6" },
    { @"phi;", @"\U000003C6" },
    { @"phiv;", @"\U000003D5" },
    { @"phmmat;", @"\U00002133" },
    { @"phone;", @"\U0000260E" },
    { @"Pi;", @"\U000003A0" },
    { @"pi;", @"\U000003C0" },
    { @"pitchfork;", @"\U000022D4" },
    { @"piv;", @"\U000003D6" },
    { @"planck;", @"\U0000210F" },
    { @"planckh;", @"\U0000210E" },
    { @"plankv;", @"\U0000210F" },
    { @"plus;", @"+" },
    { @"plusacir;", @"\U00002A23" },
    { @"plusb;", @"\U0000229E" },
    { @"pluscir;", @"\U00002A22" },
    { @"plusdo;", @"\U00002214" },
    { @"plusdu;", @"\U00002A25" },
    { @"pluse;", @"\U00002A72" },
    { @"PlusMinus;", @"\U000000B1" },
    { @"plusmn;", @"\U000000B1" },
    { @"plusmn", @"\U000000B1" },
    { @"plussim;", @"\U00002A26" },
    { @"plustwo;", @"\U00002A27" },
    { @"pm;", @"\U000000B1" },
    { @"Poincareplane;", @"\U0000210C" },
    { @"pointint;", @"\U00002A15" },
    { @"Popf;", @"\U00002119" },
    { @"popf;", @"\U0001D561" },
    { @"pound;", @"\U000000A3" },
    { @"pound", @"\U000000A3" },
    { @"Pr;", @"\U00002ABB" },
    { @"pr;", @"\U0000227A" },
    { @"prap;", @"\U00002AB7" },
    { @"prcue;", @"\U0000227C" },
    { @"prE;", @"\U00002AB3" },
    { @"pre;", @"\U00002AAF" },
    { @"prec;", @"\U0000227A" },
    { @"precapprox;", @"\U00002AB7" },
    { @"preccurlyeq;", @"\U0000227C" },
    { @"Precedes;", @"\U0000227A" },
    { @"PrecedesEqual;", @"\U00002AAF" },
    { @"PrecedesSlantEqual;", @"\U0000227C" },
    { @"PrecedesTilde;", @"\U0000227E" },
    { @"preceq;", @"\U00002AAF" },
    { @"precnapprox;", @"\U00002AB9" },
    { @"precneqq;", @"\U00002AB5" },
    { @"precnsim;", @"\U000022E8" },
    { @"precsim;", @"\U0000227E" },
    { @"Prime;", @"\U00002033" },
    { @"prime;", @"\U00002032" },
    { @"primes;", @"\U00002119" },
    { @"prnap;", @"\U00002AB9" },
    { @"prnE;", @"\U00002AB5" },
    { @"prnsim;", @"\U000022E8" },
    { @"prod;", @"\U0000220F" },
    { @"Product;", @"\U0000220F" },
    { @"profalar;", @"\U0000232E" },
    { @"profline;", @"\U00002312" },
    { @"profsurf;", @"\U00002313" },
    { @"prop;", @"\U0000221D" },
    { @"Proportion;", @"\U00002237" },
    { @"Proportional;", @"\U0000221D" },
    { @"propto;", @"\U0000221D" },
    { @"prsim;", @"\U0000227E" },
    { @"prurel;", @"\U000022B0" },
    { @"Pscr;", @"\U0001D4AB" },
    { @"pscr;", @"\U0001D4C5" },
    { @"Psi;", @"\U000003A8" },
    { @"psi;", @"\U000003C8" },
    { @"puncsp;", @"\U00002008" },
    { @"Qfr;", @"\U0001D514" },
    { @"qfr;", @"\U0001D52E" },
    { @"qint;", @"\U00002A0C" },
    { @"Qopf;", @"\U0000211A" },
    { @"qopf;", @"\U0001D562" },
    { @"qprime;", @"\U00002057" },
    { @"Qscr;", @"\U0001D4AC" },
    { @"qscr;", @"\U0001D4C6" },
    { @"quaternions;", @"\U0000210D" },
    { @"quatint;", @"\U00002A16" },
    { @"quest;", @"?" },
    { @"questeq;", @"\U0000225F" },
    { @"QUOT;", @"\"" },
    { @"QUOT", @"\"" },
    { @"quot;", @"\"" },
    { @"quot", @"\"" },
    { @"rAarr;", @"\U000021DB" },
    { @"race;", @"\U0000223D\U00000331" },
    { @"Racute;", @"\U00000154" },
    { @"racute;", @"\U00000155" },
    { @"radic;", @"\U0000221A" },
    { @"raemptyv;", @"\U000029B3" },
    { @"Rang;", @"\U000027EB" },
    { @"rang;", @"\U000027E9" },
    { @"rangd;", @"\U00002992" },
    { @"range;", @"\U000029A5" },
    { @"rangle;", @"\U000027E9" },
    { @"raquo;", @"\U000000BB" },
    { @"raquo", @"\U000000BB" },
    { @"Rarr;", @"\U000021A0" },
    { @"rArr;", @"\U000021D2" },
    { @"rarr;", @"\U00002192" },
    { @"rarrap;", @"\U00002975" },
    { @"rarrb;", @"\U000021E5" },
    { @"rarrbfs;", @"\U00002920" },
    { @"rarrc;", @"\U00002933" },
    { @"rarrfs;", @"\U0000291E" },
    { @"rarrhk;", @"\U000021AA" },
    { @"rarrlp;", @"\U000021AC" },
    { @"rarrpl;", @"\U00002945" },
    { @"rarrsim;", @"\U00002974" },
    { @"Rarrtl;", @"\U00002916" },
    { @"rarrtl;", @"\U000021A3" },
    { @"rarrw;", @"\U0000219D" },
    { @"rAtail;", @"\U0000291C" },
    { @"ratail;", @"\U0000291A" },
    { @"ratio;", @"\U00002236" },
    { @"rationals;", @"\U0000211A" },
    { @"RBarr;", @"\U00002910" },
    { @"rBarr;", @"\U0000290F" },
    { @"rbarr;", @"\U0000290D" },
    { @"rbbrk;", @"\U00002773" },
    { @"rbrace;", @"}" },
    { @"rbrack;", @"]" },
    { @"rbrke;", @"\U0000298C" },
    { @"rbrksld;", @"\U0000298E" },
    { @"rbrkslu;", @"\U00002990" },
    { @"Rcaron;", @"\U00000158" },
    { @"rcaron;", @"\U00000159" },
    { @"Rcedil;", @"\U00000156" },
    { @"rcedil;", @"\U00000157" },
    { @"rceil;", @"\U00002309" },
    { @"rcub;", @"}" },
    { @"Rcy;", @"\U00000420" },
    { @"rcy;", @"\U00000440" },
    { @"rdca;", @"\U00002937" },
    { @"rdldhar;", @"\U00002969" },
    { @"rdquo;", @"\U0000201D" },
    { @"rdquor;", @"\U0000201D" },
    { @"rdsh;", @"\U000021B3" },
    { @"Re;", @"\U0000211C" },
    { @"real;", @"\U0000211C" },
    { @"realine;", @"\U0000211B" },
    { @"realpart;", @"\U0000211C" },
    { @"reals;", @"\U0000211D" },
    { @"rect;", @"\U000025AD" },
    { @"REG;", @"\U000000AE" },
    { @"REG", @"\U000000AE" },
    { @"reg;", @"\U000000AE" },
    { @"reg", @"\U000000AE" },
    { @"ReverseElement;", @"\U0000220B" },
    { @"ReverseEquilibrium;", @"\U000021CB" },
    { @"ReverseUpEquilibrium;", @"\U0000296F" },
    { @"rfisht;", @"\U0000297D" },
    { @"rfloor;", @"\U0000230B" },
    { @"Rfr;", @"\U0000211C" },
    { @"rfr;", @"\U0001D52F" },
    { @"rHar;", @"\U00002964" },
    { @"rhard;", @"\U000021C1" },
    { @"rharu;", @"\U000021C0" },
    { @"rharul;", @"\U0000296C" },
    { @"Rho;", @"\U000003A1" },
    { @"rho;", @"\U000003C1" },
    { @"rhov;", @"\U000003F1" },
    { @"RightAngleBracket;", @"\U000027E9" },
    { @"RightArrow;", @"\U00002192" },
    { @"Rightarrow;", @"\U000021D2" },
    { @"rightarrow;", @"\U00002192" },
    { @"RightArrowBar;", @"\U000021E5" },
    { @"RightArrowLeftArrow;", @"\U000021C4" },
    { @"rightarrowtail;", @"\U000021A3" },
    { @"RightCeiling;", @"\U00002309" },
    { @"RightDoubleBracket;", @"\U000027E7" },
    { @"RightDownTeeVector;", @"\U0000295D" },
    { @"RightDownVector;", @"\U000021C2" },
    { @"RightDownVectorBar;", @"\U00002955" },
    { @"RightFloor;", @"\U0000230B" },
    { @"rightharpoondown;", @"\U000021C1" },
    { @"rightharpoonup;", @"\U000021C0" },
    { @"rightleftarrows;", @"\U000021C4" },
    { @"rightleftharpoons;", @"\U000021CC" },
    { @"rightrightarrows;", @"\U000021C9" },
    { @"rightsquigarrow;", @"\U0000219D" },
    { @"RightTee;", @"\U000022A2" },
    { @"RightTeeArrow;", @"\U000021A6" },
    { @"RightTeeVector;", @"\U0000295B" },
    { @"rightthreetimes;", @"\U000022CC" },
    { @"RightTriangle;", @"\U000022B3" },
    { @"RightTriangleBar;", @"\U000029D0" },
    { @"RightTriangleEqual;", @"\U000022B5" },
    { @"RightUpDownVector;", @"\U0000294F" },
    { @"RightUpTeeVector;", @"\U0000295C" },
    { @"RightUpVector;", @"\U000021BE" },
    { @"RightUpVectorBar;", @"\U00002954" },
    { @"RightVector;", @"\U000021C0" },
    { @"RightVectorBar;", @"\U00002953" },
    { @"ring;", @"\U000002DA" },
    { @"risingdotseq;", @"\U00002253" },
    { @"rlarr;", @"\U000021C4" },
    { @"rlhar;", @"\U000021CC" },
    { @"rlm;", @"\U0000200F" },
    { @"rmoust;", @"\U000023B1" },
    { @"rmoustache;", @"\U000023B1" },
    { @"rnmid;", @"\U00002AEE" },
    { @"roang;", @"\U000027ED" },
    { @"roarr;", @"\U000021FE" },
    { @"robrk;", @"\U000027E7" },
    { @"ropar;", @"\U00002986" },
    { @"Ropf;", @"\U0000211D" },
    { @"ropf;", @"\U0001D563" },
    { @"roplus;", @"\U00002A2E" },
    { @"rotimes;", @"\U00002A35" },
    { @"RoundImplies;", @"\U00002970" },
    { @"rpar;", @")" },
    { @"rpargt;", @"\U00002994" },
    { @"rppolint;", @"\U00002A12" },
    { @"rrarr;", @"\U000021C9" },
    { @"Rrightarrow;", @"\U000021DB" },
    { @"rsaquo;", @"\U0000203A" },
    { @"Rscr;", @"\U0000211B" },
    { @"rscr;", @"\U0001D4C7" },
    { @"Rsh;", @"\U000021B1" },
    { @"rsh;", @"\U000021B1" },
    { @"rsqb;", @"]" },
    { @"rsquo;", @"\U00002019" },
    { @"rsquor;", @"\U00002019" },
    { @"rthree;", @"\U000022CC" },
    { @"rtimes;", @"\U000022CA" },
    { @"rtri;", @"\U000025B9" },
    { @"rtrie;", @"\U000022B5" },
    { @"rtrif;", @"\U000025B8" },
    { @"rtriltri;", @"\U000029CE" },
    { @"RuleDelayed;", @"\U000029F4" },
    { @"ruluhar;", @"\U00002968" },
    { @"rx;", @"\U0000211E" },
    { @"Sacute;", @"\U0000015A" },
    { @"sacute;", @"\U0000015B" },
    { @"sbquo;", @"\U0000201A" },
    { @"Sc;", @"\U00002ABC" },
    { @"sc;", @"\U0000227B" },
    { @"scap;", @"\U00002AB8" },
    { @"Scaron;", @"\U00000160" },
    { @"scaron;", @"\U00000161" },
    { @"sccue;", @"\U0000227D" },
    { @"scE;", @"\U00002AB4" },
    { @"sce;", @"\U00002AB0" },
    { @"Scedil;", @"\U0000015E" },
    { @"scedil;", @"\U0000015F" },
    { @"Scirc;", @"\U0000015C" },
    { @"scirc;", @"\U0000015D" },
    { @"scnap;", @"\U00002ABA" },
    { @"scnE;", @"\U00002AB6" },
    { @"scnsim;", @"\U000022E9" },
    { @"scpolint;", @"\U00002A13" },
    { @"scsim;", @"\U0000227F" },
    { @"Scy;", @"\U00000421" },
    { @"scy;", @"\U00000441" },
    { @"sdot;", @"\U000022C5" },
    { @"sdotb;", @"\U000022A1" },
    { @"sdote;", @"\U00002A66" },
    { @"searhk;", @"\U00002925" },
    { @"seArr;", @"\U000021D8" },
    { @"searr;", @"\U00002198" },
    { @"searrow;", @"\U00002198" },
    { @"sect;", @"\U000000A7" },
    { @"sect", @"\U000000A7" },
    { @"semi;", @";" },
    { @"seswar;", @"\U00002929" },
    { @"setminus;", @"\U00002216" },
    { @"setmn;", @"\U00002216" },
    { @"sext;", @"\U00002736" },
    { @"Sfr;", @"\U0001D516" },
    { @"sfr;", @"\U0001D530" },
    { @"sfrown;", @"\U00002322" },
    { @"sharp;", @"\U0000266F" },
    { @"SHCHcy;", @"\U00000429" },
    { @"shchcy;", @"\U00000449" },
    { @"SHcy;", @"\U00000428" },
    { @"shcy;", @"\U00000448" },
    { @"ShortDownArrow;", @"\U00002193" },
    { @"ShortLeftArrow;", @"\U00002190" },
    { @"shortmid;", @"\U00002223" },
    { @"shortparallel;", @"\U00002225" },
    { @"ShortRightArrow;", @"\U00002192" },
    { @"ShortUpArrow;", @"\U00002191" },
    { @"shy;", @"\U000000AD" },
    { @"shy", @"\U000000AD" },
    { @"Sigma;", @"\U000003A3" },
    { @"sigma;", @"\U000003C3" },
    { @"sigmaf;", @"\U000003C2" },
    { @"sigmav;", @"\U000003C2" },
    { @"sim;", @"\U0000223C" },
    { @"simdot;", @"\U00002A6A" },
    { @"sime;", @"\U00002243" },
    { @"simeq;", @"\U00002243" },
    { @"simg;", @"\U00002A9E" },
    { @"simgE;", @"\U00002AA0" },
    { @"siml;", @"\U00002A9D" },
    { @"simlE;", @"\U00002A9F" },
    { @"simne;", @"\U00002246" },
    { @"simplus;", @"\U00002A24" },
    { @"simrarr;", @"\U00002972" },
    { @"slarr;", @"\U00002190" },
    { @"SmallCircle;", @"\U00002218" },
    { @"smallsetminus;", @"\U00002216" },
    { @"smashp;", @"\U00002A33" },
    { @"smeparsl;", @"\U000029E4" },
    { @"smid;", @"\U00002223" },
    { @"smile;", @"\U00002323" },
    { @"smt;", @"\U00002AAA" },
    { @"smte;", @"\U00002AAC" },
    { @"smtes;", @"\U00002AAC\U0000FE00" },
    { @"SOFTcy;", @"\U0000042C" },
    { @"softcy;", @"\U0000044C" },
    { @"sol;", @"/" },
    { @"solb;", @"\U000029C4" },
    { @"solbar;", @"\U0000233F" },
    { @"Sopf;", @"\U0001D54A" },
    { @"sopf;", @"\U0001D564" },
    { @"spades;", @"\U00002660" },
    { @"spadesuit;", @"\U00002660" },
    { @"spar;", @"\U00002225" },
    { @"sqcap;", @"\U00002293" },
    { @"sqcaps;", @"\U00002293\U0000FE00" },
    { @"sqcup;", @"\U00002294" },
    { @"sqcups;", @"\U00002294\U0000FE00" },
    { @"Sqrt;", @"\U0000221A" },
    { @"sqsub;", @"\U0000228F" },
    { @"sqsube;", @"\U00002291" },
    { @"sqsubset;", @"\U0000228F" },
    { @"sqsubseteq;", @"\U00002291" },
    { @"sqsup;", @"\U00002290" },
    { @"sqsupe;", @"\U00002292" },
    { @"sqsupset;", @"\U00002290" },
    { @"sqsupseteq;", @"\U00002292" },
    { @"squ;", @"\U000025A1" },
    { @"Square;", @"\U000025A1" },
    { @"square;", @"\U000025A1" },
    { @"SquareIntersection;", @"\U00002293" },
    { @"SquareSubset;", @"\U0000228F" },
    { @"SquareSubsetEqual;", @"\U00002291" },
    { @"SquareSuperset;", @"\U00002290" },
    { @"SquareSupersetEqual;", @"\U00002292" },
    { @"SquareUnion;", @"\U00002294" },
    { @"squarf;", @"\U000025AA" },
    { @"squf;", @"\U000025AA" },
    { @"srarr;", @"\U00002192" },
    { @"Sscr;", @"\U0001D4AE" },
    { @"sscr;", @"\U0001D4C8" },
    { @"ssetmn;", @"\U00002216" },
    { @"ssmile;", @"\U00002323" },
    { @"sstarf;", @"\U000022C6" },
    { @"Star;", @"\U000022C6" },
    { @"star;", @"\U00002606" },
    { @"starf;", @"\U00002605" },
    { @"straightepsilon;", @"\U000003F5" },
    { @"straightphi;", @"\U000003D5" },
    { @"strns;", @"\U000000AF" },
    { @"Sub;", @"\U000022D0" },
    { @"sub;", @"\U00002282" },
    { @"subdot;", @"\U00002ABD" },
    { @"subE;", @"\U00002AC5" },
    { @"sube;", @"\U00002286" },
    { @"subedot;", @"\U00002AC3" },
    { @"submult;", @"\U00002AC1" },
    { @"subnE;", @"\U00002ACB" },
    { @"subne;", @"\U0000228A" },
    { @"subplus;", @"\U00002ABF" },
    { @"subrarr;", @"\U00002979" },
    { @"Subset;", @"\U000022D0" },
    { @"subset;", @"\U00002282" },
    { @"subseteq;", @"\U00002286" },
    { @"subseteqq;", @"\U00002AC5" },
    { @"SubsetEqual;", @"\U00002286" },
    { @"subsetneq;", @"\U0000228A" },
    { @"subsetneqq;", @"\U00002ACB" },
    { @"subsim;", @"\U00002AC7" },
    { @"subsub;", @"\U00002AD5" },
    { @"subsup;", @"\U00002AD3" },
    { @"succ;", @"\U0000227B" },
    { @"succapprox;", @"\U00002AB8" },
    { @"succcurlyeq;", @"\U0000227D" },
    { @"Succeeds;", @"\U0000227B" },
    { @"SucceedsEqual;", @"\U00002AB0" },
    { @"SucceedsSlantEqual;", @"\U0000227D" },
    { @"SucceedsTilde;", @"\U0000227F" },
    { @"succeq;", @"\U00002AB0" },
    { @"succnapprox;", @"\U00002ABA" },
    { @"succneqq;", @"\U00002AB6" },
    { @"succnsim;", @"\U000022E9" },
    { @"succsim;", @"\U0000227F" },
    { @"SuchThat;", @"\U0000220B" },
    { @"Sum;", @"\U00002211" },
    { @"sum;", @"\U00002211" },
    { @"sung;", @"\U0000266A" },
    { @"Sup;", @"\U000022D1" },
    { @"sup;", @"\U00002283" },
    { @"sup1;", @"\U000000B9" },
    { @"sup1", @"\U000000B9" },
    { @"sup2;", @"\U000000B2" },
    { @"sup2", @"\U000000B2" },
    { @"sup3;", @"\U000000B3" },
    { @"sup3", @"\U000000B3" },
    { @"supdot;", @"\U00002ABE" },
    { @"supdsub;", @"\U00002AD8" },
    { @"supE;", @"\U00002AC6" },
    { @"supe;", @"\U00002287" },
    { @"supedot;", @"\U00002AC4" },
    { @"Superset;", @"\U00002283" },
    { @"SupersetEqual;", @"\U00002287" },
    { @"suphsol;", @"\U000027C9" },
    { @"suphsub;", @"\U00002AD7" },
    { @"suplarr;", @"\U0000297B" },
    { @"supmult;", @"\U00002AC2" },
    { @"supnE;", @"\U00002ACC" },
    { @"supne;", @"\U0000228B" },
    { @"supplus;", @"\U00002AC0" },
    { @"Supset;", @"\U000022D1" },
    { @"supset;", @"\U00002283" },
    { @"supseteq;", @"\U00002287" },
    { @"supseteqq;", @"\U00002AC6" },
    { @"supsetneq;", @"\U0000228B" },
    { @"supsetneqq;", @"\U00002ACC" },
    { @"supsim;", @"\U00002AC8" },
    { @"supsub;", @"\U00002AD4" },
    { @"supsup;", @"\U00002AD6" },
    { @"swarhk;", @"\U00002926" },
    { @"swArr;", @"\U000021D9" },
    { @"swarr;", @"\U00002199" },
    { @"swarrow;", @"\U00002199" },
    { @"swnwar;", @"\U0000292A" },
    { @"szlig;", @"\U000000DF" },
    { @"szlig", @"\U000000DF" },
    { @"Tab;", @"\t" },
    { @"target;", @"\U00002316" },
    { @"Tau;", @"\U000003A4" },
    { @"tau;", @"\U000003C4" },
    { @"tbrk;", @"\U000023B4" },
    { @"Tcaron;", @"\U00000164" },
    { @"tcaron;", @"\U00000165" },
    { @"Tcedil;", @"\U00000162" },
    { @"tcedil;", @"\U00000163" },
    { @"Tcy;", @"\U00000422" },
    { @"tcy;", @"\U00000442" },
    { @"tdot;", @"\U000020DB" },
    { @"telrec;", @"\U00002315" },
    { @"Tfr;", @"\U0001D517" },
    { @"tfr;", @"\U0001D531" },
    { @"there4;", @"\U00002234" },
    { @"Therefore;", @"\U00002234" },
    { @"therefore;", @"\U00002234" },
    { @"Theta;", @"\U00000398" },
    { @"theta;", @"\U000003B8" },
    { @"thetasym;", @"\U000003D1" },
    { @"thetav;", @"\U000003D1" },
    { @"thickapprox;", @"\U00002248" },
    { @"thicksim;", @"\U0000223C" },
    { @"ThickSpace;", @"\U0000205F\U0000200A" },
    { @"thinsp;", @"\U00002009" },
    { @"ThinSpace;", @"\U00002009" },
    { @"thkap;", @"\U00002248" },
    { @"thksim;", @"\U0000223C" },
    { @"THORN;", @"\U000000DE" },
    { @"THORN", @"\U000000DE" },
    { @"thorn;", @"\U000000FE" },
    { @"thorn", @"\U000000FE" },
    { @"Tilde;", @"\U0000223C" },
    { @"tilde;", @"\U000002DC" },
    { @"TildeEqual;", @"\U00002243" },
    { @"TildeFullEqual;", @"\U00002245" },
    { @"TildeTilde;", @"\U00002248" },
    { @"times;", @"\U000000D7" },
    { @"times", @"\U000000D7" },
    { @"timesb;", @"\U000022A0" },
    { @"timesbar;", @"\U00002A31" },
    { @"timesd;", @"\U00002A30" },
    { @"tint;", @"\U0000222D" },
    { @"toea;", @"\U00002928" },
    { @"top;", @"\U000022A4" },
    { @"topbot;", @"\U00002336" },
    { @"topcir;", @"\U00002AF1" },
    { @"Topf;", @"\U0001D54B" },
    { @"topf;", @"\U0001D565" },
    { @"topfork;", @"\U00002ADA" },
    { @"tosa;", @"\U00002929" },
    { @"tprime;", @"\U00002034" },
    { @"TRADE;", @"\U00002122" },
    { @"trade;", @"\U00002122" },
    { @"triangle;", @"\U000025B5" },
    { @"triangledown;", @"\U000025BF" },
    { @"triangleleft;", @"\U000025C3" },
    { @"trianglelefteq;", @"\U000022B4" },
    { @"triangleq;", @"\U0000225C" },
    { @"triangleright;", @"\U000025B9" },
    { @"trianglerighteq;", @"\U000022B5" },
    { @"tridot;", @"\U000025EC" },
    { @"trie;", @"\U0000225C" },
    { @"triminus;", @"\U00002A3A" },
    { @"TripleDot;", @"\U000020DB" },
    { @"triplus;", @"\U00002A39" },
    { @"trisb;", @"\U000029CD" },
    { @"tritime;", @"\U00002A3B" },
    { @"trpezium;", @"\U000023E2" },
    { @"Tscr;", @"\U0001D4AF" },
    { @"tscr;", @"\U0001D4C9" },
    { @"TScy;", @"\U00000426" },
    { @"tscy;", @"\U00000446" },
    { @"TSHcy;", @"\U0000040B" },
    { @"tshcy;", @"\U0000045B" },
    { @"Tstrok;", @"\U00000166" },
    { @"tstrok;", @"\U00000167" },
    { @"twixt;", @"\U0000226C" },
    { @"twoheadleftarrow;", @"\U0000219E" },
    { @"twoheadrightarrow;", @"\U000021A0" },
    { @"Uacute;", @"\U000000DA" },
    { @"Uacute", @"\U000000DA" },
    { @"uacute;", @"\U000000FA" },
    { @"uacute", @"\U000000FA" },
    { @"Uarr;", @"\U0000219F" },
    { @"uArr;", @"\U000021D1" },
    { @"uarr;", @"\U00002191" },
    { @"Uarrocir;", @"\U00002949" },
    { @"Ubrcy;", @"\U0000040E" },
    { @"ubrcy;", @"\U0000045E" },
    { @"Ubreve;", @"\U0000016C" },
    { @"ubreve;", @"\U0000016D" },
    { @"Ucirc;", @"\U000000DB" },
    { @"Ucirc", @"\U000000DB" },
    { @"ucirc;", @"\U000000FB" },
    { @"ucirc", @"\U000000FB" },
    { @"Ucy;", @"\U00000423" },
    { @"ucy;", @"\U00000443" },
    { @"udarr;", @"\U000021C5" },
    { @"Udblac;", @"\U00000170" },
    { @"udblac;", @"\U00000171" },
    { @"udhar;", @"\U0000296E" },
    { @"ufisht;", @"\U0000297E" },
    { @"Ufr;", @"\U0001D518" },
    { @"ufr;", @"\U0001D532" },
    { @"Ugrave;", @"\U000000D9" },
    { @"Ugrave", @"\U000000D9" },
    { @"ugrave;", @"\U000000F9" },
    { @"ugrave", @"\U000000F9" },
    { @"uHar;", @"\U00002963" },
    { @"uharl;", @"\U000021BF" },
    { @"uharr;", @"\U000021BE" },
    { @"uhblk;", @"\U00002580" },
    { @"ulcorn;", @"\U0000231C" },
    { @"ulcorner;", @"\U0000231C" },
    { @"ulcrop;", @"\U0000230F" },
    { @"ultri;", @"\U000025F8" },
    { @"Umacr;", @"\U0000016A" },
    { @"umacr;", @"\U0000016B" },
    { @"uml;", @"\U000000A8" },
    { @"uml", @"\U000000A8" },
    { @"UnderBar;", @"_" },
    { @"UnderBrace;", @"\U000023DF" },
    { @"UnderBracket;", @"\U000023B5" },
    { @"UnderParenthesis;", @"\U000023DD" },
    { @"Union;", @"\U000022C3" },
    { @"UnionPlus;", @"\U0000228E" },
    { @"Uogon;", @"\U00000172" },
    { @"uogon;", @"\U00000173" },
    { @"Uopf;", @"\U0001D54C" },
    { @"uopf;", @"\U0001D566" },
    { @"UpArrow;", @"\U00002191" },
    { @"Uparrow;", @"\U000021D1" },
    { @"uparrow;", @"\U00002191" },
    { @"UpArrowBar;", @"\U00002912" },
    { @"UpArrowDownArrow;", @"\U000021C5" },
    { @"UpDownArrow;", @"\U00002195" },
    { @"Updownarrow;", @"\U000021D5" },
    { @"updownarrow;", @"\U00002195" },
    { @"UpEquilibrium;", @"\U0000296E" },
    { @"upharpoonleft;", @"\U000021BF" },
    { @"upharpoonright;", @"\U000021BE" },
    { @"uplus;", @"\U0000228E" },
    { @"UpperLeftArrow;", @"\U00002196" },
    { @"UpperRightArrow;", @"\U00002197" },
    { @"Upsi;", @"\U000003D2" },
    { @"upsi;", @"\U000003C5" },
    { @"upsih;", @"\U000003D2" },
    { @"Upsilon;", @"\U000003A5" },
    { @"upsilon;", @"\U000003C5" },
    { @"UpTee;", @"\U000022A5" },
    { @"UpTeeArrow;", @"\U000021A5" },
    { @"upuparrows;", @"\U000021C8" },
    { @"urcorn;", @"\U0000231D" },
    { @"urcorner;", @"\U0000231D" },
    { @"urcrop;", @"\U0000230E" },
    { @"Uring;", @"\U0000016E" },
    { @"uring;", @"\U0000016F" },
    { @"urtri;", @"\U000025F9" },
    { @"Uscr;", @"\U0001D4B0" },
    { @"uscr;", @"\U0001D4CA" },
    { @"utdot;", @"\U000022F0" },
    { @"Utilde;", @"\U00000168" },
    { @"utilde;", @"\U00000169" },
    { @"utri;", @"\U000025B5" },
    { @"utrif;", @"\U000025B4" },
    { @"uuarr;", @"\U000021C8" },
    { @"Uuml;", @"\U000000DC" },
    { @"Uuml", @"\U000000DC" },
    { @"uuml;", @"\U000000FC" },
    { @"uuml", @"\U000000FC" },
    { @"uwangle;", @"\U000029A7" },
    { @"vangrt;", @"\U0000299C" },
    { @"varepsilon;", @"\U000003F5" },
    { @"varkappa;", @"\U000003F0" },
    { @"varnothing;", @"\U00002205" },
    { @"varphi;", @"\U000003D5" },
    { @"varpi;", @"\U000003D6" },
    { @"varpropto;", @"\U0000221D" },
    { @"vArr;", @"\U000021D5" },
    { @"varr;", @"\U00002195" },
    { @"varrho;", @"\U000003F1" },
    { @"varsigma;", @"\U000003C2" },
    { @"varsubsetneq;", @"\U0000228A\U0000FE00" },
    { @"varsubsetneqq;", @"\U00002ACB\U0000FE00" },
    { @"varsupsetneq;", @"\U0000228B\U0000FE00" },
    { @"varsupsetneqq;", @"\U00002ACC\U0000FE00" },
    { @"vartheta;", @"\U000003D1" },
    { @"vartriangleleft;", @"\U000022B2" },
    { @"vartriangleright;", @"\U000022B3" },
    { @"Vbar;", @"\U00002AEB" },
    { @"vBar;", @"\U00002AE8" },
    { @"vBarv;", @"\U00002AE9" },
    { @"Vcy;", @"\U00000412" },
    { @"vcy;", @"\U00000432" },
    { @"VDash;", @"\U000022AB" },
    { @"Vdash;", @"\U000022A9" },
    { @"vDash;", @"\U000022A8" },
    { @"vdash;", @"\U000022A2" },
    { @"Vdashl;", @"\U00002AE6" },
    { @"Vee;", @"\U000022C1" },
    { @"vee;", @"\U00002228" },
    { @"veebar;", @"\U000022BB" },
    { @"veeeq;", @"\U0000225A" },
    { @"vellip;", @"\U000022EE" },
    { @"Verbar;", @"\U00002016" },
    { @"verbar;", @"|" },
    { @"Vert;", @"\U00002016" },
    { @"vert;", @"|" },
    { @"VerticalBar;", @"\U00002223" },
    { @"VerticalLine;", @"|" },
    { @"VerticalSeparator;", @"\U00002758" },
    { @"VerticalTilde;", @"\U00002240" },
    { @"VeryThinSpace;", @"\U0000200A" },
    { @"Vfr;", @"\U0001D519" },
    { @"vfr;", @"\U0001D533" },
    { @"vltri;", @"\U000022B2" },
    { @"vnsub;", @"\U00002282\U000020D2" },
    { @"vnsup;", @"\U00002283\U000020D2" },
    { @"Vopf;", @"\U0001D54D" },
    { @"vopf;", @"\U0001D567" },
    { @"vprop;", @"\U0000221D" },
    { @"vrtri;", @"\U000022B3" },
    { @"Vscr;", @"\U0001D4B1" },
    { @"vscr;", @"\U0001D4CB" },
    { @"vsubnE;", @"\U00002ACB\U0000FE00" },
    { @"vsubne;", @"\U0000228A\U0000FE00" },
    { @"vsupnE;", @"\U00002ACC\U0000FE00" },
    { @"vsupne;", @"\U0000228B\U0000FE00" },
    { @"Vvdash;", @"\U000022AA" },
    { @"vzigzag;", @"\U0000299A" },
    { @"Wcirc;", @"\U00000174" },
    { @"wcirc;", @"\U00000175" },
    { @"wedbar;", @"\U00002A5F" },
    { @"Wedge;", @"\U000022C0" },
    { @"wedge;", @"\U00002227" },
    { @"wedgeq;", @"\U00002259" },
    { @"weierp;", @"\U00002118" },
    { @"Wfr;", @"\U0001D51A" },
    { @"wfr;", @"\U0001D534" },
    { @"Wopf;", @"\U0001D54E" },
    { @"wopf;", @"\U0001D568" },
    { @"wp;", @"\U00002118" },
    { @"wr;", @"\U00002240" },
    { @"wreath;", @"\U00002240" },
    { @"Wscr;", @"\U0001D4B2" },
    { @"wscr;", @"\U0001D4CC" },
    { @"xcap;", @"\U000022C2" },
    { @"xcirc;", @"\U000025EF" },
    { @"xcup;", @"\U000022C3" },
    { @"xdtri;", @"\U000025BD" },
    { @"Xfr;", @"\U0001D51B" },
    { @"xfr;", @"\U0001D535" },
    { @"xhArr;", @"\U000027FA" },
    { @"xharr;", @"\U000027F7" },
    { @"Xi;", @"\U0000039E" },
    { @"xi;", @"\U000003BE" },
    { @"xlArr;", @"\U000027F8" },
    { @"xlarr;", @"\U000027F5" },
    { @"xmap;", @"\U000027FC" },
    { @"xnis;", @"\U000022FB" },
    { @"xodot;", @"\U00002A00" },
    { @"Xopf;", @"\U0001D54F" },
    { @"xopf;", @"\U0001D569" },
    { @"xoplus;", @"\U00002A01" },
    { @"xotime;", @"\U00002A02" },
    { @"xrArr;", @"\U000027F9" },
    { @"xrarr;", @"\U000027F6" },
    { @"Xscr;", @"\U0001D4B3" },
    { @"xscr;", @"\U0001D4CD" },
    { @"xsqcup;", @"\U00002A06" },
    { @"xuplus;", @"\U00002A04" },
    { @"xutri;", @"\U000025B3" },
    { @"xvee;", @"\U000022C1" },
    { @"xwedge;", @"\U000022C0" },
    { @"Yacute;", @"\U000000DD" },
    { @"Yacute", @"\U000000DD" },
    { @"yacute;", @"\U000000FD" },
    { @"yacute", @"\U000000FD" },
    { @"YAcy;", @"\U0000042F" },
    { @"yacy;", @"\U0000044F" },
    { @"Ycirc;", @"\U00000176" },
    { @"ycirc;", @"\U00000177" },
    { @"Ycy;", @"\U0000042B" },
    { @"ycy;", @"\U0000044B" },
    { @"yen;", @"\U000000A5" },
    { @"yen", @"\U000000A5" },
    { @"Yfr;", @"\U0001D51C" },
    { @"yfr;", @"\U0001D536" },
    { @"YIcy;", @"\U00000407" },
    { @"yicy;", @"\U00000457" },
    { @"Yopf;", @"\U0001D550" },
    { @"yopf;", @"\U0001D56A" },
    { @"Yscr;", @"\U0001D4B4" },
    { @"yscr;", @"\U0001D4CE" },
    { @"YUcy;", @"\U0000042E" },
    { @"yucy;", @"\U0000044E" },
    { @"Yuml;", @"\U00000178" },
    { @"yuml;", @"\U000000FF" },
    { @"yuml", @"\U000000FF" },
    { @"Zacute;", @"\U00000179" },
    { @"zacute;", @"\U0000017A" },
    { @"Zcaron;", @"\U0000017D" },
    { @"zcaron;", @"\U0000017E" },
    { @"Zcy;", @"\U00000417" },
    { @"zcy;", @"\U00000437" },
    { @"Zdot;", @"\U0000017B" },
    { @"zdot;", @"\U0000017C" },
    { @"zeetrf;", @"\U00002128" },
    { @"ZeroWidthSpace;", @"\U0000200B" },
    { @"Zeta;", @"\U00000396" },
    { @"zeta;", @"\U000003B6" },
    { @"Zfr;", @"\U00002128" },
    { @"zfr;", @"\U0001D537" },
    { @"ZHcy;", @"\U00000416" },
    { @"zhcy;", @"\U00000436" },
    { @"zigrarr;", @"\U000021DD" },
    { @"Zopf;", @"\U00002124" },
    { @"zopf;", @"\U0001D56B" },
    { @"Zscr;", @"\U0001D4B5" },
    { @"zscr;", @"\U0001D4CF" },
    { @"zwj;", @"\U0000200D" },
    { @"zwnj;", @"\U0000200C" },
};

#pragma mark NSEnumerator

- (id)nextObject
{
    while (!_done && _tokenQueue.count == 0) {
        [self resume];
    }
    if (_tokenQueue.count == 0) return nil;
    id token = _tokenQueue[0];
    [_tokenQueue removeObjectAtIndex:0];
    return token;
}

#pragma mark NSObject

- (id)init
{
    return [self initWithString:nil];
}

@end

@implementation HTMLDOCTYPEToken
{
    NSMutableString *_name;
    NSMutableString *_publicIdentifier;
    NSMutableString *_systemIdentifier;
}

- (NSString *)name
{
    return [_name copy];
}

- (void)appendLongCharacterToName:(UTF32Char)character
{
    if (!_name) _name = [NSMutableString new];
    AppendLongCharacter(_name, character);
}

- (NSString *)publicIdentifier
{
    return [_publicIdentifier copy];
}

- (void)setPublicIdentifier:(NSString *)string
{
    _publicIdentifier = [string mutableCopy];
}

- (void)appendLongCharacterToPublicIdentifier:(UTF32Char)character
{
    if (!_publicIdentifier) _publicIdentifier = [NSMutableString new];
    AppendLongCharacter(_publicIdentifier, character);
}

- (NSString *)systemIdentifier
{
    return [_systemIdentifier copy];
}

- (void)setSystemIdentifier:(NSString *)string
{
    _systemIdentifier = [string mutableCopy];
}

- (void)appendLongCharacterToSystemIdentifier:(UTF32Char)character
{
    if (!_systemIdentifier) _systemIdentifier = [NSMutableString new];
    AppendLongCharacter(_systemIdentifier, character);
}

#pragma mark NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p <!DOCTYPE %@ %@ %@> >", self.class, self, self.name,
            self.publicIdentifier, self.systemIdentifier];
}

- (BOOL)isEqual:(HTMLDOCTYPEToken *)other
{
    #define AreNilOrEqual(a, b) ([(a) isEqual:(b)] || ((a) == nil && (b) == nil))
    return ([other isKindOfClass:[HTMLDOCTYPEToken class]] &&
            AreNilOrEqual(other.name, self.name) &&
            AreNilOrEqual(other.publicIdentifier, self.publicIdentifier) &&
            AreNilOrEqual(other.systemIdentifier, self.systemIdentifier));
}

@end

@implementation HTMLTagToken
{
    NSMutableString *_tagName;
    BOOL _selfClosingFlag;
    NSMutableArray *_attributes;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    _tagName = [NSMutableString new];
    _attributes = [NSMutableArray new];
    return self;
}

- (id)initWithTagName:(NSString *)tagName
{
    if (!(self = [self init])) return nil;
    [_tagName setString:tagName];
    return self;
}

- (void)addAttributeWithName:(NSString *)name value:(NSString *)value
{
    if (!_attributes) _attributes = [NSMutableArray new];
    [_attributes addObject:[[HTMLAttribute alloc] initWithName:name value:value]];
}

- (NSString *)tagName
{
    return [_tagName copy];
}

- (BOOL)selfClosingFlag
{
    return _selfClosingFlag;
}

- (void)setSelfClosingFlag:(BOOL)flag
{
    _selfClosingFlag = flag;
}

- (NSArray *)attributes
{
    return [_attributes copy];
}

- (void)appendLongCharacterToTagName:(UTF32Char)character
{
    AppendLongCharacter(_tagName, character);
}

- (void)addNewAttribute
{
    [_attributes addObject:[HTMLAttribute new]];
}

- (BOOL)removeLastAttributeIfDuplicateName
{
    if (_attributes.count <= 1) return NO;
    NSString *lastAttributeName = [_attributes.lastObject name];
    for (NSUInteger i = 0; i < _attributes.count - 1; i++) {
        if ([[_attributes[i] name] isEqualToString:lastAttributeName]) {
            [_attributes removeLastObject];
            return YES;
        }
    }
    return NO;
}

#pragma mark NSObject

- (BOOL)isEqual:(HTMLTagToken *)other
{
    return ([other isKindOfClass:[HTMLTagToken class]] &&
            [other.tagName isEqualToString:self.tagName] &&
            other.selfClosingFlag == self.selfClosingFlag &&
            AreNilOrEqual(other.attributes, self.attributes));
}

- (NSUInteger)hash
{
    return self.tagName.hash + self.attributes.hash;
}

@end

@implementation HTMLStartTagToken

- (id)copyWithTagName:(NSString *)tagName
{
    HTMLStartTagToken *copy = [[self.class alloc] initWithTagName:tagName];
    for (HTMLAttribute *attribute in self.attributes) {
        [copy addAttributeWithName:attribute.name value:attribute.value];
    }
    copy.selfClosingFlag = self.selfClosingFlag;
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    NSArray *attributeDescriptions = [self.attributes valueForKey:@"keyValueDescription"];
    return [NSString stringWithFormat:@"<%@: %p <%@%@%@> >", self.class, self, self.tagName,
            self.attributes.count > 0 ? @" " : @"", [attributeDescriptions componentsJoinedByString:@" "]];
}

- (BOOL)isEqual:(HTMLStartTagToken *)other
{
    return ([super isEqual:other] &&
            [other isKindOfClass:[HTMLStartTagToken class]]);
}

@end

@implementation HTMLEndTagToken

#pragma mark NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p </%@> >", self.class, self, self.tagName];
}

- (BOOL)isEqual:(HTMLEndTagToken *)other
{
    return ([other isKindOfClass:[HTMLEndTagToken class]] &&
            [other.tagName isEqualToString:self.tagName]);
}

@end

@implementation HTMLCommentToken
{
    NSMutableString *_data;
}

- (id)initWithData:(NSString *)data
{
    if (!(self = [super init])) return nil;
    _data = [NSMutableString stringWithString:data];
    return self;
}

- (id)init
{
    return [self initWithData:@""];
}

- (NSString *)data
{
    return _data;
}

- (void)appendFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    [_data appendString:[[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
}

- (void)appendString:(NSString *)string
{
    [_data appendString:string];
}

- (void)appendLongCharacter:(UTF32Char)character
{
    AppendLongCharacter(_data, character);
}

#pragma mark NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p <!-- %@ --> >", self.class, self, self.data];
}

- (BOOL)isEqual:(HTMLCommentToken *)other
{
    return ([other isKindOfClass:[HTMLCommentToken class]] &&
            [other.data isEqualToString:self.data]);
}

- (NSUInteger)hash
{
    return self.data.hash;
}

@end

@implementation HTMLCharacterToken

- (id)initWithData:(UTF32Char)data
{
    if (!(self = [super init])) return nil;
    _data = data;
    return self;
}

#pragma mark NSObject

- (NSString *)description
{
    NSMutableString *description = [NSMutableString new];
    [description appendFormat:@"<%@: %p '", self.class, self];
    AppendLongCharacter(description, self.data);
    [description appendString:@"'>"];
    return description;
}

- (BOOL)isEqual:(HTMLCharacterToken *)other
{
    return ([other isKindOfClass:[HTMLCharacterToken class]] &&
            other.data == self.data);
}

- (NSUInteger)hash
{
    return self.data;
}

@end

@implementation HTMLParseErrorToken

#pragma mark NSObject

- (BOOL)isEqual:(id)other
{
    return [other isKindOfClass:[HTMLParseErrorToken class]];
}

- (NSUInteger)hash
{
    // Must be constant since all parse errors are equivalent.
    return 27;
}

@end
