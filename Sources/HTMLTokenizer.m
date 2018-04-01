//  HTMLTokenizer.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTokenizer.h"
#import "HTMLEntities.h"
#import "HTMLParser.h"
#import "HTMLPreprocessedInputStream.h"
#import "HTMLString.h"

@interface HTMLTagToken ()

- (void)appendLongCharacterToTagName:(UTF32Char)character;

@end

@interface HTMLDOCTYPEToken ()

- (void)appendLongCharacterToName:(UTF32Char)character;
- (void)appendStringToPublicIdentifier:(NSString *)string;
- (void)appendStringToSystemIdentifier:(NSString *)string;

@end

@interface HTMLCommentToken ()

- (void)appendString:(NSString *)string;
- (void)appendLongCharacter:(UTF32Char)character;

@end

@interface HTMLParser ()

@property (readonly, strong, nonatomic) HTMLElement *adjustedCurrentNode;

@end

@implementation HTMLTokenizer
{
    HTMLPreprocessedInputStream *_inputStream;
    HTMLTokenizerState _state;
    NSMutableArray *_tokenQueue;
    NSMutableString *_characterBuffer;
    id _currentToken;
    HTMLTokenizerState _sourceAttributeValueState;
    NSMutableString *_currentAttributeName;
    NSMutableString *_currentAttributeValue;
    NSMutableString *_temporaryBuffer;
    UTF32Char _additionalAllowedCharacter;
    NSString *_mostRecentEmittedStartTagName;
    BOOL _done;
}

- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (!self) return nil;
    
    _inputStream = [[HTMLPreprocessedInputStream alloc] initWithString:string];
    __weak __typeof__(self) weakSelf = self;
    [_inputStream setErrorBlock:^(NSString *error) {
        [weakSelf emitParseError:@"%@", error];
    }];
    self.state = HTMLDataTokenizerState;
    _tokenQueue = [NSMutableArray new];
    _characterBuffer = [NSMutableString new];
    
    return self;
}

- (NSString *)string
{
    return _inputStream.string;
}

- (void)setLastStartTag:(NSString *)tagName
{
    _mostRecentEmittedStartTagName = [tagName copy];
}

- (void)dataState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in data state"];
        }
        return c == '&' || c == '<';
    }];
    [self emitCharacterTokenWithString:string];
    switch ([self consumeNextInputCharacter]) {
        case '&':
            return [self switchToState:HTMLCharacterReferenceInDataTokenizerState];
        case '<':
            return [self switchToState:HTMLTagOpenTokenizerState];
        case EOF:
            _done = YES;
            break;
    }
}

- (void)characterReferenceInDataState
{
    [self switchToState:HTMLDataTokenizerState];
    _additionalAllowedCharacter = (UTF32Char)EOF;
    NSString *data = [self attemptToConsumeCharacterReference];
    if (data) {
        [self emitCharacterTokenWithString:data];
    } else {
        [self emitCharacterTokenWithString:@"&"];
    }
}

- (void)RCDATAState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in RCDATA state"];
        }
        return c == '&' || c == '<';
    }];
    [self emitCharacterTokenWithString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '&':
            return [self switchToState:HTMLCharacterReferenceInRCDATATokenizerState];
        case '<':
            return [self switchToState:HTMLRCDATALessThanSignTokenizerState];
        case EOF:
            _done = YES;
            break;
    }
}

- (void)characterReferenceInRCDATAState
{
    [self switchToState:HTMLRCDATATokenizerState];
    _additionalAllowedCharacter = (UTF32Char)EOF;
    NSString *data = [self attemptToConsumeCharacterReference];
    if (data) {
        [self emitCharacterTokenWithString:data];
    } else {
        [self emitCharacterTokenWithString:@"&"];
    }
}

- (void)RAWTEXTState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in RAWTEXT state"];
        }
        return c == '<';
    }];
    [self emitCharacterTokenWithString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '<':
            return [self switchToState:HTMLRAWTEXTLessThanSignTokenizerState];
        case EOF:
            _done = YES;
            break;
    }
}

- (void)scriptDataState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in script data state"];
        }
        return c == '<';
    }];
    [self emitCharacterTokenWithString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '<':
            return [self switchToState:HTMLScriptDataLessThanSignTokenizerState];
        case EOF:
            _done = YES;
            break;
    }
}

- (void)PLAINTEXTState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in PLAINTEXT state"];
        }
        return NO;
    }];
    [self emitCharacterTokenWithString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    _done = YES;
}

static inline BOOL is_upper(NSInteger c)
{
    return c >= 'A' && c <= 'Z';
}

static inline BOOL is_lower(NSInteger c)
{
    return c >= 'a' && c <= 'z';
}

- (void)tagOpenState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '!':
            [self switchToState:HTMLMarkupDeclarationOpenTokenizerState];
            break;
        case '/':
            [self switchToState:HTMLEndTagOpenTokenizerState];
            break;
        case '?':
            [self emitParseError:@"Bogus ? in tag open state"];
            [self switchToState:HTMLBogusCommentTokenizerState];
            // SPEC We are to "emit a comment token whose data is the concatenation of all characters starting from and including the character that caused the state machine to switch into the bogus comment state...". This is effectively, but not explicitly, reconsuming the current input character.
            [_inputStream reconsumeCurrentInputCharacter];
            break;
        default:
            if (is_upper(c) || is_lower(c)) {
                _currentToken = [HTMLStartTagToken new];
                unichar toAppend = c + (is_upper(c) ? 0x0020 : 0);
                [_currentToken appendLongCharacterToTagName:toAppend];
                [self switchToState:HTMLTagNameTokenizerState];
            } else {
                [self emitParseError:@"Unexpected character in tag open state"];
                [self switchToState:HTMLDataTokenizerState];
                [self emitCharacterTokenWithString:@"<"];
                [self reconsume:c];
            }
            break;
    }
}

- (void)endTagOpenState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '>':
            [self emitParseError:@"Unexpected > in end tag open state"];
            [self switchToState:HTMLDataTokenizerState];
            break;
        case EOF:
            [self emitParseError:@"EOF in end tag open state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCharacterTokenWithString:@"</"];
            [self reconsume:c];
            break;
        default:
            if (is_upper(c) || is_lower(c)) {
                _currentToken = [HTMLEndTagToken new];
                unichar toAppend = c + (is_upper(c) ? 0x0020 : 0);
                [_currentToken appendLongCharacterToTagName:toAppend];
                [self switchToState:HTMLTagNameTokenizerState];
            } else {
                [self emitParseError:@"Unexpected character in end tag open state"];
                [self switchToState:HTMLBogusCommentTokenizerState];
                // SPEC We are to "emit a comment token whose data is the concatenation of all characters starting from and including the character that caused the state machine to switch into the bogus comment state...". This is effectively, but not explicitly, reconsuming the current input character.
                [self reconsume:c];
            }
            break;
    }
}

- (void)tagNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"U+0000 NULL in tag name state"];
            [_currentToken appendLongCharacterToTagName:0xFFFD];
            break;
        case EOF:
            [self emitParseError:@"EOF in tag name state"];
            [self switchToState:HTMLDataTokenizerState];
            break;
        default:
            if (is_upper(c)) {
                [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
            } else {
                [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
            }
            break;
    }
}

