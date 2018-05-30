//  HTMLSelector.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

// Implements CSS Selectors Level 3 http://www.w3.org/TR/css3-selectors/ with some pointers from CSS Syntax Module Level 3 http://www.w3.org/TR/2014/CR-css-syntax-3-20140220/

#import "HTMLSelector.h"
#import "HTMLString.h"
#import "HTMLTextNode.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^HTMLSelectorPredicate)(HTMLElement *node);
typedef HTMLSelectorPredicate HTMLSelectorPredicateGen;

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString, NSError **error);

static NSError * ParseError(NSString *reason, NSString *string, NSUInteger position)
{
    /*
	 String that looks like
	 
	 Error near character 4: Pseudo elements unsupported
     tag::
        ^
     
     */
    NSString *caretString = [@"^" stringByPaddingToLength:position+1 withString:@" " startingAtIndex:0];
    NSString *failureReason = [NSString stringWithFormat:@"Error near character %lu: %@\n\n\t%@\n\t\%@",
                               (unsigned long)position,
                               reason,
                               string,
                               caretString];
    
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: reason,
                                NSLocalizedFailureReasonErrorKey: failureReason,
                                HTMLSelectorInputStringErrorKey: string,
                                HTMLSelectorLocationErrorKey: @(position),
                                };
    return [NSError errorWithDomain:HTMLSelectorErrorDomain code:1 userInfo:userInfo];
}

static __nullable HTMLSelectorPredicateGen negatePredicate(HTMLSelectorPredicate predicate)
{
	if (!predicate) return nil;
	
	return ^BOOL(HTMLElement *node) {
		return !predicate(node);
	};
}

static HTMLSelectorPredicateGen neverPredicate(void)
{
    return ^(HTMLElement *node) {
        return NO;
    };
}

#pragma mark - Combinators

static HTMLSelectorPredicateGen bothCombinatorPredicate(__nullable HTMLSelectorPredicate a, __nullable HTMLSelectorPredicate b)
{
	// There was probably an error somewhere else in parsing, so return a block that always returns NO
    if (!a || !b) return ^(HTMLElement *_) { return NO; };
	
	return ^BOOL(HTMLElement *node) {
		return a(node) && b(node);
	};
}

static HTMLSelectorPredicateGen andCombinatorPredicate(NSArray * __nullable predicates)
{
    return ^(HTMLElement *node) {
        for (HTMLSelectorPredicate predicate in predicates) {
            if (!predicate(node)) {
                return NO;
            }
        }
        return YES;
    };
}

static HTMLSelectorPredicateGen orCombinatorPredicate(NSArray * __nullable predicates)
{
	return ^(HTMLElement *node) {
		for (HTMLSelectorPredicate predicate in predicates) {
			if (predicate(node)) {
				return YES;
			}
		}
		return NO;
	};
}

static HTMLSelectorPredicateGen isTagTypePredicate(NSString *tagType)
{
	if ([tagType isEqualToString:@"*"]) {
		return ^(HTMLElement *node) {
            return YES;
        };
	} else {
		return ^BOOL(HTMLElement *node) {
			return [node.tagName compare:tagType options:NSCaseInsensitiveSearch] == NSOrderedSame;
		};
	}
}

static HTMLSelectorPredicateGen childOfOtherPredicatePredicate(HTMLSelectorPredicate parentPredicate)
{
    static HTMLSelectorPredicateGen const AlwaysNo = ^(HTMLElement *_) { return NO; };
    if (!parentPredicate) return AlwaysNo;
	
	return ^(HTMLElement *element) {
        BOOL predicateResult = NO;
        if (element.parentElement) {
            predicateResult = parentPredicate((HTMLElement * __nonnull)element.parentElement);
        }
        return predicateResult;
	};
}

static HTMLSelectorPredicateGen descendantOfPredicate(__nullable HTMLSelectorPredicate parentPredicate)
{
    if (!parentPredicate) return ^(HTMLElement *_) { return NO; };
	
	return ^(HTMLElement *element) {
		HTMLElement *parent = element.parentElement;
		while (parent) {
			if (parentPredicate(parent)) {
				return YES;
			}
			parent = parent.parentElement;
		}
		return NO;
	};
}

static HTMLSelectorPredicateGen isEmptyPredicate(void)
{
	return ^BOOL(HTMLElement *node) {
        for (HTMLNode *child in node.children) {
            if ([child isKindOfClass:[HTMLElement class]]) {
                return NO;
            } else if ([child isKindOfClass:[HTMLTextNode class]]) {
                HTMLTextNode *textNode = (HTMLTextNode *)child;
                if (textNode.data.length > 0) {
                    return NO;
                }
            }
        }
        return YES;
	};
}


