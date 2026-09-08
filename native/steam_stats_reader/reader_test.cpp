#include "reader.hpp"
#include <stdexcept>
#include <iostream>

struct Fake final : lsh::Api {
    bool live = true, done = false, io = false, retrieved = true, getter = true;
    uint64_t id = 76561198000000001ULL, next = 0xf123456789abcdefULL;
    uint32_t appid = 5088120;
    lsh::Received received{5088120, 1, 0, id};
    uint64_t polled = 0, fetched = 0;
    int requests = 0, gets = 0;
    int32_t value = 0;
    bool ready() override { return live; }
    uint64_t owner() override { return id; }
    uint32_t app() override { return appid; }
    uint64_t request(uint64_t user) override { if (user != id) throw std::runtime_error("wrong request user"); ++requests; return next; }
    bool completed(uint64_t h, bool &f) override { polled = h; f = io; return done; }
    bool result(uint64_t h, lsh::Received &r, bool &f) override { fetched = h; r = received; f = io; return retrieved; }
    bool stat(uint64_t, const char *, int32_t &v, bool) override { ++gets; v = value; return getter; }
    bool achievement(uint64_t, const char *, bool &v, bool) override { ++gets; v = false; return getter; }
};
int checks = 0;
void check(bool ok) { ++checks; if (!ok) throw std::runtime_error("check " + std::to_string(checks)); }
bool has(const std::string &s, const char *text) { return s.find(text) != std::string::npos; }
void begin(lsh::Reader &r, Fake &a) { check(has(r.query("request " + std::to_string(a.id)), "f123456789abcdef")); }
int main() {
    try {
        Fake a; lsh::Reader r(a);
        check(has(r.query("identity"), std::to_string(a.id).c_str()));
        check(has(r.query("current_stat TOTAL_KILLS"), "\"value\":0"));
        a.getter = false; check(has(r.query("current_stat TOTAL_KILLS"), "GETTER_FAILED"));
        check(has(r.query("current_achievement ACH_WINS_10"), "GETTER_FAILED")); a.getter = true;
        check(has(r.query("user_stat TOTAL_KILLS"), "READ_NOT_READY"));
        check(has(r.query("request 0"), "WRONG_OWNER"));
        check(has(r.query("request 18446744073709551616"), "WRONG_OWNER"));
        check(has(r.query("request 076561198000000001"), "WRONG_OWNER"));
        check(has(r.query("request 76561198000000002"), "WRONG_OWNER")); check(a.requests == 0);
        begin(r, a); check(has(r.query("request " + std::to_string(a.id)), "READ_BUSY")); check(a.requests == 1);
        check(has(r.query("poll f123456789abcdee"), "UNKNOWN_HANDLE")); check(a.polled == 0);
        check(has(r.query("poll f123456789abcdef"), "\"pending\":true")); check(a.polled == a.next);
        check(has(r.query("user_stat TOTAL_KILLS"), "READ_NOT_READY"));
        a.done = true; check(has(r.query("poll f123456789abcdef"), "\"pending\":false")); check(a.fetched == a.next);
        check(has(r.query("poll f123456789abcdef"), "UNKNOWN_HANDLE"));
        auto snapshot = r.query("user_stat TOTAL_KILLS"); check(has(snapshot, "\"value\":0") && has(snapshot, "f123456789abcdef"));
        check(has(r.query("user_achievement ACH_WINS_10"), "\"value\":false"));
        a.value = INT32_MAX; check(has(r.query("user_stat TOTAL_KILLS"), "2147483647"));
        int gets = a.gets; check(has(r.query("user_stat BAD\"NAME"), "BAD_API_NAME")); check(a.gets == gets);
        check(has(r.query("storeStats"), "BAD_COMMAND"));
        a.getter = false; check(has(r.query("user_stat TOTAL_KILLS"), "GETTER_FAILED"));
        a.getter = true; check(has(r.query("user_stat TOTAL_KILLS"), "READ_NOT_READY"));
        // Same process can read repeatedly; a previous handle never polls a new call.
        a.next = 0xfedcba9876543210ULL;
        check(has(r.query("request " + std::to_string(a.id)), "fedcba9876543210"));
        check(has(r.query("poll f123456789abcdef"), "UNKNOWN_HANDLE"));
        check(has(r.query("poll fedcba9876543210"), "\"pending\":false"));
        check(has(r.query("user_stat TOTAL_KILLS"), "fedcba9876543210"));
        a.id++; check(has(r.query("identity"), "ACCOUNT_CHANGED")); a.id--;
        check(has(r.query("identity"), "READER_CLOSED"));
        for (int failure = 0; failure < 5; ++failure) {
            Fake b; lsh::Reader reader(b); begin(reader, b); b.done = true;
            if (failure == 0) b.io = true;
            if (failure == 1) b.retrieved = false;
            if (failure == 2) b.received.result = 8;
            if (failure == 3) b.received.game++;
            if (failure == 4) b.received.owner++;
            check(has(reader.query("poll f123456789abcdef"), "\"ok\":false"));
            check(has(reader.query("user_stat TOTAL_KILLS"), "\"ok\":false")); check(b.gets == 0);
        }
        Fake b; lsh::Reader reader(b); b.live = false;
        check(has(reader.query("identity"), "STEAM_NOT_INITIALIZED"));
        b.live = true; check(has(reader.query("identity"), "\"ok\":true"));
        b.live = false; check(has(reader.query("identity"), "STEAM_NOT_INITIALIZED")); b.live = true;
        check(has(reader.query("identity"), "READER_CLOSED"));
        Fake c; lsh::Reader wrong(c); c.appid++;
        check(has(wrong.query("identity"), "WRONG_IDENTITY")); check(c.requests == 0 && c.gets == 0);
        std::cout << "{\"passed\":true,\"checks\":" << checks << "}\n";
    } catch (const std::exception &e) { std::cerr << e.what() << "\n"; return 1; }
}