- (void)RCDATALessThanSignState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (c == '/') {
        _temporaryBuffer = [NSMutableString new];
        [self switchToState:HTMLRCDATAEndTagOpenTokenizerState];
    } else {
        [self switchToState:HTMLRCDATATokenizerState];
        [self emitCharacterTokenWithString:@"<"];
        [self reconsume:c];
    }
}

- (void)RCDATAEndTagOpenState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (is_upper(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLRCDATAEndTagNameTokenizerState];
    } else if (is_lower(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLRCDATAEndTagNameTokenizerState];
    } else {
        [self switchToState:HTMLRCDATATokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self reconsume:c];
    }
}

- (void)RCDATAEndTagNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                return;
            }
            break;
        case '/':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                return;
            }
            break;
        case '>':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLDataTokenizerState];
                [self emitCurrentToken];
                return;
            }
            break;
    }
    if (is_upper(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else if (is_lower(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else {
        [self switchToState:HTMLRCDATATokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self emitCharacterTokenWithString:_temporaryBuffer];
        [self reconsume:c];
    }
}

- (void)RAWTEXTLessThanSignState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (c == '/') {
        _temporaryBuffer = [NSMutableString new];
        [self switchToState:HTMLRAWTEXTEndTagOpenTokenizerState];
    } else {
        [self switchToState:HTMLRAWTEXTTokenizerState];
        [self emitCharacterTokenWithString:@"<"];
        [self reconsume:c];
    }
}

- (void)RAWTEXTEndTagOpenState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (is_upper(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLRAWTEXTEndTagNameTokenizerState];
    } else if (is_lower(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLRAWTEXTEndTagNameTokenizerState];
    } else {
        [self switchToState:HTMLRAWTEXTTokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self reconsume:c];
    }
}

- (void)RAWTEXTEndTagNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                return;
            }
            break;
        case '/':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                return;
            }
            break;
        case '>':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLDataTokenizerState];
                [self emitCurrentToken];
                return;
            }
            break;
    }
    if (is_upper(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else if (is_lower(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else {
        [self switchToState:HTMLRAWTEXTTokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self emitCharacterTokenWithString:_temporaryBuffer];
        [self reconsume:c];
    }
}

- (void)scriptDataLessThanSignState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '/':
            _temporaryBuffer = [NSMutableString new];
            [self switchToState:HTMLScriptDataEndTagOpenTokenizerState];
            break;
        case '!':
            [self switchToState:HTMLScriptDataEscapeStartTokenizerState];
            [self emitCharacterTokenWithString:@"<!"];
            break;
        default:
            [self switchToState:HTMLScriptDataTokenizerState];
            [self emitCharacterTokenWithString:@"<"];
            [self reconsume:c];
            break;
    }
}

- (void)scriptDataEndTagOpenState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (is_upper(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLScriptDataEndTagNameTokenizerState];
    } else if (is_lower(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLScriptDataEndTagNameTokenizerState];
    } else {
        [self switchToState:HTMLScriptDataTokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self reconsume:c];
    }
}

- (void)scriptDataEndTagNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                return;
            }
            break;
        case '/':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                return;
            }
            break;
        case '>':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLDataTokenizerState];
                [self emitCurrentToken];
                return;
            }
            break;
    }
    if (is_upper(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else if (is_lower(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else {
        [self switchToState:HTMLScriptDataTokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self emitCharacterTokenWithString:_temporaryBuffer];
        [self reconsume:c];
    }
}

- (void)scriptDataEscapeStartState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (c == '-') {
        [self switchToState:HTMLScriptDataEscapeStartDashTokenizerState];
        [self emitCharacterTokenWithString:@"-"];
    } else {
        [self switchToState:HTMLScriptDataTokenizerState];
        [self reconsume:c];
    }
}

- (void)scriptDataEscapeStartDashState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (c == '-') {
        [self switchToState:HTMLScriptDataEscapedDashDashTokenizerState];
        [self emitCharacterTokenWithString:@"-"];
    } else {
        [self switchToState:HTMLScriptDataTokenizerState];
        [self reconsume:c];
    }
}

- (void)scriptDataEscapedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in script data escaped state"];
        }
        return c == '-' || c == '<';
    }];
    [self emitCharacterTokenWithString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLScriptDataEscapedDashTokenizerState];
            [self emitCharacterTokenWithString:@"-"];
            break;
        case '<':
            return [self switchToState:HTMLScriptDataEscapedLessThanSignTokenizerState];
        case EOF:
            [self switchToState:HTMLDataTokenizerState];
            [self emitParseError:@"EOF in script data escaped state"];
            [self reconsume:EOF];
            break;
    }
}

- (void)scriptDataEscapedDashState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLScriptDataEscapedDashDashTokenizerState];
            [self emitCharacterTokenWithString:@"-"];
            break;
        case '<':
            [self switchToState:HTMLScriptDataEscapedLessThanSignTokenizerState];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in script data escaped dash state"];
            [self switchToState:HTMLScriptDataEscapedTokenizerState];
            [self emitCharacterTokenWithString:@"\uFFFD"];
            break;
        case EOF:
            [self emitParseError:@"EOF in script data escaped dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
            [self switchToState:HTMLScriptDataEscapedTokenizerState];
            [self emitCharacterToken:(UTF32Char)c];
            break;
    }
}

- (void)scriptDataEscapedDashDashState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self emitCharacterTokenWithString:@"-"];
            break;
        case '<':
            [self switchToState:HTMLScriptDataEscapedLessThanSignTokenizerState];
            break;
        case '>':
            [self switchToState:HTMLScriptDataTokenizerState];
            [self emitCharacterTokenWithString:@">"];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in script data escaped dash dash state"];
            [self switchToState:HTMLScriptDataEscapedTokenizerState];
            [self emitCharacterTokenWithString:@"\uFFFD"];
            break;
        case EOF:
            [self emitParseError:@"EOF in script data escaped dash dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
            [self switchToState:HTMLScriptDataEscapedTokenizerState];
            [self emitCharacterToken:(UTF32Char)c];
            break;
    }
}

- (void)scriptDataEscapedLessThanSignState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '/':
            _temporaryBuffer = [NSMutableString new];
            [self switchToState:HTMLScriptDataEscapedEndTagOpenTokenizerState];
            break;
        default:
            if (is_upper(c)) {
                _temporaryBuffer = [NSMutableString new];
                AppendLongCharacter(_temporaryBuffer, (UTF32Char)c + 0x0020);
                [self switchToState:HTMLScriptDataDoubleEscapeStartTokenizerState];
                [self emitCharacterTokenWithString:@"<"];
                [self emitCharacterToken:(UTF32Char)c];
            } else if (is_lower(c)) {
                _temporaryBuffer = [NSMutableString new];
                AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
                [self switchToState:HTMLScriptDataDoubleEscapeStartTokenizerState];
                [self emitCharacterTokenWithString:@"<"];
                [self emitCharacterToken:(UTF32Char)c];
            } else {
                [self switchToState:HTMLScriptDataEscapedTokenizerState];
                [self emitCharacterTokenWithString:@"<"];
                [self reconsume:c];
            }
            break;
    }
}