#pragma mark - Attribute Predicates

static HTMLSelectorPredicateGen hasAttributePredicate(NSString *attributeName)
{
	return ^BOOL(HTMLElement *node) {
		return !!node[attributeName];
	};
}

static HTMLSelectorPredicateGen attributeIsExactlyPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElement *node) {
		return [node[attributeName] isEqualToString:attributeValue];
	};
}

NSCharacterSet * HTMLSelectorWhitespaceCharacterSet(void)
{
    // http://www.w3.org/TR/css3-selectors/#whitespace
    return [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r\f"];
}

static HTMLSelectorPredicateGen attributeContainsExactWhitespaceSeparatedValuePredicate(NSString *attributeName, NSString *attributeValue)
{
    NSCharacterSet *whitespace = HTMLSelectorWhitespaceCharacterSet();
    return ^(HTMLElement *node) {
        NSArray *items = [node[attributeName] componentsSeparatedByCharactersInSet:whitespace];
        return [items containsObject:attributeValue];
    };
}

static HTMLSelectorPredicateGen attributeStartsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElement *node) {
		return [node[attributeName] hasPrefix:attributeValue];
	};
}

static HTMLSelectorPredicateGen attributeContainsPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^BOOL(HTMLElement *node) {
        NSString *value = node[attributeName];
		return value && [value rangeOfString:attributeValue].location != NSNotFound;
	};
}

static HTMLSelectorPredicateGen attributeEndsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElement *node) {
		return [node[attributeName] hasSuffix:attributeValue];
	};
}

#pragma mark Sibling Predicates

static __nullable HTMLSelectorPredicateGen adjacentSiblingPredicate(__nullable HTMLSelectorPredicate siblingTest)
{
	if (!siblingTest) return nil;
	
	return ^BOOL(HTMLElement *node) {
		NSArray *parentChildren = node.parentElement.childElementNodes;
		NSUInteger nodeIndex = [parentChildren indexOfObject:node];
		return nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex - 1]);
	};
}

static __nullable HTMLSelectorPredicateGen generalSiblingPredicate(__nullable HTMLSelectorPredicate siblingTest)
{
	if (!siblingTest) return nil;
	
	return ^(HTMLElement *node) {
		for (HTMLElement *sibling in node.parentElement.childElementNodes) {
			if ([sibling isEqual:node]) {
				break;
			}
			if (siblingTest(node)) {
				return YES;
			}
		}
		return NO;
	};
}

#pragma mark nth- Predicates

static HTMLSelectorPredicateGen isNthChildPredicate(HTMLNthExpression nth, BOOL fromLast)
{
	return ^BOOL(HTMLNode *node) {
		NSArray *parentElements = node.parentElement.childElementNodes;
		// Index relative to start/end
		NSInteger nthPosition;
		if (fromLast) {
			nthPosition = parentElements.count - [parentElements indexOfObject:node];
		} else {
			nthPosition = [parentElements indexOfObject:node] + 1;
		}
        if (nth.n > 0) {
            return (nthPosition - nth.c) % nth.n == 0;
        } else {
            return nthPosition == nth.c;
        }
	};
}

static __nullable HTMLSelectorPredicateGen isNthChildOfTypePredicate(HTMLNthExpression nth, __nullable HTMLSelectorPredicate typePredicate, BOOL fromLast)
{
	if (!typePredicate) return nil;
	
	return ^BOOL(HTMLElement *node) {
		id <NSFastEnumeration> enumerator = (fromLast
                                             ? node.parentElement.childElementNodes.reverseObjectEnumerator
                                             : node.parentElement.childElementNodes);
		NSInteger count = 0;
		for (HTMLElement *currentNode in enumerator) {
			if (typePredicate(currentNode)) {
				count++;
			}
			if ([currentNode isEqual:node]) {
				// check if the current node is the nth element of its type based on the current count
				if (nth.n > 0) {
					return (count - nth.c) % nth.n == 0;
				} else {
					return (count - nth.c) == 0;
				}
			}
		}
		return NO;
	};
}

static HTMLSelectorPredicateGen isFirstChildPredicate(void)
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), NO);
}

static HTMLSelectorPredicateGen isLastChildPredicate(void)
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), YES);
}

