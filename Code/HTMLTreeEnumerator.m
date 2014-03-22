//  HTMLTreeEnumerator.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTreeEnumerator.h"
#import "HTMLNode.h"

@implementation HTMLTreeEnumerator
{
	BOOL _isReversed;
    NSUInteger *_nextNodePath;
    NSUInteger _nextNodePathCount;
    NSUInteger _nextNodePathCapacity;
}

- (void)dealloc
{
    free(_nextNodePath);
}

- (id)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed
{
    self = [super init];
    if (!self) return nil;
    
    _node = node;
	_isReversed = reversed;
    
    return self;
}

- (id)nextObject
{
    HTMLNode *currentNode = _node;
    if (!_nextNodePath) {
        _nextNodePathCapacity = 10;
        _nextNodePath = calloc(_nextNodePathCapacity, sizeof(_nextNodePath[0]));
        _nextNodePathCount = 1;
        return currentNode;
    }
    for (NSUInteger i = 0; i < _nextNodePathCount - 1; i++) {
        NSInteger index = _isReversed ? currentNode.numberOfChildren - _nextNodePath[i] - 1 : _nextNodePath[i];
        currentNode = [currentNode childAtIndex:index];
    }
    NSUInteger lastIndex = _nextNodePath[_nextNodePathCount - 1];
    if (lastIndex >= currentNode.numberOfChildren) {
        _nextNodePathCount--;
        if (_nextNodePathCount == 0) return nil;
        _nextNodePath[_nextNodePathCount - 1]++;
        return [self nextObject];
    }
    if (_nextNodePathCount == _nextNodePathCapacity) {
        _nextNodePathCapacity *= 2;
        _nextNodePath = reallocf(_nextNodePath, _nextNodePathCapacity * sizeof(_nextNodePath[0]));
    }
    _nextNodePath[_nextNodePathCount++] = 0;
    NSInteger index = _isReversed ? currentNode.numberOfChildren - lastIndex - 1 : lastIndex;
    return [currentNode childAtIndex:index];
}

@end
