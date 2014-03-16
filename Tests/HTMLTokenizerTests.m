//  HTMLTokenizerTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLString.h"
#import "HTMLTokenizer.h"

@interface HTMLTokenizerTest : NSObject

@property (copy, nonatomic) NSDictionary *dictionary;
@property (readonly, copy, nonatomic) NSArray *expectedTokens;
@property (readonly, copy, nonatomic) NSArray *tokenizers;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSArray *parseErrors;

@end

@implementation HTMLTokenizerTest

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (!self) return nil;
    _dictionary = [dictionary copy];
    NSMutableArray *expectedTokens = [NSMutableArray new];
    NSMutableArray *parseErrors = [NSMutableArray new];
    NSMutableString *characterBuffer = [NSMutableString new];
    void (^flushCharacterBuffer)() = ^{
        if (characterBuffer.length > 0) {
            [expectedTokens addObject:[[HTMLCharacterToken alloc] initWithString:characterBuffer]];
            characterBuffer.string = @"";
        }
    };
    for (id test in _dictionary[@"output"]) {
        if ([test isEqual:@"ParseError"]) {
            [parseErrors addObject:[HTMLParseErrorToken new]];
            continue;
        }
        NSString *tokenType = test[0];
        if ([tokenType isEqualToString:@"Character"]) {
            NSString *output = test[1];
            if (_dictionary[@"doubleEscaped"]) {
                output = UnDoubleEscape(test[1]);
            }
            [characterBuffer appendString:output];
            continue;
        } else {
            flushCharacterBuffer();
        }
        if ([tokenType isEqualToString:@"Comment"]) {
            NSString *comment = test[1];
            if (_dictionary[@"doubleEscaped"]) {
                comment = UnDoubleEscape(test[1]);
            }
            [expectedTokens addObject:[[HTMLCommentToken alloc] initWithData:comment]];
        } else if ([tokenType isEqualToString:@"StartTag"]) {
            HTMLStartTagToken *startTag = [[HTMLStartTagToken alloc] initWithTagName:test[1]];
            for (NSString *name in test[2]) {
                [startTag addAttributeWithName:name value:[test[2] objectForKey:name]];
            }
            startTag.selfClosingFlag = [test count] == 4;
            [expectedTokens addObject:startTag];
        } else if ([tokenType isEqualToString:@"EndTag"]) {
            [expectedTokens addObject:[[HTMLEndTagToken alloc] initWithTagName:test[1]]];
        } else if ([tokenType isEqualToString:@"DOCTYPE"]) {
            HTMLDOCTYPEToken *doctype = [HTMLDOCTYPEToken new];
            #define NilOutNull(o) ([[NSNull null] isEqual:(o)] ? nil : o)
            doctype.name = NilOutNull(test[1]);
            doctype.publicIdentifier = NilOutNull(test[2]);
            doctype.systemIdentifier = NilOutNull(test[3]);
            doctype.forceQuirks = ![test[4] boolValue];
            [expectedTokens addObject:doctype];
        } else {
            NSAssert(NO, @"unexpected token type %@ in tokenizer test", tokenType);
        }
    }
    flushCharacterBuffer();
    _expectedTokens = expectedTokens;
    _parseErrors = parseErrors;
    
    NSString *input = _dictionary[@"input"];
    if (_dictionary[@"doubleEscaped"]) {
        input = UnDoubleEscape(input);
    }
    NSMutableArray *tokenizers = [NSMutableArray new];
    for (NSString *stateName in _dictionary[@"initialStates"] ?: @[ @"" ]) {
        HTMLTokenizerState state = HTMLDataTokenizerState;
        if ([stateName isEqualToString:@"RCDATA state"]) {
            state = HTMLRCDATATokenizerState;
        } else if ([stateName isEqualToString:@"RAWTEXT state"]) {
            state = HTMLRAWTEXTTokenizerState;
        } else if ([stateName isEqualToString:@"PLAINTEXT state"]) {
            state = HTMLPLAINTEXTTokenizerState;
        }
        HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] initWithString:input];
        tokenizer.state = state;
        [tokenizer setLastStartTag:_dictionary[@"lastStartTag"]];
        [tokenizers addObject:tokenizer];
    }
    _tokenizers = tokenizers;
    
    _name = [dictionary[@"description"] copy];
    return self;
}

