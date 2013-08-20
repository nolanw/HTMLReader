//
//  HTMLNode.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//

#import <Foundation/Foundation.h>
#import "HTMLAttribute.h"

typedef NS_ENUM(NSInteger, HTMLNamespace)
{
    HTMLNamespaceHTML,
    HTMLNamespaceMathML,
    HTMLNamespaceSVG,
};

@interface HTMLNode : NSObject <NSCopying>

@property (readonly, weak, nonatomic) HTMLNode *parentNode;

@property (readonly, strong, nonatomic) HTMLNode *rootNode;

@property (copy, nonatomic) NSArray *childNodes;

- (void)appendChild:(HTMLNode *)child;
- (void)insertChild:(HTMLNode *)child atIndex:(NSUInteger)index;
- (void)removeChild:(HTMLNode *)child;

@property (copy, nonatomic) NSArray *childElementNodes;

- (NSEnumerator *)treeEnumerator;
- (NSEnumerator *)reversedTreeEnumerator;

- (NSString *)recursiveDescription;

- (id)objectForKeyedSubscript:(id)key;

@end

@interface HTMLElementNode : HTMLNode

// Designated initializer.
- (id)initWithTagName:(NSString *)tagName;

@property (readonly, copy, nonatomic) NSString *tagName;

@property (readonly, copy, nonatomic) NSArray *attributes;
- (void)addAttribute:(HTMLAttribute *)attribute;
- (HTMLAttribute *)attributeNamed:(NSString*)name;

@property (nonatomic) HTMLNamespace namespace;

@end

@interface HTMLTextNode : HTMLNode

- (id)initWithData:(NSString *)data;

- (void)appendLongCharacter:(UTF32Char)character;

@property (readonly, copy, nonatomic) NSString *data;

@end

@interface HTMLCommentNode : HTMLNode

- (id)initWithData:(NSString *)data;

@property (readonly, copy, nonatomic) NSString *data;

@end

@interface HTMLDocumentTypeNode : HTMLNode

- (id)initWithName:(NSString *)name publicId:(NSString *)publicId systemId:(NSString *)systemId;

@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSString *publicId;
@property (readonly, copy, nonatomic) NSString *systemId;

@end