static __nullable HTMLSelectorPredicateGen isFirstChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), typePredicate, NO);
}

static __nullable HTMLSelectorPredicateGen isLastChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), typePredicate, YES);
}

#pragma mark Attribute Helpers

static HTMLSelectorPredicateGen isKindOfClassPredicate(NSString *classname)
{
	return attributeContainsExactWhitespaceSeparatedValuePredicate(@"class", classname);
}

static HTMLSelectorPredicateGen hasIDPredicate(NSString *idValue)
{
	return attributeIsExactlyPredicate(@"id", idValue);
}

static HTMLSelectorPredicateGen isLinkPredicate(void)
{
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/selectors.html#selector-link
    return andCombinatorPredicate(@[orCombinatorPredicate(@[isTagTypePredicate(@"a"),
                                                            isTagTypePredicate(@"area"),
                                                            isTagTypePredicate(@"link")
                                                            ]),
                                    hasAttributePredicate(@"href")
                                    ]);
}

static HTMLSelectorPredicateGen isDisabledPredicate(void)
{
    HTMLSelectorPredicateGen (*and)(NSArray *) = andCombinatorPredicate;
    HTMLSelectorPredicateGen (*or)(NSArray *) = orCombinatorPredicate;
    HTMLSelectorPredicateGen (*not)(HTMLSelectorPredicate) = negatePredicate;
    HTMLSelectorPredicate hasDisabledAttribute = hasAttributePredicate(@"disabled");
    
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/common-idioms.html#concept-element-disabled
    HTMLSelectorPredicate disabledOptgroup = and(@[isTagTypePredicate(@"optgroup"), hasDisabledAttribute]);
    HTMLSelectorPredicate disabledFieldset = and(@[isTagTypePredicate(@"fieldset"), hasDisabledAttribute]);
    HTMLSelectorPredicate disabledMenuitem = and(@[isTagTypePredicate(@"menuitem"), hasDisabledAttribute]);
    
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/association-of-controls-and-forms.html#concept-fe-disabled
    HTMLSelectorPredicate formElement = or(@[isTagTypePredicate(@"button"),
                                              isTagTypePredicate(@"input"),
                                              isTagTypePredicate(@"select"),
                                              isTagTypePredicate(@"textarea")
                                              ]);
    HTMLSelectorPredicate firstLegend = isFirstChildOfTypePredicate(isTagTypePredicate(@"legend"));
    HTMLSelectorPredicate firstLegendOfDisabledFieldset = and(@[firstLegend, descendantOfPredicate(disabledFieldset)]);
    HTMLSelectorPredicate disabledFormElement = and(@[formElement,
                                                      or(@[hasDisabledAttribute,
                                                           and(@[descendantOfPredicate(disabledFieldset),
                                                                 not(descendantOfPredicate(firstLegendOfDisabledFieldset))
                                                                 ])
                                                           ])
                                                      ]);
    
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/the-button-element.html#concept-option-disabled
    HTMLSelectorPredicate disabledOption = and(@[ isTagTypePredicate(@"option"),
                                                  or(@[ hasDisabledAttribute,
                                                        descendantOfPredicate(disabledOptgroup) ])
                                                  ]);
    
    return or(@[ disabledOptgroup, disabledFieldset, disabledMenuitem, disabledFormElement, disabledOption ]);
}

static HTMLSelectorPredicateGen isEnabledPredicate(void)
{
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/selectors.html#selector-enabled
    HTMLSelectorPredicate hasHrefAttribute = hasAttributePredicate(@"href");
    HTMLSelectorPredicate enabledByHref = orCombinatorPredicate(@[isTagTypePredicate(@"a"),
                                                                  isTagTypePredicate(@"area"),
                                                                  isTagTypePredicate(@"link")
                                                                  ]);
    HTMLSelectorPredicate canOtherwiseBeEnabled = orCombinatorPredicate(@[isTagTypePredicate(@"button"),
                                                                          isTagTypePredicate(@"input"),
                                                                          isTagTypePredicate(@"select"),
                                                                          isTagTypePredicate(@"textarea"),
                                                                          isTagTypePredicate(@"optgroup"),
                                                                          isTagTypePredicate(@"option"),
                                                                          isTagTypePredicate(@"menuitem"),
                                                                          isTagTypePredicate(@"fieldset")
                                                                          ]);
    NSMutableArray *combinator = [NSMutableArray arrayWithObject:canOtherwiseBeEnabled];
    HTMLSelectorPredicateGen negate = negatePredicate(isDisabledPredicate());
    if (negate) {
        [combinator addObject:negate];
    }
    return orCombinatorPredicate(@[andCombinatorPredicate(@[enabledByHref, hasHrefAttribute ]),
                                   andCombinatorPredicate(combinator)
                                   ]);
}

