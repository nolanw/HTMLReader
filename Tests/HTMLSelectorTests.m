//
//  HTMLSelectorTest.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "HTMLNode+Selectors.h"

@interface HTMLSelectorTests : XCTestCase

@end

@implementation HTMLSelectorTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
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

- (void)testTesting
{
	SelectorFunctionForString(@"img:last-of-type");

	
	SelectorFunctionForString(@"img:not(div)");

	id thing = SelectorFunctionForString(@"img:nth-child(n + 1)");

	
	
	
	
	SelectorFunctionForString(@"*");

	thing = nil;
	
	SelectorFunctionForString(@"div");

	

	
	SelectorFunctionForString(@"img ~ div");
	
	SelectorFunctionForString(@"img~div");
	
	SelectorFunctionForString(@"img div");


	
	
	
	SelectorFunctionForString(@"E[foo*=\"bar\"]");

	SelectorFunctionForString(@"Efoo*=\"bar\"]");


}

@end
