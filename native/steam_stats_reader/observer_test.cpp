#include "observer.hpp"
#include <stdexcept>
#include <iostream>
#include <functional>

namespace {
constexpr uint64_t observer_id = 76561198000000001ULL, target_id = 76561198000000002ULL;
constexpr uint64_t first_handle = 0xf123456789abcdefULL;
const std::string bind = "bind 76561198000000001 76561198000000002";
const std::string poll = "poll f123456789abcdef";
const std::string stat_command = "stat f123456789abcdef TOTAL_KILLS";
struct Clock final : lsh::ObserverClock {
    uint64_t now = 100;
    uint64_t milliseconds() override { return now; }
};
struct Fake final : lsh::Api {
    bool live = true, done = false, io = false, retrieved = true, result_io = false, getter = true;
    bool achieved = false;
    uint64_t id = observer_id, next = first_handle;
    uint32_t appid = 5088120;
    int32_t value = 0;
    lsh::Received received{5088120, 1, 0, target_id};
    uint64_t requested = 0, polled = 0, fetched = 0, gotten = 0;
    int requests = 0, gets = 0, completions = 0, results = 0;
    std::function<void()> in_request, in_completed, in_result, in_getter;
    bool ready() override { return live; }
    uint64_t owner() override { return id; }
    uint32_t app() override { return appid; }
    uint64_t request(uint64_t user) override { requested = user; ++requests; if (in_request) in_request(); return next; }
    bool completed(uint64_t h, bool &f) override { polled = h; ++completions; f = io; if (in_completed) in_completed(); return done; }
    bool result(uint64_t h, lsh::Received &r, bool &f) override { fetched = h; ++results; r = received; f = result_io; if (in_result) in_result(); return retrieved; }
    bool stat(uint64_t user, const char *, int32_t &v, bool current) override {
        if (current) throw std::runtime_error("forbidden current-user stat getter");
        gotten = user; ++gets; v = value; if (in_getter) in_getter(); return getter;
    }
    bool achievement(uint64_t user, const char *, bool &v, bool current) override {
        if (current) throw std::runtime_error("forbidden current-user achievement getter");
        gotten = user; ++gets; v = achieved; if (in_getter) in_getter(); return getter;
    }
};
int checks = 0;
void check(bool ok, const char *name) { ++checks; if (!ok) throw std::runtime_error(std::to_string(checks) + ": " + name); }
bool has(const std::string &s, const std::string &needle) { return s.find(needle) != std::string::npos; }
void code(lsh::Observer &r, const std::string &command, const char *expected) {
    auto result = r.query(command);
    check(has(result, "\"ok\":false") && has(result, std::string("\"code\":\"") + expected + "\""), expected);
}
void ok(lsh::Observer &r, const std::string &command) { check(has(r.query(command), "\"ok\":true"), command.c_str()); }
void begin(lsh::Observer &r, Fake &a) {
    ok(r, bind); auto started = r.query("request");
    check(has(started, "\"ok\":true") && has(started, "f123456789abcdef") && has(started, "\"timeout_ms\":30000"), "request envelope");
    check(a.requested == target_id, "request uses target, never observer");
}
void completed(lsh::Observer &r, Fake &a) { a.done = true; ok(r, poll); }
}
int main() {
    try {
        {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s);
            code(r, "identity", "NOT_ATTACHED");
            code(r, "bind 0 1", "BAD_IDENTITIES");
            code(r, "bind 76561198000000001 18446744073709551616", "BAD_IDENTITIES");
            code(r, "bind 76561198000000001 076561198000000002", "BAD_IDENTITIES");
            code(r, bind + " extra", "BAD_IDENTITIES");
            code(r, "bind 76561198000000002 76561198000000001", "WRONG_OBSERVER");
            code(r, "bind 76561198000000001 76561198000000001", "TARGET_IS_OBSERVER");
            check(a.requests == 0 && a.gets == 0, "bad identities have no SDK read side effect");
            ok(r, bind); code(r, bind, "ALREADY_ATTACHED");
            auto identity = r.query("identity");
            check(has(identity, "\"observer\":\"76561198000000001\"") && has(identity, "\"target\":\"76561198000000002\"") && has(identity, "\"app\":5088120") && has(identity, "independent_requested_user_cache"), "both identities and source explicit");
            code(r, stat_command, "READ_NOT_READY");
            code(r, "current_stat TOTAL_KILLS", "BAD_COMMAND");
            code(r, "user_stat TOTAL_KILLS", "BAD_COMMAND");
            code(r, "StoreStats", "BAD_COMMAND");
            ok(r, "request"); check(a.requested == target_id, "target requested");
            code(r, "request", "READ_BUSY"); check(a.requests == 1, "single pending SDK request");
            code(r, "poll f123456789abcdee", "UNKNOWN_HANDLE"); check(a.completions == 0, "wrong handle not dispatched");
            check(has(r.query(poll), "\"pending\":true"), "pending no completed read");
            check(a.polled == first_handle && a.results == 0, "exact opaque call checked");
            code(r, stat_command, "READ_NOT_READY");
            completed(r, a); check(a.fetched == first_handle, "exact opaque result retrieved");
            code(r, poll, "UNKNOWN_HANDLE");
            code(r, "stat f123456789abcdee TOTAL_KILLS", "UNKNOWN_HANDLE");
            check(a.gets == 0, "unknown getter handle does not fetch data");
            auto zero = r.query(stat_command);
            check(has(zero, "\"value\":0") && has(zero, "\"handle\":\"f123456789abcdef\"") && has(zero, "\"target\":\"76561198000000002\""), "zero is valid target data");
            check(a.gotten == target_id, "getter only uses target");
            check(has(r.query("achievement f123456789abcdef ACH_WINS_10"), "\"value\":false"), "false is valid data");
            a.achieved = true; check(has(r.query("achievement f123456789abcdef ACH_WINS_10"), "\"value\":true"), "true preserved");
            a.value = INT32_MAX; check(has(r.query(stat_command), "2147483647"), "int32 max exact");
            int gets = a.gets; code(r, "stat f123456789abcdef BAD\"NAME", "BAD_API_NAME"); check(a.gets == gets, "invalid name never reaches SDK");
            a.next++; ok(r, "request"); code(r, poll, "UNKNOWN_HANDLE"); code(r, stat_command, "READ_NOT_READY");
            ok(r, "poll f123456789abcdf0"); code(r, stat_command, "UNKNOWN_HANDLE");
            ok(r, "stat f123456789abcdf0 TOTAL_KILLS");
        }
        for (int failure = 0; failure < 9; ++failure) {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s); begin(r, a); a.done = true;
            const char *expected = "";
            switch (failure) {
                case 0: a.io = true; expected = "READ_IO_FAILED"; break;
                case 1: a.retrieved = false; expected = "RESULT_UNAVAILABLE"; break;
                case 2: a.result_io = true; expected = "RESULT_UNAVAILABLE"; break;
                case 3: a.received.result = 8; expected = "READ_RESULT_FAILED"; break;
                case 4: a.received.owner = observer_id; expected = "RESULT_IDENTITY_MISMATCH"; break;
                case 5: a.received.game++; expected = "RESULT_IDENTITY_MISMATCH"; break;
                case 6: a.id++; expected = "OBSERVER_CHANGED"; break;
                case 7: a.appid++; expected = "WRONG_IDENTITY"; break;
                case 8: a.live = false; expected = "STEAM_NOT_INITIALIZED"; break;
            }
            code(r, poll, expected);
            check(has(r.query(stat_command), "\"ok\":false") && a.gets == 0, "failure cannot yield snapshot");
            if (failure != 3) check(s.uncertain.count(target_id) == 1, "uncertain target fenced until process restart");
            else {
                a.received.result = 1; a.next++; ok(r, "request"); ok(r, "poll f123456789abcdf0");
            }
        }
        {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s); begin(r, a); completed(r, a);
            a.getter = false; code(r, stat_command, "GETTER_FAILED"); a.getter = true; code(r, stat_command, "READ_NOT_READY");
            a.next++; ok(r, "request"); ok(r, "poll f123456789abcdf0"); ok(r, "stat f123456789abcdf0 TOTAL_KILLS");
        }
        for (int seam = 0; seam < 4; ++seam) {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s);
            if (seam == 0) { ok(r, bind); a.in_request = [&a]() { a.id++; }; code(r, "request", "OBSERVER_CHANGED"); }
            if (seam == 1) { begin(r, a); a.in_completed = [&a]() { a.id++; }; code(r, poll, "OBSERVER_CHANGED"); }
            if (seam == 2) { begin(r, a); a.done = true; a.in_result = [&a]() { a.id++; }; code(r, poll, "OBSERVER_CHANGED"); }
            if (seam == 3) { begin(r, a); completed(r, a); a.in_getter = [&a]() { a.id++; }; code(r, stat_command, "OBSERVER_CHANGED"); }
            a.id = observer_id; code(r, "identity", "OBSERVER_CLOSED");
        }
        for (int seam = 0; seam < 4; ++seam) {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s);
            if (seam == 0) { ok(r, bind); a.in_request = [&t]() { t.now += 30000; }; code(r, "request", "READ_TIMEOUT"); }
            if (seam == 1) { begin(r, a); t.now += 29999; check(has(r.query(poll), "\"pending\":true"), "before timeout stays pending"); t.now++; code(r, poll, "READ_TIMEOUT"); }
            if (seam == 2) { begin(r, a); a.in_completed = [&t]() { t.now += 30000; }; code(r, poll, "READ_TIMEOUT"); }
            if (seam == 3) { begin(r, a); a.done = true; a.in_result = [&t]() { t.now += 30000; }; code(r, poll, "READ_TIMEOUT"); }
            a.done = true; code(r, poll, "OBSERVER_CLOSED"); check(a.gets == 0, "late callback after timeout yields no data");
            lsh::Observer other(a, t, s); code(other, bind, "TARGET_REQUIRES_PROCESS_RESTART");
        }
        {
            Fake a; Clock t; lsh::ObserverRegistry s;
            { lsh::Observer r(a, t, s); begin(r, a); lsh::Observer duplicate(a, t, s); code(duplicate, bind, "TARGET_BUSY"); }
            lsh::Observer after(a, t, s); code(after, bind, "TARGET_REQUIRES_PROCESS_RESTART");
        }
        {
            Fake a; Clock t; lsh::ObserverRegistry s;
            { lsh::Observer r(a, t, s); begin(r, a); completed(r, a); }
            lsh::Observer after(a, t, s); ok(after, bind); a.next++; ok(after, "request");
            code(after, poll, "UNKNOWN_HANDLE"); ok(after, "poll f123456789abcdf0");
        }
        {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s); begin(r, a); completed(r, a);
            code(r, "request", "REUSED_HANDLE"); code(r, stat_command, "OBSERVER_CLOSED");
        }
        {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s); begin(r, a); t.now--;
            code(r, poll, "CLOCK_REGRESSED"); code(r, "request", "OBSERVER_CLOSED");
        }
        {
            Fake a; Clock t; lsh::ObserverRegistry s; lsh::Observer r(a, t, s);
            a.live = false; code(r, bind, "STEAM_NOT_INITIALIZED"); a.live = true;
            a.appid++; code(r, bind, "WRONG_IDENTITY"); a.appid = 5088120; ok(r, bind);
            a.next = 0; code(r, "request", "REQUEST_FAILED"); a.next = first_handle; ok(r, "request"); completed(r, a);
            a.live = false; code(r, "identity", "STEAM_NOT_INITIALIZED"); a.live = true; code(r, "identity", "OBSERVER_CLOSED");
        }
        std::cout << "{\"passed\":true,\"checks\":" << checks << ",\"live_steam_tested\":false}\n";
    } catch (const std::exception &e) { std::cerr << e.what() << "\n"; return 1; }
}
