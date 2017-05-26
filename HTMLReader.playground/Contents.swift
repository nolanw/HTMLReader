//: HTMLReader – A WHATWG-compliant HTML parser
import HTMLReader
import PlaygroundSupport

let homepage = "https://github.com/nolanw/HTMLReader"

URLSession.shared.dataTask(with: URL(string: homepage)!) { (data, response, error) in
    defer { PlaygroundPage.finishExecution(PlaygroundPage.current) }
    
    
    var contentType: String? = nil
    if let response = response as? HTTPURLResponse {
        contentType = response.allHeaderFields["Content-Type"] as? String
    }
    
    guard let data = data else {
        print("No data received, sorry.")
        return
    }
    
    let home = HTMLDocument(data: data, contentTypeHeader:contentType)
    
    guard let div = home.firstNode(matchingSelector: ".repository-meta-content") else {
        print("Failed to match .repository-meta-content, maybe the HTML changed?")
        return
    }
    
    print(div.textContent.trimmingCharacters(in: .whitespacesAndNewlines))

    PlaygroundPage.current.finishExecution()
}.resume()

PlaygroundPage.current.needsIndefiniteExecution = true
