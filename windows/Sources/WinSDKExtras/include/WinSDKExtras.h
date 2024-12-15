#pragma once

#include <windows.h>
#include <sddl.h>

// Provide some additional definitions that are not available by default in WinSDK
#include <wininet.h>

// userenv.h
HRESULT _CreateAppContainerProfile(
    _In_ PCWSTR pszAppContainerName,
    _In_ PCWSTR pszDisplayName,
    _In_ PCWSTR pszDescription,
    _In_ PSID_AND_ATTRIBUTES pCapabilities,
    _In_  DWORD dwCapabilityCount,
    _Outptr_ PSID* ppSidAppContainerSid);

HRESULT _DeleteAppContainerProfile(
    _In_ PCWSTR pszAppContainerName);

HRESULT _DeriveAppContainerSidFromAppContainerName(
    _In_ PCWSTR pszAppContainerName,
    _Outptr_ PSID* ppSidAppContainerSid);

BOOL _DeriveCapabilitySidsFromName(
  _In_  LPCWSTR CapName,
  _Outptr_ PSID    **CapabilityGroupSids,
  _Outptr_ DWORD   *CapabilityGroupSidCount,
  _Outptr_ PSID    **CapabilitySids,
  _Outptr_ DWORD   *CapabilitySidCount
);

DWORD _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES();

DWORD _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY();

DWORD _MAKELANGID(WORD p, WORD s);

DWORD _SECURITY_MAX_SID_SIZE();

// TODO - again how to do this nicely in swift
LPPROC_THREAD_ATTRIBUTE_LIST allocateAttributeList(size_t dwAttributeCount);

BOOL _IsWindows10OrGreater();

DWORD Win32FromHResult(HRESULT hr);

PSID SidFromAccessAllowedAce(LPVOID ace, DWORD sidStart);

PSID SidFromAccessDeniedAce(LPVOID ace, DWORD sidStart);