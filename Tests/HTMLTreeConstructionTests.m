//
//  HTMLTreeConstructionTests.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-08-06.
//

#import <XCTest/XCTest.h>
#import "HTMLParser.h"
#import "HTMLTestUtilities.h"

@interface HTMLTreeConstructionTests : XCTestCase

@property (readonly, copy, nonatomic) NSString *data;
@property (readonly, assign, nonatomic) NSUInteger expectedErrors;
@property (readonly, copy, nonatomic) NSString *documentFragment;
@property (readonly, copy, nonatomic) NSArray *expectedRootNodes;

@end

@implementation HTMLTreeConstructionTests

+ (id)defaultTestSuite
{
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
    NSString *testString = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    NSScanner *scanner = [NSScanner scannerWithString:testString];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    
    // http://wiki.whatwg.org/wiki/Parser_tests#Tree_Construction_Tests
    NSString *singleTestString;
    while ([scanner scanUpToString:@"\n#data" intoString:&singleTestString]) {
        [suite addTest:[self testCaseWithString:singleTestString]];
        [scanner scanString:singleTestString intoString:nil];
        [scanner scanString:@"\n" intoString:nil];
    }
    return suite;
}

+ (instancetype)testCaseWithString:(NSString *)string
{
    HTMLTreeConstructionTests *testCase = [self testCaseWithSelector:@selector(test)];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    [scanner scanString:@"#data\n" intoString:nil];
    NSString *data;
    [scanner scanUpToString:@"\n#errors\n" intoString:&data];
    testCase->_data = [data copy];
    
    [scanner scanString:@"\n#errors\n" intoString:nil];
    NSString *errorLines;
    if ([scanner scanUpToString:@"#document" intoString:&errorLines]) {
        testCase->_expectedErrors = [errorLines componentsSeparatedByString:@"\n"].count - 1;
    }
    
    NSString *fragment;
    if ([scanner scanString:@"#document-fragment\n" intoString:nil]) {
        [scanner scanUpToString:@"\n" intoString:&fragment];
        testCase->_documentFragment = [fragment copy];
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
    testCase->_expectedRootNodes = [roots copy];
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
    if (_documentFragment) {
        HTMLElementNode *context = [[HTMLElementNode alloc] initWithTagName:_documentFragment];
        parser = [[HTMLParser alloc] initWithString:_data context:context];
    } else {
        parser = [[HTMLParser alloc] initWithString:_data];
    }
    NSString *description = [NSString stringWithFormat:@"parsed: %@\nfixture:\n%@",
                             parser.document.recursiveDescription,
                             [[_expectedRootNodes valueForKey:@"recursiveDescription"]
                              componentsJoinedByString:@"\n"]];
    XCTAssert(TreesAreTestEquivalent(parser.document.childNodes, _expectedRootNodes),
              @"%@", description);
    XCTAssertEqual(parser.errors.count, _expectedErrors, @"%@", description);
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

@end
