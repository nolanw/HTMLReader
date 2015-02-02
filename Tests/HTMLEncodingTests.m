//  HTMLEncodingTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"

@interface DataScanner : NSObject

- (instancetype)initWithData:(NSData *)data;

@property (readonly, copy, nonatomic) NSData *data;
@property (assign, nonatomic) NSUInteger scanLocation;

- (NSData *)scanUpToString:(const char *)string;
- (NSData *)scanString:(const char *)string;

@end

@implementation DataScanner

- (instancetype)initWithData:(NSData *)data
{
    if ((self = [super init])) {
        _data = [data copy];
    }
    return self;
}

- (NSData *)scanUpToString:(const char *)string
{
    NSRange rangeOfString = [self rangeOfString:string anchored:NO];
    NSRange rangeOfSubdata;
    if (rangeOfString.location == NSNotFound) {
        rangeOfSubdata = NSMakeRange(self.scanLocation, self.data.length - self.scanLocation);
        self.scanLocation = self.data.length;
    } else {
        rangeOfSubdata = NSMakeRange(self.scanLocation, rangeOfString.location - self.scanLocation);
        self.scanLocation = rangeOfString.location;
    }
    
    return [self.data subdataWithRange:rangeOfSubdata];
}

- (NSData *)scanString:(const char *)string
{
    NSRange rangeOfString = [self rangeOfString:string anchored:YES];
    if (rangeOfString.location == NSNotFound) {
        return nil;
    }
    
    self.scanLocation = NSMaxRange(rangeOfString);
    return [self.data subdataWithRange:rangeOfString];
}

- (NSRange)rangeOfString:(const char *)string anchored:(BOOL)anchored
{
    NSData *dataToFind = [NSData dataWithBytes:string length:strlen(string)];
    NSRange workingRange = NSMakeRange(self.scanLocation, self.data.length - self.scanLocation);
    NSUInteger options = anchored ? NSDataSearchAnchored : 0;
    return [self.data rangeOfData:dataToFind options:options range:workingRange];
}

@end

@interface HTMLEncodingTest : NSObject

@property (readonly, copy, nonatomic) NSData *testData;
@property (readonly, copy, nonatomic) NSString *correctEncodingLabel;

@property (readonly, nonatomic) NSString *testString;

@end

@implementation HTMLEncodingTest

+ (instancetype)testFromScanner:(DataScanner *)scanner
{
    [scanner scanUpToString:"#data"];
    if (![scanner scanString:"#data\n"]) {
        return nil;
    }
    
    NSData *testData = [scanner scanUpToString:"\n#encoding"];
    NSAssert(testData, @"malformed test: #data with no subsequent #encoding");
    
    [scanner scanString:"\n#encoding\n"];
    
    NSData *rawEncodingLabel = [scanner scanUpToString:"\n"];
    NSAssert(rawEncodingLabel, @"malformed test: couldn't read encoding label");
    NSString *encodingLabel = [[NSString alloc] initWithData:rawEncodingLabel encoding:NSASCIIStringEncoding];
    NSAssert(encodingLabel, @"could not decode encoding label");
    
    HTMLEncodingTest *test = [self new];
    test->_testData = [testData copy];
    test->_correctEncodingLabel = [encodingLabel copy];
    return test;
}

- (NSString *)testString
{
    return ([[NSString alloc] initWithData:self.testData encoding:NSUTF8StringEncoding] ?:
            [[NSString alloc] initWithData:self.testData encoding:NSWindowsCP1252StringEncoding]);
}

@end

@interface HTMLEncodingTests : XCTestCase

@end

@implementation HTMLEncodingTests

- (void)testEncodingDetection
{
    for (NSURL *fileURL in TestFileURLs()) {
        NSString *testName = [fileURL.lastPathComponent stringByDeletingPathExtension];
        [TestsInFileAtURL(fileURL) enumerateObjectsUsingBlock:^(HTMLEncodingTest *test, NSUInteger i, BOOL *stop) {
            // TODO
            NSString *detectedEncodingLabel = @"TODO";
            
            NSString *description = [NSString stringWithFormat:@"%@ test%tu got %@ but expected %@; fixture:\n%@", testName, i, detectedEncodingLabel, test.correctEncodingLabel, test.testString];
            XCTAssert([test.correctEncodingLabel caseInsensitiveCompare:detectedEncodingLabel] == NSOrderedSame, @"%@", description);
        }];
    }
}

static NSArray * TestFileURLs(void)
{
    NSURL *directory = [[NSURL URLWithString:html5libTestPath()] URLByAppendingPathComponent:@"encoding"];
    NSError *error;
    NSArray *candidates = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory
                                                        includingPropertiesForKeys:nil
                                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                             error:&error];
    NSCAssert(candidates, @"possible error listing test directory: %@", error);
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension = 'dat'"];
    return [candidates filteredArrayUsingPredicate:predicate];
}

static NSArray * TestsInFileAtURL(NSURL *URL)
{
    NSData *allTests = [NSData dataWithContentsOfURL:URL];
    NSCAssert(allTests, @"possible error loading test file at %@", URL);
    
    NSMutableArray *tests = [NSMutableArray new];
    DataScanner *scanner = [[DataScanner alloc] initWithData:allTests];
    for (;;) {
        HTMLEncodingTest *test = [HTMLEncodingTest testFromScanner:scanner];
        
        if (!test) {
            break;
        }
        
        [tests addObject:test];
    }
    return tests;
}

@end
