// TODO remove this file, this is just a test application
let winsock = try! WinSockInit()
defer {
    // Ensure that WinSock is cleaned up when the program exits
    let _ = winsock
}

let httpServer = try! HTTPServer(port: 8080)

// Wait for any key input before exiting

print("Press any key to exit...")
_ = readLine()