- (void)scriptDataEscapedEndTagOpenState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (is_upper(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLScriptDataEscapedEndTagNameTokenizerState];
    } else if (is_lower(c)) {
        _currentToken = [HTMLEndTagToken new];
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
        [self switchToState:HTMLScriptDataEscapedEndTagNameTokenizerState];
    } else {
        [self switchToState:HTMLScriptDataEscapedTokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self reconsume:c];
    }
}

- (void)scriptDataEscapedEndTagNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLBeforeAttributeNameTokenizerState];
                return;
            }
            break;
        case '/':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLSelfClosingStartTagTokenizerState];
                return;
            }
            break;
        case '>':
            if ([self currentTagIsAppropriateEndTagToken]) {
                [self switchToState:HTMLDataTokenizerState];
                [self emitCurrentToken];
                return;
            }
            break;
    }
    if (is_upper(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c + 0x0020];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else if (is_lower(c)) {
        [_currentToken appendLongCharacterToTagName:(UTF32Char)c];
        AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
    } else {
        [self switchToState:HTMLScriptDataEscapedTokenizerState];
        [self emitCharacterTokenWithString:@"</"];
        [self emitCharacterTokenWithString:_temporaryBuffer];
        [self reconsume:c];
    }
}

- (void)scriptDataDoubleEscapeStartState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitCharacterToken:(UTF32Char)c];
            break;
        default:
            if (is_upper(c)) {
                AppendLongCharacter(_temporaryBuffer, (UTF32Char)c + 0x0020);
                [self emitCharacterToken:(UTF32Char)c];
            } else if (is_lower(c)) {
                AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
                [self emitCharacterToken:(UTF32Char)c];
            } else {
                [self switchToState:HTMLScriptDataEscapedTokenizerState];
                [self reconsume:c];
            }
            break;
    }
}

- (void)scriptDataDoubleEscapedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in script data double escaped state"];
        }
        return c == '-' || c == '<';
    }];
    [self emitCharacterTokenWithString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLScriptDataDoubleEscapedDashTokenizerState];
            [self emitCharacterTokenWithString:@"-"];
            break;
        case '<':
            [self switchToState:HTMLScriptDataDoubleEscapedLessThanSignTokenizerState];
            [self emitCharacterTokenWithString:@"<"];
            break;
        case EOF:
            [self emitParseError:@"EOF in script data double escaped state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
    }
}

- (void)scriptDataDoubleEscapedDashState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLScriptDataDoubleEscapedDashDashTokenizerState];
            [self emitCharacterTokenWithString:@"-"];
            break;
        case '<':
            [self switchToState:HTMLScriptDataDoubleEscapedLessThanSignTokenizerState];
            [self emitCharacterTokenWithString:@"<"];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in script data double escaped dash state"];
            [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
            [self emitCharacterTokenWithString:@"\uFFFD"];
            break;
        case EOF:
            [self emitParseError:@"EOF in script data double escaped dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
            [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
            [self emitCharacterToken:(UTF32Char)c];
            break;
    }
}

- (void)scriptDataDoubleEscapedDashDashState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self emitCharacterTokenWithString:@"-"];
            break;
        case '<':
            [self switchToState:HTMLScriptDataDoubleEscapedLessThanSignTokenizerState];
            [self emitCharacterTokenWithString:@"<"];
            break;
        case '>':
            [self switchToState:HTMLScriptDataTokenizerState];
            [self emitCharacterTokenWithString:@">"];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in script data double escaped dash dash state"];
            [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
            [self emitCharacterTokenWithString:@"\uFFFD"];
            break;
        case EOF:
            [self emitParseError:@"EOF in script data double escaped dash dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
            [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
            [self emitCharacterToken:(UTF32Char)c];
            break;
    }
}

- (void)scriptDataDoubleEscapedLessThanSignState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (c == '/') {
        _temporaryBuffer = [NSMutableString new];
        [self switchToState:HTMLScriptDataDoubleEscapeEndTokenizerState];
        [self emitCharacterTokenWithString:@"/"];
    } else {
        [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
        [self reconsume:c];
    }
}

- (void)scriptDataDoubleEscapeEndState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitCharacterToken:(UTF32Char)c];
            break;
        default:
            if (is_upper(c)) {
                AppendLongCharacter(_temporaryBuffer, (UTF32Char)c + 0x0020);
                [self emitCharacterToken:(UTF32Char)c];
            } else if (is_lower(c)) {
                AppendLongCharacter(_temporaryBuffer, (UTF32Char)c);
                [self emitCharacterToken:(UTF32Char)c];
            } else {
                [self switchToState:HTMLScriptDataDoubleEscapedTokenizerState];
                [self reconsume:c];
            }
            break;
    }
}

- (void)beforeAttributeNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"U+0000 NULL in before attribute name state"];
            _currentAttributeName = [NSMutableString new];
            AppendLongCharacter(_currentAttributeName, 0xFFFD);
            [self switchToState:HTMLAttributeNameTokenizerState];
            break;
        case '"':
        case '\'':
        case '<':
        case '=':
            [self emitParseError:@"Unexpected %c in before attribute name state", (char)c];
            goto anythingElse;
        case EOF:
            [self emitParseError:@"EOF in before attribute name state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
        anythingElse:
            _currentAttributeName = [NSMutableString new];
            if (is_upper(c)) {
                AppendLongCharacter(_currentAttributeName, (UTF32Char)c + 0x0020);
            } else {
                AppendLongCharacter(_currentAttributeName, (UTF32Char)c);
            }
            [self switchToState:HTMLAttributeNameTokenizerState];
            break;
    }
}

- (void)attributeNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            [self switchToState:HTMLAfterAttributeNameTokenizerState];
            break;
        case '/':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLSelfClosingStartTagTokenizerState];
            break;
        case '=':
            [self switchToState:HTMLBeforeAttributeValueTokenizerState];
            break;
        case '>':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in attribute name state"];
            AppendLongCharacter(_currentAttributeName, 0xFFFD);
            break;
        case '"':
        case '\'':
        case '<':
            [self emitParseError:@"Unexpected %c in attribute name state", (char)c];
            goto anythingElse;
        case EOF:
            [self emitParseError:@"EOF in attribute name state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
        anythingElse:
            if (is_upper(c)) {
                AppendLongCharacter(_currentAttributeName, (UTF32Char)c + 0x0020);
            } else {
                AppendLongCharacter(_currentAttributeName, (UTF32Char)c);
            }
            break;
    }
}

- (void)afterAttributeNameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            break;
        case '/':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLSelfClosingStartTagTokenizerState];
            break;
        case '=':
            [self switchToState:HTMLBeforeAttributeValueTokenizerState];
            break;
        case '>':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in after attribute name state"];
            [self addCurrentAttributeToCurrentToken];
            _currentAttributeName = [NSMutableString new];
            AppendLongCharacter(_currentAttributeName, 0xFFFD);
            [self switchToState:HTMLAttributeNameTokenizerState];
            break;
        case '"':
        case '\'':
        case '<':
            [self emitParseError:@"Unexpected %c in after attribute name state", (char)c];
            goto anythingElse;
        case EOF:
            [self emitParseError:@"EOF in after attribute name state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
        anythingElse:
            [self addCurrentAttributeToCurrentToken];
            _currentAttributeName = [NSMutableString new];
            if (is_upper(c)) {
                AppendLongCharacter(_currentAttributeName, (UTF32Char)c + 0x0020);
            } else {
                AppendLongCharacter(_currentAttributeName, (UTF32Char)c);
            }
            [self switchToState:HTMLAttributeNameTokenizerState];
            break;
    }
}

