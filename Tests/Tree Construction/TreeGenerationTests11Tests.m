// This file was autogenerated from Tests/html5lib/tree-construction/tests11.dat

#import <SenTestingKit/SenTestingKit.h>
#import "HTMLTreeConstructionTestUtilities.h"

@interface TreeGenerationTests11Tests : SenTestCase

@end

@implementation TreeGenerationTests11Tests

- (void)test000
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><svg attributeName='' attributeType='' baseFrequency='' baseProfile='' calcMode='' clipPathUnits='' contentScriptType='' contentStyleType='' diffuseConstant='' edgeMode='' externalResourcesRequired='' filterRes='' filterUnits='' glyphRef='' gradientTransform='' gradientUnits='' kernelMatrix='' kernelUnitLength='' keyPoints='' keySplines='' keyTimes='' lengthAdjust='' limitingConeAngle='' markerHeight='' markerUnits='' markerWidth='' maskContentUnits='' maskUnits='' numOctaves='' pathLength='' patternContentUnits='' patternTransform='' patternUnits='' pointsAtX='' pointsAtY='' pointsAtZ='' preserveAlpha='' preserveAspectRatio='' primitiveUnits='' refX='' refY='' repeatCount='' repeatDur='' requiredExtensions='' requiredFeatures='' specularConstant='' specularExponent='' spreadMethod='' startOffset='' stdDeviation='' stitchTiles='' surfaceScale='' systemLanguage='' tableValues='' targetX='' targetY='' textLength='' viewBox='' viewTarget='' xChannelSelector='' yChannelSelector='' zoomAndPan=''></svg>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       attributeName=\"\"\n|       attributeType=\"\"\n|       baseFrequency=\"\"\n|       baseProfile=\"\"\n|       calcMode=\"\"\n|       clipPathUnits=\"\"\n|       contentScriptType=\"\"\n|       contentStyleType=\"\"\n|       diffuseConstant=\"\"\n|       edgeMode=\"\"\n|       externalResourcesRequired=\"\"\n|       filterRes=\"\"\n|       filterUnits=\"\"\n|       glyphRef=\"\"\n|       gradientTransform=\"\"\n|       gradientUnits=\"\"\n|       kernelMatrix=\"\"\n|       kernelUnitLength=\"\"\n|       keyPoints=\"\"\n|       keySplines=\"\"\n|       keyTimes=\"\"\n|       lengthAdjust=\"\"\n|       limitingConeAngle=\"\"\n|       markerHeight=\"\"\n|       markerUnits=\"\"\n|       markerWidth=\"\"\n|       maskContentUnits=\"\"\n|       maskUnits=\"\"\n|       numOctaves=\"\"\n|       pathLength=\"\"\n|       patternContentUnits=\"\"\n|       patternTransform=\"\"\n|       patternUnits=\"\"\n|       pointsAtX=\"\"\n|       pointsAtY=\"\"\n|       pointsAtZ=\"\"\n|       preserveAlpha=\"\"\n|       preserveAspectRatio=\"\"\n|       primitiveUnits=\"\"\n|       refX=\"\"\n|       refY=\"\"\n|       repeatCount=\"\"\n|       repeatDur=\"\"\n|       requiredExtensions=\"\"\n|       requiredFeatures=\"\"\n|       specularConstant=\"\"\n|       specularExponent=\"\"\n|       spreadMethod=\"\"\n|       startOffset=\"\"\n|       stdDeviation=\"\"\n|       stitchTiles=\"\"\n|       surfaceScale=\"\"\n|       systemLanguage=\"\"\n|       tableValues=\"\"\n|       targetX=\"\"\n|       targetY=\"\"\n|       textLength=\"\"\n|       viewBox=\"\"\n|       viewTarget=\"\"\n|       xChannelSelector=\"\"\n|       yChannelSelector=\"\"\n|       zoomAndPan=\"\"\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test001
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><BODY><SVG ATTRIBUTENAME='' ATTRIBUTETYPE='' BASEFREQUENCY='' BASEPROFILE='' CALCMODE='' CLIPPATHUNITS='' CONTENTSCRIPTTYPE='' CONTENTSTYLETYPE='' DIFFUSECONSTANT='' EDGEMODE='' EXTERNALRESOURCESREQUIRED='' FILTERRES='' FILTERUNITS='' GLYPHREF='' GRADIENTTRANSFORM='' GRADIENTUNITS='' KERNELMATRIX='' KERNELUNITLENGTH='' KEYPOINTS='' KEYSPLINES='' KEYTIMES='' LENGTHADJUST='' LIMITINGCONEANGLE='' MARKERHEIGHT='' MARKERUNITS='' MARKERWIDTH='' MASKCONTENTUNITS='' MASKUNITS='' NUMOCTAVES='' PATHLENGTH='' PATTERNCONTENTUNITS='' PATTERNTRANSFORM='' PATTERNUNITS='' POINTSATX='' POINTSATY='' POINTSATZ='' PRESERVEALPHA='' PRESERVEASPECTRATIO='' PRIMITIVEUNITS='' REFX='' REFY='' REPEATCOUNT='' REPEATDUR='' REQUIREDEXTENSIONS='' REQUIREDFEATURES='' SPECULARCONSTANT='' SPECULAREXPONENT='' SPREADMETHOD='' STARTOFFSET='' STDDEVIATION='' STITCHTILES='' SURFACESCALE='' SYSTEMLANGUAGE='' TABLEVALUES='' TARGETX='' TARGETY='' TEXTLENGTH='' VIEWBOX='' VIEWTARGET='' XCHANNELSELECTOR='' YCHANNELSELECTOR='' ZOOMANDPAN=''></SVG>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       attributeName=\"\"\n|       attributeType=\"\"\n|       baseFrequency=\"\"\n|       baseProfile=\"\"\n|       calcMode=\"\"\n|       clipPathUnits=\"\"\n|       contentScriptType=\"\"\n|       contentStyleType=\"\"\n|       diffuseConstant=\"\"\n|       edgeMode=\"\"\n|       externalResourcesRequired=\"\"\n|       filterRes=\"\"\n|       filterUnits=\"\"\n|       glyphRef=\"\"\n|       gradientTransform=\"\"\n|       gradientUnits=\"\"\n|       kernelMatrix=\"\"\n|       kernelUnitLength=\"\"\n|       keyPoints=\"\"\n|       keySplines=\"\"\n|       keyTimes=\"\"\n|       lengthAdjust=\"\"\n|       limitingConeAngle=\"\"\n|       markerHeight=\"\"\n|       markerUnits=\"\"\n|       markerWidth=\"\"\n|       maskContentUnits=\"\"\n|       maskUnits=\"\"\n|       numOctaves=\"\"\n|       pathLength=\"\"\n|       patternContentUnits=\"\"\n|       patternTransform=\"\"\n|       patternUnits=\"\"\n|       pointsAtX=\"\"\n|       pointsAtY=\"\"\n|       pointsAtZ=\"\"\n|       preserveAlpha=\"\"\n|       preserveAspectRatio=\"\"\n|       primitiveUnits=\"\"\n|       refX=\"\"\n|       refY=\"\"\n|       repeatCount=\"\"\n|       repeatDur=\"\"\n|       requiredExtensions=\"\"\n|       requiredFeatures=\"\"\n|       specularConstant=\"\"\n|       specularExponent=\"\"\n|       spreadMethod=\"\"\n|       startOffset=\"\"\n|       stdDeviation=\"\"\n|       stitchTiles=\"\"\n|       surfaceScale=\"\"\n|       systemLanguage=\"\"\n|       tableValues=\"\"\n|       targetX=\"\"\n|       targetY=\"\"\n|       textLength=\"\"\n|       viewBox=\"\"\n|       viewTarget=\"\"\n|       xChannelSelector=\"\"\n|       yChannelSelector=\"\"\n|       zoomAndPan=\"\"\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test002
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><svg attributename='' attributetype='' basefrequency='' baseprofile='' calcmode='' clippathunits='' contentscripttype='' contentstyletype='' diffuseconstant='' edgemode='' externalresourcesrequired='' filterres='' filterunits='' glyphref='' gradienttransform='' gradientunits='' kernelmatrix='' kernelunitlength='' keypoints='' keysplines='' keytimes='' lengthadjust='' limitingconeangle='' markerheight='' markerunits='' markerwidth='' maskcontentunits='' maskunits='' numoctaves='' pathlength='' patterncontentunits='' patterntransform='' patternunits='' pointsatx='' pointsaty='' pointsatz='' preservealpha='' preserveaspectratio='' primitiveunits='' refx='' refy='' repeatcount='' repeatdur='' requiredextensions='' requiredfeatures='' specularconstant='' specularexponent='' spreadmethod='' startoffset='' stddeviation='' stitchtiles='' surfacescale='' systemlanguage='' tablevalues='' targetx='' targety='' textlength='' viewbox='' viewtarget='' xchannelselector='' ychannelselector='' zoomandpan=''></svg>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       attributeName=\"\"\n|       attributeType=\"\"\n|       baseFrequency=\"\"\n|       baseProfile=\"\"\n|       calcMode=\"\"\n|       clipPathUnits=\"\"\n|       contentScriptType=\"\"\n|       contentStyleType=\"\"\n|       diffuseConstant=\"\"\n|       edgeMode=\"\"\n|       externalResourcesRequired=\"\"\n|       filterRes=\"\"\n|       filterUnits=\"\"\n|       glyphRef=\"\"\n|       gradientTransform=\"\"\n|       gradientUnits=\"\"\n|       kernelMatrix=\"\"\n|       kernelUnitLength=\"\"\n|       keyPoints=\"\"\n|       keySplines=\"\"\n|       keyTimes=\"\"\n|       lengthAdjust=\"\"\n|       limitingConeAngle=\"\"\n|       markerHeight=\"\"\n|       markerUnits=\"\"\n|       markerWidth=\"\"\n|       maskContentUnits=\"\"\n|       maskUnits=\"\"\n|       numOctaves=\"\"\n|       pathLength=\"\"\n|       patternContentUnits=\"\"\n|       patternTransform=\"\"\n|       patternUnits=\"\"\n|       pointsAtX=\"\"\n|       pointsAtY=\"\"\n|       pointsAtZ=\"\"\n|       preserveAlpha=\"\"\n|       preserveAspectRatio=\"\"\n|       primitiveUnits=\"\"\n|       refX=\"\"\n|       refY=\"\"\n|       repeatCount=\"\"\n|       repeatDur=\"\"\n|       requiredExtensions=\"\"\n|       requiredFeatures=\"\"\n|       specularConstant=\"\"\n|       specularExponent=\"\"\n|       spreadMethod=\"\"\n|       startOffset=\"\"\n|       stdDeviation=\"\"\n|       stitchTiles=\"\"\n|       surfaceScale=\"\"\n|       systemLanguage=\"\"\n|       tableValues=\"\"\n|       targetX=\"\"\n|       targetY=\"\"\n|       textLength=\"\"\n|       viewBox=\"\"\n|       viewTarget=\"\"\n|       xChannelSelector=\"\"\n|       yChannelSelector=\"\"\n|       zoomAndPan=\"\"\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test003
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><math attributeName='' attributeType='' baseFrequency='' baseProfile='' calcMode='' clipPathUnits='' contentScriptType='' contentStyleType='' diffuseConstant='' edgeMode='' externalResourcesRequired='' filterRes='' filterUnits='' glyphRef='' gradientTransform='' gradientUnits='' kernelMatrix='' kernelUnitLength='' keyPoints='' keySplines='' keyTimes='' lengthAdjust='' limitingConeAngle='' markerHeight='' markerUnits='' markerWidth='' maskContentUnits='' maskUnits='' numOctaves='' pathLength='' patternContentUnits='' patternTransform='' patternUnits='' pointsAtX='' pointsAtY='' pointsAtZ='' preserveAlpha='' preserveAspectRatio='' primitiveUnits='' refX='' refY='' repeatCount='' repeatDur='' requiredExtensions='' requiredFeatures='' specularConstant='' specularExponent='' spreadMethod='' startOffset='' stdDeviation='' stitchTiles='' surfaceScale='' systemLanguage='' tableValues='' targetX='' targetY='' textLength='' viewBox='' viewTarget='' xChannelSelector='' yChannelSelector='' zoomAndPan=''></math>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       attributename=\"\"\n|       attributetype=\"\"\n|       basefrequency=\"\"\n|       baseprofile=\"\"\n|       calcmode=\"\"\n|       clippathunits=\"\"\n|       contentscripttype=\"\"\n|       contentstyletype=\"\"\n|       diffuseconstant=\"\"\n|       edgemode=\"\"\n|       externalresourcesrequired=\"\"\n|       filterres=\"\"\n|       filterunits=\"\"\n|       glyphref=\"\"\n|       gradienttransform=\"\"\n|       gradientunits=\"\"\n|       kernelmatrix=\"\"\n|       kernelunitlength=\"\"\n|       keypoints=\"\"\n|       keysplines=\"\"\n|       keytimes=\"\"\n|       lengthadjust=\"\"\n|       limitingconeangle=\"\"\n|       markerheight=\"\"\n|       markerunits=\"\"\n|       markerwidth=\"\"\n|       maskcontentunits=\"\"\n|       maskunits=\"\"\n|       numoctaves=\"\"\n|       pathlength=\"\"\n|       patterncontentunits=\"\"\n|       patterntransform=\"\"\n|       patternunits=\"\"\n|       pointsatx=\"\"\n|       pointsaty=\"\"\n|       pointsatz=\"\"\n|       preservealpha=\"\"\n|       preserveaspectratio=\"\"\n|       primitiveunits=\"\"\n|       refx=\"\"\n|       refy=\"\"\n|       repeatcount=\"\"\n|       repeatdur=\"\"\n|       requiredextensions=\"\"\n|       requiredfeatures=\"\"\n|       specularconstant=\"\"\n|       specularexponent=\"\"\n|       spreadmethod=\"\"\n|       startoffset=\"\"\n|       stddeviation=\"\"\n|       stitchtiles=\"\"\n|       surfacescale=\"\"\n|       systemlanguage=\"\"\n|       tablevalues=\"\"\n|       targetx=\"\"\n|       targety=\"\"\n|       textlength=\"\"\n|       viewbox=\"\"\n|       viewtarget=\"\"\n|       xchannelselector=\"\"\n|       ychannelselector=\"\"\n|       zoomandpan=\"\"\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test004
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><svg><altGlyph /><altGlyphDef /><altGlyphItem /><animateColor /><animateMotion /><animateTransform /><clipPath /><feBlend /><feColorMatrix /><feComponentTransfer /><feComposite /><feConvolveMatrix /><feDiffuseLighting /><feDisplacementMap /><feDistantLight /><feFlood /><feFuncA /><feFuncB /><feFuncG /><feFuncR /><feGaussianBlur /><feImage /><feMerge /><feMergeNode /><feMorphology /><feOffset /><fePointLight /><feSpecularLighting /><feSpotLight /><feTile /><feTurbulence /><foreignObject /><glyphRef /><linearGradient /><radialGradient /><textPath /></svg>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg altGlyph>\n|       <svg altGlyphDef>\n|       <svg altGlyphItem>\n|       <svg animateColor>\n|       <svg animateMotion>\n|       <svg animateTransform>\n|       <svg clipPath>\n|       <svg feBlend>\n|       <svg feColorMatrix>\n|       <svg feComponentTransfer>\n|       <svg feComposite>\n|       <svg feConvolveMatrix>\n|       <svg feDiffuseLighting>\n|       <svg feDisplacementMap>\n|       <svg feDistantLight>\n|       <svg feFlood>\n|       <svg feFuncA>\n|       <svg feFuncB>\n|       <svg feFuncG>\n|       <svg feFuncR>\n|       <svg feGaussianBlur>\n|       <svg feImage>\n|       <svg feMerge>\n|       <svg feMergeNode>\n|       <svg feMorphology>\n|       <svg feOffset>\n|       <svg fePointLight>\n|       <svg feSpecularLighting>\n|       <svg feSpotLight>\n|       <svg feTile>\n|       <svg feTurbulence>\n|       <svg foreignObject>\n|       <svg glyphRef>\n|       <svg linearGradient>\n|       <svg radialGradient>\n|       <svg textPath>\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test005
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><svg><altglyph /><altglyphdef /><altglyphitem /><animatecolor /><animatemotion /><animatetransform /><clippath /><feblend /><fecolormatrix /><fecomponenttransfer /><fecomposite /><feconvolvematrix /><fediffuselighting /><fedisplacementmap /><fedistantlight /><feflood /><fefunca /><fefuncb /><fefuncg /><fefuncr /><fegaussianblur /><feimage /><femerge /><femergenode /><femorphology /><feoffset /><fepointlight /><fespecularlighting /><fespotlight /><fetile /><feturbulence /><foreignobject /><glyphref /><lineargradient /><radialgradient /><textpath /></svg>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg altGlyph>\n|       <svg altGlyphDef>\n|       <svg altGlyphItem>\n|       <svg animateColor>\n|       <svg animateMotion>\n|       <svg animateTransform>\n|       <svg clipPath>\n|       <svg feBlend>\n|       <svg feColorMatrix>\n|       <svg feComponentTransfer>\n|       <svg feComposite>\n|       <svg feConvolveMatrix>\n|       <svg feDiffuseLighting>\n|       <svg feDisplacementMap>\n|       <svg feDistantLight>\n|       <svg feFlood>\n|       <svg feFuncA>\n|       <svg feFuncB>\n|       <svg feFuncG>\n|       <svg feFuncR>\n|       <svg feGaussianBlur>\n|       <svg feImage>\n|       <svg feMerge>\n|       <svg feMergeNode>\n|       <svg feMorphology>\n|       <svg feOffset>\n|       <svg fePointLight>\n|       <svg feSpecularLighting>\n|       <svg feSpotLight>\n|       <svg feTile>\n|       <svg feTurbulence>\n|       <svg foreignObject>\n|       <svg glyphRef>\n|       <svg linearGradient>\n|       <svg radialGradient>\n|       <svg textPath>\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test006
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><BODY><SVG><ALTGLYPH /><ALTGLYPHDEF /><ALTGLYPHITEM /><ANIMATECOLOR /><ANIMATEMOTION /><ANIMATETRANSFORM /><CLIPPATH /><FEBLEND /><FECOLORMATRIX /><FECOMPONENTTRANSFER /><FECOMPOSITE /><FECONVOLVEMATRIX /><FEDIFFUSELIGHTING /><FEDISPLACEMENTMAP /><FEDISTANTLIGHT /><FEFLOOD /><FEFUNCA /><FEFUNCB /><FEFUNCG /><FEFUNCR /><FEGAUSSIANBLUR /><FEIMAGE /><FEMERGE /><FEMERGENODE /><FEMORPHOLOGY /><FEOFFSET /><FEPOINTLIGHT /><FESPECULARLIGHTING /><FESPOTLIGHT /><FETILE /><FETURBULENCE /><FOREIGNOBJECT /><GLYPHREF /><LINEARGRADIENT /><RADIALGRADIENT /><TEXTPATH /></SVG>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg altGlyph>\n|       <svg altGlyphDef>\n|       <svg altGlyphItem>\n|       <svg animateColor>\n|       <svg animateMotion>\n|       <svg animateTransform>\n|       <svg clipPath>\n|       <svg feBlend>\n|       <svg feColorMatrix>\n|       <svg feComponentTransfer>\n|       <svg feComposite>\n|       <svg feConvolveMatrix>\n|       <svg feDiffuseLighting>\n|       <svg feDisplacementMap>\n|       <svg feDistantLight>\n|       <svg feFlood>\n|       <svg feFuncA>\n|       <svg feFuncB>\n|       <svg feFuncG>\n|       <svg feFuncR>\n|       <svg feGaussianBlur>\n|       <svg feImage>\n|       <svg feMerge>\n|       <svg feMergeNode>\n|       <svg feMorphology>\n|       <svg feOffset>\n|       <svg fePointLight>\n|       <svg feSpecularLighting>\n|       <svg feSpotLight>\n|       <svg feTile>\n|       <svg feTurbulence>\n|       <svg foreignObject>\n|       <svg glyphRef>\n|       <svg linearGradient>\n|       <svg radialGradient>\n|       <svg textPath>\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test007
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><math><altGlyph /><altGlyphDef /><altGlyphItem /><animateColor /><animateMotion /><animateTransform /><clipPath /><feBlend /><feColorMatrix /><feComponentTransfer /><feComposite /><feConvolveMatrix /><feDiffuseLighting /><feDisplacementMap /><feDistantLight /><feFlood /><feFuncA /><feFuncB /><feFuncG /><feFuncR /><feGaussianBlur /><feImage /><feMerge /><feMergeNode /><feMorphology /><feOffset /><fePointLight /><feSpecularLighting /><feSpotLight /><feTile /><feTurbulence /><foreignObject /><glyphRef /><linearGradient /><radialGradient /><textPath /></math>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math altglyph>\n|       <math altglyphdef>\n|       <math altglyphitem>\n|       <math animatecolor>\n|       <math animatemotion>\n|       <math animatetransform>\n|       <math clippath>\n|       <math feblend>\n|       <math fecolormatrix>\n|       <math fecomponenttransfer>\n|       <math fecomposite>\n|       <math feconvolvematrix>\n|       <math fediffuselighting>\n|       <math fedisplacementmap>\n|       <math fedistantlight>\n|       <math feflood>\n|       <math fefunca>\n|       <math fefuncb>\n|       <math fefuncg>\n|       <math fefuncr>\n|       <math fegaussianblur>\n|       <math feimage>\n|       <math femerge>\n|       <math femergenode>\n|       <math femorphology>\n|       <math feoffset>\n|       <math fepointlight>\n|       <math fespecularlighting>\n|       <math fespotlight>\n|       <math fetile>\n|       <math feturbulence>\n|       <math foreignobject>\n|       <math glyphref>\n|       <math lineargradient>\n|       <math radialgradient>\n|       <math textpath>\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

- (void)test008
{
    HTMLParser *parser = [[HTMLParser alloc] initWithString:@"<!DOCTYPE html><body><svg><solidColor /></svg>" context:nil];
    NSArray *fixture = ReifiedTreeForTestDocument(@"| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg solidcolor>\n");
    STAssertTrue(parser.errors.count == 0 && [parser.document.childNodes isEqual:fixture], nil);
}

@end