// Independent tuple oracle supplied by the reviewed current/previous image contracts.
#include "../../EFM/source/AesaHostProfile.h"
#include <array>
#include <cstdlib>
#include <iostream>
#include <type_traits>

namespace {
using AesaHostProfile::Image;
using AesaHostProfile::Modules;
using AesaHostProfile::Profile;
constexpr Modules old_images{{0x6ac12468, 0x59a000}, {0x6aae1e0e, 0x46000},
                             {0x6aae1d9b, 0x14000}, {0x6ac122f4, 0x125b000}};
constexpr Modules new_images{{0x6adbad09, 0x68e000}, {0x6ad87426, 0x46000},
                             {0x6acb804e, 0x14000}, {0x6adbace0, 0x127b000}};
unsigned checks = 0;
void require(bool value, const char* message) {
    ++checks;
    if (!value) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
std::array<Image*, 4> fields(Modules& value) {
    return {&value.cockpit, &value.objects, &value.world, &value.general};
}
void exact_offsets() {
    const auto* previous = AesaHostProfile::select(old_images);
    const auto* current = AesaHostProfile::select(new_images);
    if (!previous || !current) {
        require(false, "exact old/current bundle was not selected");
        return;
    }
    require(previous != current, "exact old/current bundles did not select distinct profiles");
    require(previous->ecm_table == 0x1d0778 && previous->ecm_active == 0x65bd0 && previous->ecm_strength == 0x65bc0,
            "previous host ECM offsets changed");
    require(current->ecm_table == 0x1ef6a8 && current->ecm_active == 0x80c70 && current->ecm_strength == 0x80c60,
            "current host ECM offsets changed");
}
void all_image_combinations() {
    unsigned allowed = 0;
    for (unsigned mask = 0; mask < 16; ++mask) {
        Modules candidate = old_images;
        Modules next = new_images;
        const auto destinations = fields(candidate), sources = fields(next);
        for (unsigned module = 0; module < 4; ++module)
            if (mask & (1u << module)) *destinations[module] = *sources[module];
        const auto* profile = AesaHostProfile::select(candidate);
        require((profile != nullptr) == (mask == 0 || mask == 15), "mixed image bundle borrowed a supported profile");
        if (profile) ++allowed;
    }
    require(allowed == 2, "selector admitted more than the two reviewed coherent bundles");
}
void malformed_and_caller_mutation() {
    for (const auto& valid : {old_images, new_images}) {
        for (unsigned module = 0; module < 4; ++module) {
            for (unsigned fault = 0; fault < 5; ++fault) {
                Modules candidate = valid;
                Image& image = *fields(candidate)[module];
                if (fault == 0) image.stamp ^= 1;
                if (fault == 1) image.size ^= 0x1000;
                if (fault == 2) image = {};
                if (fault == 3) image.stamp = 0xffffffffu;
                if (fault == 4) image.size = 0xffffffffu;
                require(!AesaHostProfile::select(candidate), "unknown/zero/out-of-profile image bypassed selection");
            }
        }
        Modules caller = valid;
        const Profile* selected = AesaHostProfile::select(caller);
        caller.general.size = 0;
        require(selected && AesaHostProfile::matches(selected->modules, valid),
                "selected profile borrowed caller storage instead of immutable profile data");
        require(!AesaHostProfile::select(caller), "mutating a previously valid caller tuple retained profile eligibility");
    }
    require(!AesaHostProfile::select(Modules{}), "empty tuple passed the exact image gate");
}
// The selector has no READY/status override argument, and publishes no capability.
using Selector = decltype(&AesaHostProfile::select);
static_assert(std::is_invocable_r_v<const Profile*, Selector, const Modules&>);
static_assert(!std::is_invocable_v<Selector, const Modules&, bool>);
static_assert(!std::is_invocable_v<Selector, bool>);
static_assert(std::is_const_v<std::remove_pointer_t<decltype(AesaHostProfile::select(old_images))>>);
static_assert(AesaHostProfile::select(Modules{}) == nullptr);
}
int main() {
    exact_offsets();
    all_image_combinations();
    malformed_and_caller_mutation();
    std::cout << "PASS " << checks << " exact-bundle/offset/mixed/fault/storage checks; status override excluded by API\n";
    std::cout << "Profile selection alone does not qualify exports, ownership, callbacks or live radar capability.\n";
}
