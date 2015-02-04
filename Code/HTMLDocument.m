//  HTMLDocument.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocument.h"
#import "HTMLParser.h"

@implementation HTMLDocument

+ (instancetype)documentWithData:(NSData *)data contentTypeHeader:(NSString *)contentType
{
    HTMLParser *parser = ParserWithDataAndContentType(data, contentType);
    return parser.document;
}

- (instancetype)initWithData:(NSData *)data contentTypeHeader:(NSString *)contentType
{
    return [self.class documentWithData:data contentTypeHeader:contentType];
}

+ (instancetype)documentWithString:(NSString *)string
{
    HTMLStringEncoding defaultEncoding = (HTMLStringEncoding){
        .encoding = NSUTF8StringEncoding,
        .confidence = Tentative
    };
    HTMLParser *parser = [[HTMLParser alloc] initWithString:string encoding:defaultEncoding context:nil];
    return parser.document;
}

- (instancetype)initWithString:(NSString *)string
{
    return [self.class documentWithString:string];
}

- (HTMLDocumentType *)documentType
{
    return FirstNodeOfType(self.children, [HTMLDocumentType class]);
}

- (void)setDocumentType:(HTMLDocumentType *)documentType
{
    HTMLDocumentType *oldDocumentType = self.documentType;
    NSMutableOrderedSet *children = [self mutableChildren];
    if (oldDocumentType && documentType) {
        NSUInteger i = [children indexOfObject:oldDocumentType];
        [children replaceObjectAtIndex:i withObject:documentType];
    } else if (documentType) {
        HTMLElement *rootElement = self.rootElement;
        if (rootElement) {
            [children insertObject:documentType atIndex:[children indexOfObject:rootElement]];
        } else {
            [children addObject:documentType];
        }
    } else if (oldDocumentType) {
        [children removeObject:oldDocumentType];
    }
}

- (HTMLElement *)rootElement
{
    return FirstNodeOfType(self.children, [HTMLElement class]);
}

- (void)setRootElement:(HTMLElement *)rootElement
{
    HTMLElement *oldRootElement = self.rootElement;
    NSMutableOrderedSet *children = [self mutableChildren];
    if (oldRootElement && rootElement) {
        [children replaceObjectAtIndex:[children indexOfObject:oldRootElement] withObject:rootElement];
    } else if (rootElement) {
        [children addObject:rootElement];
    } else if (oldRootElement) {
        [children removeObject:oldRootElement];
    }
}

static id FirstNodeOfType(id <NSFastEnumeration> collection, Class type)
{
    for (id node in collection) {
        if ([node isKindOfClass:type]) {
            return node;
        }
    }
    return nil;
}

@end
