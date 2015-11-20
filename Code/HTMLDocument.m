//  HTMLDocument.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocument.h"
#import "HTMLParser.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLDocument

+ (instancetype)documentWithData:(NSData *)data contentTypeHeader:(NSString * __nullable)contentType
{
    NSParameterAssert(data);
    
    HTMLParser *parser = ParserWithDataAndContentType(data, contentType);
    return parser.document;
}

- (instancetype)initWithData:(NSData *)data contentTypeHeader:(NSString * __nullable)contentType
{
    NSParameterAssert(data);
    
    return [self.class documentWithData:data contentTypeHeader:contentType];
}

+ (instancetype)documentWithString:(NSString *)string
{
    NSParameterAssert(string);
    
    HTMLStringEncoding defaultEncoding = (HTMLStringEncoding){
        .encoding = NSUTF8StringEncoding,
        .confidence = Tentative
    };
    HTMLParser *parser = [[HTMLParser alloc] initWithString:string encoding:defaultEncoding context:nil];
    return parser.document;
}

- (instancetype)initWithString:(NSString *)string
{
    NSParameterAssert(string);
    
    return [self.class documentWithString:string];
}

- (HTMLDocumentType * __nullable)documentType
{
    return FirstNodeOfType(self.children, [HTMLDocumentType class]);
}

- (void)setDocumentType:(HTMLDocumentType * __nullable)documentType
{
    HTMLDocumentType *oldDocumentType = self.documentType;
    NSMutableOrderedSet *children = [self mutableChildren];
    if (oldDocumentType && documentType) {
        NSUInteger i = [children indexOfObject:oldDocumentType];
        [children replaceObjectAtIndex:i withObject:(HTMLDocumentType * __nonnull)documentType];
    } else if (documentType) {
        HTMLElement *rootElement = self.rootElement;
        if (rootElement) {
            [children insertObject:(HTMLDocumentType * __nonnull)documentType atIndex:[children indexOfObject:rootElement]];
        } else {
            [children addObject:(HTMLDocumentType * __nonnull)documentType];
        }
    } else if (oldDocumentType) {
        [children removeObject:oldDocumentType];
    }
}

- (HTMLElement * __nullable)rootElement
{
    return FirstNodeOfType(self.children, [HTMLElement class]);
}

- (void)setRootElement:(HTMLElement * __nullable)rootElement
{
    HTMLElement *oldRootElement = self.rootElement;
    NSMutableOrderedSet *children = [self mutableChildren];
    if (oldRootElement && rootElement) {
        [children replaceObjectAtIndex:[children indexOfObject:oldRootElement] withObject:(HTMLElement * __nonnull)rootElement];
    } else if (rootElement) {
        [children addObject:(HTMLElement * __nonnull)rootElement];
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

NS_ASSUME_NONNULL_END
