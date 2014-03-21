//  Benchmarker.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLReader.h"
#import <mach/mach_time.h>

static NSTimeInterval Time(NSInteger count, void (^block)(void))
{
    static mach_timebase_info_data_t timebaseInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebaseInfo);
    });
    uint64_t elapsed = 0;
    
    for (NSInteger i = 0; i < count; i++) {
        uint64_t start = mach_absolute_time();
        block();
        uint64_t end = mach_absolute_time();
        elapsed += (end - start);
    }
    
    return (NSTimeInterval)elapsed * timebaseInfo.numer / timebaseInfo.denom / 1e9;
}

static NSString * LargeHTMLDocument(void)
{
    NSString *fixture = [[@(__FILE__) stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Fixtures/html5.html"];
    return [NSString stringWithContentsOfFile:fixture usedEncoding:nil error:nil];
}

int main(void) { @autoreleasepool {
    NSString *string = LargeHTMLDocument();
    NSInteger count = 1;
    NSTimeInterval overallTime = Time(count, ^{
        [HTMLDocument documentWithString:string];
    });
    NSLog(@"Time for parsing fixture: %gs", overallTime / count);
    return 0;
}}
