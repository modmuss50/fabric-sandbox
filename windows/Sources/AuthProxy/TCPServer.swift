import WinSDK
import WindowsUtils
import ucrt

// https://github.com/swiftlang/swift-corelibs-foundation/blob/4c3228c00a17aca68d1a83d35dbd156a8aa169ee/Tests/Foundation/HTTPServer.swift#L153
public class TCPServer: Thread {
    let tcpHandler: TCPHandler

    let listenSocket: SOCKET
    let socketAddress: UnsafeMutablePointer<sockaddr_in>

    private var stopping = false
    private var clients = [TCPClientThread]()

    public init(tcpHandler: TCPHandler, port: UInt16) throws {
        var sa = sockaddr_in()
        sa.sin_family = ADDRESS_FAMILY(AF_INET)
        sa.sin_addr = IN_ADDR(S_un: in_addr.__Unnamed_union_S_un(S_addr: UInt32(INADDR_LOOPBACK).bigEndian)) // Only accept connections from localhost
        sa.sin_port = UInt16(bigEndian: port)

        let socketAddress = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1) 
        socketAddress.initialize(to: sa)

        let socket = WSASocketW(AF_INET, SOCK_STREAM, IPPROTO_TCP.rawValue, nil, 0, DWORD(WSA_FLAG_OVERLAPPED))
        guard socket != INVALID_SOCKET else {
            throw WinSockError("WSASocketW")
        }

        var value: Int8 = 1
        let result = setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &value, Int32(MemoryLayout.size(ofValue: value)))
        guard result == 0 else {
            throw WinSockError("setsockopt")
        }

        try socketAddress.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) { 
            let addr = UnsafePointer<sockaddr>($0)
            var result = bind(socket, addr, socklen_t(MemoryLayout<sockaddr>.size))
            guard result == 0 else {
                throw WinSockError("bind")
            }

            result = listen(socket, SOMAXCONN)
            guard result == 0 else {
                throw WinSockError("listen")
            }
        }

        self.tcpHandler = tcpHandler
        self.listenSocket = socket
        self.socketAddress = socketAddress

        try super.init()
        start()
    }

    deinit {
        stopping = true
        clients.removeAll()
        closesocket(listenSocket)
        join()
    }

    open override func run() {
        while !stopping {
            do {
                let clientSocket = try acceptConnection()
                let client = try TCPClientThread(tcpHandler: tcpHandler, socket: clientSocket)
                clients.append(client)
            } catch {
                print("Error accepting connection: \(error)")
            }
        }
    }

    private func acceptConnection() throws -> SOCKET {
        let socket = self.socketAddress.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
            let addr = UnsafeMutablePointer<sockaddr>($0)
            var sockLen = socklen_t(MemoryLayout<sockaddr>.size)
            return WSAAccept(listenSocket, addr, &sockLen, nil, 0)
        }
        guard socket != INVALID_SOCKET else {
            throw WinSockError("WSAAccept")
        }

        return socket
    }
}

private class TCPClientThread: Thread {
    let tcpHandler: TCPHandler
    let socket: SOCKET

    private var stopping = false

    init(tcpHandler: TCPHandler, socket: SOCKET) throws {
        self.tcpHandler = tcpHandler
        self.socket = socket

        try super.init()
        start()
    }

    deinit {
        stopping = true
        closesocket(socket)
        join()
    }

    open override func run() {
        while !stopping {
            do {
                let data = try readData()

                guard let data = data else {
                    return
                }

                if let response = tcpHandler.handle(data) {
                    try writeData(response)
                } else {
                    return
                }
            } catch {
                print("Error reading data: \(error)")
            }
        }
    }
    
    // Returns nil when the connection was closed
    private func readData() throws -> [UInt8]? {
        var buffer = [CChar](repeating: 0, count: 4096)
        var bytesRead: DWORD = 0
        let result = buffer.withUnsafeMutableBufferPointer {
            var wsaBuffer: WSABUF = WSABUF(len: ULONG($0.count), buf: $0.baseAddress)
            var flags: DWORD = 0
            return WSARecv(self.socket, &wsaBuffer, 1, &bytesRead, &flags, nil, nil)
        }

        let lastError = WSAGetLastError()
        if lastError == WSA_OPERATION_ABORTED || lastError == WSAECONNABORTED {
            return nil
        }

        guard result == 0 else {
            throw WinSockError("WSARecv")
        }
        return buffer.map { UInt8(bitPattern: $0) }
    }

    private func writeData(_ data: [UInt8]) throws {
        let result = data.withUnsafeBytes {
            var bytesSent: DWORD = 0
            var wsaBuffer: WSABUF = WSABUF(len: ULONG(data.count), buf: UnsafeMutablePointer<CHAR>(mutating: $0.bindMemory(to: CHAR.self).baseAddress))
            return WSASend(self.socket, &wsaBuffer, 1, &bytesSent, 0, nil, nil)
        }
        guard result != SOCKET_ERROR else {
            throw WinSockError("WSASend")
        }
    }
}

public protocol TCPHandler {
    // Return nil to close the connection
    func handle(_ data: [UInt8]) -> [UInt8]?
}