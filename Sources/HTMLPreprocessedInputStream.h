//  HTMLPreprocessedInputStream.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLSupport.h"

/**
    An HTMLPreprocessedInputStream handles carriage returns, disallowed characters, and surrogate pairs.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/parsing.html#preprocessing-the-input-stream
 */
@interface HTMLPreprocessedInputStream : NSObject

/// Initializes a stream.
- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;

/// The string backing an input stream.
@property (readonly, copy, nonatomic) NSString *string;

/**
    Consumes matching input characters.
 
    @param string The string to match. The whole string must match for any characters to be consumed.
    @param caseSensitive YES if matching should consider ASCII case, otherwise NO.
 
    @return YES if input characters were consumed, otherwise NO.
 */
- (BOOL)consumeString:(NSString *)string matchingCase:(BOOL)caseSensitive;

/**
    Continually consumes characters until a certain character is encountered.
 
    @param test A block that is called with each character consumed. When the block returns YES, character consumption stops.
 
    @return A string of the characters consumed, or nil if the stream is fully consumed before the block returns YES.
 */
- (NSString *)consumeCharactersUpToFirstPassingTest:(BOOL(^)(UTF32Char character))test;

/**
    Consumes characters matching hexadecimal digits.
 
    @param number On return, the number represented by the matched digits. Pass NULL to skip over the digits.
 
    @return YES if any input characters were consumed, otherwise NO.
 */
- (BOOL)consumeHexInt:(out unsigned int *)number;

/**
    Consumes characters matching decimal digits.
 
    @param number On return, the number represented by the matched digits. Pass NULL to skip over the digits.
 
    @return YES if any input characters were consumed, otherwise NO.
 */
- (BOOL)consumeUnsignedInt:(out unsigned int *)number;

/// Returns, but does not consume, the next input character. No parse errors are emitted. If a stream is fully consumed, returns EOF.
@property (readonly, assign, nonatomic) UTF32Char nextInputCharacter;

/**
    Returns a string of characters from the stream's current position. The characters are not preprocessed for carriage returns, and no parse errors are emitted.
 
    @param length The maximum length of the returned string.
 
    @return A string, or nil if the stream has no characters remaining.
 */
- (NSString *)nextUnprocessedCharactersWithMaximumLength:(NSUInteger)length;

/// Returns a scanner for the stream's unprocessed characters whose scan location is set to the stream's current location.
- (NSScanner *)unprocessedScanner;

/// Returns the next input character and moves scanLocation ahead, emitting parse errors as appropriate. If a stream is fully consumed, returns EOF.
- (UTF32Char)consumeNextInputCharacter;

/// Set the next input character to the current input character. This method is idempotent.
- (void)reconsumeCurrentInputCharacter;

/// Rewinds the stream.
- (void)unconsumeInputCharacters:(NSUInteger)numberOfCharactersToUnconsume;

/**
    A block called whenever a parse error occurs. The block has no return value and takes as parameters:
 
    * error A description of the error.
 */
@property (copy, nonatomic) void (^errorBlock)(NSString *error);

@end
