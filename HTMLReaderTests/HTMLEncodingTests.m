//  HTMLEncodingTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"
#import "HTMLEncoding.h"
#import "HTMLParser.h"

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
@property (readonly, nonatomic) NSStringEncoding correctEncoding;

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

- (NSStringEncoding)correctEncoding
{
    return StringEncodingForLabel(self.correctEncodingLabel);
}

- (NSString *)testString
{
    return [[NSString alloc] initWithData:self.testData encoding:NSISOLatin1StringEncoding];
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
            // tests1.dat has four tests that require implementations HTMLReader doesn't have, so we'll skip those.
            if ([fileURL.lastPathComponent isEqualToString:@"tests1.dat"]) {
                // These three tests require scripting support, which HTMLReader does not.
                if (i == 54 || i == 55 || i == 56) {
                    return;
                }
                
                // This test passes successfully if one prescans the byte stream, which HTMLReader does not.
                if (i == 57) {
                    return;
                }
            }
            
            HTMLParser *parser = ParserWithDataAndContentType(test.testData, nil);
            
            CFStringEncoding cfcorrectEncoding = CFStringConvertNSStringEncodingToEncoding(test.correctEncoding);
            CFStringEncoding cfparserEncoding = CFStringConvertNSStringEncodingToEncoding(parser.encoding.encoding);
            NSString *description = [NSString stringWithFormat:@"%@ test%tu expected %@ (CFStringEncoding 0x%X) but got CFStringEncoding 0x%X; fixture:\n%@", testName, i, test.correctEncodingLabel, (unsigned int)cfcorrectEncoding, (unsigned int)cfparserEncoding, test.testString];
            XCTAssertEqual(parser.encoding.encoding, test.correctEncoding, @"%@", description);
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
    if (candidates == nil) {
        NSLog(@"Cannot find the HTML5 tests, do you have the submodule (%@) checked out?", html5libTestPath());
    }
    
    // Skipping test-yahoo-jp.dat because I can't be bothered to figure out how it's encoded.
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension = 'dat' && lastPathComponent != 'test-yahoo-jp.dat'"];
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

- (void)testIncorrectContentTypeHeader
{
    const char neitherUTF8NorWin1252[] = "\x90";
    NSData *data = [NSData dataWithBytes:neitherUTF8NorWin1252 length:sizeof(neitherUTF8NorWin1252)];
    HTMLParser *parser = ParserWithDataAndContentType(data, @"charset=utf-8");
    XCTAssertNotNil(parser);
    XCTAssertTrue(parser.encoding.encoding == NSISOLatin1StringEncoding);
}

@end
