//  HTMLTokenizerTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLString.h"
#import "HTMLTokenizer.h"
#import <objc/runtime.h>

@interface HTMLTokenizerTest : NSObject

@property (copy, nonatomic) NSDictionary *dictionary;
@property (readonly, copy, nonatomic) NSArray *expectedTokens;
@property (readonly, copy, nonatomic) NSArray *tokenizers;
@property (readonly, copy, nonatomic) NSString *name;

@end

@implementation HTMLTokenizerTest

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (!self) return nil;
    _dictionary = [dictionary copy];
    NSMutableArray *expectedTokens = [NSMutableArray new];
    for (id test in _dictionary[@"output"]) {
        if ([test isEqual:@"ParseError"]) {
            [expectedTokens addObject:[HTMLParseErrorToken new]];
            continue;
        }
        NSString *tokenType = test[0];
        if ([tokenType isEqualToString:@"Character"]) {
            NSString *output = test[1];
            if (_dictionary[@"doubleEscaped"]) {
                output = UnDoubleEscape(test[1]);
            }
            EnumerateLongCharacters(output, ^(UTF32Char character) {
                [expectedTokens addObject:[[HTMLCharacterToken alloc] initWithData:character]];
            });
        } else if ([tokenType isEqualToString:@"Comment"]) {
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
    _expectedTokens = expectedTokens;
    
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
    for (NSURL *testFileURL in [[self class] testFileURLs]) {
        NSString *testName = [testFileURL.lastPathComponent stringByDeletingPathExtension];
        NSUInteger i = 0;
        for (HTMLTokenizerTest *test in [self testsWithTestFileURL:testFileURL]) {
            i++;
            for (HTMLTokenizer *tokenizer in test.tokenizers) {
                NSArray *parsedTokens = tokenizer.allObjects;
                XCTAssertEqualObjects(parsedTokens, test.expectedTokens, @"-[%@%@-test%zu] %@", [self class], testName, i, test.name);
            }
        }
    }
}

@end
