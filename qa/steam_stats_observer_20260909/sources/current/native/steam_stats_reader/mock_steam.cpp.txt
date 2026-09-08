// Synthetic ABI fixture, compiled only by QA. Never shipped in vendor/.
#include "gdextension_interface.h"
#include "reader.hpp"
#include <cstdlib>
#include <cstring>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#define EXPORT extern "C" __declspec(dllexport)
int setting(const char *key, int fallback = 0) { char value[32]{}; return GetEnvironmentVariableA(key, value, sizeof(value)) ? std::atoi(value) : fallback; }
void *context() { return reinterpret_cast<void *>(uintptr_t(0x1234)); }
EXPORT int SteamAPI_GetHSteamPipe() { return setting("LSH_MOCK_READY", 1); }
EXPORT int SteamAPI_GetHSteamUser() { return setting("LSH_MOCK_READY", 1); }
EXPORT void *SteamAPI_SteamUserStats_v013() { return context(); }
EXPORT void *SteamAPI_SteamUser_v023() { return context(); }
EXPORT void *SteamAPI_SteamUtils_v011() { return context(); }
EXPORT uint64_t SteamAPI_ISteamUser_GetSteamID(void *) { return 76561198000000001ULL + setting("LSH_MOCK_OWNER_OFFSET"); }
EXPORT uint32_t SteamAPI_ISteamUtils_GetAppID(void *) { return 5088120 + setting("LSH_MOCK_APP_OFFSET"); }
uint64_t fixture_target() { return 76561198000000001ULL + setting("LSH_MOCK_TARGET_OFFSET"); }
uint64_t active = 0;
EXPORT uint64_t SteamAPI_ISteamUserStats_RequestUserStats(void *self, uint64_t owner) {
    if (self != context() || owner != fixture_target()) return 0;
    if (!active) active = 0xf123456789abcdefULL; else ++active;
    return active;
}
EXPORT bool SteamAPI_ISteamUtils_IsAPICallCompleted(void *self, uint64_t handle, bool *failed) {
    *failed = self != context() || handle != active || setting("LSH_MOCK_IO");
    return setting("LSH_MOCK_DONE") != 0;
}
EXPORT bool SteamAPI_ISteamUtils_GetAPICallResult(void *self, uint64_t handle, void *data, int size, int callback, bool *failed) {
    *failed = self != context() || handle != active;
    if (size != 24 || callback != 1101 || *failed) return false;
    // Independent wire fixture: do not memcpy the bridge's logical struct.
    unsigned char wire[24]; std::memset(wire, 0xA5, sizeof(wire));
    uint64_t game = 5088120, owner = fixture_target() + setting("LSH_MOCK_RESULT_OWNER_OFFSET");
    int32_t result = setting("LSH_MOCK_RESULT", 1);
    std::memcpy(wire, &game, 8); std::memcpy(wire + 8, &result, 4);
    std::memcpy(wire + 12, &owner, 8);
    std::memcpy(data, wire, sizeof(wire)); return true;
}
EXPORT bool SteamAPI_ISteamUserStats_GetStatInt32(void *self, const char *name, int32_t *value) {
    *value = setting("LSH_MOCK_VALUE");
    return self == context() && name && !setting("LSH_MOCK_GET_FAIL");
}
EXPORT bool SteamAPI_ISteamUserStats_GetUserStatInt32(void *self, uint64_t owner, const char *name, int32_t *value) {
    return owner == fixture_target() && SteamAPI_ISteamUserStats_GetStatInt32(self, name, value);
}
EXPORT bool SteamAPI_ISteamUserStats_GetAchievement(void *self, const char *name, bool *value) {
    *value = setting("LSH_MOCK_ACHIEVED") != 0;
    return self == context() && name && !setting("LSH_MOCK_GET_FAIL");
}
EXPORT bool SteamAPI_ISteamUserStats_GetUserAchievement(void *self, uint64_t owner, const char *name, bool *value) {
    return owner == fixture_target() && SteamAPI_ISteamUserStats_GetAchievement(self, name, value);
}
void noop(void *, GDExtensionInitializationLevel) {}
EXPORT GDExtensionBool lsh_mock_init(GDExtensionInterfaceGetProcAddress, GDExtensionClassLibraryPtr, GDExtensionInitialization *init) {
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE; init->initialize = noop; init->deinitialize = noop; return true;
}