static HTMLSelectorPredicateGen isCheckedPredicate(void)
{
	return orCombinatorPredicate(@[hasAttributePredicate(@"checked"), hasAttributePredicate(@"selected")]);
}

#pragma mark - Only Child

static HTMLSelectorPredicateGen isOnlyChildPredicate(void)
{
	return ^BOOL(HTMLNode *node) {
		return [node.parentElement childElementNodes].count == 1;
	};
}

static __nullable HTMLSelectorPredicateGen isOnlyChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return bothCombinatorPredicate(isFirstChildOfTypePredicate(typePredicate), isLastChildOfTypePredicate(typePredicate));
}

static HTMLSelectorPredicateGen isRootPredicate(void)
{
	return ^BOOL(HTMLElement *node)
	{
		return !node.parentElement;
	};
}

static NSNumber * __nullable parseNumber(NSString *number, NSInteger defaultValue)
{
    // Strip whitespace so -isAtEnd check below answers "was this a valid integer?"
    number = [number stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
	NSScanner *scanner = [NSScanner scannerWithString:number];
    NSInteger result = defaultValue;
	[scanner scanInteger:&result];
    return scanner.isAtEnd ? @(result) : nil;
}

#pragma mark Parse

NSString * __nullable scanIdentifier(NSScanner *scanner,  NSError ** __nullable error);

static NSString * __nullable scanFunctionInterior(NSScanner *scanner, NSError ** __nullable error)
{
	BOOL ok;
    
    ok = [scanner scanString:@"(" intoString:nil];
	if (!ok) {
		if (error) *error = ParseError(@"Expected ( to start function", scanner.string, scanner.scanLocation);
		return nil;
	}
	
    NSString *interior;
	ok = [scanner scanUpToString:@")" intoString:&interior];
	if (!ok) {
		*error = ParseError(@"Expected ) to end function", scanner.string, scanner.scanLocation);
		return nil;
	}
    
    [scanner scanString:@")" intoString:nil];
	return interior;
}

static __nullable HTMLSelectorPredicateGen scanPredicateFromPseudoClass(NSScanner *scanner,
                                                                        HTMLSelectorPredicate typePredicate,
                                                                        NSError ** __nullable error)
{
	NSString *pseudo = scanIdentifier(scanner, error);
	
	// Case-insensitively look for pseudo classes
	pseudo = [pseudo lowercaseString];
	
	static NSDictionary *simplePseudos = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        simplePseudos = @{
                          @"first-child": isFirstChildPredicate(),
                          @"last-child": isLastChildPredicate(),
                          @"only-child": isOnlyChildPredicate(),
                          
                          @"empty": isEmptyPredicate(),
                          @"root": isRootPredicate(),
                          
                          @"link": isLinkPredicate(),
                          @"visited": neverPredicate(),
                          @"active": neverPredicate(),
                          @"hover": neverPredicate(),
                          @"focus": neverPredicate(),
                          
                          @"enabled": isEnabledPredicate(),
                          @"disabled": isDisabledPredicate(),
                          @"checked": isCheckedPredicate()
                          };
	});
	
    id simple = [simplePseudos objectForKey:pseudo];
	if (simple) {
		return simple;
	}
	else if ([pseudo isEqualToString:@"first-of-type"]){
		return isFirstChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo isEqualToString:@"last-of-type"]){
		return isLastChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo isEqualToString:@"only-of-type"]){
		return isOnlyChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo hasPrefix:@"nth"]) {
		NSString *interior = scanFunctionInterior(scanner, error);
		
		if (!interior) return nil;
		
		HTMLNthExpression nth = HTMLNthExpressionFromString(interior);
		
		if (HTMLNthExpressionEqualToNthExpression(nth, HTMLNthExpressionInvalid)) {
			*error = ParseError(@"Failed to parse Nth statement", scanner.string, scanner.scanLocation);
			return nil;
		}

		if ([pseudo isEqualToString:@"nth-child"]){
			return isNthChildPredicate(nth, NO);
		}
		else if ([pseudo isEqualToString:@"nth-last-child"]){
			return isNthChildPredicate(nth, YES);
		}
		else if ([pseudo isEqualToString:@"nth-of-type"]){
			return isNthChildOfTypePredicate(nth, typePredicate, NO);
		}
		else if ([pseudo isEqualToString:@"nth-last-of-type"]){
			return isNthChildOfTypePredicate(nth, typePredicate, YES);
		}
	}
	else if ([pseudo isEqualToString:@"not"]) {
		NSString *toNegateString = scanFunctionInterior(scanner, error);
		HTMLSelectorPredicate toNegate = SelectorFunctionForString(toNegateString, error);
		return negatePredicate(toNegate);
	}
	
	*error = ParseError(@"Unrecognized pseudo class", scanner.string, scanner.scanLocation);
	return nil;
}


