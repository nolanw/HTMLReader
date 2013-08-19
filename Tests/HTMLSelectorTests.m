//
//  HTMLSelectorTest.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
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

	testDoc = [HTMLParser documentForString:@"<root id='root'>\
			   \
			   <parent id='empty'></parent>\
			   \
			   <parent id='one-child'> <elem id='only-child'> </elem> </parent>\
			   \
			   <parent id='three-children'> <elem id='child1'> </elem> <other id='child2'> </other> <elem id='child3'> </elem> </parent>\
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


#define TestSelector(selectorString, parsedSelector, expectedIds, name) -(void)test##name {\
CSSSelector *selector = [CSSSelector selectorForString:selectorString];\
/*Deal with parsed selector, when/if implemented*/ \
/*XCTAssertEqualObjects(selector.parsedEquivalent, parsedSelector);*/\
NSArray *returnedNodes = [testDoc nodesForSelector:selector];\
NSArray *returnedIds = [returnedNodes valueForKey:@"[id]"];\
XCTAssertEqualObjects(returnedIds, expectedIds, @"Test of %@ failed", selectorString);\
}



TestSelector(@"root", @"root", @[@"root"], RootElementCheck)
TestSelector(@"parent", @"parent", (@[@"empty", @"one-child", @"three-children"]), ParentElementsCheck)
TestSelector(@"elem", @"elem", (@[@"only-child", @"child1", @"child3"]), ElemElementsCheck)
TestSelector(@"other", @"other", (@[@"child2"]), OtherElementCheck)

//Any tag type with a parent of type "parent"
TestSelector(@"parent *", @"parent *", (@[@"only-child", @"child1", @"child2", @"child3"]), ParentCheck)

//Test grandchild chaining, as described in http://www.w3.org/TR/css3-selectors/#descendant-combinators
//"root * elem" == <root><*any*><elem/></*any></root>
TestSelector(@"root * elem", @"root * elem", (@[@"only-child", @"child1", @"child3"]), GrandparentCheck)
			 

TestSelector(@"parent:empty", @"elem:empty", (@[@"empty"]), EmptyElement);

TestSelector(@"elem:first-of-type", @"elem:first-of-type", (@[@"only-child", @"child1"]), FirstOfTypeElem)

TestSelector(@"elem:last-of-type", @"elem:last-of-type", (@[@"only-child", @"child3"]), LastOfTypeElem)

TestSelector(@"other:first-of-type", @"other:first-of-type", (@[@"child2"]), FirstOfTypeOther)

TestSelector(@"other:first-of-type", @"other:first-of-type", (@[@"child2"]), LastOfTypeOther)


TestSelector(@"elem+other", @"other+elem", (@[@"child2"]), AdjacentSiblingOtherFromElem)

TestSelector(@"other+elem", @"other+elem", (@[@"child3"]), AdjacentSiblingElemFromOther)

TestSelector(@"elem~elem", @"other~elem", (@[@"child3"]), GeneralSiblingElemFromElem)

TestSelector(@"elem#child1", @"elem#child1", (@[@"child1"]), IDCheckChild1)


TestSelector(@"elem:not(elem#only-child)", @"elem#only-child", (@[@"child1", @"child3"]), NotTest)



/*
 
 
 [CSSSelector selectorForString:@"img"]);
 
 
 
 [CSSSelector selectorForString:@"E[foo*=\"bar\"]"]);
 
 [CSSSelector selectorForString:@"Efoo*=\"bar\"]"]);
 
 */

@end
