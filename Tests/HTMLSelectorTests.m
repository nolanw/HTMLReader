//
//  HTMLSelectorTest.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "HTMLParser.h"
#import "HTMLSelector.h"

extern struct mb {int m; int b;} parseNth(NSString *nthString);

@interface CSSSelector (Private)

@property (readonly) NSString *parsedEquivalent;

@end

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
			   <parent id='empty'></parent>\
			   \
			   <parent id='one-child'> <elem id='only-child'> </elem> </parent>\
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
	
	//Deal with parsed selector, when/if implemented
	parsedSelector = nil;
	//XCTAssertEqualObjects(selector.parsedEquivalent, parsedSelector);
	
	NSArray *returnedNodes = [testDoc nodesForSelector:selector];
	NSArray *returnedIds = [returnedNodes valueForKey:@"[id]"];
	
	XCTAssertEqualObjects(returnedIds, expectedIds, @"Test of %@ failed", selectorString);

}

- (void)testSelectors
{
	//Test grandchild chaining, as described in http://www.w3.org/TR/css3-selectors/#descendant-combinators
	//"root * elem" == <root><*any*><elem/></*any></root>
	[self testSelector:@"root * elem" withExpectedParsedSelector:@"img * elem" andExpectedIds:@[@"only-child"]];

	
	[self testSelector:@"elem:empty" withExpectedParsedSelector:@"elem:empty" andExpectedIds:@[@"empty"]];


	
	SelectorFunctionForString(@"img * elem");

	
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
