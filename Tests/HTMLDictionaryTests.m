//  HTMLDictionaryTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLOrderedDictionary.h"

@interface HTMLDictionaryTests : XCTestCase

@end

@implementation HTMLDictionaryTests
{
    HTMLOrderedDictionary *_dictionary;
}

static NSArray *fixtureKeys;

+ (void)setUp
{
    fixtureKeys = @[ @"sup", @"ahoy", @"howdy", @"yo", @"hola" ];
}

- (void)setUp
{
    [super setUp];
    _dictionary = [HTMLOrderedDictionary new];
}

- (void)populateDictionary
{
    for (id key in fixtureKeys) {
        _dictionary[key] = key;
    }
}

- (void)testInitWithObjectsForKeysCount
{
    // -initWithObjects:forKeys: calls -initWithObjects:forKeys:count:
    _dictionary = [[HTMLOrderedDictionary alloc] initWithObjects:fixtureKeys forKeys:fixtureKeys];
    XCTAssertNotNil(_dictionary);
}

- (void)testKeyEnumerator
{
    XCTAssertNotNil(_dictionary.keyEnumerator);
    NSArray *keys = _dictionary.keyEnumerator.allObjects;
    XCTAssertNotNil(keys);
    XCTAssertTrue(keys.count == 0);
    
    [self populateDictionary];
    NSEnumerator *enumerator = _dictionary.keyEnumerator;
    XCTAssertNotNil(enumerator);
    XCTAssertTrue(enumerator.allObjects.count == 5);
}

- (void)testAllKeys
{
    NSMutableArray *keys = [NSMutableArray new];
    for (NSUInteger i = 0; i < 30; i++) {
        [keys addObject:@(i)];
        _dictionary[@(i)] = @(i);
    }
    XCTAssertEqualObjects(_dictionary.allKeys, keys);
}

- (void)testIndexedSubscript
{
    XCTAssertThrows(_dictionary[0]);
    [self populateDictionary];
    XCTAssertEqualObjects(_dictionary[0], fixtureKeys.firstObject);
    XCTAssertThrows(_dictionary[_dictionary.count]);
}

- (void)testObjectEnumerator
{
    XCTAssertNotNil(_dictionary.objectEnumerator);
    NSArray *objects = _dictionary.objectEnumerator.allObjects;
    XCTAssertNotNil(objects);
    XCTAssertTrue(objects.count == 0);
    
    [self populateDictionary];
    NSEnumerator *enumerator = _dictionary.objectEnumerator;
    XCTAssertNotNil(enumerator);
    XCTAssertTrue(enumerator.allObjects.count == 5);
}

- (void)testRemoveObjectForKey
{
    XCTAssertNil(_dictionary[@"yo"]);
    XCTAssertNoThrow([_dictionary removeObjectForKey:@"yo"]);
    
    [self populateDictionary];
    XCTAssertNotNil(_dictionary[@"yo"]);
    XCTAssertNoThrow([_dictionary removeObjectForKey:@"yo"]);
    XCTAssertNil(_dictionary[@"yo"]);
}

- (void)testSetObjectForKey
{
    XCTAssertThrows([_dictionary setObject:@1 forKey:nil]);
    XCTAssertThrows([_dictionary setObject:nil forKey:@1]);
    
    XCTAssertNil(_dictionary[@"yo"]);
    _dictionary[@"yo"] = @"hey";
    XCTAssertEqualObjects(_dictionary[@"yo"], @"hey");
    
    [_dictionary removeAllObjects];
    [self populateDictionary];
    id key = fixtureKeys.lastObject;
    id value = _dictionary[key];
    _dictionary[key] = value;
    XCTAssertEqualObjects(_dictionary[key], value);
    _dictionary[key] = @1;
    XCTAssertNotEqualObjects(_dictionary[key], value);
    
    XCTAssertEqualObjects(_dictionary.lastKey, key);
    _dictionary[fixtureKeys.firstObject] = @1;
    XCTAssertEqualObjects(_dictionary.lastKey, key);
}

- (void)testInsertObjectForKeyAtIndex
{
    XCTAssertThrows([_dictionary insertObject:@"yo" forKey:@"yo" atIndex:1]);
    XCTAssertThrows([_dictionary insertObject:nil forKey:@"yo" atIndex:0]);
    XCTAssertThrows([_dictionary insertObject:@"yo" forKey:nil atIndex:0]);
    
    [self populateDictionary];
    NSUInteger count = _dictionary.count;
    XCTAssertThrows([_dictionary insertObject:@"yo" forKey:@"yo" atIndex:count + 1]);
    
    XCTAssertNoThrow([_dictionary insertObject:@"aloha" forKey:@"aloha" atIndex:count]);
    XCTAssertEqualObjects(_dictionary.lastKey, @"aloha");
    
    XCTAssertNoThrow([_dictionary insertObject:@"ciao" forKey:@"ciao" atIndex:0]);
    XCTAssertEqualObjects(_dictionary.firstKey, @"ciao");
}

- (void)testNSCoding
{
    [self populateDictionary];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_dictionary];
    HTMLOrderedDictionary *clone = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertEqualObjects(_dictionary, clone);
}

- (void)testNSCopying
{
    HTMLOrderedDictionary *copy = [_dictionary copy];
    XCTAssertEqual(_dictionary.count, copy.count);
    XCTAssertEqual(_dictionary.hash, copy.hash);
    XCTAssertEqualObjects(_dictionary.class, copy.class);
    
    [self populateDictionary];
    XCTAssertNotEqual(_dictionary.count, copy.count);
    
    copy = [_dictionary copy];
    XCTAssertEqual(_dictionary.count, copy.count);
    XCTAssertEqual(_dictionary.hash, copy.hash);
    XCTAssertEqualObjects(_dictionary, copy);
    XCTAssertEqualObjects(_dictionary.allKeys, copy.allKeys);
}

- (void)testIndexOfKey
{
    XCTAssertEqual([_dictionary indexOfKey:@"yo"], NSNotFound);
    [self populateDictionary];
    XCTAssertEqual([_dictionary indexOfKey:@"yo"], [fixtureKeys indexOfObject:@"yo"]);
}

- (void)testFirstKey
{
    XCTAssertNil(_dictionary.firstKey);
    [self populateDictionary];
    XCTAssertEqualObjects(_dictionary.firstKey, fixtureKeys.firstObject);
}

- (void)testLastKey
{
    XCTAssertNil(_dictionary.lastKey);
    [self populateDictionary];
    XCTAssertEqualObjects(_dictionary.lastKey, fixtureKeys.lastObject);
}

@end
