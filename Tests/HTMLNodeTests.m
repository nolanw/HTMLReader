//  HTMLNodeTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLComment.h"
#import "HTMLDocument.h"
#import "HTMLTextNode.h"

@interface HTMLNodeTests : XCTestCase

@end

@implementation HTMLNodeTests
{
    HTMLDocument *_document;
}

static NSArray *nodeChildClasses;

+ (void)setUp
{
    [super setUp];
    nodeChildClasses = @[ [HTMLComment class], [HTMLTextNode class] ];
}

- (void)setUp
{
    [super setUp];
    _document = [HTMLDocument new];
}

- (void)testDocumentType
{
    HTMLDocumentType *doctype = [HTMLDocumentType new];
    
    XCTAssertNil(doctype.document);
    XCTAssertNil(_document.documentType);
    _document.documentType = doctype;
    XCTAssertEqualObjects(_document.documentType, doctype);
    XCTAssertEqualObjects(doctype.document, _document);
    
    HTMLDocumentType *otherDoctype = [HTMLDocumentType new];
    _document.documentType = otherDoctype;
    XCTAssertEqualObjects(_document.documentType, otherDoctype);
    XCTAssertEqualObjects(otherDoctype.document, _document);
    XCTAssertNil(doctype.document);
    
    _document.documentType = nil;
    XCTAssertNil(_document.documentType);
    XCTAssertNil(otherDoctype.document);
}

- (void)testElementAttributes
{
    HTMLElement *element = [HTMLElement new];
    
    XCTAssertTrue(element.attributes.count == 0);
    element[@"class"] = @"bursty";
    XCTAssertEqualObjects(element.attributes.allKeys, (@[ @"class" ]));
    XCTAssertEqualObjects(element.attributes[@"class"], @"bursty");
    XCTAssertEqualObjects(element[@"class"], @"bursty");
    
    element[@"id"] = @"shovel";
    XCTAssertEqualObjects(element.attributes.allKeys[1], @"id");
    XCTAssertEqualObjects(element[@"id"], @"shovel");
    
    element[@"style"] = @"blink";
    XCTAssertEqualObjects(element.attributes.allKeys[1], @"id");
    element[@"id"] = @"maven";
    XCTAssertEqualObjects(element.attributes.allKeys[1], @"id");
    
    XCTAssertEqualObjects(element.attributes.allKeys[0], @"class");
    [element removeAttributeWithName:@"class"];
    XCTAssertNil(element[@"class"]);
    XCTAssertEqualObjects(element.attributes.allKeys[0], @"id");
}

- (void)testNode
{
    HTMLComment *comment = [HTMLComment new];
    
    XCTAssertNil(comment.document);
    XCTAssertTrue(_document.children.count == 0);
    [[_document mutableChildren] addObject:comment];
    XCTAssertEqualObjects(comment.document, _document);
    XCTAssertEqualObjects(_document.children.array, (@[ comment ]));
    [[_document mutableChildren] removeObject:comment];
    XCTAssertNil(comment.document);
    XCTAssertTrue(_document.children.count == 0);
    
    HTMLElement *element = [HTMLElement new];
    XCTAssertNil(comment.parentElement);
    comment.parentElement = element;
    XCTAssertEqualObjects(comment.parentElement, element);
    
    XCTAssertNil(comment.document);
    [[_document mutableChildren] addObject:element];
    XCTAssertEqualObjects(comment.document, _document);
    [[_document mutableChildren] removeObject:element];
    XCTAssertNil(comment.document);
}

- (void)testTextContent
{
    HTMLElement *root = [[HTMLElement alloc] initWithTagName:@"body" attributes:nil];
    XCTAssertEqualObjects(root.textContent, @"");
    
    HTMLComment *comment = [[HTMLComment alloc] initWithData:@"shhh"];
    comment.parentElement = root;
    XCTAssertEqualObjects(root.textContent, @"");
    XCTAssertEqualObjects(comment.textContent, @"shhh");
    
    [[root mutableChildren] addObject:[[HTMLTextNode alloc] initWithData:@"  "]];
    HTMLElement *p = [[HTMLElement alloc] initWithTagName:@"p" attributes:nil];
    [[root mutableChildren] addObject:p];
    [[p mutableChildren] addObject:[[HTMLTextNode alloc] initWithData:@"hello"]];
    [[root mutableChildren] addObject:[[HTMLTextNode alloc] initWithData:@" sup sup sup"]];
    XCTAssertEqualObjects(root.textContent, @"  hello sup sup sup");
    XCTAssertEqualObjects(p.textContent, @"hello");
    
    root.textContent = @"now what";
    XCTAssertEqualObjects(root.textContent, @"now what");
    XCTAssertEqualObjects([root.children.array valueForKey:@"class"], (@[ [HTMLTextNode class] ]));
    XCTAssertNil(p.parentElement);
    XCTAssertNil(comment.parentNode);
}

@end
