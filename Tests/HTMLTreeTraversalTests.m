//  HTMLTreeTraversalTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLParser.h"

@interface HTMLTreeTraversalTests : XCTestCase

@end

@implementation HTMLTreeTraversalTests

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
    NSArray *expectedOrder = @[ @"parent", @"child2", @"child1" ];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder);
}

- (void)testChristmasTree
{
    HTMLNode *root = [self rootNodeWithString:@"<a><b><c></c></b><b><c><d></d></c><c></c></b>"];
    NSArray *nodes = [root.treeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"a", @"b", @"c", @"b", @"c", @"d", @"c" ];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder);
}

- (HTMLNode *)rootNodeWithString:(NSString *)string
{
    HTMLDocument *document = [[HTMLParser alloc] initWithString:string context:nil].document;
    return [document.childNodes[0] childNodes][0];
}

@end
