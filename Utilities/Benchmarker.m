//  Benchmarker.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLReader.h"
#import <mach/mach_time.h>

static NSTimeInterval Time(void (^block)(void))
{
    static mach_timebase_info_data_t timebaseInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebaseInfo);
    });

    uint64_t start = mach_absolute_time();
    block();
    uint64_t end = mach_absolute_time();
    
    return (NSTimeInterval)(end - start) * timebaseInfo.numer / timebaseInfo.denom / 1e9;
}

static NSString * PathForFixture(NSString *fixture)
{
    return [[[@(__FILE__) stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Fixtures"] stringByAppendingPathComponent:fixture];
}

int main(void) { @autoreleasepool {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    arguments = [arguments subarrayWithRange:NSMakeRange(1, arguments.count - 1)];
    if (arguments.count == 0) arguments = @[ @"large", @"selector" ];
    
    if ([arguments containsObject:@"large"]) {
        NSString *large = [NSString stringWithContentsOfFile:PathForFixture(@"html5.html") usedEncoding:nil error:nil];
        NSTimeInterval largeParseTime = Time(^{
            [HTMLDocument documentWithString:large];
        });
        NSLog(@"Time for parsing fixture: %gs", largeParseTime);
    }
    
    if ([arguments containsObject:@"selector"]) {
        HTMLDocument *selectorsDocument = [HTMLDocument documentWithString:[NSString stringWithContentsOfFile:PathForFixture(@"query-selector.html") usedEncoding:nil error:nil]];
        NSArray *selectorSuites = [NSArray arrayWithContentsOfFile:PathForFixture(@"query-selector.plist")];
        NSTimeInterval selectorTime = Time(^{
            for (NSDictionary *suite in selectorSuites) {
                NSInteger count = [suite[@"fraction"] integerValue];
                for (NSInteger i = 0; i < count; i++) {
                    NSArray *selectors = suite[@"selectors"];
                    for (NSString *selector in selectors) {
                        [selectorsDocument nodesMatchingSelector:selector];
                    }
                }
            }
        });
        NSLog(@"Time for selecting nodes: %gs", selectorTime);
    }
    return 0;
}}