#pragma mark

static NSCharacterSet *identifierCharacters(void)
{
    static NSCharacterSet *frozenSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"-_"];
        [set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        frozenSet = [set copy];
    });
	return frozenSet;
}

static NSCharacterSet *tagModifierCharacters(void)
{
	return [NSCharacterSet characterSetWithCharactersInString:@".:#["];
}

static NSCharacterSet *combinatorCharacters(void)
{
    static NSCharacterSet *frozenSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Combinators are: whitespace, "greater-than sign" (U+003E, >), "plus sign" (U+002B, +) and "tilde" (U+007E, ~)
        NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@">+~"];
        [set formUnionWithCharacterSet:HTMLSelectorWhitespaceCharacterSet()];
        frozenSet = [set copy];
    });
	return frozenSet;
}

NSString * __nullable scanEscape(NSScanner *scanner, NSError ** __nullable error)
{
    if (![scanner scanString:@"\\" intoString:nil]) {
        return nil;
    }
    
    NSCharacterSet *hexCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    NSUInteger scanLocation = scanner.scanLocation;
    NSString *hex;
    if ([scanner scanCharactersFromSet:hexCharacters intoString:&hex]) {
        if (scanner.scanLocation - scanLocation > 6) {
            NSRange range = NSMakeRange(scanLocation, 6);
            hex = [scanner.string substringWithRange:range];
            scanner.scanLocation = NSMaxRange(range);
        }
        
        // Optional single trailing whitespace.
        if (![scanner scanString:@"\r\n" intoString:nil]) {
            scanLocation = scanner.scanLocation;
            if ([scanner scanCharactersFromSet:HTMLSelectorWhitespaceCharacterSet() intoString:nil]) {
                scanner.scanLocation = scanLocation + 1;
            }
        }
        
        unsigned int codepoint;
        [[NSScanner scannerWithString:hex] scanHexInt:&codepoint];
        if (codepoint == 0x0 || codepoint > 0x10FFFF || (codepoint >= 0xD800 && codepoint <= 0xDFFF)) {
            return @"\uFFFD";
        } else {
            return StringWithLongCharacter(codepoint);
        }
    } else if ([scanner scanString:@"\r\n" intoString:nil] || [scanner scanString:@"\n" intoString:nil] || [scanner scanString:@"\r" intoString:nil] || [scanner scanString:@"\f" intoString:nil]) {
        if (error) {
            *error = ParseError(@"Expected non-newline or hex digit(s) after starting escape", scanner.string, scanLocation);
        }
        return nil;
    } else if (scanner.isAtEnd) {
        return @"\uFFFD";
    } else {
        unichar characters[2];
        NSUInteger count = 1;
        characters[0] = [scanner.string characterAtIndex:scanner.scanLocation];
        ++scanner.scanLocation;
        if (CFStringIsSurrogateHighCharacter(characters[0])) {
            characters[1] = [scanner.string characterAtIndex:scanner.scanLocation];
            ++count;
            ++scanner.scanLocation;
        }
        return [NSString stringWithCharacters:characters length:count];
    }
}

