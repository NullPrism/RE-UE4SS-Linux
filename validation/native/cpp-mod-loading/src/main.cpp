#include <cstddef>
#include <unistd.h>

#include <Mod/CppUserModBase.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UObjectGlobals.hpp>

namespace
{
    template <std::size_t Size>
    auto emit_marker(const char (&message)[Size]) noexcept -> void
    {
        static_assert(Size > 1);

        const auto ignored_message_result =
            ::write(STDERR_FILENO, message, Size - 1);

        const auto ignored_newline_result =
            ::write(STDERR_FILENO, "\n", 1);

        static_cast<void>(ignored_message_result);
        static_cast<void>(ignored_newline_result);
    }

    class NullPrismNativeAcceptance final
        : public RC::CppUserModBase
    {
      public:
        NullPrismNativeAcceptance()
        {
            emit_marker(
                "[NullPrismNativeAcceptance] constructor"
            );
        }

        ~NullPrismNativeAcceptance() override
        {
            emit_marker(
                "[NullPrismNativeAcceptance] destructor"
            );
        }

        auto on_program_start() -> void override
        {
            emit_marker(
                "[NullPrismNativeAcceptance] on_program_start"
            );
        }

        auto on_cpp_mods_loaded() -> void override
        {
            emit_marker(
                "[NullPrismNativeAcceptance] on_cpp_mods_loaded"
            );
        }

        auto on_unreal_init() -> void override
        {
            emit_marker(
                "[NullPrismNativeAcceptance] on_unreal_init"
            );

            auto* object_class =
                RC::Unreal::UObjectGlobals::StaticFindObject<
                    RC::Unreal::UObject*>(
                    nullptr,
                    nullptr,
                    STR("/Script/CoreUObject.Object")
                );

            if (object_class == nullptr)
            {
                emit_marker(
                    "[NullPrismNativeAcceptance] "
                    "StaticFindObject result=null"
                );

                emit_marker(
                    "[NullPrismNativeAcceptance] RESULT=FAIL"
                );

                return;
            }

            emit_marker(
                "[NullPrismNativeAcceptance] "
                "StaticFindObject result=valid"
            );

            emit_marker(
                "[NullPrismNativeAcceptance] RESULT=PASS"
            );
        }
    };
}

extern "C"
__attribute__((visibility("default")))
auto start_mod() -> RC::CppUserModBase*
{
    emit_marker(
        "[NullPrismNativeAcceptance] start_mod export"
    );

    return new NullPrismNativeAcceptance{};
}

extern "C"
__attribute__((visibility("default")))
auto uninstall_mod(RC::CppUserModBase* mod) -> void
{
    emit_marker(
        "[NullPrismNativeAcceptance] uninstall_mod export"
    );

    delete mod;
}
