public class HTTPServer {
    fileprivate let httpReqHandler: HTTPRequestHandler
    let tcpServer: TCPServer

    public init(port: UInt16) throws {
        let httpReqHandler = HTTPRequestHandler()
        let tcpServer = try TCPServer(tcpHandler: httpReqHandler, port: port)
        
        self.httpReqHandler = httpReqHandler
        self.tcpServer = tcpServer
    }
}

private class HTTPRequestHandler: TCPHandler {
    public func handle(_ data: [UInt8]) -> [UInt8]? {
        let request = String(decodingCString: data, as: UTF8.self)
        let httpRequest = HTTPRequestHandler.parseRequest(request)
        let httpResponse = handleHttpRequest(httpRequest)
        return HTTPRequestHandler.encodeResponse(httpResponse)
    }

    private func handleHttpRequest(_ request: HttpRequest) -> HttpResponse {
        let str = "Hello World!"
        return HttpResponse(statusCode: 200, content: Array(str.utf8))
    }

    private static func parseRequest(_ request: String) -> HttpRequest {
        // TODO write this code
        return HttpRequest(method: .GET, path: "/", headers: [:], content: [])
    }

    private static func encodeResponse(_ response: HttpResponse) -> [UInt8] {
        let buffer = ByteBuffer()
        buffer.appendLine("HTTP/1.1 \(response.statusCode) OK")
        buffer.appendLine("Content-Length: \(response.content.count)")
        // UTF-8 encoding is assumed
        buffer.appendLine("Content-Type: text/plain; charset=utf-8")
        for (key, value) in response.headers {
            buffer.appendLine("\(key): \(value)")
        }
        buffer.appendLine("")
        buffer.data.append(contentsOf: response.content)
        return buffer.data
    }
}

private struct HttpRequest {
    let method: HttpMethod
    let path: String
    let headers: [String: String]
    let content: [UInt8]

    init(method: HttpMethod, path: String, headers: [String: String], content: [UInt8]) {
        self.method = method
        self.path = path
        self.headers = headers
        self.content = content
    }
}

private struct HttpResponse {
    let statusCode: Int
    let headers: [String: String]
    let content: [UInt8]

    init(statusCode: Int, headers: [String: String] = [:], content: [UInt8] = []) {
        self.statusCode = statusCode
        self.headers = headers
        self.content = content
    }
}

private enum HttpMethod {
    case GET
    case POST
    case PUT
    case DELETE
}

private class ByteBuffer {
    var data: [UInt8]

    init() {
        data = []
    }

    func append<S: Sequence>(_ sequence: S) where S.Element == UInt8 {
        data.append(contentsOf: sequence)
    }

    func appendLine(_ str: String) {
        append(str.utf8)
        append("\r\n".utf8)
    }
}