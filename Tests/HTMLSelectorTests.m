//
//  HTMLSelectorTest.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import <XCTest/XCTest.h>

#import "HTMLParser.h"
#import "HTMLSelector.h"

extern HTMLNthExpression parseNth(NSString *nthString);

@interface HTMLSelector (Private)

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
			   <parent id='empty' class='snoopy dog'></parent>\
               \
               <arbitrary id='nonempty-yet-devoid-of-elements'> </arbitrary>\
			   \
			   <parent id='one-child'> <elem id='only-child'> </elem> </parent>\
			   \
			   <parent id='three-children'> <elem id='child1'> </elem> <other id='child2'> </other> <elem id='child3'> </elem> </parent>\
			   \
			   </root>"];
}


- (void)testNthParsing
{
	XCTAssertEqual(parseNth(@"odd"), HTMLNthExpressionOdd);
	XCTAssertEqual(parseNth(@"even"), HTMLNthExpressionEven);

	XCTAssertEqual(parseNth(@"   odd    "), HTMLNthExpressionOdd);
    
    XCTAssertEqual(parseNth(@" oDD"), HTMLNthExpressionOdd);
    XCTAssertEqual(parseNth(@"EVEN"), HTMLNthExpressionEven);
	
	XCTAssertEqual(parseNth(@"2"), HTMLNthExpressionMake(0, 2));
	XCTAssertEqual(parseNth(@"-2"), HTMLNthExpressionMake(0, -2));
	
	XCTAssertEqual(parseNth(@"n"), HTMLNthExpressionMake(1, 0));
	XCTAssertEqual(parseNth(@"-n"), HTMLNthExpressionMake(-1, 0));
	XCTAssertEqual(parseNth(@"2n"), HTMLNthExpressionMake(2, 0));
	
	XCTAssertEqual(parseNth(@"n + 1"), HTMLNthExpressionMake(1, 1));
	
	XCTAssertEqual(parseNth(@"2n + 3"), HTMLNthExpressionMake(2, 3));
	XCTAssertEqual(parseNth(@"2n - 3"), HTMLNthExpressionMake(2, -3));
    
    XCTAssertEqual(parseNth(@"2n + 0"), HTMLNthExpressionMake(2, 0));
    XCTAssertEqual(parseNth(@"2n - 0"), HTMLNthExpressionMake(2, 0));
    
    XCTAssertEqual(parseNth(@"0n + 5"), HTMLNthExpressionMake(0, 5));

	XCTAssertEqual(parseNth(@" - 3"), HTMLNthExpressionMake(0, -3));

	XCTAssertEqual(parseNth(@"2 - 2n"), HTMLNthExpressionInvalid, @"bad order");
    
	XCTAssertEqual(parseNth(@"2n + 3b"), HTMLNthExpressionInvalid, @"bad character");
}


#define TestSelector(selectorString, parsedSelector, expectedIds, name) \
- (void)test##name \
{ \
    HTMLSelector *selector = [HTMLSelector selectorForString:selectorString]; \
    /* TODO Deal with parsed selector, when/if implemented */ \
    /* XCTAssertEqualObjects(selector.parsedEquivalent, parsedSelector); */ \
    NSArray *returnedNodes = [testDoc nodesForSelector:selector]; \
    NSMutableArray *returnedIds = [NSMutableArray new]; \
    for (HTMLElementNode *node in returnedNodes) { \
        [returnedIds addObject:node[@"id"]]; \
    } \
    XCTAssertEqualObjects(returnedIds, expectedIds, @"Test of %@ failed", selectorString); \
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

TestSelector(@"parent.dog", @"parent.dog", (@[@"empty"]), Class)


TestSelector(@"elem:not(elem#only-child)", @"elem#only-child", (@[@"child1", @"child3"]), NotTest)
TestSelector(@"elem:NOT(elem#only-child)", @"elem#only-child", (@[@"child1", @"child3"]), UppercaseNotTest)



/*
 
 
 [CSSSelector selectorForString:@"img"]);
 
 
 
 [CSSSelector selectorForString:@"E[foo*=\"bar\"]"]);
 
 [CSSSelector selectorForString:@"Efoo*=\"bar\"]"]);
 
 */

@end
