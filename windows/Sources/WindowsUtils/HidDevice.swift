import WinSDK
import WinSDKExtras

fileprivate let BUFFER_SIZE = 128

public class HidDevice {
    public let devicePath: String
    let handle: HANDLE

    init(_ devicePath: String) throws {
        let handle = CreateFileW(devicePath.wide, GENERIC_READ, DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE), nil, DWORD(OPEN_EXISTING), 0, nil)

        guard handle != INVALID_HANDLE_VALUE, let handle = handle else {
            throw Win32Error("CreateFileW(\(devicePath))")
        }

        self.devicePath = devicePath
        self.handle = handle
    }

    deinit {
        CloseHandle(handle)
    }

    public func getManufacturer() throws -> String {
        return try getHidString(HidD_GetManufacturerString, name: "HidD_GetManufacturerString")
    }

    public func getProduct() throws -> String {
        return try getHidString(HidD_GetProductString, name: "HidD_GetProductString")
    }

    public static func getAllDevices() throws -> [HidDevice] {
        var count: UINT = 0

        while true {
            let result = GetRawInputDeviceList(nil, &count, UINT(MemoryLayout<RAWINPUTDEVICELIST>.size))
            guard result == 0 else {
                throw Win32Error("GetRawInputDeviceList")
            }

            guard count > 0 else {
                // We successfully got the count of devices, but there are none
                break
            }

            let devices = UnsafeMutablePointer<RAWINPUTDEVICELIST>.allocate(capacity: Int(count))
            defer { devices.deallocate() }
            count = GetRawInputDeviceList(devices, &count, UINT(MemoryLayout<RAWINPUTDEVICELIST>.size))
            guard Int(count) != -1 else {
                if GetLastError() == ERROR_INSUFFICIENT_BUFFER {
                    // This can happen if a device was added or removed between the two calls
                    continue
                }

                throw Win32Error("GetRawInputDeviceList")
            }

            return try (0..<Int(count)).compactMap {
                let name = try getDeviceName(devices[$0].hDevice)
                // Ingore errors as it seems that its quite commont that some devices do not grant access
                return try? HidDevice(name)
            }
        }

        return []
    }

    fileprivate func getHidString(_ function: (HANDLE?, PVOID?, ULONG) -> BOOLEAN, name: String) throws -> String {
        var buffer = [UInt16](repeating: 0, count: BUFFER_SIZE)
        let result = function(handle, &buffer, UInt32(buffer.count * MemoryLayout<UInt16>.size))
        guard result == 1 else {
            throw Win32Error(name)
        }
        return String(decodingCString: buffer, as: UTF16.self)
    }

    fileprivate static func getDeviceName(_ deviceHandle: HANDLE) throws -> String {
        var buffer = [UInt16](repeating: 0, count: Int(MAX_PATH))
        var size = DWORD(buffer.count * MemoryLayout<UInt16>.size)
        let result = GetRawInputDeviceInfoW(deviceHandle, UINT(RIDI_DEVICENAME), &buffer, &size)
        guard result > 0 else {
            throw Win32Error("GetRawInputDeviceInfoW")
        }
        return String(decodingCString: buffer, as: UTF16.self)
    }
}