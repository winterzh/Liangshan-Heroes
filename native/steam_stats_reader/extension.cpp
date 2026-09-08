#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include "windows_api.hpp"

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
void initialize_reader(godot::ModuleInitializationLevel level) {
    if (level == godot::MODULE_INITIALIZATION_LEVEL_SCENE) godot::ClassDB::register_class<SteamStatsReader>();
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
