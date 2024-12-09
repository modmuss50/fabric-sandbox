import WinSDK
import WindowsUtils
import Logging

let SANDBOX_USER_GROUP = "FabricSandboxUsers"

let logger = Logger(label: "net.fabricmc.sandbox.setup")

logger.info("Fabric Sandbox Setup")

guard IsUserAnAdmin() else {
    setupError("This program must be run as an administrator")
}

do {
    try setup()
} catch {
    setupError("Failed to setup Fabric Sandbox: \(error)")
}

MessageBoxW(nil, "Done".wide, "Fabric Sandbox Setup".wide, UINT(MB_OK | MB_ICONINFORMATION))

func setup() throws {
    let group = try UserGroup.getGroup(name: SANDBOX_USER_GROUP)

    if group == nil {
        logger.info("Creating group \(SANDBOX_USER_GROUP)")
        do {
            let group = try UserGroup.createGroup(name: SANDBOX_USER_GROUP, description: "Fabric Sandbox Users")
            logger.info("Created group \(group.name)")
        } catch {
            setupError("Failed to create group \(SANDBOX_USER_GROUP): \(error)")
        }
    } else {
        logger.info("Group \(SANDBOX_USER_GROUP) already exists")
    }
}

func setupError(_ message: String) -> Never {
    logger.error("\(message)")
    MessageBoxW(nil, message.wide, "Fabric Sandbox Setup".wide, UINT(MB_OK | MB_ICONERROR))
    fatalError(message)
}