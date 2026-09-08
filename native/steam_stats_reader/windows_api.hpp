#pragma once
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <array>
#include <cstring>
#include "reader.hpp"

namespace lsh {
// The project pins Steamworks 1.65 / steam_api64.dll. Bind only already-loaded
// exports, with no DLL search, API initialization, writes, or callback dispatch.
class WindowsApi final : public Api {
    HMODULE module = nullptr;
    void *stats = nullptr, *utils = nullptr, *user = nullptr;
    using Interface = void *(*)();
    int (*pipe)() = nullptr;
    int (*huser)() = nullptr;
    uint64_t (*get_owner)(void *) = nullptr;
    uint32_t (*get_app)(void *) = nullptr;
    uint64_t (*get_request)(void *, uint64_t) = nullptr;
    bool (*is_completed)(void *, uint64_t, bool *) = nullptr;
    bool (*get_result)(void *, uint64_t, void *, int, int, bool *) = nullptr;
    bool (*get_stat)(void *, const char *, int32_t *) = nullptr;
    bool (*get_user_stat)(void *, uint64_t, const char *, int32_t *) = nullptr;
    bool (*get_achievement)(void *, const char *, bool *) = nullptr;
    bool (*get_user_achievement)(void *, uint64_t, const char *, bool *) = nullptr;
    template<class T> bool bind(T &fn, const char *name) {
        fn = reinterpret_cast<T>(GetProcAddress(module, name)); return fn != nullptr;
    }
public:
    bool ready() override {
        module = GetModuleHandleW(L"steam_api64.dll");
        if (!module) return false;
        Interface stats_fn, utils_fn, user_fn;
        if (!bind(pipe, "SteamAPI_GetHSteamPipe") || !bind(huser, "SteamAPI_GetHSteamUser") || !pipe() || !huser()) return false;
        if (!bind(stats_fn, "SteamAPI_SteamUserStats_v013") || !bind(utils_fn, "SteamAPI_SteamUtils_v011") || !bind(user_fn, "SteamAPI_SteamUser_v023")) return false;
        if (!bind(get_owner, "SteamAPI_ISteamUser_GetSteamID") || !bind(get_app, "SteamAPI_ISteamUtils_GetAppID") ||
            !bind(get_request, "SteamAPI_ISteamUserStats_RequestUserStats") || !bind(is_completed, "SteamAPI_ISteamUtils_IsAPICallCompleted") ||
            !bind(get_result, "SteamAPI_ISteamUtils_GetAPICallResult") || !bind(get_stat, "SteamAPI_ISteamUserStats_GetStatInt32") ||
            !bind(get_user_stat, "SteamAPI_ISteamUserStats_GetUserStatInt32") || !bind(get_achievement, "SteamAPI_ISteamUserStats_GetAchievement") ||
            !bind(get_user_achievement, "SteamAPI_ISteamUserStats_GetUserAchievement")) return false;
        stats = stats_fn(); utils = utils_fn(); user = user_fn();
        return stats && utils && user;
    }
    uint64_t owner() override { return get_owner(user); }
    uint32_t app() override { return get_app(utils); }
    uint64_t request(uint64_t id) override { return get_request(stats, id); }
    bool completed(uint64_t h, bool &f) override { return is_completed(utils, h, &f); }
    bool result(uint64_t h, Received &r, bool &f) override {
        // CSteamID is packed to alignment 1 in Valve's steamclientpublic.h.
        // Windows callback alignment is 8: size 24, but the ID starts at 12,
        // with four trailing pad bytes. A plain uint64 member starts at 16.
        std::array<unsigned char, 24> wire{};
        if (!get_result(utils, h, wire.data(), static_cast<int>(wire.size()), 1101, &f)) return false;
        std::memcpy(&r.game, wire.data(), 8);
        std::memcpy(&r.result, wire.data() + 8, 4);
        std::memcpy(&r.owner, wire.data() + 12, 8);
        return true;
    }
    bool stat(uint64_t id, const char *n, int32_t &v, bool current) override { return current ? get_stat(stats, n, &v) : get_user_stat(stats, id, n, &v); }
    bool achievement(uint64_t id, const char *n, bool &v, bool current) override { return current ? get_achievement(stats, n, &v) : get_user_achievement(stats, id, n, &v); }
};
}
