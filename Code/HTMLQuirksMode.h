//  HTMLQuirksMode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLSupport.h"

NS_ASSUME_NONNULL_BEGIN

/**
    HTMLDocumentQuirksMode can change parts of the parsing algorithm.
 
    For more information, see http://dom.spec.whatwg.org/#concept-document-quirks
 */
typedef NS_ENUM(NSInteger, HTMLQuirksMode)
{
    /// The default quirks mode.
    HTMLQuirksModeNoQuirks,
    
    /// A quirks mode for old versions of HTML.
    HTMLQuirksModeQuirks,
    
    /// A quirks mode for (XHTML 1.0 or HTML 4.01) (Frameset or Transitional).
    HTMLQuirksModeLimitedQuirks,
};

NS_ASSUME_NONNULL_END