- (void)beforeAttributeValueState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            break;
        case '"':
            _currentAttributeValue = [NSMutableString new];
            [self switchToState:HTMLAttributeValueDoubleQuotedTokenizerState];
            break;
        case '&':
            _currentAttributeValue = [NSMutableString new];
            [self switchToState:HTMLAttributeValueUnquotedTokenizerState];
            [self reconsume:c];
            break;
        case '\'':
            _currentAttributeValue = [NSMutableString new];
            [self switchToState:HTMLAttributeValueSingleQuotedTokenizerState];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in before attribute value state"];
            _currentAttributeValue = [NSMutableString new];
            AppendLongCharacter(_currentAttributeValue, 0xFFFD);
            [self switchToState:HTMLAttributeValueUnquotedTokenizerState];
            break;
        case '>':
            [self emitParseError:@"Unexpected > in before attribute value state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case '<':
        case '=':
        case '`':
            [self emitParseError:@"Unexpected %c in before attribute value state", (char)c];
            goto anythingElse;
        case EOF:
            [self emitParseError:@"EOF in before attribute value state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
        anythingElse:
            _currentAttributeValue = [NSMutableString new];
            AppendLongCharacter(_currentAttributeValue, (UTF32Char)c);
            [self switchToState:HTMLAttributeValueUnquotedTokenizerState];
            break;
    }
}

- (void)attributeValueDoubleQuotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in attribute value double quoted state"];
        }
        return c == '"' || c == '&';
    }] ?: @"";
    [_currentAttributeValue appendString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '"':
            return [self switchToState:HTMLAfterAttributeValueQuotedTokenizerState];
        case '&':
            [self switchToState:HTMLCharacterReferenceInAttributeValueTokenizerState];
            _additionalAllowedCharacter = '"';
            _sourceAttributeValueState = HTMLAttributeValueDoubleQuotedTokenizerState;
            break;
        case EOF:
            [self emitParseError:@"EOF in attribute value double quoted state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
    }
}

- (void)attributeValueSingleQuotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in attribute value single quoted state"];
        }
        return c == '\'' || c == '&';
    }] ?: @"";
    [_currentAttributeValue appendString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '\'':
            return [self switchToState:HTMLAfterAttributeValueQuotedTokenizerState];
        case '&':
            [self switchToState:HTMLCharacterReferenceInAttributeValueTokenizerState];
            _additionalAllowedCharacter = '\'';
            _sourceAttributeValueState = HTMLAttributeValueSingleQuotedTokenizerState;
            break;
        case EOF:
            [self emitParseError:@"EOF in attribute value single quoted state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
    }
}

- (void)attributeValueUnquotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in attribute value unquoted state"];
        } else if (c == '"' || c == '\'' || c == '<' || c == '=' || c == '`') {
            [self emitParseError:@"Unexpected %c in attribute value unquoted state", (char)c];
        }
        return is_whitespace(c) || c == '&' || c == '>';
    }] ?: @"";
    [_currentAttributeValue appendString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            [self addCurrentAttributeToCurrentToken];
            return [self switchToState:HTMLBeforeAttributeNameTokenizerState];
        case '&':
            [self switchToState:HTMLCharacterReferenceInAttributeValueTokenizerState];
            _additionalAllowedCharacter = '>';
            _sourceAttributeValueState = HTMLAttributeValueUnquotedTokenizerState;
            break;
        case '>':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in attribute value unquoted state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
    }
}

- (void)characterReferenceInAttributeValueState
{
    NSString *characters = [self attemptToConsumeCharacterReferenceAsPartOfAnAttribute];
    if (characters) {
        [_currentAttributeValue appendString:characters];
    } else {
        [_currentAttributeValue appendString:@"&"];
    }
    [self switchToState:_sourceAttributeValueState];
}

- (void)afterAttributeValueQuotedState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLBeforeAttributeNameTokenizerState];
            break;
        case '/':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLSelfClosingStartTagTokenizerState];
            break;
        case '>':
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in after attribute value quoted state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in after attribute value quoted state"];
            [self addCurrentAttributeToCurrentToken];
            [self switchToState:HTMLBeforeAttributeNameTokenizerState];
            [self reconsume:c];
            break;
    }
}

- (void)selfClosingStartTagState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '>':
            [_currentToken setSelfClosingFlag:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in self closing start tag state"];
            [self switchToState:HTMLDataTokenizerState];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in self closing start tag state"];
            [self switchToState:HTMLBeforeAttributeNameTokenizerState];
            [self reconsume:c];
            break;
    }
}

- (void)bogusCommentState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        return c == '>';
    }];
    _currentToken = [[HTMLCommentToken alloc] initWithData:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    [self emitCurrentToken];
    [self switchToState:HTMLDataTokenizerState];
    if ([self consumeNextInputCharacter] == (UTF32Char)EOF) {
        [self reconsume:EOF];
    }
}

- (void)markupDeclarationOpenState
{
    if ([_inputStream consumeString:@"--" matchingCase:YES]) {
        _currentToken = [[HTMLCommentToken alloc] initWithData:@""];
        [self switchToState:HTMLCommentStartTokenizerState];
    } else if (_parser.adjustedCurrentNode.htmlNamespace != HTMLNamespaceHTML && [_inputStream consumeString:@"[CDATA[" matchingCase:YES]) {
        [self switchToState:HTMLCDATASectionTokenizerState];
    } else if ([_inputStream consumeString:@"DOCTYPE" matchingCase:NO]) {
        [self switchToState:HTMLDOCTYPETokenizerState];
    } else {
        [self emitParseError:@"Bogus character in markup declaration open state"];
        [self switchToState:HTMLBogusCommentTokenizerState];
    }
}

- (void)commentStartState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLCommentStartDashTokenizerState];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in comment start state"];
            [_currentToken appendLongCharacter:0xFFFD];
            [self switchToState:HTMLCommentTokenizerState];
            break;
        case '>':
            [self emitParseError:@"Unexpected > in comment start state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in comment start state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [_currentToken appendLongCharacter:(UTF32Char)c];
            [self switchToState:HTMLCommentTokenizerState];
            break;
    }
}

- (void)commentStartDashState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLCommentEndTokenizerState];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in comment start dash state"];
            [_currentToken appendLongCharacter:'-'];
            [_currentToken appendLongCharacter:0xFFFD];
            [self switchToState:HTMLCommentTokenizerState];
            break;
        case '>':
            [self emitParseError:@"Unexpected > in comment start dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in comment start dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [_currentToken appendLongCharacter:'-'];
            [_currentToken appendLongCharacter:(UTF32Char)c];
            [self switchToState:HTMLCommentTokenizerState];
            break;
    }
}

- (void)commentState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in comment state"];
        }
        return c == '-';
    }];
    [_currentToken appendString:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '-':
            return [self switchToState:HTMLCommentEndDashTokenizerState];
        case EOF:
            [self emitParseError:@"EOF in comment state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
    }
}

