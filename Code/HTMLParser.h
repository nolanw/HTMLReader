//
//  HTMLParser.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTMLDocument.h"
#import "HTMLNode.h"

// The tree construction stage of parsing HTML.
@interface HTMLParser : NSObject

// Designated initializer for using the HTML parsing algorithm.
- (id)initWithString:(NSString *)string;

// Designated initializer for using the HTML fragment parsing algorithm. context may be nil.
- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context;

@property (readonly, copy, nonatomic) NSArray *errors;

@property (readonly, strong, nonatomic) HTMLDocument *document;

@property (readonly, strong, nonatomic) HTMLElementNode *adjustedCurrentNode;

@end
