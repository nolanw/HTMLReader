//
//  HTMLTestUtilities.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-08-06.
//

#import "HTMLTestUtilities.h"
#import <XCTest/XCTest.h>

NSString * html5libTestPath(void)
{
    #define STRINGIFY_EXPAND(a) #a
    #define STRINGIFY(a) @STRINGIFY_EXPAND(a)
    return STRINGIFY(HTML5LIBTESTPATH);
}

BOOL ShouldRunTestsForParameterizedTestClass(Class class)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *scope = [defaults stringForKey:XCTestScopeKey];
    if ([scope isEqualToString:XCTestScopeAll] || [scope isEqualToString:XCTestScopeSelf]) {
        return YES;
    } else if ([scope isEqualToString:XCTestScopeNone]) {
        return NO;
    } else {
        NSArray *tests = [scope componentsSeparatedByString:@","];
        NSString *parameterizedName = [NSString stringWithFormat:@"%@/test", NSStringFromClass(class)];
        BOOL invertScope = [defaults boolForKey:@"XCTestInvertScope"];
        return [tests containsObject:parameterizedName] != invertScope;
    }
}