- (void)commentEndDashState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [self switchToState:HTMLCommentEndTokenizerState];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in comment end dash state"];
            [_currentToken appendLongCharacter:'-'];
            [_currentToken appendLongCharacter:0xFFFD];
            [self switchToState:HTMLCommentTokenizerState];
            break;
        case EOF:
            [self emitParseError:@"EOF in comment end dash state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [_currentToken appendLongCharacter:'-'];
            [_currentToken appendLongCharacter:(UTF32Char)c];
            [self switchToState:HTMLCommentTokenizerState];
            break;
    }
}

- (void)commentEndState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '>':
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in comment end state"];
            [_currentToken appendString:@"--"];
            [_currentToken appendLongCharacter:0xFFFD];
            [self switchToState:HTMLCommentTokenizerState];
            break;
        case '!':
            [self emitParseError:@"Unexpected ! in comment end state"];
            [self switchToState:HTMLCommentEndBangTokenizerState];
            break;
        case '-':
            [self emitParseError:@"Unexpected - in comment end state"];
            [_currentToken appendLongCharacter:'-'];
            break;
        case EOF:
            [self emitParseError:@"EOF in comment end state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in comment end state"];
            [_currentToken appendString:@"--"];
            [_currentToken appendLongCharacter:(UTF32Char)c];
            [self switchToState:HTMLCommentTokenizerState];
            break;
    }
}

- (void)commentEndBangState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '-':
            [_currentToken appendString:@"--!"];
            [self switchToState:HTMLCommentEndDashTokenizerState];
            break;
        case '>':
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in comment end bang state"];
            [_currentToken appendString:@"--!\uFFFD"];
            [self switchToState:HTMLCommentTokenizerState];
            break;
        case EOF:
            [self emitParseError:@"EOF in comment end bang state"];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [_currentToken appendString:@"--!"];
            [_currentToken appendLongCharacter:(UTF32Char)c];
            [self switchToState:HTMLCommentTokenizerState];
            break;
    }
}

- (void)DOCTYPEState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            [self switchToState:HTMLBeforeDOCTYPENameTokenizerState];
            break;
        case EOF:
            [self emitParseError:@"EOF in DOCTYPE state"];
            [self switchToState:HTMLDataTokenizerState];
            _currentToken = [HTMLDOCTYPEToken new];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in DOCTYPE state"];
            [self switchToState:HTMLBeforeDOCTYPENameTokenizerState];
            [self reconsume:c];
            break;
    }
}

- (void)beforeDOCTYPENameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            break;
        case '\0':
            [self emitParseError:@"U+0000 NULL in before DOCTYPE name state"];
            _currentToken = [HTMLDOCTYPEToken new];
            [_currentToken appendLongCharacterToName:0xFFFD];
            [self switchToState:HTMLDOCTYPENameTokenizerState];
            break;
        case '>':
            [self emitParseError:@"Unexpected > in before DOCTYPE name state"];
            _currentToken = [HTMLDOCTYPEToken new];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in before DOCTYPE name state"];
            [self switchToState:HTMLDataTokenizerState];
            _currentToken = [HTMLDOCTYPEToken new];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            _currentToken = [HTMLDOCTYPEToken new];
            if (is_upper(c)) {
                [_currentToken appendLongCharacterToName:(UTF32Char)c + 0x0020];
            } else {
                [_currentToken appendLongCharacterToName:(UTF32Char)c];
            }
            [self switchToState:HTMLDOCTYPENameTokenizerState];
            break;
    }
}

- (void)DOCTYPENameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"U+0000 NULL in DOCTYPE name state"];
            [_currentToken appendLongCharacterToName:0xFFFD];
            break;
        case EOF:
            [self emitParseError:@"EOF in DOCTYPE name state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            if (is_upper(c)) {
                [_currentToken appendLongCharacterToName:(UTF32Char)c + 0x0020];
            } else {
                [_currentToken appendLongCharacterToName:(UTF32Char)c];
            }
            break;
    }
}

- (void)afterDOCTYPENameState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"EOF in after DOCTYPE name state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        case 'P':
        case 'p':
            if ([_inputStream consumeString:@"UBLIC" matchingCase:NO]) {
                [self switchToState:HTMLAfterDOCTYPEPublicKeywordTokenizerState];
            } else {
                goto anythingElse;
            }
            break;
        case 'S':
        case 's':
            if ([_inputStream consumeString:@"YSTEM" matchingCase:NO]) {
                [self switchToState:HTMLAfterDOCTYPESystemKeywordTokenizerState];
            } else {
                goto anythingElse;
            }
            break;
        default:
        anythingElse:
                [self emitParseError:@"Unexpected character in after DOCTYPE name state"];
                [_currentToken setForceQuirks:YES];
                [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)afterDOCTYPEPublicKeywordState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            [self switchToState:HTMLBeforeDOCTYPEPublicIdentifierTokenizerState];
            break;
        case '"':
            [self emitParseError:@"Unexpected \" in after DOCTYPE public keyword state"];
            [_currentToken setPublicIdentifier:@""];
            [self switchToState:HTMLDOCTYPEPublicIdentifierDoubleQuotedTokenizerState];
            break;
        case '\'':
            [self emitParseError:@"Unexpected ' in after DOCTYPE public keyword state"];
            [_currentToken setPublicIdentifier:@""];
            [self switchToState:HTMLDOCTYPEPublicIdentifierSingleQuotedTokenizerState];
            break;
        case '>':
            [self emitParseError:@"Unexpected > in after DOCTYPE public keyword state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in after DOCTYPE public keyword state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in after DOCTYPE public keyword state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)beforeDOCTYPEPublicIdentifierState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"Unexpected > in before DOCTYPE public identifier state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in before DOCTYPE public identifier state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in before DOCTYPE public identifier state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)DOCTYPEPublicIdentifierDoubleQuotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in DOCTYPE public identifier double quoted state"];
        }
        return c == '"' || c == '>';
    }];
    [_currentToken appendStringToPublicIdentifier:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '"':
            return [self switchToState:HTMLAfterDOCTYPEPublicIdentifierTokenizerState];
        case '>':
            [self emitParseError:@"Unexpected > in DOCTYPE public identifier double quoted state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in DOCTYPE public identifier double quoted state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
    }
}

- (void)DOCTYPEPublicIdentifierSingleQuotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in DOCTYPE public identifier single quoted state"];
        }
        return c == '\'' || c == '>';
    }];
    [_currentToken appendStringToPublicIdentifier:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '\'':
            return [self switchToState:HTMLAfterDOCTYPEPublicIdentifierTokenizerState];
        case '>':
            [self emitParseError:@"Unexpected > in DOCTYPE public identifier single quoted state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in DOCTYPE public identifier single quoted state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
    }
}

