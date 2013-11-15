//  HTMLTreeConstructionTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLMutability.h"
#import "HTMLParser.h"
#import "HTMLTestUtilities.h"
#import <objc/runtime.h>

@interface HTMLTreeConstructionTests : XCTestCase

@property (copy, nonatomic) NSString *data;
@property (copy, nonatomic) NSArray *expectedErrors;
@property (copy, nonatomic) NSString *documentFragment;
@property (copy, nonatomic) NSArray *expectedRootNodes;

@end

@implementation HTMLTreeConstructionTests

+ (id)defaultTestSuite
{
    if (!ShouldRunTestsForParameterizedTestClass([HTMLTreeConstructionTests class])) {
        return nil;
    }
    NSString *testPath = [html5libTestPath() stringByAppendingPathComponent:@"tree-construction"];
    NSArray *potentialTestPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:testPath
                                                                                      error:nil];
    XCTestSuite *suite = [XCTestSuite testSuiteWithName:@"html5lib tree construction tests"];
    for (NSString *filename in potentialTestPaths) {
        // TODO stop skipping template tests once we implement templates.
        if ([filename.lastPathComponent isEqualToString:@"template.dat"]) continue;
        
        if ([filename.pathExtension isEqualToString:@"dat"]) {
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
    NSString *testClassName = [NSString stringWithFormat:@"%@-%@", NSStringFromClass(self), suiteName];
    Class testClass = objc_allocateClassPair(self, [testClassName UTF8String], 0);
    objc_registerClassPair(testClass);
    NSString *testString = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    NSScanner *scanner = [NSScanner scannerWithString:testString];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    
    // http://wiki.whatwg.org/wiki/Parser_tests#Tree_Construction_Tests
    NSString *singleTestString;
    NSInteger i = 1;
    while ([scanner scanUpToString:@"\n#data" intoString:&singleTestString]) {
        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"test%zd", i++]);
        [suite addTest:[self testCaseWithString:singleTestString class:testClass selector:selector]];
        [scanner scanString:singleTestString intoString:nil];
        [scanner scanString:@"\n" intoString:nil];
    }
    return suite;
}

+ (instancetype)testCaseWithString:(NSString *)string class:(Class)class selector:(SEL)selector
{
    HTMLTreeConstructionTests *testCase = [class testCaseWithSelector:selector];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    [scanner scanString:@"#data\n" intoString:nil];
    NSString *data;
    [scanner scanUpToString:@"\n#errors\n" intoString:&data];
    testCase.data = data;
    
    [scanner scanString:@"\n#errors\n" intoString:nil];
    NSString *errorLines;
    if ([scanner scanUpToString:@"#document" intoString:&errorLines]) {
        NSArray *errors = [errorLines componentsSeparatedByString:@"\n"];
        errors = [errors subarrayWithRange:NSMakeRange(0, errors.count - 1)];
        testCase.expectedErrors = errors;
    }
    
    NSString *fragment;
    if ([scanner scanString:@"#document-fragment\n" intoString:nil]) {
        [scanner scanUpToString:@"\n" intoString:&fragment];
        testCase.documentFragment = fragment;
        [scanner scanString:@"\n" intoString:nil];
    }
    
    [scanner scanString:@"#document\n" intoString:nil];
    NSMutableArray *roots = [NSMutableArray new];
    NSMutableArray *stack = [NSMutableArray new];
    NSCharacterSet *spaceSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    while ([scanner scanString:@"| " intoString:nil]) {
        NSString *spaces;
        [scanner scanCharactersFromSet:spaceSet intoString:&spaces];
        while (stack.count > spaces.length / 2) {
            [stack removeLastObject];
        }
        NSString *nodeString;
        [scanner scanUpToString:@"\n| " intoString:&nodeString];
        id nodeOrAttribute = NodeOrAttributeFromString(nodeString);
        if ([nodeOrAttribute isKindOfClass:[HTMLAttribute class]]) {
            [stack.lastObject addAttribute:nodeOrAttribute];
        } else if (stack.count > 0) {
            [stack.lastObject appendChild:nodeOrAttribute];
        } else {
            [roots addObject:nodeOrAttribute];
        }
        if ([nodeOrAttribute isKindOfClass:[HTMLElementNode class]]) {
            [stack addObject:nodeOrAttribute];
        }
        [scanner scanString:@"\n" intoString:nil];
    }
    testCase.expectedRootNodes = roots;
    return testCase;
}

