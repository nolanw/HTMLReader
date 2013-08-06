//
//  HTMLTokenizerTests.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-08-06.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "HTMLString.h"
#import "HTMLTokenizer.h"

#define STRINGIFY_EXPAND(a) #a
#define STRINGIFY(a) @STRINGIFY_EXPAND(a)

@interface HTMLTokenizerTests : XCTestCase

@property (readonly, copy, nonatomic) NSDictionary *dictionary;
@property (readonly, copy, nonatomic) NSArray *expectedTokens;
@property (readonly, copy, nonatomic) NSArray *tokenizers;

@end

@implementation HTMLTokenizerTests

+ (id)defaultTestSuite
{
    NSString *testPath = STRINGIFY(HTML5LIBTESTPATH) "/tokenizer";
    NSArray *potentialTestPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:testPath
                                                                                      error:nil];
    XCTestSuite *suite = [XCTestSuite testSuiteWithName:@"html5lib tokenizer tests"];
    for (NSString *filename in potentialTestPaths) {
        if ([filename.pathExtension isEqualToString:@"test"]) {
            NSString *filepath = [testPath stringByAppendingPathComponent:filename];
            [suite addTest:[self testSuiteWithFileAtPath:filepath]];
        }
    }
    return suite;
}

+ (XCTestSuite *)testSuiteWithFileAtPath:(NSString *)path
{
    NSString *suiteName = [path.lastPathComponent stringByDeletingPathExtension];
    XCTestSuite *suite = [XCTestSuite testSuiteWithName:suiteName];
    NSData *testData = [NSData dataWithContentsOfFile:path];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:testData options:0 error:nil];
    
    // http://wiki.whatwg.org/wiki/Parser_tests#Tokenizer_Tests
    for (NSDictionary *test in json[@"tests"]) {
        HTMLTokenizerTests *testCase = [self testCaseWithDictionary:test];
        [suite addTest:testCase];
    }
    
    return suite;
}

+ (instancetype)testCaseWithDictionary:(NSDictionary *)dictionary
{
    HTMLTokenizerTests *testCase = [self testCaseWithSelector:@selector(test)];
    testCase->_dictionary = [dictionary copy];
    return testCase;
}

- (void)setUp
{
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
            XCTFail(@"unexpected token type %@ in tokenizer test", tokenType);
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

- (void)test
{
    for (HTMLTokenizer *tokenizer in _tokenizers) {
        NSArray *parsedTokens = tokenizer.allObjects;
        XCTAssertEqualObjects(parsedTokens, _expectedTokens, @"%@", _dictionary[@"description"]);
    }
}

@end
