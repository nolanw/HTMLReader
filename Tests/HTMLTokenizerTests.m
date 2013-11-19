//  HTMLTokenizerTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLString.h"
#import "HTMLTokenizer.h"
#import <objc/runtime.h>

@interface HTMLTokenizerTests : XCTestCase

@property (readonly, copy, nonatomic) NSDictionary *dictionary;
@property (readonly, copy, nonatomic) NSArray *expectedTokens;
@property (readonly, copy, nonatomic) NSArray *tokenizers;
@property (copy, nonatomic) NSString *name;

@end

@implementation HTMLTokenizerTests

+ (id)defaultTestSuite
{
    if (!ShouldRunTestsForParameterizedTestClass([HTMLTokenizerTests class])) {
        return nil;
    }
    NSURL *testURL = [[NSURL URLWithString:html5libTestPath()] URLByAppendingPathComponent:@"tokenizer"];
    NSArray *potentialTestURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:testURL
                                                               includingPropertiesForKeys:0
                                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                    error:nil];
    XCTestSuite *suite = [XCTestSuite testSuiteWithName:@"html5lib tokenizer tests"];
    for (NSURL *testURL in potentialTestURLs) {
        if ([testURL.pathExtension isEqualToString:@"test"]) {
            [suite addTest:[self testSuiteWithFileAtURL:testURL]];
        }
    }
    return suite;
}

+ (XCTestSuite *)testSuiteWithFileAtURL:(NSURL *)testURL
{
    NSString *suiteName = testURL.lastPathComponent.stringByDeletingPathExtension;
    XCTestSuite *suite = [XCTestSuite testSuiteWithName:suiteName];
    NSString *testClassName = [NSString stringWithFormat:@"%@-%@", NSStringFromClass(self), suiteName];
    Class testClass = objc_allocateClassPair(self, testClassName.UTF8String, 0);
    objc_registerClassPair(testClass);
    NSData *testData = [NSData dataWithContentsOfURL:testURL];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:testData options:0 error:nil];
    NSInteger i = 1;
    Method testMethod = class_getInstanceMethod(testClass, @selector(genericTestMethod));
    
    // http://wiki.whatwg.org/wiki/Parser_tests#Tokenizer_Tests
    for (NSDictionary *test in json[@"tests"]) {
        SEL selector = sel_registerName([NSString stringWithFormat:@"test%zd", i++].UTF8String);
        class_addMethod(testClass, selector, method_getImplementation(testMethod), method_getTypeEncoding(testMethod));
        HTMLTokenizerTests *testCase = [testClass testCaseWithSelector:selector];
        testCase->_dictionary = test;
        testCase.name = test[@"description"];
        [suite addTest:testCase];
    }
    
    return suite;
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

- (void)genericTestMethod
{
    for (HTMLTokenizer *tokenizer in _tokenizers) {
        NSArray *parsedTokens = tokenizer.allObjects;
        XCTAssertEqualObjects(parsedTokens, _expectedTokens, @"%@", _dictionary[@"description"]);
    }
}

@end
