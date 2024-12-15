import WinSDK
import WinSDKExtras
import WindowsUtils

// TODO WinHttpOpenRequest
public class HTTPClient {
    private let internet: HINTERNET

    public init (userAgent: String = "FabricSandbox/AuthProxy") throws {
        let internet = InternetOpenW(userAgent.wide, DWORD(INTERNET_OPEN_TYPE_DIRECT), nil, nil, 0)
        guard let internetHandle = internet else {
            throw Win32Error("InternetOpenW")
        }
        self.internet = internetHandle
    }

    deinit {
        InternetCloseHandle(internet)
    }

    public func get(_ url: String) throws -> String {
        let flags = DWORD(INTERNET_FLAG_RELOAD) | DWORD(INTERNET_FLAG_PRAGMA_NOCACHE) | DWORD(INTERNET_FLAG_NO_CACHE_WRITE) | DWORD(INTERNET_FLAG_SECURE)
        let connection = InternetOpenUrlW(internet, url.wide, nil, 0, flags, 0)
        guard let connectionHandle = connection else {
            throw InternetError("InternetOpenUrlW")
        }
        defer {
            InternetCloseHandle(connectionHandle)
        }

        var buffer = [CChar](repeating: 0, count: 4096)
        var bytesRead: DWORD = 0

        while true {
            let result = buffer.withUnsafeMutableBufferPointer {
                InternetReadFile(connection, $0.baseAddress, DWORD($0.count), &bytesRead)
            }
            guard result else {
                throw InternetError("InternetReadFile")
            }
            if bytesRead == 0 {
                break
            }
        }

        return String(cString: buffer)
    }
}

// https://learn.microsoft.com/en-us/windows/win32/wininet/wininet-errors
fileprivate func InternetError(_ message: String) -> Win32Error {
    // Make sure to note down the error code before calling GetLastResponseInfo
    let errrorCode = GetLastError()

    let lastResponseInfo = GetLastResponseInfo()
    var fullMessage = message
    if let lastResponseInfo = lastResponseInfo {
        fullMessage += ": \(lastResponseInfo)"
    }
    return Win32Error(fullMessage, errorCode: errrorCode)
}

fileprivate func GetLastResponseInfo() -> String? {
    var errorCode = DWORD(0)
    var bufferLength = DWORD(0)

    InternetGetLastResponseInfoW(&errorCode, nil, &bufferLength)
    guard bufferLength > 0 else {
        print("hummm")
        return nil
    }

    var buffer = [WCHAR](repeating: 0, count: Int(bufferLength))
    let result = buffer.withUnsafeMutableBufferPointer { bufferPointer in
        InternetGetLastResponseInfoW(&errorCode, bufferPointer.baseAddress, &bufferLength)
    }
    guard result else {
        print("InternetGetLastResponseInfoW failed")
        return nil
    }
    return String(decodingCString: buffer, as: UTF16.self)
}