//
//  HTMLTreeConstructionTestUtilities.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLDocument.h"
#import "HTMLParser.h"

extern NSArray * ReifiedTreeForTestDocument(NSString *document);

extern BOOL TreesAreTestEquivalent(id a, id b);

#define HTMLAssertParserState(parser, numErrors, fixtureNodes) \
do { \
    id rootNodes = [[(parser) document] childNodes]; \
    XCTAssert(TreesAreTestEquivalent(rootNodes, (fixtureNodes)), \
              @"parsed: %@\nfixture:\n%@", [(parser).document recursiveDescription], \
              [[(fixtureNodes) valueForKey:@"recursiveDescription"] componentsJoinedByString:@"\n"]); \
    XCTAssertEqual([[(parser) errors] count], (NSUInteger)(numErrors), @""); \
} while(0)
