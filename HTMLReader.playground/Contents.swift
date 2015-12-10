//: HTMLReader – A WHATWG-compliant HTML parser
import HTMLReader
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

let homepage = "https://github.com/nolanw/HTMLReader"
NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: homepage)!) {
    (data, response, error) in
    var contentType: String? = nil
    if let response = response as? NSHTTPURLResponse {
        contentType = response.allHeaderFields["Content-Type"] as? String
    }
    if let data = data {
        let home = HTMLDocument(data: data, contentTypeHeader:contentType)
        if let div = home.firstNodeMatchingSelector(".repository-meta-content") {
            let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
            print(div.textContent.stringByTrimmingCharactersInSet(whitespace))
        } else {
            print("Failed to match .repository-meta-content, maybe the HTML changed?")
        }
    } else {
        print("No data received, sorry.")
    }
    XCPlaygroundPage.finishExecution(XCPlaygroundPage.currentPage)
}.resume()
