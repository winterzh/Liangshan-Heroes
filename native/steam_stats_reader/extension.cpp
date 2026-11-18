#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include "windows_api.hpp"
#include "observer.hpp"
#include <bcrypt.h>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <limits>

class SteamStatsReader : public godot::RefCounted {
    GDCLASS(SteamStatsReader, godot::RefCounted)
    lsh::WindowsApi api;
    lsh::Reader reader{api};
protected:
    static void _bind_methods() { godot::ClassDB::bind_method(godot::D_METHOD("query", "command"), &SteamStatsReader::query); }
public:
    godot::String query(const godot::String &command) {
        if (command.length() > 180) return "{\"ok\":false,\"code\":\"BAD_COMMAND\"}";
        auto utf8 = command.utf8();
        std::string answer = reader.query(std::string(utf8.get_data(), utf8.length()));
        return godot::String::utf8(answer.c_str());
    }
};
namespace {
lsh::ObserverRegistry observer_registry;
}
class SteamStatsObserver : public godot::RefCounted {
    GDCLASS(SteamStatsObserver, godot::RefCounted)
    lsh::WindowsApi api;
    lsh::SteadyObserverClock clock;
    lsh::Observer observer{api, clock, observer_registry};
protected:
    static void _bind_methods() { godot::ClassDB::bind_method(godot::D_METHOD("observer_query", "command"), &SteamStatsObserver::observer_query); }
public:
    godot::String observer_query(const godot::String &command) {
        if (command.length() > 180) return "{\"ok\":false,\"code\":\"BAD_COMMAND\"}";
        auto utf8 = command.utf8();
        std::string answer = observer.query(std::string(utf8.get_data(), utf8.length()));
        return godot::String::utf8(answer.c_str());
    }
};
class RunWindowsSha256 : public godot::RefCounted {
    GDCLASS(RunWindowsSha256, godot::RefCounted)
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;

    void close() {
        if (hash) BCryptDestroyHash(hash);
        if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
        hash = nullptr;
        algorithm = nullptr;
    }

protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(godot::D_METHOD("start"), &RunWindowsSha256::start);
        godot::ClassDB::bind_method(godot::D_METHOD("update", "bytes"), &RunWindowsSha256::update);
        godot::ClassDB::bind_method(godot::D_METHOD("finish"), &RunWindowsSha256::finish);
    }

public:
    ~RunWindowsSha256() override { close(); }

    godot::Error start() {
        close();
        if (!BCRYPT_SUCCESS(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0))
                || !BCRYPT_SUCCESS(BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0))) {
            close();
            return godot::ERR_UNAVAILABLE;
        }
        return godot::OK;
    }

    godot::Error update(const godot::PackedByteArray &bytes) {
        if (!hash) return godot::ERR_UNCONFIGURED;
        if (bytes.size() > std::numeric_limits<ULONG>::max()) return godot::ERR_INVALID_PARAMETER;
        if (bytes.is_empty()) return godot::OK;
        // BCryptHashData reads the input through a non-const API parameter.
        const auto count = static_cast<ULONG>(bytes.size());
        if (BCRYPT_SUCCESS(BCryptHashData(hash, const_cast<PUCHAR>(bytes.ptr()), count, 0))) {
            return godot::OK;
        }
        close();
        return godot::FAILED;
    }

    godot::PackedByteArray finish() {
        std::array<unsigned char, 32> digest{};
        const auto size = static_cast<ULONG>(digest.size());
        const bool success = hash && BCRYPT_SUCCESS(BCryptFinishHash(hash, digest.data(), size, 0));
        close();
        godot::PackedByteArray result;
        if (success && result.resize(size) == godot::OK) {
            std::memcpy(result.ptrw(), digest.data(), size);
        }
        return result;
    }
};

void initialize_reader(godot::ModuleInitializationLevel level) {
    if (level == godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
        godot::ClassDB::register_class<SteamStatsReader>();
        godot::ClassDB::register_class<SteamStatsObserver>();
        godot::ClassDB::register_class<RunWindowsSha256>();
    }
}
void deinitialize_reader(godot::ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT lsh_stats_reader_init(
        GDExtensionInterfaceGetProcAddress proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization *init) {
    godot::GDExtensionBinding::InitObject binding(proc, library, init);
    binding.register_initializer(initialize_reader);
    binding.register_terminator(deinitialize_reader);
    binding.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);
    return binding.init();
}
