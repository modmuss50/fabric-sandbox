import Testing
import AuthProxy

struct HttpServerTests {
    @Test func get() throws {
        let winsock = try WinSockInit()
        defer {
            let _ = winsock
        }

        let httpServer = try HTTPServer(port: 8080)
        defer {
            let _ = httpServer
        }
        let httpClient = try HTTPClient()

        let response = try httpClient.get("http://localhost:8080")
        #expect(response == "Hello World!")
    }
}