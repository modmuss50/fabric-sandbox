import WinSDK
import WindowsUtils
import WinSDKExtras

public class WinSockInit {
  public init() throws {
      let version = makeWord(2, 2)

      var data = WSADATA()
      let result = WSAStartup(version, &data)
      guard result == 0 else {
          throw WinSockError("WSAStartup", errorCode: result)
      }

      guard data.wVersion == version else {
          throw WinSockError("WSAStartup: Unsupported version")
      }
  }

  deinit {
      WSACleanup()
  }
}

public struct WinSockError: Error {
  let message: String
  let errorCode: Int32

  public init(_ message: String, errorCode: Int32 = WSAGetLastError()) {
      self.message = message
      self.errorCode = errorCode
  }

  var errorDescription: String? {
      return "\(message): \(errorCode)"
  }
}

fileprivate func makeWord(_ low: UInt8, _ high: UInt8) -> UInt16 {
    return UInt16(low) | UInt16(high) << 8
}