//
//  HTMLDocument.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTMLNode.h"

typedef NS_ENUM(NSInteger, HTMLDocumentQuirksMode)
{
    HTMLNoQuirksMode,
    HTMLQuirksMode,
    HTMLLimitedQuirksMode,
};

@interface HTMLDocument : NSObject

@property (nonatomic) HTMLDocumentTypeNode *doctype;

@property (readonly, nonatomic) NSArray *childNodes;

- (void)addChildNode:(id)node;

@property (nonatomic) HTMLDocumentQuirksMode quirksMode;

@end
