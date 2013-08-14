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

@interface HTMLDocument : HTMLNode

+ (instancetype)documentWithString:(NSString *)string;

@property (nonatomic) HTMLDocumentTypeNode *doctype;
@property (nonatomic) HTMLDocumentQuirksMode quirksMode;

@property (readonly, strong, nonatomic) HTMLElementNode *rootNode;

@end
