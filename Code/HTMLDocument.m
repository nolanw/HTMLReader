//  HTMLDocument.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocument.h"
#import "HTMLParser.h"

@implementation HTMLDocument

+ (instancetype)documentWithString:(NSString *)string
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:string context:nil];
    return parser.document;
}

- (HTMLDocumentType *)documentType
{
    for (id node in self.children) {
        if ([node isKindOfClass:[HTMLDocumentType class]]) {
            return node;
        }
    }
    return nil;
}

- (void)setDocumentType:(HTMLDocumentType *)documentType
{
    HTMLDocumentType *oldDocumentType = self.documentType;
    if (oldDocumentType == documentType) return;
    
    NSMutableOrderedSet *children = [self mutableChildren];
    NSUInteger i = children.count;
    if (oldDocumentType) {
        i = [children indexOfObject:oldDocumentType];
        [children removeObjectAtIndex:i];
    }
    if (documentType) {
        [children insertObject:documentType atIndex:i];
    }
}

- (HTMLElement *)rootElement
{
    for (id node in self.children) {
        if ([node isKindOfClass:[HTMLElement class]]) {
            return node;
        }
    }
    return nil;
}

- (void)setRootElement:(HTMLElement *)rootElement
{
    HTMLElement *oldRootElement = self.rootElement;
    if (oldRootElement == rootElement) return;
    
    NSMutableOrderedSet *children = [self mutableChildren];
    NSUInteger i = children.count;
    if (oldRootElement) {
        i = [children indexOfObject:oldRootElement];
        [children removeObjectAtIndex:i];
    }
    if (rootElement) {
        [children insertObject:rootElement atIndex:i];
    }
}

- (void)insertObject:(HTMLNode *)node inChildrenAtIndex:(NSUInteger)index
{
    [super insertObject:node inChildrenAtIndex:index];
    node.document = self;
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index
{
    HTMLNode *node = self.children[index];
    [super removeObjectFromChildrenAtIndex:index];
    node.document = nil;
}

@end