NSString * __nullable scanIdentifier(NSScanner *scanner,  NSError ** __nullable error)
{
    NSMutableString *ident = [NSMutableString new];
    NSString *part;
    while ([scanner scanCharactersFromSet:identifierCharacters() intoString:&part]) {
        [ident appendString:part];
        NSString *escape = scanEscape(scanner, error);
        if (escape) {
            [ident appendString:escape];
        } else {
            break;
        }
    }
    NSString *trimmed = [ident stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

NSString * __nullable scanTagModifier(NSScanner *scanner, NSError ** __nullable error)
{
	NSString *modifier;
	[scanner scanCharactersFromSet:tagModifierCharacters() intoString:&modifier];
	modifier = [modifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	modifier = [modifier length] != 0 ? modifier : nil;
	return modifier;
}

NSString *scanCombinator(NSScanner *scanner,  NSError ** __nullable error)
{
	NSString *operator;
	[scanner scanCharactersFromSet:combinatorCharacters() intoString:&operator];
	operator = [operator stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return operator;
}

__nullable HTMLSelectorPredicate scanAttributePredicate(NSScanner *scanner, NSError ** __nullable error)
{
    NSCAssert([scanner.string characterAtIndex:scanner.scanLocation - 1] == '[', nil);
    
	NSString *attributeName = scanIdentifier(scanner, error);
	NSString *operator;
    NSString *attributeValue;
    BOOL ok;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"=]"]
                            intoString:&operator];
    ok = [scanner scanString:@"=" intoString:nil];
    if (ok) {
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		operator = [operator stringByTrimmingCharactersInSet:whitespace];
        operator = operator.length > 0 ? operator : @"=";
        [scanner scanCharactersFromSet:whitespace intoString:nil];
        attributeValue = scanIdentifier(scanner, error);
        if (!attributeValue) {
            [scanner scanCharactersFromSet:whitespace intoString:nil];
            NSString *quote = [scanner.string substringWithRange:NSMakeRange(scanner.scanLocation, 1)];
            if (!([quote isEqualToString:@"\""] || [quote isEqualToString:@"'"])) {
				*error = ParseError(@"Expected quote in attribute value", scanner.string, scanner.scanLocation);
                return nil;
            }
            [scanner scanString:quote intoString:nil];
            [scanner scanUpToString:quote intoString:&attributeValue];
            [scanner scanString:quote intoString:nil];
        }
    } else {
        operator = nil;
    }
	
	[scanner scanUpToString:@"]" intoString:nil];
	ok = [scanner scanString:@"]" intoString:nil];
	if (!ok) {
		*error = ParseError(@"Expected ] to close attribute", scanner.string, scanner.scanLocation);
		return nil;
	}
	
	if ([operator length] == 0) {
		return hasAttributePredicate(attributeName);
	} else if ([operator isEqualToString:@"="]) {
		return attributeIsExactlyPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"~"]) {
        return attributeContainsExactWhitespaceSeparatedValuePredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"^"]) {
		return attributeStartsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"$"]) {
		return attributeEndsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"*"]) {
		return attributeContainsPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"|"]) {
		return orCombinatorPredicate(@[attributeIsExactlyPredicate(attributeName, attributeValue),
                                       attributeStartsWithPredicate(attributeName, [attributeValue stringByAppendingString:@"-"])]);
	} else {
		*error = ParseError(@"Unexpected operator", scanner.string, scanner.scanLocation - operator.length);
		return nil;
	}
}

HTMLSelectorPredicateGen scanTagPredicate(NSScanner *scanner, NSError ** __nullable error)
{
	NSString *identifier = scanIdentifier(scanner, error);
	if (identifier) {
        return isTagTypePredicate(identifier);
    } else {
        [scanner scanString:@"*" intoString:nil];
        return isTagTypePredicate(@"*");
    }
}


