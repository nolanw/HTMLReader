//
//  HTMLSelectorTest.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "HTMLParser.h"
#import "HTMLNode+Selectors.h"

@interface HTMLSelectorTests : XCTestCase
{
	HTMLDocument *testDoc;
}

@end

@implementation HTMLSelectorTests

- (void)setUp
{
    [super setUp];

	testDoc = [HTMLParser documentForString:@"<root>\
			   \
			   <elem id='empty'></elem>\
			   \
			   \
			   </root>"];
}


- (void)testNthParsing
{
	
	XCTAssertEqual(parseNth(@"odd"), ((struct mb){2, 1}));
	XCTAssertEqual(parseNth(@"even"), ((struct mb){2, 0}));

	XCTAssertEqual(parseNth(@"   odd    "), ((struct mb){2, 1}));
	
	XCTAssertEqual(parseNth(@"2"), ((struct mb){0, 2}));
	XCTAssertEqual(parseNth(@"-2"), ((struct mb){0, -2}));
	
	XCTAssertEqual(parseNth(@"n"), ((struct mb){1, 0}));
	XCTAssertEqual(parseNth(@"-n"), ((struct mb){-1, 0}));
	XCTAssertEqual(parseNth(@"2n"), ((struct mb){2, 0}));
	
	XCTAssertEqual(parseNth(@"n + 1"), ((struct mb){1, 1}));
	
	XCTAssertEqual(parseNth(@"2n + 3"), ((struct mb){2, 3}));
	XCTAssertEqual(parseNth(@"2n - 3"), ((struct mb){2, -3}));

	
	XCTAssertEqual(parseNth(@" - 3"), ((struct mb){0, -3}));

	
	//Bad order
	XCTAssertEqual(parseNth(@"2 - 2n"), ((struct mb){0, 0}));
	
	//Bad character
	XCTAssertEqual(parseNth(@"2n + 3b"), ((struct mb){0, 0}));
	
	
}


-(void)testSelector:(NSString *)selectorString withExpectedParsedSelector:(NSString *)parsedSelector andExpectedIds:(NSArray *)expectedIds
{
	CSSSelector *selector = [CSSSelector selectorForString:selectorString];
	
	parsedSelector = nil;
	//XCTAssertEqualObjects(selector.parsedEquivalent, parsedSelector);
	
	NSArray *returnedNodes = [testDoc nodesForSelector:selector];
	NSArray *returnedIds = [returnedNodes valueForKey:@"[id]"];
	
	XCTAssertEqualObjects(returnedIds, expectedIds, @"Test empty failed");

}

- (void)testSelectors
{
	[self testSelector:@"elem:empty" withExpectedParsedSelector:@"elem:empty" andExpectedIds:@[@"empty"]];

	
	SelectorFunctionForString(@"img:last-of-type");

	

	
	SelectorFunctionForString(@"img:not(div)");
	
	SelectorFunctionForString(@"*");
	
	SelectorFunctionForString(@"div");

	

	
	SelectorFunctionForString(@"img ~ div");
	
	SelectorFunctionForString(@"img~div");
	
	SelectorFunctionForString(@"img div");


	
	
	
	SelectorFunctionForString(@"E[foo*=\"bar\"]");

	SelectorFunctionForString(@"Efoo*=\"bar\"]");
	
}

@end
