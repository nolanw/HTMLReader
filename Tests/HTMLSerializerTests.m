//
//  HTMLSerializerTests.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-08-27.
//

// TODO Use html5lib's serializer tests directly. (And update them for the current spec.)

#import <XCTest/XCTest.h>
#import "HTMLNode.h"
#import "HTMLMutability.h"

@interface HTMLSerializerTests : XCTestCase

@end

@implementation HTMLSerializerTests

// From html5lib's serializers/core.test

- (void)testAttributes
{
    #define TestAttribute(input, expected) do { \
        HTMLElementNode *node = [[HTMLElementNode alloc] initWithTagName:@"span"]; \
        HTMLAttribute *attribute = [[HTMLAttribute alloc] initWithName:@"title" value:(input)]; \
        [node addAttribute:attribute]; \
        XCTAssertEqualObjects(node.serializedFragment, (expected)); \
    } while (0)
    
    TestAttribute(@"test \"with\" &quot;", @"<span title=\"test &quot;with&quot; &amp;quot;\"></span>");
    TestAttribute(@"foo", @"<span title=\"foo\"></span>");
    TestAttribute(@"foo<bar", @"<span title=\"foo<bar\"></span>");
    TestAttribute(@"foo=bar", @"<span title=\"foo=bar\"></span>");
    TestAttribute(@"foo>bar", @"<span title=\"foo>bar\"></span>");
    TestAttribute(@"foo\"bar", @"<span title=\"foo&quot;bar\"></span>");
    TestAttribute(@"foo'bar", @"<span title=\"foo'bar\"></span>");
    TestAttribute(@"foo'bar\"baz", @"<span title=\"foo'bar&quot;baz\"></span>");
    TestAttribute(@"foo bar", @"<span title=\"foo bar\"></span>");
    TestAttribute(@"foo\tbar", @"<span title=\"foo\tbar\"></span>");
    TestAttribute(@"foo\nbar", @"<span title=\"foo\nbar\"></span>");
    TestAttribute(@"foo\rbar", @"<span title=\"foo\rbar\"></span>");
    TestAttribute(@"foo\fbar", @"<span title=\"foo\fbar\"></span>");
}

- (void)testDoctype
{
    #define TestDoctype(name, public, system, expected) do { \
        HTMLDocumentTypeNode *node = [[HTMLDocumentTypeNode alloc] initWithName:(name) publicId:(public) systemId:(system)]; \
        XCTAssertEqualObjects(node.serializedFragment, (expected)); \
    } while (0)
    
    TestDoctype(@"HTML", nil, nil, @"<!DOCTYPE HTML>");
    TestDoctype(@"HTML", @"-//W3C//DTD HTML 4.01//EN", @"http://www.w3.org/TR/html4/strict.dtd", @"<!DOCTYPE HTML>");
    TestDoctype(@"HTML", @"-//W3C//DTD HTML 4.01//EN", nil, @"<!DOCTYPE HTML>");
    TestDoctype(@"html", nil, @"http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd", @"<!DOCTYPE html>");
}

- (void)testText
{
    HTMLTextNode *node = [[HTMLTextNode alloc] initWithData:@"a<b>c&d"];
    XCTAssertEqualObjects(node.serializedFragment, @"a&lt;b&gt;c&amp;d");
}

- (void)testRCDATA
{
    HTMLElementNode *node = [[HTMLElementNode alloc] initWithTagName:@"script"];
    [node appendChild:[[HTMLTextNode alloc] initWithData:@"a<b>c&d"]];
    XCTAssertEqualObjects(node.serializedFragment, @"<script>a<b>c&d</script>");
}

@end
