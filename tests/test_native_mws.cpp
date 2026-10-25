// GPL-3.0-or-later. Guarded native transport, not simulated optical performance.
#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../EFM/source/NativeMWS.cpp"
#include <array>
#include <cassert>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <stdexcept>
template <class T> void store(void *at, const T &value) {
    std::memcpy(at, &value, sizeof(value));
}
unsigned allocations{}, frees{}, constructors{}, destructors{}, throw_at{};
bool fail_allocation{};
int main() {
    using namespace NativeMWS;
    alignas(8) std::array<std::byte, 1176> object{};
    alignas(8) std::array<std::byte, 136> head{}, one{}, two{};
    alignas(8) std::array<std::byte, 512> linked_object{};
    auto linked = reinterpret_cast<std::uintptr_t>(linked_object.data()) + 256;
    const void *device_table = object.data() + 1160;
    const void *contact_table = head.data() + 120;
    Api a{};
    a.device_table = device_table;
    a.contact_table = contact_table;
    a.contacts = [](const void *p) -> const void * { return static_cast<const std::byte *>(p) + 208; };
    a.spike = [](void *, Polar *result, void *c) -> Polar * {
        std::memcpy(result, static_cast<std::byte *>(c) + 64, sizeof(Polar));
        return result;
    };
    auto hp = reinterpret_cast<std::uintptr_t>(head.data());
    auto op = reinterpret_cast<std::uintptr_t>(one.data());
    auto tp = reinterpret_cast<std::uintptr_t>(two.data());
    store(object.data(), device_table);
    store(object.data() + 208, hp);
    store(object.data() + 216, std::size_t{2});
    store(head.data() + 8, op);
    head[25] = std::byte{1};
    for (auto *p : {one.data(), two.data()}) {
        store(p, hp);
        store(p + 16, hp);
        store(p + 40, contact_table);
        store(p + 88, linked);
        store(p + 96, 9.9);
        store(p + 104, Polar{.2, -.1, 1000});
        store(p + 128, unsigned{4});
    }
    store(one.data() + 16, tp);
    store(one.data() + 32, unsigned{101});
    store(two.data() + 32, unsigned{102});
    auto address = reinterpret_cast<std::uintptr_t>(object.data());
    std::vector<Contact> contacts;
    a.allocate = [](std::size_t bytes) -> void * {
        ++allocations;
        return fail_allocation ? nullptr : std::malloc(bytes);
    };
    a.free = [](void *p) { ++frees; std::free(p); };
    a.threat_construct = [](void *p) {
        if (++constructors == throw_at) throw std::runtime_error("test native construction failure");
        std::memset(p, 0, 72);
    };
    a.threat_destroy = [](void *) { ++destructors; };
    assert(initialize_pool(a, address));
    assert(allocations == 1 && constructors == 16 && frees == 0);
    std::uintptr_t begin{}, end{}, capacity{};
    unsigned active{}; unsigned short limit{};
    assert(load(address + 352, begin) && load(address + 360, end) && load(address + 368, capacity));
    assert(end - begin == 16 * 72 && end == capacity);
    assert(load(address + 376, active) && active == 0 && load(address + 384, limit) && limit == 16);
    assert(initialize_pool(a, address) && allocations == 1 && constructors == 16);
    store(object.data() + 376, unsigned{17}); assert(!initialize_pool(a, address));
    store(object.data() + 376, unsigned{0});
    NativeMWS::reset(); assert(frees == 0); // Committed buffer belongs to the native device.
    for (unsigned i = 0; i < 16; ++i) a.threat_destroy(reinterpret_cast<void *>(begin + i * 72));
    a.free(reinterpret_cast<void *>(begin));
    for (auto offset : {352, 360, 368}) store(object.data() + offset, std::uintptr_t{});
    constructors = destructors = 0; throw_at = 4;
    assert(!initialize_pool(a, address) && constructors == 4 && destructors == 3 && frees == 2);
    assert(load(address + 352, begin) && !begin && load(address + 360, end) && !end);
    throw_at = 0; fail_allocation = true;
    assert(!initialize_pool(a, address) && constructors == 4);
    fail_allocation = false;
    assert(collect(a, address, 10, contacts) && contacts.size() == 2 && contacts[0].id == 101);
    assert(contacts[0].az == .2 && contacts[0].el == -.1 && contacts[0].time == 9.9);
    store(one.data() + 128, unsigned{3});
    assert(collect(a, address, 10, contacts) && contacts.size() == 1);
    store(two.data() + 96, 8.0);
    assert(collect(a, address, 10, contacts) && contacts.empty());
    store(one.data() + 128, unsigned{4});
    store(two.data() + 96, 9.9);
    store(two.data() + 16, op);
    assert(!collect(a, address, 10, contacts));
    store(two.data() + 16, hp);
    store(object.data() + 216, std::size_t{513});
    assert(!collect(a, address, 10, contacts));
    store(object.data() + 216, std::size_t{2});
    store(object.data(), static_cast<const void *>(nullptr));
    assert(!collect(a, address, 10, contacts));
    store(object.data(), device_table);
    store(two.data() + 40, static_cast<const void *>(nullptr));
    assert(!collect(a, address, 10, contacts));
    store(two.data() + 40, contact_table);
    store(two.data() + 88, std::uintptr_t{1});
    assert(!collect(a, address, 10, contacts));
    store(two.data() + 88, linked);
    store(one.data() + 104, std::numeric_limits<double>::quiet_NaN());
    assert(!collect(a, address, 10, contacts));
    assert(!collect(a, 0, 10, contacts));
    a.spike = nullptr;
    assert(!collect(a, address, 10, contacts));
    std::cout << "Native optical transport: ownership, bounded map, confirmation, timestamp, direction and "
                 "corruption guards PASS\n";
}
