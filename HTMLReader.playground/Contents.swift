//: HTMLReader – A WHATWG-compliant HTML parser

import HTMLReader
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely()

let homepage = "https://github.com/nolanw/HTMLReader"
NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: homepage)!) { (data, response, error) in
    var contentType: String? = nil
    if let response = response as? NSHTTPURLResponse {
        contentType = response.allHeaderFields["Content-Type"] as? String
    }
    let home = HTMLDocument(data: data, contentTypeHeader:contentType)
    let div = home.firstNodeMatchingSelector(".repository-description")
    let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
    println(div.textContent.stringByTrimmingCharactersInSet(whitespace))
}.resume()
