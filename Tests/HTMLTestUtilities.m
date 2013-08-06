//
//  HTMLTestUtilities.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-08-06.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTestUtilities.h"

NSString * html5libTestPath(void)
{
    #define STRINGIFY_EXPAND(a) #a
    #define STRINGIFY(a) @STRINGIFY_EXPAND(a)
    return STRINGIFY(HTML5LIBTESTPATH);
}
