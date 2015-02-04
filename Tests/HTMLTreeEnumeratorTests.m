//  HTMLTreeEnumeratorTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLParser.h"

@interface HTMLTreeEnumeratorTests : XCTestCase

@end

@implementation HTMLTreeEnumeratorTests

- (void)testSingleNode
{
    HTMLNode *root = [self rootNodeWithString:@"<a>"];
    XCTAssertEqualObjects([root.treeEnumerator allObjects], @[ root ]);
}

- (void)testBalancedThreeNodes
{
    HTMLNode *parent = [self rootNodeWithString:@"<parent><child1></child1><child2>"];
    NSArray *nodes = [parent.treeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"parent", @"child1", @"child2" ];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder);
}

- (void)testBalancedThreeNodesReversed
{
    HTMLNode *parent = [self rootNodeWithString:@"<parent><child1></child1><child2>"];
    NSArray *nodes = [parent.reversedTreeEnumerator allObjects];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], (@[ @"parent", @"child2", @"child1" ]));
}

- (void)testChristmasTree
{
    HTMLNode *root = [self rootNodeWithString:@"<a><b><c></c></b><b><c><d></d></c><c></c></b>"];
    NSArray *nodes = [root.treeEnumerator allObjects];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], (@[ @"a", @"b", @"c", @"b", @"c", @"d", @"c" ]));
}

- (HTMLNode *)rootNodeWithString:(NSString *)string
{
    HTMLStringEncoding encoding = (HTMLStringEncoding){ .encoding = NSUTF8StringEncoding, .confidence = Certain };
    HTMLDocument *document = [[HTMLParser alloc] initWithString:string encoding:encoding context:nil].document;
    HTMLElement *body = document.rootElement.children.lastObject;
    return body.children[0];
}

@end
