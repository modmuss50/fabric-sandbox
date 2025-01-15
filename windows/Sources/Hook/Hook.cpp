#include "Runtime-Swift.h"

#include <windows.h>
#include <Detours.h>
#include <string>
#include <stdexcept>
#include <sapi.h>
#include <AtlBase.h>
#include <AtlConv.h>
#include <AtlCom.h>
#include <map>

using namespace std::string_literals;

#define VTABLE_INDEX_SPEAK 20
#define VTABLE_INDEX_SKIP 23

#define HOOK(NAME, RETURN_TYPE, ARGS) \
    RETURN_TYPE WINAPI NAME##Patch ARGS; \
    static RETURN_TYPE (WINAPI* True##NAME)ARGS = NAME; \
    RETURN_TYPE WINAPI NAME##Patch ARGS

#define DETOUR(NAME) \
    if (dwReason == DLL_PROCESS_ATTACH) { DetourAttach(&(PVOID&)True##NAME, (PVOID)NAME##Patch); } else { DetourDetach(&(PVOID&)True##NAME, (PVOID)NAME##Patch); }

#define DETOUR_VTABLE(PATCH_FUNC, VTABLE) \
    if (dwReason == DLL_PROCESS_ATTACH) { DetourAttach(&(PVOID&) VTABLE, (PVOID) PATCH_FUNC); } else { DetourDetach(&(PVOID&) VTABLE, (PVOID) PATCH_FUNC); }

// Workaround for GetVolumeInformationW not working in a UWP application
// This is by creating a handle to a file on the drive and then using GetVolumeInformationByHandleW with that handle
HOOK(GetVolumeInformationW, BOOL, (LPCWSTR lpRootPathName, LPWSTR lpVolumeNameBuffer, DWORD nVolumeNameSize, LPDWORD lpVolumeSerialNumber, LPDWORD lpMaximumComponentLength, LPDWORD lpFileSystemFlags, LPWSTR lpFileSystemNameBuffer, DWORD nFileSystemNameSize)) {
    BOOL result = TrueGetVolumeInformationW(
            lpRootPathName,
            lpVolumeNameBuffer,
            nVolumeNameSize,
            lpVolumeSerialNumber,
            lpMaximumComponentLength,
            lpFileSystemFlags,
            lpFileSystemNameBuffer,
            nFileSystemNameSize);
    auto originalError = GetLastError();
    if (originalError != ERROR_DIR_NOT_ROOT && originalError != ERROR_ACCESS_DENIED) {
        // Only apply our workaround if the error is ERROR_DIR_NOT_ROOT or ERROR_ACCESS_DENIED
        return result;
    }

    std::wstring fileName;

    if (lpRootPathName == nullptr || lpRootPathName[0] == L'\0') {
        // If the root path is null or empty, use the current directory
        fileName = L".";
    } else {
        // Otherwise, use the root path
        fileName = lpRootPathName;
    }

    fileName += L"\\.fabricSandbox";

    auto hFile = CreateFileW(fileName.c_str(), 0, FILE_SHARE_READ, nullptr, OPEN_ALWAYS, 0, nullptr);
    if (hFile == INVALID_HANDLE_VALUE) {
        // Reset the last error to the original error
        SetLastError(originalError);
        return result;
    }

    // Call GetVolumeInformationByHandleW with the handle to the file
    result = GetVolumeInformationByHandleW(
        hFile,
        lpVolumeNameBuffer,
        nVolumeNameSize,
        lpVolumeSerialNumber,
        lpMaximumComponentLength,
        lpFileSystemFlags,
        lpFileSystemNameBuffer, 
        nFileSystemNameSize);

    CloseHandle(hFile);

    if (!result) {
        // If GetVolumeInformationByHandleW fails, reset the last error to the original error
        SetLastError(originalError);
    }

    return result;
}

// Forward ClipCursor and SetCursorPos, to the parnet process as these functions are not available in UWP
HOOK(ClipCursor, BOOL, (const RECT* lpRect)) {
    if (lpRect == nullptr) {
        Runtime::clipCursor(-1, -1, -1, -1);
    } else {
        Runtime::clipCursor(lpRect->left, lpRect->top, lpRect->right, lpRect->bottom);
    }
    return true;
}

HOOK(SetCursorPos, BOOL, (int x, int y)) {
    Runtime::setCursorPos(x, y);
    return true;
}

HRESULT __stdcall SpeakPatch(ISpVoice* This, LPCWSTR pwcs, DWORD dwFlags, ULONG *pulStreamNumber) {
    CW2A utf8(pwcs, CP_UTF8);
    Runtime::speak(utf8.m_psz, dwFlags);
    return S_OK;
}

HRESULT __stdcall SpeakSkipPatch(ISpVoice* This, LPCWSTR *pItemType, long lItems, ULONG *pulNumSkipped) {
    Runtime::speakSkip();
    return S_OK;
}

struct _ISpVoiceVTable {
    void* speak;
    void* skip;
};

_ISpVoiceVTable createISpVoiceVTable() {
    CoInitializeEx(nullptr, 0);

    CComPtr<ISpVoice> spVoice;
    if (!SUCCEEDED(spVoice.CoCreateInstance(CLSID_SpVoice))) {
        throw std::runtime_error("Failed to create ISpVoice instance");
    }

    auto vTable = *(void***)spVoice.p;
    void* speak = vTable[VTABLE_INDEX_SPEAK];
    void* skip = vTable[VTABLE_INDEX_SKIP];

    return {speak, skip};
}

static _ISpVoiceVTable spVoiceVTable = createISpVoiceVTable();

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD dwReason, LPVOID reserved) {
    if (DetourIsHelperProcess()) {
        return true;
    }

    if (dwReason == DLL_PROCESS_ATTACH) {
        Runtime::processAttach();
        DetourRestoreAfterWith();
    }

    if (dwReason == DLL_PROCESS_ATTACH || dwReason == DLL_PROCESS_DETACH) {
        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());

        DETOUR(GetVolumeInformationW);
        DETOUR(ClipCursor);
        DETOUR(SetCursorPos);
        DETOUR_VTABLE(SpeakPatch, spVoiceVTable.speak);
        DETOUR_VTABLE(SpeakSkipPatch, spVoiceVTable.skip);

        DetourTransactionCommit();
    }

    if (dwReason == DLL_PROCESS_DETACH) {
        Runtime::processDetach();
    }
    return true;
}