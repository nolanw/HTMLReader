//  HTMLTreeConstructionTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLComment.h"
#import "HTMLParser.h"
#import "HTMLReader.h"
#import "HTMLTextNode.h"

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
    // Ignoring template tests because HTMLReader doesn't implement <template>.
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
    if ([data containsString:@"#script-off"]) {
        return nil;
    }
    if (data.length > 0) {
        data = [data substringToIndex:data.length - 1];
    } else {
        data = @"";
    }
    test.data = data;
    
    [scanner scanString:@"#errors\n" intoString:nil];
    NSMutableArray *errors = [NSMutableArray new];
    while (![scanner scanString:@"#" intoString:nil]) {
        NSString *errorLine;
        if ([scanner scanUpToString:@"\n" intoString:&errorLine]) {
            [errors addObject:errorLine];
        }
        [scanner scanString:@"\n" intoString:nil];
    }
    --scanner.scanLocation;
    test.expectedErrors = errors;
    
    NSString *fragment;
    if ([scanner scanString:@"#document-fragment\n" intoString:nil]) {
        [scanner scanUpToString:@"\n" intoString:&fragment];
        test.documentFragment = fragment;
        [scanner scanString:@"\n" intoString:nil];
    }
    
    if ([scanner scanString:@"#script-off\n" intoString:nil]) {
        return nil;
    } else {
        [scanner scanString:@"#script-on\n" intoString:nil];
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
        id nodeOrAttribute = NodeOrAttributeNameValuePairFromString(nodeString);
        if ([nodeOrAttribute isKindOfClass:[NSArray class]]) {
            HTMLElement *element = stack.lastObject;
            NSArray *nameValuePair = nodeOrAttribute;
            element[nameValuePair[0]] = nameValuePair[1];
        } else if (stack.count > 0) {
            [[stack.lastObject mutableChildren] addObject:nodeOrAttribute];
        } else {
            [roots addObject:nodeOrAttribute];
        }
        if ([nodeOrAttribute isKindOfClass:[HTMLElement class]]) {
            // Skipping all <ruby> tests as the spec isn't settled. https://www.w3.org/Bugs/Public/show_bug.cgi?id=26189C
            if ([[nodeOrAttribute tagName] isEqualToString:@"ruby"]) {
                return nil;
            }
            [stack addObject:nodeOrAttribute];
        }
        [scanner scanString:@"\n" intoString:nil];
    }
    test.expectedRootNodes = roots;
    return test;
}

