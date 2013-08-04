//
//  HTMLTreeTraversalTests.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-08-03.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "HTMLParser.h"

@interface HTMLTreeTraversalTests : SenTestCase

@end

@implementation HTMLTreeTraversalTests

- (void)testSingleNode
{
    HTMLNode *root = [self rootNodeWithString:@"<a>"];
    STAssertEqualObjects([root.treeEnumerator allObjects], @[ root ], nil);
}

- (void)testBalancedThreeNodes
{
    HTMLNode *parent = [self rootNodeWithString:@"<parent><child1></child1><child2>"];
    NSArray *nodes = [parent.treeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"parent", @"child1", @"child2" ];
    STAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder, nil);
}

- (void)testChristmasTree
{
    HTMLNode *root = [self rootNodeWithString:@"<a><b><c></c></b><b><c><d></d></c><c></c></b>"];
    NSArray *nodes = [root.treeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"a", @"b", @"c", @"b", @"c", @"d", @"c" ];
    STAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder, nil);
}

- (HTMLNode *)rootNodeWithString:(NSString *)string
{
    HTMLDocument *document = [[HTMLParser alloc] initWithString:string context:nil].document;
    return [document.childNodes[0] childNodes][0];
}

@end
