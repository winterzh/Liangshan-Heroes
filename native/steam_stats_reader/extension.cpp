#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include "windows_api.hpp"
#include "observer.hpp"
#include <bcrypt.h>
#include <shellapi.h>
#include <string>
#include <string_view>
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

using FileStamp = std::array<uint64_t, 6>;
using PayloadStamp = std::array<FileStamp, 2>;
PayloadStamp startup_payload{};
bool startup_payload_available = false;

bool query_file_stamp(const std::wstring &path, FileStamp &stamp) {
    HANDLE file = CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
            OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    BY_HANDLE_FILE_INFORMATION info{};
    FILE_BASIC_INFO basic{};
    const bool ok = GetFileInformationByHandle(file, &info)
            && GetFileInformationByHandleEx(file, FileBasicInfo, &basic, static_cast<DWORD>(sizeof(basic)))
            && !(info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT));
    CloseHandle(file);
    if (!ok) return false;
    stamp = {info.dwVolumeSerialNumber,
            (uint64_t(info.nFileIndexHigh) << 32) | info.nFileIndexLow,
            (uint64_t(info.nFileSizeHigh) << 32) | info.nFileSizeLow,
            static_cast<uint64_t>(basic.CreationTime.QuadPart),
            static_cast<uint64_t>(basic.LastWriteTime.QuadPart),
            static_cast<uint64_t>(basic.ChangeTime.QuadPart)};
    return true;
}

bool query_payload_stamp(PayloadStamp &stamp) {
    std::wstring executable(32768, L'\0');
    const DWORD count = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
    if (!count || count >= executable.size()) return false;
    executable.resize(count);
    const auto extension = executable.find_last_of(L'.');
    if (extension == std::wstring::npos || extension <= executable.find_last_of(L"/\\")) return false;
    const std::wstring pack = executable.substr(0, extension) + L".pck";
    return query_file_stamp(executable, stamp[0]) && query_file_stamp(pack, stamp[1]);
}
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
        godot::ClassDB::bind_method(godot::D_METHOD("payload_stamp", "at_launch"), &RunWindowsSha256::payload_stamp);
        godot::ClassDB::bind_method(godot::D_METHOD("uses_default_project"), &RunWindowsSha256::uses_default_project);
    }

public:
    ~RunWindowsSha256() override { close(); }

    godot::PackedByteArray payload_stamp(bool at_launch) const {
        PayloadStamp current{};
        if (at_launch) {
            if (!startup_payload_available) return {};
            current = startup_payload;
        } else if (!query_payload_stamp(current)) {
            return {};
        }
        godot::PackedByteArray bytes;
        if (bytes.resize(sizeof(current)) == godot::OK) {
            std::memcpy(bytes.ptrw(), current.data(), sizeof(current));
        }
        return bytes;
    }

    bool uses_default_project() const {
        // Godot consumes setup flags before exposing script-visible arguments.
        int count = 0;
        wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &count);
        if (argv == nullptr) return false;
        bool canonical = true;
        for (int i = 1; i < count; ++i) {
            std::wstring_view arg = argv[i];
            if (arg == L"--") break;
            const auto flag = arg.substr(0, arg.find(L'='));
            if (flag == L"--main-pack" || flag == L"--path" || flag == L"--upwards"
                    || flag == L"--script" || flag == L"-s" || flag == L"--editor"
                    || flag == L"-e" || flag == L"--project-manager" || flag == L"-p"
                    || arg == L"project.godot" || (arg.size() >= 14 && arg.substr(arg.size() - 14) == L"/project.godot")
                    || (arg.size() >= 14 && arg.substr(arg.size() - 14) == L"\\project.godot")) {
                canonical = false;
                break;
            }
        }
        LocalFree(argv);
        return canonical;
    }

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
        startup_payload_available = query_payload_stamp(startup_payload);
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