__nullable HTMLSelectorPredicateGen scanPredicate(NSScanner *scanner, HTMLSelectorPredicate inputPredicate, NSError **error)
{
	HTMLSelectorPredicate tagPredicate = scanTagPredicate(scanner, error);
	
	inputPredicate = inputPredicate ? bothCombinatorPredicate(tagPredicate, inputPredicate) : tagPredicate;
	
	// If we're out of things to scan, all we have is this tag, no operators on it
	if (scanner.isAtEnd) return inputPredicate;
	
	NSString *modifier;
	
	do {
		modifier = scanTagModifier(scanner, error);
		
		// Pseudo and attribute
		if ([modifier isEqualToString:@":"]) {
			inputPredicate = bothCombinatorPredicate(inputPredicate,
													 scanPredicateFromPseudoClass(scanner, inputPredicate, error));
		} else if ([modifier isEqualToString:@"::"]) {
			// We don't support *any* pseudo-elements.
			*error = ParseError(@"Pseudo elements unsupported", scanner.string, scanner.scanLocation - modifier.length);
			return nil;
		} else if ([modifier isEqualToString:@"["]) {
			inputPredicate = bothCombinatorPredicate(inputPredicate,
													 scanAttributePredicate(scanner, error));
		} else if ([modifier isEqualToString:@"."]) {
			NSString *className = scanIdentifier(scanner, error);
			inputPredicate =  bothCombinatorPredicate(inputPredicate,
                                                      isKindOfClassPredicate(className));
		} else if ([modifier isEqualToString:@"#"]) {
			NSString *idName = scanIdentifier(scanner, error);
			inputPredicate =  bothCombinatorPredicate(inputPredicate,
                                                      hasIDPredicate(idName));
		} else if (modifier != nil) {
			*error = ParseError(@"Unexpected modifier", scanner.string, scanner.scanLocation - modifier.length);
			return nil;
		}
		
	} while (modifier != nil);
	

	
	// Pseudo and attribute cases require that this is either the end of the selector, or there's another combinator after them
	
	if (scanner.isAtEnd) return inputPredicate;
	
	NSString *combinator = scanCombinator(scanner, error);
	
	if ([combinator isEqualToString:@""]) {
		// Whitespace combinator: y descendant of an x
		return descendantOfPredicate(inputPredicate);
	} else if ([combinator isEqualToString:@">"]) {
		return childOfOtherPredicatePredicate(inputPredicate);
	} else if ([combinator isEqualToString:@"+"]) {
		return adjacentSiblingPredicate(inputPredicate);
	} else if ([combinator isEqualToString:@"~"]) {
		return generalSiblingPredicate(inputPredicate);
	}
    
    if (combinator == nil) {
        NSUInteger scanLocation = scanner.scanLocation;
        [scanner scanCharactersFromSet:HTMLSelectorWhitespaceCharacterSet() intoString:nil];
        if ([scanner scanString:@"," intoString:nil]) {
            --scanner.scanLocation;
            return inputPredicate;
        } else {
            scanner.scanLocation = scanLocation;
        }
    }
    
	if (combinator == nil) {
		*error = ParseError(@"Expected a combinator here", scanner.string, scanner.scanLocation);
		return nil;
	} else {
		*error = ParseError(@"Unexpected combinator", scanner.string, scanner.scanLocation - combinator.length);
		return nil;
	}
}

static __nullable HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString, NSError ** __nullable error)
{
	// Trim non-functional whitespace
	selectorString = [selectorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // An empty selector is an invalid selector.
    if (selectorString.length == 0 || [selectorString hasPrefix:@","]) {
        if (error) *error = ParseError(@"Empty selector", selectorString, 0);
        return nil;
    }
	
	NSScanner *scanner = [NSScanner scannerWithString:selectorString];
    scanner.caseSensitive = NO; // Section 3 states that in HTML parsing, selectors are case-insensitive
    scanner.charactersToBeSkipped = nil;
    
    NSMutableArray *predicates = [NSMutableArray new];
    for (;;) {
        // Scan out predicate parts and combine them
        HTMLSelectorPredicate lastPredicate = nil;
        
        do {
            lastPredicate = scanPredicate(scanner, lastPredicate, error);
        } while (lastPredicate && ![scanner isAtEnd] && [scanner.string characterAtIndex:scanner.scanLocation] != ',' && !*error);
        
        if (*error) {
            return nil;
        }
        
        NSCAssert(lastPredicate, @"Need a predicate at this point");
        
        [predicates addObject:lastPredicate];
        
        if ([scanner scanString:@"," intoString:nil]) {
            [scanner scanCharactersFromSet:HTMLSelectorWhitespaceCharacterSet() intoString:nil];
            if ([scanner isAtEnd]) {
                if (error) *error = ParseError(@"Empty selector in group", selectorString, scanner.scanLocation);
                return nil;
            }
        } else if ([scanner isAtEnd]) {
            break;
        }
    }
    
    NSCAssert(predicates.count > 0 || *error, @"Need predicates or an error at this point");
	
    return orCombinatorPredicate(predicates);
}

@interface HTMLSelector ()

@property (copy, nonatomic) NSString *string;
@property (strong, nonatomic) NSError * __nullable error;
@property (copy, nonatomic) HTMLSelectorPredicate __nullable predicate;

@end

@implementation HTMLSelector

+ (instancetype)selectorForString:(NSString *)selectorString
{
    NSParameterAssert(selectorString);
    
	return [[self alloc] initWithString:selectorString];
}

- (instancetype)initWithString:(NSString *)selectorString
{
    NSParameterAssert(selectorString);
    
    if ((self = [super init])) {
        _string = [selectorString copy];
        NSError *error;
        _predicate = SelectorFunctionForString(selectorString, &error);
        _error = error;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithString:@""];
}

- (BOOL)matchesElement:(HTMLElement *)element
{
    NSParameterAssert(element);
    
    return self.predicate(element);
}

- (NSString *)description
{
    if (self.error) {
        return [NSString stringWithFormat:@"<%@: %p ERROR: '%@'>", self.class, self, self.error];
    } else {
        return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, self.string];
	}
}

