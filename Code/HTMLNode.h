//  HTMLNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLAttribute.h"

/**
 * HTML knows of three namespaces.
 */
typedef NS_ENUM(NSInteger, HTMLNamespace)
{
    /**
     * The default namespace is HTML.
     */
    HTMLNamespaceHTML,
    
    /**
     * Most elements within <math> tags are in the MathML namespace.
     */
    HTMLNamespaceMathML,
    
    /**
     * Most elements within <svg> tags are in the SVG namespace.
     */
    HTMLNamespaceSVG,
};

/**
 * HTMLNode is an abstract class whose instances represent a single element, block of text, comment, or document type.
 */
@interface HTMLNode : NSObject <NSCopying>

/**
 * This node's parent, or nil if this node is a root node.
 */
@property (readonly, weak, nonatomic) HTMLNode *parentNode;

/**
 * The root node of this node's tree. (Usually an HTMLDocument.)
 */
@property (readonly, strong, nonatomic) HTMLNode *rootNode;

/**
 * This node's children, in document order.
 */
@property (readonly, copy, nonatomic) NSArray *childNodes;

/**
 * This node's element children, in document order.
 */
@property (readonly, copy, nonatomic) NSArray *childElementNodes;

/**
 * Returns an enumerator that returns all nodes in the subtree rooted at this node, in tree order.
 *
 * http://www.whatwg.org/specs/web-apps/current-work/multipage/infrastructure.html#tree-order
 */
- (NSEnumerator *)treeEnumerator;

/**
 * Returns an enumerator that returns all nodes in the subtree rooted at this node, in reverse tree order.
 */
- (NSEnumerator *)reversedTreeEnumerator;

/**
 * Returns an NSString describing the subtree rooted at this node.
 */
- (NSString *)recursiveDescription;

/**
 * Returns nil. See -[HTMLElementNode objectForKeyedSubscript:].
 */
- (id)objectForKeyedSubscript:(id)key;

/**
 * Returns the serialized HTML fragment of this node's children.
 *
 * This is what's described as "the HTML fragment serialization algorithm" by the spec.
 */
- (NSString *)innerHTML;

/**
 * Returns the serialized HTML fragment of this node. Subclasses must override.
 */
- (NSString *)serializedFragment;

@end

/**
 * An HTMLElementNode represents a parsed element.
 */
@interface HTMLElementNode : HTMLNode

/**
 * Returns an initialized HTMLElementNode. This is the designated initializer.
 *
 * @param tagName The name of this element.
 */
- (id)initWithTagName:(NSString *)tagName;

/**
 * This element's name.
 */
@property (readonly, copy, nonatomic) NSString *tagName;

/**
 * This element's attributes.
 */
@property (readonly, copy, nonatomic) NSArray *attributes;

/**
 * Returns an attribute on this element, or nil if no matching element is found.
 *
 * @param name The name of the attribute to return.
 */
- (HTMLAttribute *)attributeNamed:(NSString *)name;

/**
 * Returns the value of the attribute named `key`, or nil if no such value exists.
 *
 * Attributes by default have a value of the empty string.
 */
- (id)objectForKeyedSubscript:(id)key;

/**
 * This element's namespace.
 */
@property (readonly, assign, nonatomic) HTMLNamespace namespace;

@end

/**
 * An HTMLTextNode represents a contiguous sequence of one or more characters.
 */
@interface HTMLTextNode : HTMLNode

/**
 * Returns an initialized HTMLTextNode. This is the designated initializer.
 *
 * @param data The text.
 */
- (id)initWithData:(NSString *)data;

/**
 * The node's text.
 */
@property (readonly, copy, nonatomic) NSString *data;

@end

/**
 * An HTMLCommentNode represents a comment.
 */
@interface HTMLCommentNode : HTMLNode

/**
 * Returns an initialized HTMLCommentNode. This is the designated initializer.
 *
 * @param data The comment text.
 */
- (id)initWithData:(NSString *)data;

/**
 * The comment's text.
 */
@property (readonly, copy, nonatomic) NSString *data;

@end

/**
 * An HTMLDocumentTypeNode represents an archaic description of the standards an HTML document is meant to adhere to.
 *
 * The only valid document type is `<!doctype html>`.
 */
@interface HTMLDocumentTypeNode : HTMLNode

/**
 * Returns an initialized HTMLDocumentTypeNode.
 *
 * @param name The document type's name. May be nil.
 * @param publicId The document type's public identifier (the second part of the document type). May be nil.
 * @param systemId The document type's system identifier (the third part of the document type). May be nil.
 */
- (id)initWithName:(NSString *)name publicId:(NSString *)publicId systemId:(NSString *)systemId;

/**
 * The document type's name, or nil if it has no name.
 */
@property (readonly, copy, nonatomic) NSString *name;

/**
 * The document type's public identifier, or nil if it has no public identifier.
 */
@property (readonly, copy, nonatomic) NSString *publicId;

/**
 * The document type's system identifier, or nil if it has no system identifier.
 */
@property (readonly, copy, nonatomic) NSString *systemId;

@end
