//  HTMLSerializerTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

// TODO Use html5lib's serializer tests directly.

#import <XCTest/XCTest.h>
#import "HTMLReader.h"
#import "HTMLTextNode.h"

@interface HTMLSerializerTests : XCTestCase

@end

@implementation HTMLSerializerTests

- (void)testBareElement
{
    HTMLElement *node = [[HTMLElement alloc] initWithTagName:@"br" attributes:nil];
    XCTAssertEqualObjects(node.serializedFragment, @"<br>");
}

// From html5lib's serializers/core.test

- (void)testAttributes
{
    #define TestAttribute(input, expected) do { \
        HTMLElement *node = [[HTMLElement alloc] initWithTagName:@"span" attributes:@{ @"title": (input) }]; \
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
        HTMLDocumentType *node = [[HTMLDocumentType alloc] initWithName:(name) publicIdentifier:(public) systemIdentifier:(system)]; \
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
    HTMLElement *node = [[HTMLElement alloc] initWithTagName:@"script" attributes:nil];
    HTMLTextNode *textNode = [[HTMLTextNode alloc] initWithData:@"a<b>c&d"];
    [[node mutableChildren] addObject:textNode];
    XCTAssertEqualObjects(node.serializedFragment, @"<script>a<b>c&d</script>");
}

- (void)testDescriptionForNonStringAttributes
{
    HTMLElement *node = [[HTMLElement alloc] initWithTagName:@"p" attributes:@{@"num": (id)@1}];
    XCTAssertEqualObjects(node.serializedFragment, @"<p num=\"1\"></p>");
}

@end
