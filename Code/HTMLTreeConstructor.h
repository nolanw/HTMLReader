//
//  HTMLTreeConstructor.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTMLDocument.h"
#import "HTMLTokenizer.h"
@class HTMLElementNode;

@interface HTMLTreeConstructor : NSObject

- (id)initWithDocument:(HTMLDocument *)document context:(HTMLElementNode *)context;

@property (readonly, nonatomic) HTMLDocument *document;

- (void)resume:(id)token;

@end

@interface HTMLElementNode : NSObject

// Designated initializer.
- (id)initWithTagName:(NSString *)tagName;

@property (readonly, nonatomic) NSString *tagName;

@property (readonly, nonatomic) NSArray *childNodes;

- (void)addChildNode:(id)node;

@property (readonly, nonatomic) NSArray *attributes;

- (void)addAttribute:(HTMLAttribute *)attribute;

@end

@interface HTMLTextNode : NSObject

- (id)initWithData:(NSString *)data;

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLCommentNode : NSObject

- (id)initWithData:(NSString *)data;

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLDocumentTypeNode : NSObject

@end
