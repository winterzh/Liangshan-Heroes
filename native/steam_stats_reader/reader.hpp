#pragma once
// Read-only Steam interface. No initialization, writes or callback pumping.
#include <cstdint>
#include <cstddef>
#include <cstdio>
#include <string>
#include <limits>

namespace lsh {
struct Received {
    uint64_t game;
    int32_t result;
    uint32_t padding;
    uint64_t owner;
};
static_assert(sizeof(Received) == 24 && offsetof(Received, owner) == 16);
struct Api {
    virtual ~Api() = default;
    virtual bool ready() = 0;
    virtual uint64_t owner() = 0;
    virtual uint32_t app() = 0;
    virtual uint64_t request(uint64_t user) = 0;
    virtual bool completed(uint64_t handle, bool &failed) = 0;
    virtual bool result(uint64_t handle, Received &value, bool &failed) = 0;
    virtual bool stat(uint64_t user, const char *name, int32_t &value, bool current) = 0;
    virtual bool achievement(uint64_t user, const char *name, bool &value, bool current) = 0;
};
inline std::string bad(const char *code) { return std::string("{\"ok\":false,\"code\":\"") + code + "\"}"; }
inline std::string handle_text(uint64_t handle) {
    char value[17]; std::snprintf(value, sizeof(value), "%016llx", static_cast<unsigned long long>(handle)); return value;
}
inline bool decimal(const std::string &s, uint64_t &value) {
    value = 0;
    if (s.empty() || s.size() > 20 || s[0] == '0') return false;
    for (char c : s) {
        if (c < '0' || c > '9' || value > (UINT64_MAX - (c - '0')) / 10) return false;
        value = value * 10 + c - '0';
    }
    return value != 0;
}
inline bool api_name(const std::string &s) {
    if (s.empty() || s.size() > 127) return false;
    for (char c : s) if (!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_')) return false;
    return true;
}
class Reader {
    Api &api;
    uint64_t bound_owner = 0, pending = 0, read_handle = 0;
    bool poisoned = false;
public:
    explicit Reader(Api &native) : api(native) {}
    std::string query(const std::string &command) {
        if (command.size() > 180) return bad("BAD_COMMAND");
        auto space = command.find(' ');
        auto op = command.substr(0, space);
        auto arg = space == std::string::npos ? "" : command.substr(space + 1);
        if (poisoned) return bad("READER_CLOSED");
        if (!api.ready()) {
            if (bound_owner) poisoned = true;
            return bad("STEAM_NOT_INITIALIZED");
        }
        uint64_t current = api.owner();
        if (!current || api.app() != 5088120) { poisoned = true; return bad("WRONG_IDENTITY"); }
        if (bound_owner && current != bound_owner) { poisoned = true; return bad("ACCOUNT_CHANGED"); }
        bound_owner = current;
        if (op == "identity" && arg.empty()) return "{\"ok\":true,\"owner\":\"" + std::to_string(current) + "\",\"app\":5088120}";
        if (op == "request") {
            uint64_t requested;
            if (!decimal(arg, requested) || requested != current) return bad("WRONG_OWNER");
            if (pending) return bad("READ_BUSY");
            read_handle = 0;
            pending = api.request(current);
            if (!pending) return bad("REQUEST_FAILED");
            return "{\"ok\":true,\"handle\":\"" + handle_text(pending) + "\"}";
        }
        if (op == "poll") {
            // The supplied opaque hexadecimal handle must be the actual issued call.
            if (!pending || arg != handle_text(pending)) return bad("UNKNOWN_HANDLE");
            bool failed = false;
            bool done = api.completed(pending, failed);
            if (failed) { pending = 0; return bad("READ_IO_FAILED"); }
            if (!done) return "{\"ok\":true,\"pending\":true,\"handle\":\"" + arg + "\"}";
            Received received{};
            uint64_t finished = pending;
            pending = 0;
            bool retrieved = api.result(finished, received, failed);
            if (!retrieved || failed) return bad("RESULT_UNAVAILABLE");
            if (received.game != 5088120 || received.owner != current) { poisoned = true; return bad("RESULT_IDENTITY_MISMATCH"); }
            if (received.result != 1) return "{\"ok\":false,\"code\":\"READ_RESULT_FAILED\",\"result\":" + std::to_string(received.result) + "}";
            read_handle = finished;
            return "{\"ok\":true,\"pending\":false,\"handle\":\"" + arg + "\",\"owner\":\"" + std::to_string(current) + "\"}";
        }
        bool local = op == "current_stat" || op == "current_achievement";
        bool is_stat = op == "current_stat" || op == "user_stat";
        bool is_achievement = op == "current_achievement" || op == "user_achievement";
        if (!is_stat && !is_achievement) return bad("BAD_COMMAND");
        if (!api_name(arg)) return bad("BAD_API_NAME");
        if (!local && (!read_handle || pending)) return bad("READ_NOT_READY");
        int32_t number = 0;
        bool achieved = false;
        bool ok = is_stat ? api.stat(current, arg.c_str(), number, local) : api.achievement(current, arg.c_str(), achieved, local);
        // Failure is never encoded as a successful zero or false.
        if (!ok) { if (!local) read_handle = 0; return bad("GETTER_FAILED"); }
        std::string value = is_stat ? std::to_string(number) : (achieved ? "true" : "false");
        return "{\"ok\":true,\"value\":" + value + ",\"owner\":\"" + std::to_string(current) + "\",\"source\":\"" + (local ? "current_cache" : "requested_user_cache") + "\",\"handle\":\"" + (local ? "" : handle_text(read_handle)) + "\"}";
    }
};
}
