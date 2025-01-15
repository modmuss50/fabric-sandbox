import Testing
import WindowsUtils

struct HidDeviceTests {
    @Test func getHidDevices() throws {
        let devices = try HidDevice.getAllDevices()
        for device in devices {
            print("Device: \(device.devicePath)")
            print("\tManufacturer: \(try device.getManufacturer())")
            print("\tProduct: \(try device.getProduct())")
            print("\tSecuirty: \(try getStringSecurityDescriptor(device))")
        }
    }
}