static id NodeOrAttributeFromString(NSString *s)
{
    NSScanner *scanner = [NSScanner scannerWithString:s];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    if ([scanner scanString:@"<!DOCTYPE " intoString:nil]) {
        NSString *rest;
        [scanner scanUpToString:@">" intoString:&rest];
        if (!rest) {
            return [HTMLDocumentTypeNode new];
        }
        NSScanner *doctypeScanner = [NSScanner scannerWithString:rest];
        doctypeScanner.charactersToBeSkipped = nil;
        doctypeScanner.caseSensitive = YES;
        NSString *name;
        [doctypeScanner scanUpToString:@" " intoString:&name];
        if (doctypeScanner.isAtEnd) {
            return [[HTMLDocumentTypeNode alloc] initWithName:name publicId:nil systemId:nil];
        }
        [doctypeScanner scanString:@" \"" intoString:nil];
        NSString *publicId;
        [doctypeScanner scanUpToString:@"\"" intoString:&publicId];
        [doctypeScanner scanString:@"\" \"" intoString:nil];
        NSRange rangeOfSystemId = (NSRange){
            .location = doctypeScanner.scanLocation,
            .length = doctypeScanner.string.length - doctypeScanner.scanLocation - 1,
        };
        NSString *systemId = [doctypeScanner.string substringWithRange:rangeOfSystemId];
        return [[HTMLDocumentTypeNode alloc] initWithName:name publicId:publicId systemId:systemId];
    } else if ([scanner scanString:@"<!-- " intoString:nil]) {
        NSUInteger endOfData = [s rangeOfString:@" -->" options:NSBackwardsSearch].location;
        NSRange rangeOfData = NSMakeRange(scanner.scanLocation, endOfData - scanner.scanLocation);
        return [[HTMLCommentNode alloc] initWithData:[s substringWithRange:rangeOfData]];
    } else if ([scanner scanString:@"\"" intoString:nil]) {
        NSUInteger endOfData = [s rangeOfString:@"\"" options:NSBackwardsSearch].location;
        NSRange rangeOfData = NSMakeRange(scanner.scanLocation, endOfData - scanner.scanLocation);
        return [[HTMLTextNode alloc] initWithData:[s substringWithRange:rangeOfData]];
    } else if ([scanner.string rangeOfString:@"="].location == NSNotFound) {
        [scanner scanString:@"<" intoString:nil];
        NSString *tagNameString;
        [scanner scanUpToString:@">" intoString:&tagNameString];
        NSArray *parts = [tagNameString componentsSeparatedByString:@" "];
        NSString *tagName = parts.count == 2 ? parts[1] : parts[0];
        NSString *namespace = parts.count == 2 ? parts[0] : nil;
        HTMLElementNode *node = [[HTMLElementNode alloc] initWithTagName:tagName];
        if ([namespace isEqualToString:@"svg"]) {
            node.namespace = HTMLNamespaceSVG;
        } else if ([namespace isEqualToString:@"math"]) {
            node.namespace = HTMLNamespaceMathML;
        }
        return node;
    } else {
        NSString *attributeNameString;
        [scanner scanUpToString:@"=" intoString:&attributeNameString];
        NSArray *parts = [attributeNameString componentsSeparatedByString:@" "];
        NSString *prefix = parts.count == 2 ? parts[0] : nil;
        NSString *name = parts.count == 2 ? parts[1] : parts[0];
        [scanner scanString:@"=\"" intoString:nil];
        NSUInteger endOfValue = [s rangeOfString:@"\"" options:NSBackwardsSearch].location;
        NSRange rangeOfValue = NSMakeRange(scanner.scanLocation, endOfValue - scanner.scanLocation);
        NSString *value = [s substringWithRange:rangeOfValue];
        if (prefix) {
            return [[HTMLNamespacedAttribute alloc] initWithPrefix:prefix name:name value:value];
        } else {
            return [[HTMLAttribute alloc] initWithName:name value:value];
        }
    }
}

