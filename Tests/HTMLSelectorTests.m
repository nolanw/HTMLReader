//
//  HTMLSelectorTest.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import <XCTest/XCTest.h>

#import "HTMLDocument.h"
#import "HTMLSelector.h"

extern HTMLNthExpression parseNth(NSString *nthString);

@interface HTMLSelector (Private)

@property (readonly) NSString *parsedEquivalent;

@end

@interface HTMLSelectorTests : XCTestCase

@end

@interface HTMLSelectorTests ()

@property (strong, nonatomic) HTMLDocument *testDoc;

@end

@implementation HTMLSelectorTests

- (HTMLDocument *)testDoc
{
    if (!_testDoc) {
        _testDoc = [HTMLDocument documentWithString:
                    @"<root id='root'>"
                    @"  <parent id='empty' class='big snoopy dog'></parent>"
                    @"  <arbitrary id='nonempty-yet-devoid-of-elements' class='big' lang='up-dog'> </arbitrary>"
                    @"  <parent id='one-child'> <elem id='only-child'> </elem> </parent>"
                    @"  <parent id='three-children'> <elem id='child1'> </elem> <other id='child2'> </other> <elem id='child3'> </elem> </parent>"
                    @"  <input id='root-enabled'>"
                    @"  <input id='root-disabled' disabled>"
                    @"  <fieldset disabled>"
                    @"    <input id='fieldset-disabled'>"
                    @"    <legend>"
                    @"      <input id='legend-enabled'>"
                    @"    </legend>"
                    @"    <legend>"
                    @"      <input id='legend-disabled'>"
                    @"    </legend>"
                    @"  </fieldset>"
                    @"</root>"];
    }
    return _testDoc;
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

#define TestMatchedElementIDs(selectorString, expectedIDs) do { \
    NSArray *nodes = [self.testDoc nodesForSelectorString:(selectorString)]; \
    NSMutableArray *IDs = [NSMutableArray new]; \
    for (HTMLElementNode *node in nodes) { \
        [IDs addObject:(node[@"id"] ?: [NSNull null])]; \
    } \
    XCTAssertEqualObjects(IDs, expectedIDs); \
} while(0)

- (void)testTypeSelector
{
    TestMatchedElementIDs(@"root", (@[ @"root" ]));
    TestMatchedElementIDs(@"parent", (@[ @"empty", @"one-child", @"three-children" ]));
    TestMatchedElementIDs(@"elem", (@[ @"only-child", @"child1", @"child3" ]));
    TestMatchedElementIDs(@"other", (@[ @"child2" ]));
}

- (void)testDescendantCombinator
{
    // Any tag type with a parent of type "parent".
    TestMatchedElementIDs(@"parent *", (@[ @"only-child", @"child1", @"child2", @"child3" ]));
    
    // Test grandchild chaining, as described in http://www.w3.org/TR/css3-selectors/#descendant-combinators
    // "root * elem" == <root><*any*><elem/></*any></root>
    TestMatchedElementIDs(@"root * elem", (@[ @"only-child", @"child1", @"child3" ]));
}

- (void)testPseudoClasses
{
    TestMatchedElementIDs(@"parent:empty", (@[ @"empty" ]));
    TestMatchedElementIDs(@"elem:first-of-type", (@[ @"only-child", @"child1" ]));
    TestMatchedElementIDs(@"elem:last-of-type", (@[ @"only-child", @"child3" ]));
    TestMatchedElementIDs(@"other:first-of-type", (@[ @"child2" ]));
    TestMatchedElementIDs(@"other:first-of-type", (@[ @"child2" ]));
}

- (void)testAdjacentSiblingCombinator
{
    TestMatchedElementIDs(@"elem+other", (@[ @"child2" ]));
    TestMatchedElementIDs(@"other+elem", (@[ @"child3" ]));
}

- (void)testGeneralSiblingCombinator
{
    TestMatchedElementIDs(@"elem~elem", (@[ @"child3" ]));
}

- (void)testIDSelector
{
    TestMatchedElementIDs(@"elem#child1", (@[ @"child1" ]));
    TestMatchedElementIDs(@"#child1", (@[ @"child1" ]));
}

- (void)testClassSelector
{
    TestMatchedElementIDs(@"parent.dog", (@[ @"empty" ]));
    TestMatchedElementIDs(@".dog", (@[ @"empty" ]));
	TestMatchedElementIDs(@".big:not(arbitrary)", (@[@"empty"]));
}

- (void)testNegationPseudoClass
{
    TestMatchedElementIDs(@"elem:not(elem#only-child)", (@[ @"child1", @"child3" ]));
    TestMatchedElementIDs(@"elem:NOT(elem#only-child)", (@[ @"child1", @"child3" ]));
}

- (void)testUIElementStatesPseudoClasses
{
    TestMatchedElementIDs(@"input:disabled", (@[ @"root-disabled", @"fieldset-disabled", @"legend-disabled" ]));
    TestMatchedElementIDs(@"input:enabled", (@[ @"root-enabled", @"legend-enabled" ]));
}

- (void)testAttributeSelectors
{
    TestMatchedElementIDs(@"[class]", (@[ @"empty", @"nonempty-yet-devoid-of-elements" ]));
    
    TestMatchedElementIDs(@"[class=\"big snoopy dog\"]", (@[ @"empty" ]));
    TestMatchedElementIDs(@"[class = 'big snoopy dog']", (@[ @"empty" ]));
    
    TestMatchedElementIDs(@"[class ~= 'dog']", (@[ @"empty" ]));
    TestMatchedElementIDs(@"[id ~= 'child1']", (@[ @"child1" ]));
    
    TestMatchedElementIDs(@"[lang |= 'up']", (@[ @"nonempty-yet-devoid-of-elements" ]));
    
    TestMatchedElementIDs(@"[id ^= child]", (@[ @"child1", @"child2", @"child3" ]));
    
    TestMatchedElementIDs(@"[id $= '-child']", (@[ @"one-child", @"only-child" ]));
    
    TestMatchedElementIDs(@"[id *= child]", (@[ @"one-child", @"only-child", @"three-children",
                                                @"child1", @"child2", @"child3" ]));
}

#define ExpectError(selectorString) XCTAssertNotNil([HTMLSelector selectorForString:selectorString].error)

- (void)testBadInput
{
	ExpectError(@"[id]asdf");
    ExpectError(@"h2..foo");
    ExpectError(@"");
}

@end
