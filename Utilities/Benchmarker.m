//  Benchmarker.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLReader.h"
#import <mach/mach_time.h>

static NSTimeInterval Time(NSUInteger reps, void (^block)(void))
{
    static mach_timebase_info_data_t timebaseInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebaseInfo);
    });

    uint64_t elapsed = 0;
    for (NSUInteger i = 0; i < reps; i++) {
        uint64_t start = mach_absolute_time();
        block();
        uint64_t end = mach_absolute_time();
        elapsed += (end - start);
    }
    
    return (NSTimeInterval)elapsed * timebaseInfo.numer / timebaseInfo.denom / 1e9;
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
        NSTimeInterval largeParseTime = Time(1, ^{
            [HTMLDocument documentWithString:large];
        });
        NSLog(@"Time for parsing fixture: %gs", largeParseTime);
    }
    
    if ([arguments containsObject:@"selector"]) {
        NSString * const HTMLString = [NSString stringWithContentsOfFile:PathForFixture(@"query-selector.html") usedEncoding:nil error:nil];
        HTMLDocument *selectorsDocument = (HTMLString) ? [HTMLDocument documentWithString:(NSString * __nonnull)HTMLString] : nil;
        NSArray *selectorSuites = [NSArray arrayWithContentsOfFile:PathForFixture(@"query-selector.plist")];
        NSUInteger reps = 5;
        NSTimeInterval selectorTime = Time(reps, ^{
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
        NSLog(@"Time for selecting nodes: %gs (mean)", selectorTime / reps);
    }
    
    if ([arguments containsObject:@"escape"]) {
        NSString *large = [NSString stringWithContentsOfFile:PathForFixture(@"html5.html") usedEncoding:nil error:nil];
        NSTimeInterval escapeTime = Time(1, ^{
            [large html_stringByEscapingForHTML];
        });
        NSLog(@"Time for escaping fixture: %gs", escapeTime);
        
        NSTimeInterval unescapeTime = Time(1, ^{
            [large html_stringByUnescapingHTML];
        });
        NSLog(@"Time for unescaping fixture: %gs", unescapeTime);
    }
    
    return 0;
}}