static id NodeOrAttributeNameValuePairFromString(NSString *s)
{
    NSScanner *scanner = [NSScanner scannerWithString:s];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    if ([scanner scanString:@"<!DOCTYPE " intoString:nil]) {
        NSString *rest;
        [scanner scanUpToString:@">" intoString:&rest];
        if (!rest) {
            return [HTMLDocumentType new];
        }
        NSScanner *doctypeScanner = [NSScanner scannerWithString:rest];
        doctypeScanner.charactersToBeSkipped = nil;
        doctypeScanner.caseSensitive = YES;
        NSString *name;
        [doctypeScanner scanUpToString:@" " intoString:&name];
        if (doctypeScanner.isAtEnd) {
            return [[HTMLDocumentType alloc] initWithName:name publicIdentifier:nil systemIdentifier:nil];
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
        return [[HTMLDocumentType alloc] initWithName:name publicIdentifier:publicId systemIdentifier:systemId];
    } else if ([scanner scanString:@"<!-- " intoString:nil]) {
        NSUInteger endOfData = [s rangeOfString:@" -->" options:NSBackwardsSearch].location;
        NSRange rangeOfData = NSMakeRange(scanner.scanLocation, endOfData - scanner.scanLocation);
        return [[HTMLComment alloc] initWithData:[s substringWithRange:rangeOfData]];
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
        HTMLElement *node = [[HTMLElement alloc] initWithTagName:tagName attributes:nil];
        if ([namespace isEqualToString:@"svg"]) {
            node.htmlNamespace = HTMLNamespaceSVG;
        } else if ([namespace isEqualToString:@"math"]) {
            node.htmlNamespace = HTMLNamespaceMathML;
        }
        return node;
    } else {
        NSString *name;
        [scanner scanUpToString:@"=" intoString:&name];
        NSRange space = [name rangeOfString:@" "];
        if (space.location != NSNotFound) {
            NSString *prefix = [name substringToIndex:space.location];
            NSString *localName = [name substringFromIndex:NSMaxRange(space)];
            name = [NSString stringWithFormat:@"%@:%@", prefix, localName];
        }
        [scanner scanString:@"=\"" intoString:nil];
        NSUInteger endOfValue = [s rangeOfString:@"\"" options:NSBackwardsSearch].location;
        NSRange rangeOfValue = NSMakeRange(scanner.scanLocation, endOfValue - scanner.scanLocation);
        NSString *value = [s substringWithRange:rangeOfValue];
        return @[ name, value ];
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
            if (!test) continue;
            HTMLParser *parser;
            HTMLStringEncoding defaultEncoding = (HTMLStringEncoding){ .encoding = NSUTF8StringEncoding, .confidence = Certain };
            if (test.documentFragment) {
                HTMLElement *context;
                NSScanner *scanner = [NSScanner scannerWithString:test.documentFragment];
                scanner.charactersToBeSkipped = nil;
                scanner.caseSensitive = YES;
                if ([scanner scanString:@"math " intoString:nil]) {
                    NSString *tagName = [scanner.string substringFromIndex:scanner.scanLocation];
                    context = [[HTMLElement alloc] initWithTagName:tagName attributes:nil];
                    context.htmlNamespace = HTMLNamespaceMathML;
                } else if ([scanner scanString:@"svg " intoString:nil]) {
                    NSString *tagName = [scanner.string substringFromIndex:scanner.scanLocation];
                    context = [[HTMLElement alloc] initWithTagName:tagName attributes:nil];
                    context.htmlNamespace = HTMLNamespaceSVG;
                } else {
                    context = [[HTMLElement alloc] initWithTagName:scanner.string attributes:nil];
                }
                parser = [[HTMLParser alloc] initWithString:test.data encoding:defaultEncoding context:context];
            } else {
                parser = [[HTMLParser alloc] initWithString:test.data encoding:defaultEncoding context:nil];
            }
            NSString *description = [NSString stringWithFormat:@"%@ test%tu parsed: %@\nfixture:\n%@",
                                     testName,
                                     i,
                                     parser.document.recursiveDescription,
                                     [[test.expectedRootNodes valueForKey:@"recursiveDescription"] componentsJoinedByString:@"\n"]];
            XCTAssert(TreesAreTestEquivalent(parser.document.children.array, test.expectedRootNodes), @"%@", description);
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
    BOOL (^arrayLike)(id) = ^BOOL(id maybe) {
        return [maybe conformsToProtocol:@protocol(NSFastEnumeration)] && [maybe respondsToSelector:@selector(count)];
    };
    
    if ([aThing isKindOfClass:[HTMLElement class]]) {
        if (![bThing isKindOfClass:[HTMLElement class]]) return NO;
        HTMLElement *a = aThing, *b = bThing;
        if (![a.tagName isEqualToString:b.tagName]) return NO;
        if (![a.attributes isEqual:b.attributes]) return NO;
        return TreesAreTestEquivalent(a.children, b.children);
    } else if ([aThing isKindOfClass:[HTMLTextNode class]]) {
        if (![bThing isKindOfClass:[HTMLTextNode class]]) return NO;
        HTMLTextNode *a = aThing, *b = bThing;
        return [a.data isEqualToString:b.data];
    } else if ([aThing isKindOfClass:[HTMLComment class]]) {
        if (![bThing isKindOfClass:[HTMLComment class]]) return NO;
        HTMLComment *a = aThing, *b = bThing;
        return [a.data isEqualToString:b.data];
    } else if ([aThing isKindOfClass:[HTMLDocumentType class]]) {
        if (![bThing isKindOfClass:[HTMLDocumentType class]]) return NO;
        HTMLDocumentType *a = aThing, *b = bThing;
        return (((a.name == nil && b.name == nil) || [a.name isEqualToString:b.name]) &&
                b.publicIdentifier != nil && b.systemIdentifier != nil &&
                [a.publicIdentifier isEqualToString:(NSString * __nonnull)b.publicIdentifier] &&
                [a.systemIdentifier isEqualToString:(NSString * __nonnull)b.systemIdentifier]);
    } else if (arrayLike(aThing)) {
        if (!arrayLike(bThing)) return NO;
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
