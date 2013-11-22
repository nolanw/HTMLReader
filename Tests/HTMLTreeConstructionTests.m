//  HTMLTreeConstructionTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLMutability.h"
#import "HTMLParser.h"
#import <objc/runtime.h>

#define SHOUT_ABOUT_PARSE_ERRORS NO

@interface HTMLTreeConstructionTest : NSObject

@property (copy, nonatomic) NSString *data;
@property (copy, nonatomic) NSArray *expectedErrors;
@property (copy, nonatomic) NSString *documentFragment;
@property (copy, nonatomic) NSArray *expectedRootNodes;

@end

@implementation HTMLTreeConstructionTest

@end

@interface HTMLTreeConstructionTests : XCTestCase

@end

@implementation HTMLTreeConstructionTests

+ (id <NSFastEnumeration>)testFileURLs
{
    NSURL *testsURL = [[NSURL URLWithString:html5libTestPath()] URLByAppendingPathComponent:@"tree-construction"];
    NSArray *candidates = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:testsURL
                                                        includingPropertiesForKeys:nil
                                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                             error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension = 'dat' AND lastPathComponent != 'template.dat'"];
    return [candidates filteredArrayUsingPredicate:predicate];
}

- (id <NSFastEnumeration>)singleTestStringsWithFileURL:(NSURL *)fileURL
{
    NSString *testString = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
    NSScanner *scanner = [NSScanner scannerWithString:testString];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    NSMutableArray *strings = [NSMutableArray new];
    
    // https://github.com/html5lib/html5lib-tests/blob/master/tree-construction/README.md
    NSString *singleTestString;
    while ([scanner scanUpToString:@"\n#data" intoString:&singleTestString]) {
        [strings addObject:singleTestString];
        [scanner scanString:@"\n" intoString:nil];
    }
    return strings;
}

- (HTMLTreeConstructionTest *)testWithSingleTestString:(NSString *)string
{
    HTMLTreeConstructionTest *test = [HTMLTreeConstructionTest new];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    [scanner scanString:@"#data\n" intoString:nil];
    NSString *data;
    [scanner scanUpToString:@"#errors\n" intoString:&data];
    if (data.length > 0) {
        data = [data substringToIndex:data.length - 1];
    } else {
        data = @"";
    }
    test.data = data;
    
    [scanner scanString:@"#errors\n" intoString:nil];
    NSString *errorLines;
    if ([scanner scanUpToString:@"#document" intoString:&errorLines]) {
        NSArray *errors = [errorLines componentsSeparatedByString:@"\n"];
        errors = [errors subarrayWithRange:NSMakeRange(0, errors.count - 1)];
        test.expectedErrors = errors;
    }
    
    NSString *fragment;
    if ([scanner scanString:@"#document-fragment\n" intoString:nil]) {
        [scanner scanUpToString:@"\n" intoString:&fragment];
        test.documentFragment = fragment;
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
    test.expectedRootNodes = roots;
    return test;
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
    for (NSURL *testFileURL in [[self class] testFileURLs]) {
        NSString *testName = [[testFileURL lastPathComponent] stringByDeletingPathExtension];
        id <NSFastEnumeration> testStrings = [self singleTestStringsWithFileURL:testFileURL];
        NSUInteger i = 0;
        for (NSString *singleTestString in testStrings) {
            i++;
            HTMLTreeConstructionTest *test = [self testWithSingleTestString:singleTestString];
            HTMLParser *parser;
            if (test.documentFragment) {
                HTMLElementNode *context = [[HTMLElementNode alloc] initWithTagName:test.documentFragment];
                parser = [[HTMLParser alloc] initWithString:test.data context:context];
            } else {
                parser = [[HTMLParser alloc] initWithString:test.data];
            }
            NSString *description = [NSString stringWithFormat:@"%@ test%tu parsed: %@\nfixture:\n%@",
                                     testName,
                                     i,
                                     parser.document.recursiveDescription,
                                     [[test.expectedRootNodes valueForKey:@"recursiveDescription"] componentsJoinedByString:@"\n"]];
            XCTAssert(TreesAreTestEquivalent(parser.document.childNodes, test.expectedRootNodes), @"%@", description);
            if (SHOUT_ABOUT_PARSE_ERRORS && parser.errors.count != test.expectedErrors.count) {
                NSLog(@"-[HTMLTreeConstructionTests-%@ test%tu] ignoring mismatch in number (%tu) of parse errors:\n%@\n%tu expected:\n%@\n%@",
                      testName,
                      i,
                      parser.errors.count,
                      [parser.errors componentsJoinedByString:@"\n"],
                      test.expectedErrors.count,
                      [test.expectedErrors componentsJoinedByString:@"\n"],
                      description);
            }
        }
    }
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
