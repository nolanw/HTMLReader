//
//  HTMLDocument.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//

#import <Foundation/Foundation.h>
#import "HTMLNode.h"

typedef NS_ENUM(NSInteger, HTMLDocumentQuirksMode)
{
    HTMLNoQuirksMode,
    HTMLQuirksMode,
    HTMLLimitedQuirksMode,
};

// Property and method names follow the DOM specification and do not attempt to follow Objective-C conventions.

@interface HTMLDocument : HTMLNode

@property (nonatomic) HTMLDocumentTypeNode *doctype;
@property (nonatomic) HTMLDocumentQuirksMode quirksMode;

@end