- (void)afterDOCTYPEPublicIdentifierState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"Unexpected \" in after DOCTYPE public identifier state"];
            [_currentToken setSystemIdentifier:@""];
            [self switchToState:HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState];
            break;
        case '\'':
            [self emitParseError:@"Unexpected ' in after DOCTYPE public identifier state"];
            [_currentToken setSystemIdentifier:@""];
            [self switchToState:HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState];
            break;
        case EOF:
            [self emitParseError:@"EOF in after DOCTYPE public identifier state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in after DOCTYPE public identifier state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)betweenDOCTYPEPublicAndSystemIdentifiersState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"EOF in between DOCTYPE public and system identifiers state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in between DOCTYPE public and system identifiers state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)afterDOCTYPESystemKeywordState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
            [self switchToState:HTMLBeforeDOCTYPESystemIdentifierTokenizerState];
            break;
        case '"':
            [self emitParseError:@"Unexpected \" in after DOCTYPE system keyword state"];
            [_currentToken setSystemIdentifier:@""];
            [self switchToState:HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState];
            break;
        case '\'':
            [self emitParseError:@"Unexpected ' in after DOCTYPE system keyword state"];
            [_currentToken setSystemIdentifier:@""];
            [self switchToState:HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState];
            break;
        case '>':
            [self emitParseError:@"Unexpected > in after DOCTYPE system keyword state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in after DOCTYPE system keyword state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in after DOCTYPE system keyword state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)beforeDOCTYPESystemIdentifierState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"Unexpected > in before DOCTYPE system identifier state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in before DOCTYPE system identifier state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in before DOCTYPE system identifier state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)DOCTYPESystemIdentifierDoubleQuotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in DOCTYPE system identifier double quoted state"];
        }
        return c == '"' || c == '>';
    }];
    [_currentToken appendStringToSystemIdentifier:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '"':
            return [self switchToState:HTMLAfterDOCTYPESystemIdentifierTokenizerState];
        case '>':
            [self emitParseError:@"Unexpected > in DOCTYPE system identifier double quoted state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in DOCTYPE system identifier double quoted state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
    }
}

