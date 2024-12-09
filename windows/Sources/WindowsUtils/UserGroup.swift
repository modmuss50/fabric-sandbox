import WinSDK

public class UserGroup {
    public let name: String

    private init(name: String) {
        self.name = name
    }

    public static func getOrCreateGroup(name: String, description: String) throws -> UserGroup {
        let group = try getGroup(name: name)
        if let group = group {
            return group
        }
        return try createGroup(name: name, description: description)
    }

    public func deleteGroup() throws {
        try name.withCString(encodedAs: UTF16.self) { name in
            let result = NetLocalGroupDel(nil, name)
            guard result == NERR_Success else {
                throw Win32Error("NetLocalGroupDel")
            }
        }
    }

    public func getSid() throws -> Sid {
        var sid: PSID?
        var sidSize: DWORD = 0
        let result = LookupAccountNameW(nil, name.wide, &sid, &sidSize, nil, nil, nil)
        guard !result, let sid = sid else {
            throw Win32Error("LookupAccountNameW")
        }
        return Sid(sid)
    }

    public static func getGroup(name: String) throws -> UserGroup? {
        var groupInfo: LPBYTE?
        let result = NetLocalGroupGetInfo(nil, name.wide, 1, &groupInfo)
        guard result == NERR_Success else {
            return nil
        }
        return UserGroup(name: name)
    }

    public static func createGroup(name: String, description: String) throws -> UserGroup {
        try name.withCString(encodedAs: UTF16.self) { name in
            try description.withCString(encodedAs: UTF16.self) { description in
                var groupInfo: LOCALGROUP_INFO_1 = LOCALGROUP_INFO_1(lgrpi1_name: UnsafeMutablePointer(mutating: name), lgrpi1_comment: UnsafeMutablePointer(mutating: description))
                let result = NetLocalGroupAdd(nil, 1, &groupInfo, nil)
                guard result == NERR_Success else {
                    throw Win32Error("NetLocalGroupAdd", errorCode: result)
                }
            }
        }

        return UserGroup(name: name)
    }
}