// GPL-3.0-or-later. Actual owning video Api with inert, test-owned PE images.
#include <Windows.h>
#include <array>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string_view>
#include <vector>

namespace {
struct Image {
    DWORD stamp{};
    DWORD size{};
};
constexpr std::array<Image, 5> video_prior_images{{
    {0x6ac12468, 0x59a000}, {0x6ac12454, 0x312000},
    {0x6aae1e3e, 0x70000}, {0x6aae1e38, 0xa9000},
    {0x6aae1df2, 0x62000}
}};
constexpr std::array<Image, 5> video_current_images{{
    {0x6adbad09, 0x68e000}, {0x6ad87745, 0x340000},
    {0x6acb811a, 0x70000}, {0x6acb8107, 0xa9000},
    {0x6acb8063, 0x62000}
}};
constexpr std::array video_module_names{
    L"CockpitBase.dll", L"Visualizer.dll", L"SceneRenderer.dll",
    L"enlight.dll", L"GraphicsVista.dll", L"World.dll"
};
struct Export {
    unsigned module{};
    const char* name{};
};
constexpr std::array<Export, 8> video_required_exports{{
    {0, "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"},
    {0, "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"},
    {0, "?get_context@ccContextRelatedObject@cockpit@@QEBAPEAVccCockpitContext@2@XZ"},
    {0, "?get_controller@ccDrawable@cockpit@@QEAAPEAVavDevice@2@XZ"},
    {5, "?GetModelTime@wTime@@SANXZ"},
    {4, "??0Camera@Graphics@@QEAA@W4Type@01@@Z"},
    {0, "?render_targets@ccDrawable@cockpit@@2V?$vector@PEAVccDrawable@cockpit@@V?$allocator@PEAVccDrawable@cockpit@@@ed@@@ed@@A"},
    {0, "??_7ccIndicator@cockpit@@6BccContextRelatedObject@1@@"}
}};
unsigned checks{};
unsigned failures{};
void check(bool condition, const char* message) {
    ++checks;
    if (!condition) {
        ++failures;
        std::printf("FAIL %s\n", message);
    }
}
struct Fixture {
    std::array<std::vector<std::byte>, 6> modules;
    std::string_view denied;
    int missing = -1;
    unsigned module_requests{};
    unsigned export_requests{};
    unsigned unexpected_requests{};
    Fixture() {
        constexpr std::array<std::size_t, 6> capacity{
            0x68e000, 0x340000, 0x70000, 0xa9000, 0x62000, 0x14000
        };
        for (unsigned i = 0; i < modules.size(); ++i) modules[i].resize(capacity[i]);
    }
    IMAGE_DOS_HEADER& dos(unsigned index) {
        return *reinterpret_cast<IMAGE_DOS_HEADER*>(modules[index].data());
    }
    IMAGE_NT_HEADERS64& pe(unsigned index) {
        return *reinterpret_cast<IMAGE_NT_HEADERS64*>(modules[index].data() + 128);
    }
    HMODULE handle(unsigned index) const {
        return reinterpret_cast<HMODULE>(const_cast<std::byte*>(modules[index].data()));
    }
    void reset(unsigned current_mask) {
        denied = {};
        missing = -1;
        module_requests = 0;
        export_requests = 0;
        unexpected_requests = 0;
        for (unsigned i = 0; i < modules.size(); ++i) {
            std::memset(modules[i].data(), 0, 512);
            dos(i).e_magic = IMAGE_DOS_SIGNATURE;
            dos(i).e_lfanew = 128;
            pe(i).Signature = IMAGE_NT_SIGNATURE;
            pe(i).FileHeader.Machine = IMAGE_FILE_MACHINE_AMD64;
            pe(i).OptionalHeader.Magic = IMAGE_NT_OPTIONAL_HDR64_MAGIC;
            const Image image = i < 5 ? ((current_mask & (1u << i)) ? video_current_images[i] : video_prior_images[i])
                                      : Image{0x6acb804e, 0x14000};
            pe(i).FileHeader.TimeDateStamp = image.stamp;
            pe(i).OptionalHeader.SizeOfImage = image.size;
        }
    }
} fixture;
void inert_export() { std::abort(); }
HMODULE WINAPI fixture_module(LPCWSTR name) {
    ++fixture.module_requests;
    for (unsigned i = 0; i < video_module_names.size(); ++i) {
        if (std::wcscmp(name, video_module_names[i]) == 0) {
            if (fixture.missing == static_cast<int>(i)) return nullptr;
            return fixture.handle(i);
        }
    }
    ++fixture.unexpected_requests;
    return nullptr;
}
FARPROC WINAPI fixture_export(HMODULE module, LPCSTR name) {
    ++fixture.export_requests;
    for (const auto& symbol : video_required_exports) {
        if (std::strcmp(name, symbol.name) != 0) continue;
        if (module != fixture.handle(symbol.module)) {
            ++fixture.unexpected_requests;
            return nullptr;
        }
        if (fixture.denied == name) return nullptr;
        return reinterpret_cast<FARPROC>(&inert_export);
    }
    ++fixture.unexpected_requests;
    return nullptr;
}
}
#define GetModuleHandleW fixture_module
#define GetProcAddress fixture_export
#include "../../EFM/source/NativeGroundVideo.cpp"
#undef GetModuleHandleW
#undef GetProcAddress

