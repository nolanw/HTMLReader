//  HTMLRegressionTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLDocument.h"

@interface HTMLRegressionTests : XCTestCase

@end

@implementation HTMLRegressionTests

- (void)testIssue95
{
    // https://github.com/nolanw/HTMLReader/issues/95
    // Reduced from http://thegreatstory.org/MD-writings.html on 2022-10-06
    // Test is to not crash :)
    [HTMLDocument documentWithString:@
     "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">"
     "<a>"
     "<font>"
     "<font>"
     "<font>"
     "<font color>"
     "<font size>"
     "<p>"
     "<a></a>"
    ];
}

@end
