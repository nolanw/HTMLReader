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

// Designated initializer.
- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context;

@property (readonly, nonatomic) NSArray *errors;

@property (readonly, nonatomic) HTMLDocument *document;

@end
