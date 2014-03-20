//  HTMLNamespace.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

/**
 * This HTML parser treats three namespaces with any special consideration whatsoever.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/namespaces.html#namespaces
 */
typedef NS_ENUM(NSInteger, HTMLNamespace)
{
    /**
     * The default namespace is HTML.
     */
    HTMLNamespaceHTML,
    
    /**
     * Most elements within <math> tags are in the MathML namespace.
     */
    HTMLNamespaceMathML,
    
    /**
     * Most elements within <svg> tags are in the SVG namespace.
     */
    HTMLNamespaceSVG,
};