@end

NSString * const HTMLSelectorErrorDomain = @"HTMLSelectorErrorDomain";

NSString * const HTMLSelectorInputStringErrorKey = @"HTMLSelectorInputString";

NSString * const HTMLSelectorLocationErrorKey = @"HTMLSelectorLocation";

@implementation HTMLNode (HTMLSelector)

- (HTMLArrayOf(HTMLElement *) *)nodesMatchingSelector:(NSString *)selectorString
{
	return [self nodesMatchingParsedSelector:[HTMLSelector selectorForString:selectorString]];
}

- (HTMLElement * __nullable)firstNodeMatchingSelector:(NSString *)selectorString
{
    return [self firstNodeMatchingParsedSelector:[HTMLSelector selectorForString:selectorString]];
}

- (HTMLArrayOf(HTMLElement *) *)nodesMatchingParsedSelector:(HTMLSelector *)selector
{
    if (selector.error) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Attempted to use selector with error: %@", selector.error] userInfo:nil];
    }
    
	NSMutableArray *ret = [NSMutableArray new];
	for (HTMLElement *node in self.treeEnumerator) {
		if ([node isKindOfClass:[HTMLElement class]] && [selector matchesElement:node]) {
			[ret addObject:node];
		}
	}
	return ret;
}

- (HTMLElement * __nullable)firstNodeMatchingParsedSelector:(HTMLSelector *)selector
{
    if (selector.error) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Attempted to use selector with error: %@", selector.error] userInfo:nil];
    }
    
    for (HTMLElement *node in self.treeEnumerator) {
        if ([node isKindOfClass:[HTMLElement class]] && [selector matchesElement:node]) {
            return node;
        }
    }
    return nil;
}

@end

HTMLNthExpression HTMLNthExpressionMake(NSInteger n, NSInteger c)
{
    return (HTMLNthExpression){ .n = n, .c = c };
}

BOOL HTMLNthExpressionEqualToNthExpression(HTMLNthExpression a, HTMLNthExpression b)
{
    return a.n == b.n && a.c == b.c;
}

HTMLNthExpression HTMLNthExpressionFromString(NSString *string)
{
    NSCParameterAssert(string);
    
	string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([string compare:@"odd" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		return HTMLNthExpressionOdd;
	} else if ([string compare:@"even" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		return HTMLNthExpressionEven;
	} else {
        NSCharacterSet *nthCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789 nN+-"] invertedSet];
        if ([string rangeOfCharacterFromSet:nthCharacters].location != NSNotFound) {
            return HTMLNthExpressionInvalid;
        }
	}
	
	NSArray *valueSplit = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]];
	
	if (valueSplit.count == 0 || valueSplit.count > 2) {
		// No Ns or multiple Ns, fail
		return HTMLNthExpressionInvalid;
	} else if (valueSplit.count == 2) {
        NSNumber *numberOne = parseNumber([valueSplit objectAtIndex:0], 1);
        NSNumber *numberTwo = parseNumber([valueSplit objectAtIndex:1], 0);
		
        if ([[valueSplit objectAtIndex:0] isEqualToString:@"-"] && numberTwo) {
			// "n" was defined, and only "-" was given as a multiplier
			return HTMLNthExpressionMake(-1, numberTwo.integerValue);
		} else if (numberOne && numberTwo) {
			return HTMLNthExpressionMake(numberOne.integerValue, numberTwo.integerValue);
		} else {
			return HTMLNthExpressionInvalid;
		}
	} else {
        NSNumber *number = parseNumber([valueSplit objectAtIndex:0], 1);
		
		// "n" not found, use whole string as b
		return HTMLNthExpressionMake(0, number.integerValue);
	}
}

const HTMLNthExpression HTMLNthExpressionOdd = (HTMLNthExpression){ .n = 2, .c = 1 };

const HTMLNthExpression HTMLNthExpressionEven = (HTMLNthExpression){ .n = 2, .c = 0 };

const HTMLNthExpression HTMLNthExpressionInvalid = (HTMLNthExpression){ .n = 0, .c = 0 };

NS_ASSUME_NONNULL_END