namespace {
using Api = NativeGroundVideo::Api;
void exact_bundles() {
    for (unsigned mask = 0; mask < 32; ++mask) {
        fixture.reset(mask);
        Api api;
        api.initialize();
        const bool supported = mask == 0 || mask == 31;
        check(api.ready == supported, "only complete old/current renderer tuples bind");
        check(api.reason == (supported ? 0 : 2), "mixed tuple reports profile refusal");
        check(api.incompatible == !supported, "only unsupported tuples latch incompatible");
        check(fixture.export_requests == (supported ? video_required_exports.size() : 0),
              "profile admission precedes every export lookup");
        check(fixture.unexpected_requests == 0, "Api binds only its declared capability subset");
    }
}
enum class Fault { Mz, Pe, Machine, Magic, NegativeOffset, HugeOffset, Stamp, Size };
void corrupt(unsigned module, Fault fault) {
    switch (fault) {
    case Fault::Mz: fixture.dos(module).e_magic = 0; break;
    case Fault::Pe: fixture.pe(module).Signature = 0; break;
    case Fault::Machine: fixture.pe(module).FileHeader.Machine = IMAGE_FILE_MACHINE_I386; break;
    case Fault::Magic: fixture.pe(module).OptionalHeader.Magic = IMAGE_NT_OPTIONAL_HDR32_MAGIC; break;
    case Fault::NegativeOffset: fixture.dos(module).e_lfanew = -1; break;
    case Fault::HugeOffset: fixture.dos(module).e_lfanew = 1048577; break;
    case Fault::Stamp: fixture.pe(module).FileHeader.TimeDateStamp ^= 1; break;
    case Fault::Size: fixture.pe(module).OptionalHeader.SizeOfImage ^= 0x1000; break;
    }
}
void malformed_headers() {
    constexpr std::array faults{Fault::Mz, Fault::Pe, Fault::Machine, Fault::Magic,
                               Fault::NegativeOffset, Fault::HugeOffset, Fault::Stamp, Fault::Size};
    for (unsigned mask : {0u, 31u}) {
        for (unsigned module = 0; module < 5; ++module) {
            for (Fault fault : faults) {
                fixture.reset(mask);
                corrupt(module, fault);
                Api api;
                api.initialize();
                check(!api.ready && api.incompatible && api.reason == 2,
                      "malformed private image fails closed");
                check(fixture.export_requests == 0, "malformed PE cannot resolve callable interfaces");
                check(!api.context && !api.clock && !api.camera && !api.table && !api.targets,
                      "failed profile does not publish partially bound Api pointers");
            }
        }
    }
}
void missing_modules_retry() {
    for (unsigned mask : {0u, 31u}) {
        for (unsigned module = 0; module < video_module_names.size(); ++module) {
            fixture.reset(mask);
            fixture.missing = static_cast<int>(module);
            Api api;
            api.initialize();
            check(!api.ready && !api.incompatible && api.reason == 1,
                  "each absent renderer/clock module remains retryable");
            check(fixture.export_requests == 0, "missing module prevents premature export lookup");
            fixture.missing = -1;
            api.initialize();
            check(api.ready && !api.incompatible && api.reason == 0,
                  "same Api binds after its missing module arrives");
            check(fixture.unexpected_requests == 0, "module retry stays inside the six-module subset");
        }
    }
}
void missing_exports_retry() {
    for (unsigned mask : {0u, 31u}) {
        for (const auto& symbol : video_required_exports) {
            fixture.reset(mask);
            fixture.denied = symbol.name;
            Api api;
            api.initialize();
            check(!api.ready && !api.incompatible && api.reason == 3,
                  "each of eight required exports has a distinct retryable bind failure");
            fixture.denied = {};
            api.initialize();
            check(api.ready && !api.incompatible && api.reason == 0,
                  "same Api recovers after required export becomes available");
            check(fixture.unexpected_requests == 0, "required exports resolve from their owning modules");
        }
    }
}
void unsupported_profile_latches() {
    for (unsigned module = 0; module < 5; ++module) {
        fixture.reset(31);
        corrupt(module, Fault::Stamp);
        Api api;
        api.initialize();
        fixture.reset(31);
        api.initialize();
        check(!api.ready && api.incompatible && api.reason == 2,
              "unknown image cannot rebind without owning lifecycle reset");
        check(fixture.export_requests == 0, "latched incompatible state dispatches no export lookup");
    }
}
void clock_is_named_only() {
    fixture.reset(31);
    std::memset(fixture.modules[5].data(), 0, 512);
    Api api;
    api.initialize();
    check(api.ready && api.reason == 0, "World clock export has no renderer private-profile dependency");
    check(fixture.export_requests == video_required_exports.size(), "clock still requires its named typed export");
}
void gpu_exports_are_optional() {
    constexpr std::array optional{
        "?getDevice@DX11Renderer@RenderAPI@@QEAAPEAUID3D11Device@@XZ",
        "?getDeviceContext@DX11Renderer@RenderAPI@@QEAAPEAUID3D11DeviceContext@@XZ",
        "?getRenderTargetInternal@DX11Renderer@RenderAPI@@AEAA?AV?$Ptr@UITexture@RenderAPI@@UDeleter@12@@ed@@PEBD@Z",
        "?callFunction@RenderingThread@ed@@YAXAEBV?$function@$$A6AXXZ@std@@PEBD@Z"
    };
    for (const char* name : optional) {
        fixture.reset(31);
        fixture.denied = name;
        Api api;
        api.initialize();
        check(api.ready && api.reason == 0, "optional GPU diagnostic exports do not gate normal video binding");
        check(fixture.export_requests == video_required_exports.size() && fixture.unexpected_requests == 0,
              "normal video Api never probes optional GPU modules or exports");
    }
}
}
int main() {
    exact_bundles();
    malformed_headers();
    missing_modules_retry();
    missing_exports_retry();
    unsupported_profile_latches();
    clock_is_named_only();
    gpu_exports_are_optional();
    std::printf("actual video Api profile checks=%u failures=%u (inert images; exports abort if invoked)\n",
                checks, failures);
    return failures ? 1 : 0;
}
