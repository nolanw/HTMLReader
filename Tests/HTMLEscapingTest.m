//  HTMLEscapingTest.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "NSString+HTMLEntities.h"

@interface HTMLEntitiesTest : XCTestCase

@end

@implementation HTMLEntitiesTest

- (void)testEscapingForHTML
{
    XCTAssertEqualObjects([@"&\u00A0<>" html_stringByEscapingForHTML], @"&amp;&nbsp;&lt;&gt;");
    XCTAssertEqualObjects([@"<hello & howdy>" html_stringByEscapingForHTML], @"&lt;hello &amp; howdy&gt;");
    XCTAssertEqualObjects([@"" html_stringByEscapingForHTML], @"");
}

- (void)testUnescapingHTML
{
    XCTAssertEqualObjects([@"&Aacute;&Aacute&preccurlyeq;&DoubleLongLeftRightArrow;" html_stringByUnescapingHTML], @"ÁÁ≼⟺");
    XCTAssertEqualObjects([@"&#65;&#x42;&#X43" html_stringByUnescapingHTML], @"ABC");
    XCTAssertEqualObjects([@"&#65;&Nope;&#X43;" html_stringByUnescapingHTML], @"A&Nope;C");
    XCTAssertEqualObjects([@"&#65&Nope;&#X43;" html_stringByUnescapingHTML], @"A&Nope;C");
    XCTAssertEqualObjects([@"&#65;&Nope;&#X43" html_stringByUnescapingHTML], @"A&Nope;C");
    XCTAssertEqualObjects([@"&#65A;" html_stringByUnescapingHTML], @"AA;");
    XCTAssertEqualObjects([@"&" html_stringByUnescapingHTML], @"&");
    XCTAssertEqualObjects([@"&;" html_stringByUnescapingHTML], @"&;");
    XCTAssertEqualObjects([@"&x;" html_stringByUnescapingHTML], @"&x;");
    XCTAssertEqualObjects([@"&X;" html_stringByUnescapingHTML], @"&X;");
    XCTAssertEqualObjects([@";" html_stringByUnescapingHTML], @";");
    XCTAssertEqualObjects([@"&lt;hello &amp; howdy&gt;" html_stringByUnescapingHTML], @"<hello & howdy>");
    XCTAssertEqualObjects([@"" html_stringByUnescapingHTML], @"");
}

- (void)testRoundTrip
{
    NSString *s = @"<hello & howdy>";
    NSString *escaped = [s html_stringByEscapingForHTML];
    XCTAssertNotEqualObjects(s, escaped);
    XCTAssertEqualObjects([escaped html_stringByUnescapingHTML], s);
}

@end