- (void)test
{
    HTMLParser *parser;
    if (self.documentFragment) {
        HTMLElementNode *context = [[HTMLElementNode alloc] initWithTagName:self.documentFragment];
        parser = [[HTMLParser alloc] initWithString:self.data context:context];
    } else {
        parser = [[HTMLParser alloc] initWithString:self.data];
    }
    NSString *description = [NSString stringWithFormat:@"parsed: %@\nfixture:\n%@",
                             parser.document.recursiveDescription,
                             [[self.expectedRootNodes valueForKey:@"recursiveDescription"]
                              componentsJoinedByString:@"\n"]];
    XCTAssert(TreesAreTestEquivalent(parser.document.childNodes, self.expectedRootNodes),
              @"%@", description);
    NSString *errors = [NSString stringWithFormat:@"parse errors: %@\nexpected errors:\n%@",
                        [parser.errors componentsJoinedByString:@"\n"],
                        [self.expectedErrors componentsJoinedByString:@"\n"]];
    XCTAssertEqual(parser.errors.count, self.expectedErrors.count, @"%@\n%@", errors, description);
}

BOOL TreesAreTestEquivalent(id aThing, id bThing)
{
    if ([aThing isKindOfClass:[HTMLElementNode class]]) {
        if (![bThing isKindOfClass:[HTMLElementNode class]]) return NO;
        HTMLElementNode *a = aThing, *b = bThing;
        if (![a.tagName isEqualToString:b.tagName]) return NO;
        NSArray *descriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES] ];
        NSArray *sortedAAttributes = [a.attributes sortedArrayUsingDescriptors:descriptors];
        NSArray *sortedBAttributes = [b.attributes sortedArrayUsingDescriptors:descriptors];
        if (![sortedAAttributes isEqualToArray:sortedBAttributes]) return NO;
        return TreesAreTestEquivalent(a.childNodes, b.childNodes);
    } else if ([aThing isKindOfClass:[HTMLTextNode class]]) {
        if (![bThing isKindOfClass:[HTMLTextNode class]]) return NO;
        HTMLTextNode *a = aThing, *b = bThing;
        return [a.data isEqualToString:b.data];
    } else if ([aThing isKindOfClass:[HTMLCommentNode class]]) {
        if (![bThing isKindOfClass:[HTMLCommentNode class]]) return NO;
        HTMLCommentNode *a = aThing, *b = bThing;
        return [a.data isEqualToString:b.data];
    } else if ([aThing isKindOfClass:[HTMLDocumentTypeNode class]]) {
        if (![bThing isKindOfClass:[HTMLDocumentTypeNode class]]) return NO;
        HTMLDocumentTypeNode *a = aThing, *b = bThing;
        return (((a.name == nil && b.name == nil) || [a.name isEqualToString:b.name]) &&
                [a.publicId isEqualToString:b.publicId] &&
                [a.systemId isEqualToString:b.systemId]);
    } else if ([aThing isKindOfClass:[NSArray class]]) {
        if (![bThing isKindOfClass:[NSArray class]]) return NO;
        NSArray *a = aThing, *b = bThing;
        if (a.count != b.count) return NO;
        for (NSUInteger i = 0; i < a.count; i++) {
            if (!TreesAreTestEquivalent(a[i], b[i])) {
                return NO;
            }
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    if ([NSStringFromSelector(invocation.selector) hasPrefix:@"test"]) {
        invocation.selector = @selector(test);
        [invocation invoke];
    } else {
        [super forwardInvocation:invocation];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (!signature && [NSStringFromSelector(selector) hasPrefix:@"test"]) {
        signature = [super methodSignatureForSelector:@selector(test)];
    }
    return signature;
}

@end
