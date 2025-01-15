#include "Runtime-Swift.h"

#include <windows.h>
#include <Hidsdi.h>
#include <Detours.h>
#include <string>
#include <stdexcept>
#include <sapi.h>
#include <AtlBase.h>
#include <AtlConv.h>
#include <AtlCom.h>
#include <vector>
#include <mutex>
#include <optional>

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

namespace {
    static std::vector<std::string> deviceNames{};
    static std::mutex deviceNamesMutex{};

    size_t getDeviceNameIndex(const std::string& str) {
        std::lock_guard<std::mutex> lock(deviceNamesMutex);

        auto it = std::find(deviceNames.begin(), deviceNames.end(), str);
        if (it != deviceNames.end()) {
            return std::distance(deviceNames.begin(), it);
        }
        
        deviceNames.push_back(str);
        return deviceNames.size() - 1;
    }

    // Copy a std::wstring into a sized wchar_t buffer
    void copyString(const std::string& str, PVOID buffer, ULONG bufferLength) {
        std::wstring wstr{str.begin(), str.end()};
        std::memcpy(buffer, wstr.c_str(), wstr.size());
        ((wchar_t*)buffer)[wstr.size()] = '\0';
    }

    std::optional<std::string> getDeviceName(HANDLE handle) {
        std::lock_guard<std::mutex> lock(deviceNamesMutex);

        auto index = reinterpret_cast<size_t>(handle);

        if (index < deviceNames.size()) {
            return deviceNames[index];
        }

        return std::nullopt;
    }
}

// Workaround for GetVolumeInformationW not working in a UWP application
// This is by creating a handle to a file on the drive and then using GetVolumeInformationByHandleW with that handle
HOOK(GetVolumeInformationW, BOOL, (
    LPCWSTR lpRootPathName,
    LPWSTR lpVolumeNameBuffer,
    DWORD nVolumeNameSize,
    LPDWORD lpVolumeSerialNumber,
    LPDWORD lpMaximumComponentLength,
    LPDWORD lpFileSystemFlags,
    LPWSTR lpFileSystemNameBuffer,
    DWORD nFileSystemNameSize)) {
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

// The sandboxed process may not have access to read from HID devices, so we need to patch CreateFileA to return a dummy handle for XInput devices
// This specifically fixes SDL not being able to read the manufacturer and product strings of XInput devices
// See the SDL code here: https://github.com/libsdl-org/SDL/blob/84d35587ee400d9704e38042652fe5cbaab30c68/src/joystick/windows/SDL_rawinputjoystick.c#L904
HOOK(CreateFileA, HANDLE, (
    LPCSTR fileName,
    DWORD desiredAccess,
    DWORD shareMode,
    LPSECURITY_ATTRIBUTES
    securityAttributes,
    DWORD creationDisposition,
    DWORD flagsAndAttributes,
    HANDLE templateFile)) {
    // First check if the file is a HID device
    if (std::strncmp(fileName, R"(\\?\HID)", 7) == 0) {
        // Check check if the HID device is an XInput device
        if (std::strstr(fileName, R"(IG_)")) {
            // Now things get really fun, we return a dummy handle and hope that its only used for the following 2 patched functions
            return reinterpret_cast<HANDLE>(getDeviceNameIndex("XInput"));
        }
    }

    return TrueCreateFileA(fileName, desiredAccess, shareMode, securityAttributes, creationDisposition, flagsAndAttributes, templateFile);
}

HOOK(HidD_GetManufacturerString, BOOLEAN, (HANDLE deviceObject, PVOID buffer, ULONG bufferLength)) {
    if (auto deviceName = getDeviceName(deviceObject); deviceName) {
        auto name = Runtime::getHidManufacturerString(*deviceName);
        if (name) {
            copyString(name.get(), buffer, bufferLength);
            return true;
        }
    }

    return TrueHidD_GetManufacturerString(deviceObject, buffer, bufferLength);
}

HOOK(HidD_GetProductString, BOOLEAN, (HANDLE deviceObject, PVOID buffer, ULONG bufferLength)) {
    if (auto deviceName = getDeviceName(deviceObject); deviceName) {
        auto name = Runtime::getHidProductString(*deviceName);
        if (name) {
            copyString(name.get(), buffer, bufferLength);
            return true;
        }
    }

    return TrueHidD_GetProductString(deviceObject, buffer, bufferLength);
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
        DETOUR(CreateFileA);
        DETOUR(HidD_GetManufacturerString);
        DETOUR(HidD_GetProductString);
        DETOUR_VTABLE(SpeakPatch, spVoiceVTable.speak);
        DETOUR_VTABLE(SpeakSkipPatch, spVoiceVTable.skip);

        DetourTransactionCommit();
    }

    if (dwReason == DLL_PROCESS_DETACH) {
        Runtime::processDetach();
    }
    return true;
}