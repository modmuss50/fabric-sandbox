// A wrapper around the functions in WinSDKExtras as sourcekit-lsp doesn't support indexing c++ modules.

import WinSDK
import WinSDKExtras

public func CreateAppContainerProfile(
    _ pszAppContainerName: PCWSTR,
    _ pszDisplayName: PCWSTR,
    _ pszDescription: PCWSTR,
    _ pCapabilities: PSID_AND_ATTRIBUTES?,
    _ dwCapabilityCount: DWORD,
    _ ppSidAppContainerSid: UnsafeMutablePointer<PSID?>?
) -> HRESULT {
    return _CreateAppContainerProfile(pszAppContainerName, pszDisplayName, pszDescription, pCapabilities, dwCapabilityCount, ppSidAppContainerSid)
}

public func DeleteAppContainerProfile(_ pszAppContainerName: PCWSTR) -> HRESULT {
    return _DeleteAppContainerProfile(pszAppContainerName)
}

public func DeriveAppContainerSidFromAppContainerName(_ pszAppContainerName: PCWSTR, _ ppSidAppContainerSid: UnsafeMutablePointer<PSID?>?) -> HRESULT {
    return _DeriveAppContainerSidFromAppContainerName(pszAppContainerName, ppSidAppContainerSid)
}

public func DeriveCapabilitySidsFromName(
    _ CapName: LPCWSTR,
    _ CapabilityGroupSids: UnsafeMutablePointer<UnsafeMutablePointer<PSID?>?>?,
    _ CapabilityGroupSidCount: UnsafeMutablePointer<DWORD>?,
    _ CapabilitySids: UnsafeMutablePointer<UnsafeMutablePointer<PSID?>?>?,
    _ CapabilitySidCount: UnsafeMutablePointer<DWORD>?
) -> Bool {
    return _DeriveCapabilitySidsFromName(CapName, CapabilityGroupSids, CapabilityGroupSidCount, CapabilitySids, CapabilitySidCount)
}

public func PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES() -> DWORD {
    return _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES()
}

public func PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY() -> DWORD {
    return _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY()
}

public func MAKELANGID(_ p: WORD, _ s: WORD) -> DWORD {
    return _MAKELANGID(p, s)
}

public func SECURITY_MAX_SID_SIZE() -> DWORD {
    return _SECURITY_MAX_SID_SIZE()
}

public func CASTSID(_ pSid: PSID) -> LPWCH {
    return _CASTSID(pSid)
}

public func allocateAttributeList(_ dwAttributeCount: size_t) -> LPPROC_THREAD_ATTRIBUTE_LIST {
    return _allocateAttributeList(dwAttributeCount)
}

public func IsWindows10OrGreater() -> Bool {
    return _IsWindows10OrGreater()
}

public func Win32FromHResult(_ hr: HRESULT) -> DWORD {
    return _Win32FromHResult(hr)
}

public func SidFromAccessAllowedAce(_ ace: LPVOID, _ sidStart: DWORD) -> PSID {
    return _SidFromAccessAllowedAce(ace, sidStart)
}

public func SidFromAccessDeniedAce(_ ace: LPVOID, _ sidStart: DWORD) -> PSID {
    return _SidFromAccessDeniedAce(ace, sidStart)
}