- (void)DOCTYPESystemIdentifierSingleQuotedState
{
    NSString *string = [self consumeCharactersUpToFirstPassingTest:^BOOL(UTF32Char c) {
        if (c == '\0') {
            [self emitParseError:@"U+0000 NULL in DOCTYPE system identifier single quoted state"];
        }
        return c == '\'' || c == '>';
    }];
    [_currentToken appendStringToSystemIdentifier:[string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
    switch ([self consumeNextInputCharacter]) {
        case '\'':
            return [self switchToState:HTMLAfterDOCTYPESystemIdentifierTokenizerState];
        case '>':
            [self emitParseError:@"Unexpected > in DOCTYPE system identifier single quoted state"];
            [_currentToken setForceQuirks:YES];
            [self switchToState:HTMLDataTokenizerState];
            [self emitCurrentToken];
            break;
        case EOF:
            [self emitParseError:@"EOF in DOCTYPE system identifier single quoted state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
    }
}

- (void)afterDOCTYPESystemIdentifierState
{
    UTF32Char c;
    switch (c = [self consumeNextInputCharacter]) {
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
            [self emitParseError:@"EOF in after DOCTYPE system identifier state"];
            [self switchToState:HTMLDataTokenizerState];
            [_currentToken setForceQuirks:YES];
            [self emitCurrentToken];
            [self reconsume:EOF];
            break;
        default:
            [self emitParseError:@"Unexpected character in after DOCTYPE system identifier state"];
            [self switchToState:HTMLBogusDOCTYPETokenizerState];
            break;
    }
}

- (void)bogusDOCTYPEState
{
    UTF32Char c = [self consumeNextInputCharacter];
    if (c == '>') {
        [self switchToState:HTMLDataTokenizerState];
        [self emitCurrentToken];
    } else if (c == (UTF32Char)EOF) {
        [self switchToState:HTMLDataTokenizerState];
        [self emitCurrentToken];
        [self reconsume:EOF];
    }
}

- (void)CDATASectionState
{
    [self switchToState:HTMLDataTokenizerState];
    NSInteger squareBracketsSeen = 0;
    for (;;) {
        UTF32Char c = [self consumeNextInputCharacter];
        if (c == ']' && squareBracketsSeen < 2) {
            squareBracketsSeen++;
        } else if (c == ']' && squareBracketsSeen == 2) {
            [self emitCharacterTokenWithString:@"]"];
        } else if (c == '>' && squareBracketsSeen == 2) {
            break;
        } else {
            for (NSInteger i = 0; i < squareBracketsSeen; i++) {
                [self emitCharacterTokenWithString:@"]"];
            }
            if (c == (UTF32Char)EOF) {
                [self reconsume:c];
                break;
            }
            squareBracketsSeen = 0;
            [self emitCharacterToken:(UTF32Char)c];
        }
    }
}

- (void)resume
{
    switch (self.state) {
        case HTMLDataTokenizerState:
            return [self dataState];
        case HTMLCharacterReferenceInDataTokenizerState:
            return [self characterReferenceInDataState];
        case HTMLRCDATATokenizerState:
            return [self RCDATAState];
        case HTMLCharacterReferenceInRCDATATokenizerState:
            return [self characterReferenceInRCDATAState];
        case HTMLRAWTEXTTokenizerState:
            return [self RAWTEXTState];
        case HTMLScriptDataTokenizerState:
            return [self scriptDataState];
        case HTMLPLAINTEXTTokenizerState:
            return [self PLAINTEXTState];
        case HTMLTagOpenTokenizerState:
            return [self tagOpenState];
        case HTMLEndTagOpenTokenizerState:
            return [self endTagOpenState];
        case HTMLTagNameTokenizerState:
            return [self tagNameState];
        case HTMLRCDATALessThanSignTokenizerState:
            return [self RCDATALessThanSignState];
        case HTMLRCDATAEndTagOpenTokenizerState:
            return [self RCDATAEndTagOpenState];
        case HTMLRCDATAEndTagNameTokenizerState:
            return [self RCDATAEndTagNameState];
        case HTMLRAWTEXTLessThanSignTokenizerState:
            return [self RAWTEXTLessThanSignState];
        case HTMLRAWTEXTEndTagOpenTokenizerState:
            return [self RAWTEXTEndTagOpenState];
        case HTMLRAWTEXTEndTagNameTokenizerState:
            return [self RAWTEXTEndTagNameState];
        case HTMLScriptDataLessThanSignTokenizerState:
            return [self scriptDataLessThanSignState];
        case HTMLScriptDataEndTagOpenTokenizerState:
            return [self scriptDataEndTagOpenState];
        case HTMLScriptDataEndTagNameTokenizerState:
            return [self scriptDataEndTagNameState];
        case HTMLScriptDataEscapeStartTokenizerState:
            return [self scriptDataEscapeStartState];
        case HTMLScriptDataEscapeStartDashTokenizerState:
            return [self scriptDataEscapeStartDashState];
        case HTMLScriptDataEscapedTokenizerState:
            return [self scriptDataEscapedState];
        case HTMLScriptDataEscapedDashTokenizerState:
            return [self scriptDataEscapedDashState];
        case HTMLScriptDataEscapedDashDashTokenizerState:
            return [self scriptDataEscapedDashDashState];
        case HTMLScriptDataEscapedLessThanSignTokenizerState:
            return [self scriptDataEscapedLessThanSignState];
        case HTMLScriptDataEscapedEndTagOpenTokenizerState:
            return [self scriptDataEscapedEndTagOpenState];
        case HTMLScriptDataEscapedEndTagNameTokenizerState:
            return [self scriptDataEscapedEndTagNameState];
        case HTMLScriptDataDoubleEscapeStartTokenizerState:
            return [self scriptDataDoubleEscapeStartState];
        case HTMLScriptDataDoubleEscapedTokenizerState:
            return [self scriptDataDoubleEscapedState];
        case HTMLScriptDataDoubleEscapedDashTokenizerState:
            return [self scriptDataDoubleEscapedDashState];
        case HTMLScriptDataDoubleEscapedDashDashTokenizerState:
            return [self scriptDataDoubleEscapedDashDashState];
        case HTMLScriptDataDoubleEscapedLessThanSignTokenizerState:
            return [self scriptDataDoubleEscapedLessThanSignState];
        case HTMLScriptDataDoubleEscapeEndTokenizerState:
            return [self scriptDataDoubleEscapeEndState];
        case HTMLBeforeAttributeNameTokenizerState:
            return [self beforeAttributeNameState];
        case HTMLAttributeNameTokenizerState:
            return [self attributeNameState];
        case HTMLAfterAttributeNameTokenizerState:
            return [self afterAttributeNameState];
        case HTMLBeforeAttributeValueTokenizerState:
            return [self beforeAttributeValueState];
        case HTMLAttributeValueDoubleQuotedTokenizerState:
            return [self attributeValueDoubleQuotedState];
        case HTMLAttributeValueSingleQuotedTokenizerState:
            return [self attributeValueSingleQuotedState];
        case HTMLAttributeValueUnquotedTokenizerState:
            return [self attributeValueUnquotedState];
        case HTMLCharacterReferenceInAttributeValueTokenizerState:
            return [self characterReferenceInAttributeValueState];
        case HTMLAfterAttributeValueQuotedTokenizerState:
            return [self afterAttributeValueQuotedState];
        case HTMLSelfClosingStartTagTokenizerState:
            return [self selfClosingStartTagState];
        case HTMLBogusCommentTokenizerState:
            return [self bogusCommentState];
        case HTMLMarkupDeclarationOpenTokenizerState:
            return [self markupDeclarationOpenState];
        case HTMLCommentStartTokenizerState:
            return [self commentStartState];
        case HTMLCommentStartDashTokenizerState:
            return [self commentStartDashState];
        case HTMLCommentTokenizerState:
            return [self commentState];
        case HTMLCommentEndDashTokenizerState:
            return [self commentEndDashState];
        case HTMLCommentEndTokenizerState:
            return [self commentEndState];
        case HTMLCommentEndBangTokenizerState:
            return [self commentEndBangState];
        case HTMLDOCTYPETokenizerState:
            return [self DOCTYPEState];
        case HTMLBeforeDOCTYPENameTokenizerState:
            return [self beforeDOCTYPENameState];
        case HTMLDOCTYPENameTokenizerState:
            return [self DOCTYPENameState];
        case HTMLAfterDOCTYPENameTokenizerState:
            return [self afterDOCTYPENameState];
        case HTMLAfterDOCTYPEPublicKeywordTokenizerState:
            return [self afterDOCTYPEPublicKeywordState];
        case HTMLBeforeDOCTYPEPublicIdentifierTokenizerState:
            return [self beforeDOCTYPEPublicIdentifierState];
        case HTMLDOCTYPEPublicIdentifierDoubleQuotedTokenizerState:
            return [self DOCTYPEPublicIdentifierDoubleQuotedState];
        case HTMLDOCTYPEPublicIdentifierSingleQuotedTokenizerState:
            return [self DOCTYPEPublicIdentifierSingleQuotedState];
        case HTMLAfterDOCTYPEPublicIdentifierTokenizerState:
            return [self afterDOCTYPEPublicIdentifierState];
        case HTMLBetweenDOCTYPEPublicAndSystemIdentifiersTokenizerState:
            return [self betweenDOCTYPEPublicAndSystemIdentifiersState];
        case HTMLAfterDOCTYPESystemKeywordTokenizerState:
            return [self afterDOCTYPESystemKeywordState];
        case HTMLBeforeDOCTYPESystemIdentifierTokenizerState:
            return [self beforeDOCTYPESystemIdentifierState];
        case HTMLDOCTYPESystemIdentifierDoubleQuotedTokenizerState:
            return [self DOCTYPESystemIdentifierDoubleQuotedState];
        case HTMLDOCTYPESystemIdentifierSingleQuotedTokenizerState:
            return [self DOCTYPESystemIdentifierSingleQuotedState];
        case HTMLAfterDOCTYPESystemIdentifierTokenizerState:
            return [self afterDOCTYPESystemIdentifierState];
        case HTMLBogusDOCTYPETokenizerState:
            return [self bogusDOCTYPEState];
        case HTMLCDATASectionTokenizerState:
            return [self CDATASectionState];
        default:
            NSAssert(NO, @"unexpected state %ld", (long)self.state);
    }
}

- (UTF32Char)consumeNextInputCharacter
{
    return [_inputStream consumeNextInputCharacter];
}

- (NSString *)consumeCharactersUpToFirstPassingTest:(BOOL(^)(UTF32Char c))test
{
    return [_inputStream consumeCharactersUpToFirstPassingTest:test];
}

- (void)switchToState:(HTMLTokenizerState)state
{
    self.state = state;
}

- (void)reconsume:(UTF32Char)character
{
    [_inputStream reconsumeCurrentInputCharacter];
}

- (void)emit:(id)token
{
    if ([token isKindOfClass:[HTMLStartTagToken class]]) {
        _mostRecentEmittedStartTagName = [token tagName];
    }
    if ([token isKindOfClass:[HTMLEndTagToken class]]) {
        HTMLEndTagToken *endTag = token;
        if (endTag.attributes.count > 0 || endTag.selfClosingFlag) {
            [self emitParseError:@"End tag with attributes and/or self-closing flag"];
        }
    }
    [self emitCore:token];
}

- (void)emitCore:(id)token
{
    [_tokenQueue addObject:token];
}

- (void)emitParseError:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2)
{
    va_list args;
    va_start(args, format);
    NSString *error = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self emit:[[HTMLParseErrorToken alloc] initWithError:error]];
}

- (void)emitCharacterToken:(UTF32Char)character
{
    [self emit:[[HTMLCharacterToken alloc] initWithString:StringWithLongCharacter(character)]];
}

- (void)emitCharacterTokenWithString:(NSString *)string
{
    if (string.length > 0) {
        [self emit:[[HTMLCharacterToken alloc] initWithString:string]];
    }
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

- (void)addCurrentAttributeToCurrentToken
{
    HTMLTagToken *token = _currentToken;
    if ([token.attributes objectForKey:_currentAttributeName]) {
        [self emitParseError:@"Duplicate attribute"];
    } else {
        [token.attributes setObject:(_currentAttributeValue ?: @"") forKey:_currentAttributeName];
    }
    _currentAttributeName = nil;
    _currentAttributeValue = nil;
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
    UTF32Char c = _inputStream.nextInputCharacter;
    if (_additionalAllowedCharacter != (UTF32Char)EOF && c == _additionalAllowedCharacter) {
        return nil;
    }
    switch (c) {
        case '\t':
        case '\n':
        case '\f':
        case ' ':
        case '<':
        case '&':
        case EOF:
            return nil;
        case '#': {
            [_inputStream consumeNextInputCharacter];
            BOOL hex = [_inputStream consumeString:@"X" matchingCase:NO];
            unsigned int number;
            BOOL ok;
            if (hex) {
                ok = [_inputStream consumeHexInt:&number];
            } else {
                ok = [_inputStream consumeUnsignedInt:&number];
            }
            if (!ok) {
                [_inputStream unconsumeInputCharacters:(hex ? 2 : 1)];
                [self emitParseError:@"Numeric entity with no numbers"];
                return nil;
            }
            ok = [_inputStream consumeString:@";" matchingCase:YES];
            if (!ok) {
                [self emitParseError:@"Missing semicolon for numeric entity"];
            }
            
            unichar replacement = ReplacementForNumericEntity(number);
            if (replacement) {
                [self emitParseError:@"Invalid numeric entity (has replacement)"];
                return [NSString stringWithFormat:@"%C", replacement];
            }
            
            if ((number >= 0xD800 && number <= 0xDFFF) || number > 0x10FFFF) {
                [self emitParseError:@"Invalid numeric entity (outside valid Unicode range)"];
                return @"\uFFFD";
            }
            if (is_undefined_or_disallowed(number)) {
                [self emitParseError:@"Invalid numeric entity (in bad Unicode range)"];
            }
            return StringWithLongCharacter(number);
        }
        default: {
            NSString *substring = [_inputStream nextUnprocessedCharactersWithMaximumLength:LongestEntityNameLength];
            NSString *parsedName;
            NSString *replacement = StringForNamedEntity(substring, &parsedName);
            if (!replacement) {
                NSScanner *scanner = [_inputStream unprocessedScanner];
                NSCharacterSet *alphanumeric = [NSCharacterSet alphanumericCharacterSet];
                if ([scanner scanCharactersFromSet:alphanumeric intoString:nil] && [scanner scanString:@";" intoString:nil]) {
                    [self emitParseError:@"Unknown named entity with semicolon"];
                }
                return nil;
            }
            [_inputStream consumeString:parsedName matchingCase:YES];
            if (![parsedName hasSuffix:@";"] && partOfAnAttribute) {
                UTF32Char next = _inputStream.nextInputCharacter;
                if (next == '=' || [[NSCharacterSet alphanumericCharacterSet] characterIsMember:next]) {
                    [_inputStream unconsumeInputCharacters:parsedName.length];
                    if (next == '=') {
                        [self emitParseError:@"Named entity in attribute ending with ="];
                    }
                    return nil;
                }
            }
            if (![parsedName hasSuffix:@";"]) {
                [self emitParseError:@"Named entity missing semicolon"];
            }
            return replacement;
        }
    }
}

#pragma mark NSEnumerator

- (id)nextObject
{
    while (!_done && _tokenQueue.count == 0) {
        [self resume];
    }
    if (_tokenQueue.count == 0) return nil;
    id token = [_tokenQueue objectAtIndex:0];
    [_tokenQueue removeObjectAtIndex:0];
    return token;
}

#pragma mark NSObject

- (instancetype)init
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

- (void)appendStringToPublicIdentifier:(NSString *)string
{
    if (string.length == 0) return;
    if (!_publicIdentifier) _publicIdentifier = [NSMutableString new];
    [_publicIdentifier appendString:string];
}

- (NSString *)systemIdentifier
{
    return [_systemIdentifier copy];
}

- (void)setSystemIdentifier:(NSString *)string
{
    _systemIdentifier = [string mutableCopy];
}

- (void)appendStringToSystemIdentifier:(NSString *)string
{
    if (string.length == 0) return;
    if (!_systemIdentifier) _systemIdentifier = [NSMutableString new];
    [_systemIdentifier appendString:string];
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
}

- (instancetype)initWithTagName:(NSString *)tagName
{
    if ((self = [super init])) {
        _tagName = [NSMutableString stringWithString:tagName];
        _attributes = [HTMLOrderedDictionary new];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithTagName:@""];
}

- (NSString *)tagName
{
    return [_tagName copy];
}

- (void)setTagName:(NSString *)tagName
{
    [_tagName setString:tagName];
}

- (BOOL)selfClosingFlag
{
    return _selfClosingFlag;
}

- (void)setSelfClosingFlag:(BOOL)flag
{
    _selfClosingFlag = flag;
}

- (void)appendLongCharacterToTagName:(UTF32Char)character
{
    AppendLongCharacter(_tagName, character);
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

- (instancetype)copyWithTagName:(NSString *)tagName
{
    HTMLStartTagToken *copy = [[self.class alloc] initWithTagName:tagName];
    copy.attributes = self.attributes;
    copy.selfClosingFlag = self.selfClosingFlag;
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    NSMutableString *attributeDescription = [NSMutableString new];
    [self.attributes enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        [attributeDescription appendFormat:@" %@=\"%@\"", name, value];
    }];
    return [NSString stringWithFormat:@"<%@: %p <%@%@> >", self.class, self, self.tagName, attributeDescription];
}

- (BOOL)isEqual:(HTMLStartTagToken *)other
{
    return ([super isEqual:other] && [other isKindOfClass:[HTMLStartTagToken class]]);
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

- (instancetype)initWithData:(NSString *)data
{
    if ((self = [super init])) {
        _data = [NSMutableString stringWithString:(data ?: @"")];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithData:nil];
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
    if (string.length == 0) return;
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

- (instancetype)initWithString:(NSString *)string
{
    if ((self = [super init])) {
        _string = [string copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithString:@""];
}

- (instancetype)leadingWhitespaceToken
{
    CFRange range = CFRangeMake(0, self.string.length);
    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)self.string, &buffer, range);
    for (CFIndex i = 0; i < range.length; i++) {
        if (!is_whitespace(CFStringGetCharacterFromInlineBuffer(&buffer, i))) {
            NSString *leadingWhitespace = [self.string substringToIndex:i];
            if (leadingWhitespace.length > 0) {
                return [[[self class] alloc] initWithString:leadingWhitespace];
            } else {
                return nil;
            }
        }
    }
    return self;
}

- (instancetype)afterLeadingWhitespaceToken
{
    CFRange range = CFRangeMake(0, self.string.length);
    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)self.string, &buffer, range);
    for (CFIndex i = 0; i < range.length; i++) {
        if (!is_whitespace(CFStringGetCharacterFromInlineBuffer(&buffer, i))) {
            NSString *afterLeadingWhitespace = [self.string substringFromIndex:i];
            return [[[self class] alloc] initWithString:afterLeadingWhitespace];
        }
    }
    return nil;
}

#pragma mark NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, self.string];
}

- (BOOL)isEqual:(HTMLCharacterToken *)other
{
    return [other isKindOfClass:[HTMLCharacterToken class]] && [other.string isEqualToString:self.string];
}

- (NSUInteger)hash
{
    return self.string.hash;
}

@end

@implementation HTMLParseErrorToken

- (instancetype)initWithError:(NSString *)error
{
    if ((self = [super init])) {
        _error = [error copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithError:nil];
}

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

@implementation HTMLEOFToken

#pragma mark NSObject

- (BOOL)isEqual:(id)other
{
    return [other isKindOfClass:[HTMLEOFToken class]];
}

- (NSUInteger)hash
{
    // Random constant.
    return 1245524566;
}

@end
