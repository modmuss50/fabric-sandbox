@_spi(Experimental) import Testing
import WinSDK

@testable import WindowsUtils

@Suite(.serial) struct UserGroupTests {
  @Test func testUserGroup() throws {
    let group = try UserGroup.getOrCreateGroup(name: "FabricSandboxTestGroup", description: "Test Group")
    let sid = try group.getSid()
    try group.deleteGroup()
  }
}
