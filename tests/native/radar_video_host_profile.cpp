// GPL-3.0-or-later. Independent renderer release identities and mixed-image cases.
#include "../../EFM/source/GroundVideoHostProfile.h"
#include <array>
#include <cstdio>
#include <type_traits>

namespace {
using GroundVideoHostProfile::Image;
using GroundVideoHostProfile::Modules;
using GroundVideoHostProfile::select;
constexpr std::array<Image, 5> prior{{{0x6ac12468, 0x59a000}, {0x6ac12454, 0x312000},
    {0x6aae1e3e, 0x70000}, {0x6aae1e38, 0xa9000}, {0x6aae1df2, 0x62000}}};
constexpr std::array<Image, 5> current{{{0x6adbad09, 0x68e000}, {0x6ad87745, 0x340000},
    {0x6acb811a, 0x70000}, {0x6acb8107, 0xa9000}, {0x6acb8063, 0x62000}}};
constexpr Modules modules(const std::array<Image, 5>& images) {
    return {images[0], images[1], images[2], images[3], images[4]};
}
static_assert(std::is_same_v<decltype(select(Modules{})), const GroundVideoHostProfile::Profile*>);
static_assert(noexcept(select(Modules{})));
static_assert(select(Modules{}) == nullptr);
unsigned checks{}, failures{};
void check(bool accepted, const char* description) {
    ++checks;
    if (!accepted) { ++failures; std::printf("FAIL %s\n", description); }
}
void mixed_images() {
    for (unsigned mask = 0; mask < 32; ++mask) {
        auto images = prior;
        for (unsigned image = 0; image < images.size(); ++image)
            if (mask & (1u << image)) images[image] = current[image];
        const auto selected = select(modules(images));
        check((selected != nullptr) == (mask == 0 || mask == 31),
              "only the two complete renderer release bundles are admitted");
        if (selected) check(selected->build == (mask == 0 ? GroundVideoHostProfile::Build::prior
                                                        : GroundVideoHostProfile::Build::current),
                            "selected identity belongs to the same complete release");
    }
}
void changed_or_missing_images() {
    for (const auto& supported : {prior, current}) {
        for (unsigned image = 0; image < supported.size(); ++image) {
            for (unsigned fault = 0; fault < 6; ++fault) {
                auto candidate = supported;
                if (fault == 0) candidate[image].stamp ^= 1;
                if (fault == 1) candidate[image].size ^= 0x1000;
                if (fault == 2) candidate[image].stamp = 0;
                if (fault == 3) candidate[image].size = 0;
                if (fault == 4) candidate[image].stamp = 0xffffffff;
                if (fault == 5) candidate[image].size = 0xffffffff;
                check(select(modules(candidate)) == nullptr,
                      "a missing, changed or out-of-range required image is rejected");
            }
        }
    }
}
void immutable_selection() {
    auto candidate = modules(current);
    const auto selected = select(candidate);
    candidate.cockpit = {};
    check(selected && GroundVideoHostProfile::matches(selected->modules, modules(current)),
          "a caller cannot mutate the selected static release record");
    check(select(candidate) == nullptr, "selection checks the caller's current image tuple");
}
}
int main() {
    mixed_images(); changed_or_missing_images(); immutable_selection();
    std::printf("renderer host profile checks=%u failures=%u\n", checks, failures);
    return failures ? 1 : 0;
}
