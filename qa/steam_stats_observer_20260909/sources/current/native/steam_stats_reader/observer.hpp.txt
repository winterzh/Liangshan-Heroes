#pragma once
// Independent-account reads only. This is a read result, never a write receipt.
#include "reader.hpp"
#include <chrono>
#include <unordered_set>

namespace lsh {
struct ObserverClock {
    virtual ~ObserverClock() = default;
    virtual uint64_t milliseconds() = 0;
};
struct SteadyObserverClock final : ObserverClock {
    uint64_t milliseconds() override {
        return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count());
    }
};
// Shared by native observer instances, not by the legacy current-user reader.
// Uncertain requests may still refresh Steam's shared user cache after timeout.
// Do not allow another observer to reuse that target until the process restarts.
struct ObserverRegistry {
    std::unordered_set<uint64_t> leased, uncertain;
};
class Observer {
    Api &api;
    ObserverClock &clock;
    ObserverRegistry &registry;
    uint64_t observer = 0, target = 0, pending = 0, read_handle = 0, started = 0;
    bool closed = false, lease = false;
    std::unordered_set<uint64_t> issued;
    static constexpr uint64_t timeout_ms = 30000;
    static constexpr size_t max_reads = 512;

    std::string close(const char *code, bool uncertain = false) {
        if ((uncertain || pending) && target) registry.uncertain.insert(target);
        closed = true; pending = 0; read_handle = 0;
        return bad(code);
    }
    const char *identity_error() {
        if (!api.ready()) return "STEAM_NOT_INITIALIZED";
        if (api.app() != 5088120 || !api.owner()) return "WRONG_IDENTITY";
        if (observer && api.owner() != observer) return "OBSERVER_CHANGED";
        return nullptr;
    }
    const char *active_error() {
        const char *error = identity_error();
        if (error) return error;
        if (pending) {
            uint64_t now = clock.milliseconds();
            if (now < started) return "CLOCK_REGRESSED";
            if (now - started >= timeout_ms) return "READ_TIMEOUT";
        }
        return nullptr;
    }
    std::string identity_fields() const {
        return "\"protocol\":1,\"app\":5088120,\"observer\":\"" + std::to_string(observer) +
            "\",\"target\":\"" + std::to_string(target) + "\",\"source\":\"independent_requested_user_cache\"";
    }
    static bool pair(const std::string &arg, std::string &first, std::string &second) {
        auto split = arg.find(' ');
        if (split == std::string::npos || split == 0 || split + 1 == arg.size() || arg.find(' ', split + 1) != std::string::npos) return false;
        first = arg.substr(0, split); second = arg.substr(split + 1); return true;
    }
public:
    Observer(Api &native, ObserverClock &timer, ObserverRegistry &sessions) : api(native), clock(timer), registry(sessions) {}
    Observer(const Observer &) = delete;
    Observer &operator=(const Observer &) = delete;
    ~Observer() {
        if (pending && target) registry.uncertain.insert(target);
        if (lease) registry.leased.erase(target);
    }
    std::string query(const std::string &command) {
        if (closed) return bad("OBSERVER_CLOSED");
        if (command.size() > 180) return bad("BAD_COMMAND");
        const char *error = active_error();
        if (error) return observer ? close(error) : bad(error);
        auto space = command.find(' ');
        auto op = command.substr(0, space);
        auto arg = space == std::string::npos ? "" : command.substr(space + 1);
        if (op == "bind") {
            if (observer) return bad("ALREADY_ATTACHED");
            std::string first, second;
            uint64_t expected = 0, subject = 0;
            if (!pair(arg, first, second) || !decimal(first, expected) || !decimal(second, subject)) return bad("BAD_IDENTITIES");
            if (expected != api.owner()) return bad("WRONG_OBSERVER");
            if (subject == expected) return bad("TARGET_IS_OBSERVER");
            if (registry.uncertain.count(subject)) return bad("TARGET_REQUIRES_PROCESS_RESTART");
            if (registry.leased.count(subject)) return bad("TARGET_BUSY");
            observer = expected; target = subject; registry.leased.insert(target); lease = true;
            error = identity_error();
            if (error) return close(error);
            return "{\"ok\":true," + identity_fields() + "}";
        }
        if (!observer) return bad("NOT_ATTACHED");
        if (registry.uncertain.count(target)) return close("TARGET_REQUIRES_PROCESS_RESTART");
        if (op == "identity" && arg.empty()) return "{\"ok\":true," + identity_fields() + "}";
        if (op == "request" && arg.empty()) {
            if (pending) return bad("READ_BUSY");
            if (issued.size() >= max_reads) return close("OBSERVER_READ_LIMIT");
            read_handle = 0;
            started = clock.milliseconds();
            pending = api.request(target);
            if (!pending) return bad("REQUEST_FAILED");
            if (!issued.insert(pending).second) return close("REUSED_HANDLE", true);
            error = active_error();
            if (error) return close(error);
            return "{\"ok\":true," + identity_fields() + ",\"handle\":\"" + handle_text(pending) + "\",\"timeout_ms\":30000}";
        }
        if (op == "poll") {
            if (!pending || arg != handle_text(pending)) return bad("UNKNOWN_HANDLE");
            bool failed = false;
            bool done = api.completed(pending, failed);
            error = active_error();
            if (error) return close(error);
            if (failed) return close("READ_IO_FAILED", true);
            if (!done) return "{\"ok\":true," + identity_fields() + ",\"pending\":true,\"handle\":\"" + arg + "\"}";
            Received received{};
            uint64_t finished = pending;
            bool retrieved = api.result(finished, received, failed);
            error = active_error();
            if (error) return close(error);
            if (!retrieved || failed) return close("RESULT_UNAVAILABLE", true);
            pending = 0;
            if (received.game != 5088120 || received.owner != target) return close("RESULT_IDENTITY_MISMATCH", true);
            if (received.result != 1) return "{\"ok\":false,\"code\":\"READ_RESULT_FAILED\",\"result\":" + std::to_string(received.result) + "}";
            read_handle = finished;
            return "{\"ok\":true," + identity_fields() + ",\"pending\":false,\"handle\":\"" + arg + "\"}";
        }
        if (op != "stat" && op != "achievement") return bad("BAD_COMMAND");
        std::string handle, name;
        if (!pair(arg, handle, name)) return bad("BAD_COMMAND");
        if (!api_name(name)) return bad("BAD_API_NAME");
        if (!read_handle || pending) return bad("READ_NOT_READY");
        if (handle != handle_text(read_handle)) return bad("UNKNOWN_HANDLE");
        int32_t number = 0; bool achieved = false;
        bool ok = op == "stat" ? api.stat(target, name.c_str(), number, false) : api.achievement(target, name.c_str(), achieved, false);
        error = identity_error();
        if (error) return close(error);
        if (!ok) { read_handle = 0; return bad("GETTER_FAILED"); }
        std::string value = op == "stat" ? std::to_string(number) : (achieved ? "true" : "false");
        return "{\"ok\":true," + identity_fields() + ",\"handle\":\"" + handle + "\",\"value\":" + value + "}";
    }
};
}
