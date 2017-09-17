//  HTMLDocumentTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLDocument.h"

@interface HTMLDocumentTests : XCTestCase

@end

@implementation HTMLDocumentTests

- (void)testParsedStringEncodingUnspecified
{
    HTMLDocument *document = [HTMLDocument new];
    XCTAssertEqual(document.parsedStringEncoding, (NSStringEncoding)NSUTF8StringEncoding);
}

- (void)testParsedStringEncodingEmptyDocument
{
    HTMLDocument *document = [HTMLDocument documentWithData:[NSData data] contentTypeHeader:nil];
    XCTAssertEqual(document.parsedStringEncoding, (NSStringEncoding)NSWindowsCP1252StringEncoding);
}

- (void)testParsedStringEncodingContentTypeISOLatin1
{
    HTMLDocument *document = [HTMLDocument documentWithData:(NSData *)[@"<!doctype html><h1>Hello!" dataUsingEncoding:NSUTF8StringEncoding]
                                          contentTypeHeader:@"text/html; charset=iso-8859-1"];
    XCTAssertEqual(document.parsedStringEncoding, (NSStringEncoding)NSWindowsCP1252StringEncoding);
}

- (void)testParsedStringEncodingContentTypeUTF8
{
    HTMLDocument *document = [HTMLDocument documentWithData:(NSData *)[@"<!doctype html><h1>Hello!" dataUsingEncoding:NSUTF8StringEncoding]
                                          contentTypeHeader:@"text/html; charset=utf-8"];
    XCTAssertEqual(document.parsedStringEncoding, (NSStringEncoding)NSUTF8StringEncoding);
}

@end