static NSString * UnDoubleEscape(NSString *input)
{
    NSMutableString *output = [NSMutableString new];
    NSScanner *scanner = [NSScanner scannerWithString:input];
    scanner.charactersToBeSkipped = nil;
    NSString *buffer;
    for (;;) {
        if ([scanner scanUpToString:@"\\u" intoString:&buffer]) {
            [output appendString:buffer];
        }
        if (scanner.isAtEnd) break;
        [scanner scanString:@"\\u" intoString:nil];
        // Only scan four hex characters.
        NSString *hexPart = [scanner.string substringWithRange:NSMakeRange(scanner.scanLocation, 4)];
        [scanner scanString:hexPart intoString:nil];
        NSScanner *hexScanner = [NSScanner scannerWithString:hexPart];
        unsigned hex;
        [hexScanner scanHexInt:&hex];
        [output appendFormat:@"%C", (unichar)hex];
    }
    return output;
}

@end

@interface HTMLTokenizerTests : XCTestCase

@end

@implementation HTMLTokenizerTests

+ (id <NSFastEnumeration>)testFileURLs
{
    NSURL *testsURL = [[NSURL URLWithString:html5libTestPath()] URLByAppendingPathComponent:@"tokenizer"];
    NSArray *candidates = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:testsURL
                                                        includingPropertiesForKeys:0
                                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                             error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension = 'test'"];
    return [candidates filteredArrayUsingPredicate:predicate];
}

- (id <NSFastEnumeration>)testsWithTestFileURL:(NSURL *)testFileURL
{
    NSData *testData = [NSData dataWithContentsOfURL:testFileURL];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:testData options:0 error:nil];
    NSMutableArray *tests = [NSMutableArray new];
    
    // https://github.com/html5lib/html5lib-tests/blob/master/tokenizer/README.md
    for (NSDictionary *JSONTest in json[@"tests"]) {
        HTMLTokenizerTest *test = [[HTMLTokenizerTest alloc] initWithDictionary:JSONTest];
        [tests addObject:test];
    }
    return tests;
}

- (void)test
{
    NSPredicate *parseErrorPredicate = [NSPredicate predicateWithBlock:^BOOL(id token, __unused NSDictionary *bindings) {
        return [token isKindOfClass:[HTMLParseErrorToken class]];
    }];
    NSPredicate *otherTokenPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:parseErrorPredicate];
    for (NSURL *testFileURL in [[self class] testFileURLs]) {
        NSString *testName = [testFileURL.lastPathComponent stringByDeletingPathExtension];
        NSUInteger i = 0;
        for (HTMLTokenizerTest *test in [self testsWithTestFileURL:testFileURL]) {
            i++;
            for (HTMLTokenizer *tokenizer in test.tokenizers) {
                HTMLTokenizerState initialState = tokenizer.state;
                NSArray *tokens = tokenizer.allObjects;
                NSArray *parseErrors = [tokens filteredArrayUsingPredicate:parseErrorPredicate];
                NSArray *parsedTokens = [self concatenateCharacterTokens:[tokens filteredArrayUsingPredicate:otherTokenPredicate]];
                NSString *description = [NSString stringWithFormat:@"%@ test%tu] %@ (%zd)", testName, i, test.name, initialState];
                XCTAssertEqualObjects(parsedTokens, test.expectedTokens, @"%@", description);
                XCTAssertEqualObjects(parseErrors, test.parseErrors, @"%@", description);
            }
        }
    }
}

- (NSArray *)concatenateCharacterTokens:(NSArray *)separateTokens
{
    NSMutableArray *tokens = [NSMutableArray new];
    NSMutableString *currentString = [NSMutableString new];
    void (^flushCurrentString)() = ^{
        if (currentString.length > 0) {
            [tokens addObject:[[HTMLCharacterToken alloc] initWithString:currentString]];
            currentString.string = @"";
        }
    };
    for (HTMLCharacterToken *token in separateTokens) {
        if ([token isKindOfClass:[HTMLCharacterToken class]]) {
            [currentString appendString:token.string];
        } else {
            flushCurrentString();
            [tokens addObject:token];
        }
    }
    flushCurrentString();
    return tokens;
}

@end
