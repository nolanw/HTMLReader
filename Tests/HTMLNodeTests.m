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

- (void)testAttributes
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

- (void)testComment
{
    HTMLComment *comment = [HTMLComment new];
    
    XCTAssertNil(comment.document);
    XCTAssertTrue(_document.children.count == 0);
    [[_document mutableChildren] addObject:comment];
    XCTAssertEqualObjects(comment.document, _document);
    XCTAssertEqualObjects(_document.children.array, (@[ comment ]));
    comment.document = nil;
    XCTAssertNil(comment.document);
    XCTAssertTrue(_document.children.count == 0);
    
    HTMLElement *element = [HTMLElement new];
    XCTAssertNil(comment.parentElement);
    comment.parentElement = element;
    XCTAssertEqualObjects(comment.parentElement, element);
    
    XCTAssertNil(comment.document);
    element.document = _document;
    XCTAssertEqualObjects(comment.document, _document);
    comment.document = nil;
    XCTAssertNil(comment.document);
    XCTAssertNil(comment.parentElement);
    XCTAssertTrue(element.children.count == 0);
    
    comment.parentElement = element;
    XCTAssertEqualObjects(comment.parentElement, element);
    comment.document = _document;
    XCTAssertEqualObjects(comment.parentElement, element);
    comment.document = nil;
    XCTAssertNil(comment.parentElement);
    XCTAssertNil(comment.document);
    XCTAssertTrue(element.children.count == 0);
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
    otherDoctype.document = _document;
    XCTAssertEqualObjects(_document.documentType, otherDoctype);
    XCTAssertEqualObjects(otherDoctype.document, _document);
    XCTAssertNil(doctype.document);
    
    _document.documentType = nil;
    XCTAssertNil(_document.documentType);
    XCTAssertNil(otherDoctype.document);
}

- (void)testElement
{
    HTMLElement *root = [HTMLElement new];
    HTMLElement *middle = [HTMLElement new];
    HTMLElement *leaf = [HTMLElement new];
    
    XCTAssertNil(middle.parentElement);
    XCTAssertTrue(root.children.count == 0);
    [[root mutableChildren] addObject:middle];
    XCTAssertEqualObjects(middle.parentElement, root);
    XCTAssertEqualObjects(root.children.array, (@[ middle ]));
    
    XCTAssertNil(leaf.parentElement);
    XCTAssertTrue(middle.children.count == 0);
    leaf.parentElement = middle;
    XCTAssertEqualObjects(leaf.parentElement, middle);
    XCTAssertEqualObjects(middle.children.array, (@[ leaf ]));
    
    XCTAssertNil(root.document);
    XCTAssertNil(middle.document);
    XCTAssertNil(leaf.document);
    root.document = _document;
    XCTAssertEqualObjects(root.document, _document);
    XCTAssertEqualObjects(middle.document, _document);
    XCTAssertEqualObjects(leaf.document, _document);
    
    XCTAssertEqualObjects(leaf.parentElement, middle);
    XCTAssertEqualObjects(middle.parentElement, root);
    middle.document = nil;
    XCTAssertEqualObjects(leaf.parentElement, middle);
    XCTAssertNil(middle.parentElement);
    
    XCTAssertEqualObjects(_document.rootElement, root);
    XCTAssertEqualObjects(root.document, _document);
    _document.rootElement = nil;
    XCTAssertNil(_document.rootElement);
    XCTAssertNil(root.document);
}

- (void)testTextNode
{
    HTMLTextNode *textNode = [HTMLTextNode new];
    
    XCTAssertNil(textNode.document);
    XCTAssertTrue(_document.children.count == 0);
    [[_document mutableChildren] addObject:textNode];
    XCTAssertEqualObjects(textNode.document, _document);
    XCTAssertTrue(_document.children.count == 1);
    XCTAssertEqualObjects(_document.children.array, (@[ textNode ]));
    textNode.document = nil;
    XCTAssertNil(textNode.document);
    XCTAssertTrue(_document.children.count == 0);
    
    HTMLElement *element = [HTMLElement new];
    XCTAssertNil(textNode.parentElement);
    textNode.parentElement = element;
    XCTAssertEqualObjects(textNode.parentElement, element);
    
    XCTAssertNil(textNode.document);
    element.document = _document;
    XCTAssertEqualObjects(textNode.document, _document);
    textNode.document = nil;
    XCTAssertNil(textNode.document);
    XCTAssertNil(textNode.parentElement);
    XCTAssertTrue(element.children.count == 0);
    
    textNode.parentElement = element;
    XCTAssertEqualObjects(textNode.parentElement, element);
    textNode.document = _document;
    XCTAssertEqualObjects(textNode.parentElement, element);
    textNode.document = nil;
    XCTAssertNil(textNode.parentElement);
    XCTAssertNil(textNode.document);
    XCTAssertTrue(element.children.count == 0);
}

@end
