//
//  HTMLTokenizer.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-14.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTMLTokenizer : NSEnumerator

+ (instancetype)tokenizerWithString:(NSString *)string;

@end
