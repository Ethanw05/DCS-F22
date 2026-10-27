// GPL-3.0-or-later. Owned common avMLWS optical observations, never shot events.
#include "NativeMWS.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <vector>
#include <algorithm>
namespace NativeMWS {
namespace {
bool readable(std::uintptr_t address, std::size_t size) {
    MEMORY_BASIC_INFORMATION m{};
    if (!address || !VirtualQuery(reinterpret_cast<void *>(address), &m, sizeof(m)))
        return false;
    return m.State == MEM_COMMIT && !(m.Protect & (PAGE_GUARD | PAGE_NOACCESS)) && size <= m.RegionSize &&
           address >= reinterpret_cast<std::uintptr_t>(m.BaseAddress) &&
           address - reinterpret_cast<std::uintptr_t>(m.BaseAddress) <= m.RegionSize - size;
}
template <class T> bool load(std::uintptr_t address, T &out) {
    if (!readable(address, sizeof(T)))
        return false;
    std::memcpy(&out, reinterpret_cast<void *>(address), sizeof(T));
    return true;
}
struct Polar {
    double az{}, el{}, range{};
};
struct Contact {
    unsigned id{};
    double time{}, az{}, el{};
    Polar world{};
    bool threat{};
};
// A low bearing rate alone also accepts a friendly missile flying away.
// Classify only native optical observations, using measured relative motion.
// These are mod warning-policy limits, not claimed aircraft specifications.
struct ApproachFilter {
    struct Track {double time{},n{},u{},e{};bool threat{};};
    std::map<unsigned,Track> tracks;
    bool observe(unsigned id,double time,const Polar &p) {
        if(!std::isfinite(time)||!std::isfinite(p.az)||!std::isfinite(p.el)||
           !std::isfinite(p.range)||p.range<1||p.range>150000)return false;
        const double ce=std::cos(p.el),n=p.range*ce*std::cos(p.az),u=p.range*std::sin(p.el),e=p.range*ce*std::sin(p.az);
        auto it=tracks.find(id);
        if(it==tracks.end()||time<it->second.time||time-it->second.time>1.) {
            tracks[id]={time,n,u,e,false};return false;
        }
        auto &old=it->second;const double dt=time-old.time;
        if(dt<.1)return old.threat;
        const double vn=(n-old.n)/dt,vu=(u-old.u)/dt,ve=(e-old.e)/dt;
        const double dot=n*vn+u*vu+e*ve,speed2=vn*vn+vu*vu+ve*ve;
        const double closing=-dot/p.range,tca=speed2>1?-dot/speed2:-1;
        const double miss=std::hypot(n+vn*tca,u+vu*tca,e+ve*tca);
        const bool threat=closing>25&&tca>0&&tca<=60&&miss<=std::max(300.,p.range*.03);
        old={time,n,u,e,threat};return threat;
    }
    void expire(double now) {for(auto i=tracks.begin();i!=tracks.end();)if(now<i->second.time||now-i->second.time>1.)i=tracks.erase(i);else ++i;}
};
ApproachFilter approach;
struct Api {
    using Context = void *(__cdecl *)();
    using Device = void *(__fastcall *)(void *, unsigned);
    using Method = void(__fastcall *)(void *);
    using Contacts = const void *(__fastcall *)(const void *);
    using Spike = Polar *(__fastcall *)(void *, Polar *, void *);
    using Clock = double(__cdecl *)();
    using Allocate = void *(__cdecl *)(std::size_t);
    using Free = void(__cdecl *)(void *);
    Context context{};
    Device device{};
    Method scan{}, clear{}, threat_construct{}, threat_destroy{};
    Allocate allocate{};
    Free free{};
    Contacts contacts{};
    Spike spike{},world_spike{};
    Clock clock{};
    const void *device_table{};
    const void *contact_table{};
    bool ready{};
    int reason = 1;
    void initialize() {
        if (ready || reason == 2)
            return;
        auto m = GetModuleHandleW(L"CockpitBase.dll"), w = GetModuleHandleW(L"World.dll");
        if (!m || !w)
            return;
        auto base = reinterpret_cast<std::uintptr_t>(m);
        IMAGE_DOS_HEADER dos{};
        IMAGE_NT_HEADERS64 pe{};
        if (!load(base, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE || dos.e_lfanew < 0 ||
            !load(base + dos.e_lfanew, pe) || pe.Signature != IMAGE_NT_SIGNATURE ||
            pe.FileHeader.TimeDateStamp != 0x6ac12468 || pe.OptionalHeader.SizeOfImage != 0x59a000) {
            reason = 2;
            return;
        }
        context = reinterpret_cast<Context>(
            GetProcAddress(m, "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"));
        device = reinterpret_cast<Device>(
            GetProcAddress(m, "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"));
        scan = reinterpret_cast<Method>(GetProcAddress(m, "?update@avMLWS@cockpit@@UEAAXXZ"));
        threat_construct = reinterpret_cast<Method>(GetProcAddress(m, "??0MWS_Threat@cockpit@@QEAA@XZ"));
        threat_destroy = reinterpret_cast<Method>(GetProcAddress(m, "??1MWS_Threat@cockpit@@QEAA@XZ"));
        // Exact native malloc/free imports, audited in this guarded PE profile.
        load(base + 0x449470, allocate);
        load(base + 0x449460, free);
        clear = reinterpret_cast<Method>(GetProcAddress(m, "?ClearThreats@avMLWS@cockpit@@IEAAXXZ"));
        contacts = reinterpret_cast<Contacts>(
            GetProcAddress(m, "?get_contacts@avMLWS@cockpit@@QEBAAEBV?$map@IVMLWS_contact@cockpit@@U?$less@I@"
                              "std@@V?$allocator@U?$pair@$$CBIVMLWS_contact@cockpit@@@std@@@ed@@@std@@XZ"));
        spike = reinterpret_cast<Spike>(
            GetProcAddress(m, "?get_spike@avMLWS@cockpit@@IEAA?AVPolar@Math@@AEAVMLWS_contact@2@@Z"));
        world_spike = reinterpret_cast<Spike>(
            GetProcAddress(m, "?get_spike_world@avMLWS@cockpit@@IEAA?AVPolar@Math@@AEAVMLWS_contact@2@@Z"));
        device_table = GetProcAddress(m, "??_7avMLWS@cockpit@@6BccContextRelatedObject@1@@");
        // This local vtable is not exported. IDA verifies its first destructor
        // and RVA in the exact timestamp/image profile checked above.
        contact_table = reinterpret_cast<const void *>(base + 0x465098);
        const void *destructor{};
        if (!load(base + 0x465098, destructor) ||
            destructor != reinterpret_cast<const void *>(base + 0x334c80)) {
            reason = 2;
            return;
        }
        clock = reinterpret_cast<Clock>(GetProcAddress(w, "?GetModelTime@wTime@@SANXZ"));
        ready = context && device && scan && clear && contacts && spike && world_spike && clock && device_table &&
                contact_table && threat_construct && threat_destroy && allocate && free;
        reason = ready ? 0 : 3;
    }
};
Api api;
std::map<std::string, void *> handles;
double last = -100;
bool was_powered = false;
void put(EDPARAM &p, const std::string &n, double value) {
    auto &h = handles[n];
    if (!h)
        h = p.getParamHandle(n.c_str());
    p.setParamNumber(h, value);
}
double get(EDPARAM &p, const std::string &n) {
    auto &h = handles[n];
    if (!h)
        h = p.getParamHandle(n.c_str());
    return p.getParamNumber(h);
}
bool owned(const Api &a, std::uintptr_t object) {
    const void *table{};
    return readable(object, 1176) && load(object, table) && table == a.device_table;
}
// The shared base constructor leaves its warning-slot vector empty and its
// count/limit unset. Derived aircraft normally initialize that hardware pool.
// Construct empty slots using the native allocator/constructors. After commit,
// the native device destructor owns their LinkBase cleanup and deallocation.
bool initialize_pool(const Api &a, std::uintptr_t object) {
    constexpr std::size_t count = 16, stride = 72, bytes = count * stride;
    if (!owned(a, object) || !a.allocate || !a.free || !a.threat_construct || !a.threat_destroy)
        return false;
    std::uintptr_t begin{}, end{}, capacity{};
    if (!load(object + 352, begin) || !load(object + 360, end) || !load(object + 368, capacity))
        return false;
    if (begin || end || capacity) {
        unsigned active{};
        unsigned short limit{};
        return begin && end >= begin && end - begin == bytes && capacity == end &&
               readable(begin, bytes) && load(object + 376, active) && load(object + 384, limit) &&
               limit == count && active <= count;
    }
    struct Staging {
        const Api &a;
        void *buffer;
        std::size_t constructed{};
        ~Staging() {
            if (!buffer) return;
            for (std::size_t i = constructed; i > 0; --i)
                a.threat_destroy(static_cast<std::byte *>(buffer) + (i - 1) * stride);
            a.free(buffer);
        }
    } staging{a, a.allocate(bytes)};
    if (!staging.buffer) return false;
    try {
        for (; staging.constructed < count; ++staging.constructed)
            a.threat_construct(static_cast<std::byte *>(staging.buffer) + staging.constructed * stride);
    } catch (...) {
        return false;
    }
    begin = reinterpret_cast<std::uintptr_t>(staging.buffer);
    end = begin + bytes;
    const unsigned active = 0;
    const unsigned short limit = count;
    std::memcpy(reinterpret_cast<void *>(object + 352), &begin, sizeof(begin));
    std::memcpy(reinterpret_cast<void *>(object + 360), &end, sizeof(end));
    std::memcpy(reinterpret_cast<void *>(object + 368), &end, sizeof(end));
    std::memcpy(reinterpret_cast<void *>(object + 376), &active, sizeof(active));
    std::memcpy(reinterpret_cast<void *>(object + 384), &limit, sizeof(limit));
    staging.buffer = nullptr;
    return true;
}
// Audited native MSVC map: head/size; node L/P/R0/8/16, nil25,key32,
// MLWS_contact40, linked object88, observation time96, confirmation hits128.
// No allocations or iterator ABI cross the DLL boundary; nodes are read only.
bool collect(const Api &a, std::uintptr_t object, double now, std::vector<Contact> &result,
             unsigned *max_hits = nullptr) {
    result.clear();
    if (max_hits)
        *max_hits = 0;
    if (!owned(a, object) || !a.contacts || !a.spike || !a.world_spike || !std::isfinite(now))
        return false;
    auto map = reinterpret_cast<std::uintptr_t>(a.contacts(reinterpret_cast<void *>(object)));
    if (map != object + 208)
        return false;
    std::uintptr_t head{}, root{};
    std::size_t count{};
    unsigned char nil{};
    if (!load(map, head) || !load(map + 8, count) || count > 512 || !load(head + 25, nil) || nil != 1 ||
        !load(head + 8, root))
        return false;
    std::vector<std::uintptr_t> pending{root};
    std::set<std::uintptr_t> seen;
    while (!pending.empty()) {
        auto node = pending.back();
        pending.pop_back();
        if (node == head)
            continue;
        if (seen.size() >= count || !seen.insert(node).second || !readable(node, 136) ||
            !load(node + 25, nil) || nil)
            return false;
        std::uintptr_t left{}, right{}, link{};
        const void *table{};
        unsigned id{}, hits{};
        double time{};
        if (!load(node, left) || !load(node + 16, right) || !load(node + 32, id) || !load(node + 40, table) ||
            !load(node + 88, link) || !load(node + 96, time) || !load(node + 128, hits))
            return false;
        pending.push_back(left);
        pending.push_back(right);
        if (table != a.contact_table)
            return false;
        if (max_hits && hits > *max_hits)
            *max_hits = hits;
        // Preserve the original native >3-observation warning confirmation.
        if (!id || !link || hits <= 3 || !std::isfinite(time) || time > now + .05 || now - time > .5)
            continue;
        // Native get_spike dereferences the LinkTarget as MovingObject at -256.
        if (link < 256 || !readable(link - 256, sizeof(void *)))
            return false;
        Polar direction{};
        a.spike(reinterpret_cast<void *>(object), &direction, reinterpret_cast<void *>(node + 40));
        if (!std::isfinite(direction.az) || !std::isfinite(direction.el) || std::abs(direction.az) > 3.142 ||
            std::abs(direction.el) > 1.572)
            return false;
        Polar world{};
        a.world_spike(reinterpret_cast<void *>(object), &world, reinterpret_cast<void *>(node + 40));
        if(!std::isfinite(world.az)||!std::isfinite(world.el)||!std::isfinite(world.range)||world.range<1)return false;
        result.push_back({id, time, direction.az, direction.el, world});
    }
    return seen.size() == count;
}
} // namespace
void reset() {
    handles.clear();
    api = {};
    last = -100;
    was_powered = false;
    approach.tracks.clear();
}
void update(EDPARAM &p) {
    api.initialize();
    if (!api.ready) {
        put(p, "F22_MWS_NATIVE_READY", 0);
        put(p, "F22_MWS_NATIVE_REASON", api.reason);
        return;
    }
    const double now = api.clock();
    if (!std::isfinite(now))
        return;
    if (now < last) {
        last = -100;
        was_powered = false;
        approach.tracks.clear();
    }
    if (now - last < .05)
        return;
    last = now;
    put(p, "F22_MWS_NATIVE_READY", 0);
    auto context = api.context();
    const double id = get(p, "F22_MWS_DEVICE_ID");
    if (!context || !std::isfinite(id) || id < 1 || id > 255 || id != std::floor(id))
        return;
    auto object = reinterpret_cast<std::uintptr_t>(api.device(context, static_cast<unsigned>(id)));
    if (!owned(api, object)) {
        put(p, "F22_MWS_NATIVE_REASON", 4);
        return;
    }
    std::uintptr_t eyes_begin{}, eyes_end{};
    double angular_limit{};
    std::size_t eye_count{};
    if (load(object + 184, eyes_begin) && load(object + 192, eyes_end) && eyes_end >= eyes_begin &&
        (eyes_end - eyes_begin) % 144 == 0 && eyes_end - eyes_begin <= 144 * 64) {
        eye_count = (eyes_end - eyes_begin) / 144;
        put(p, "F22_MWS_NATIVE_EYE_COUNT", eye_count);
    } else
        put(p, "F22_MWS_NATIVE_EYE_COUNT", -1);
    if (load(object + 1160, angular_limit))
        put(p, "F22_MWS_NATIVE_ANGULAR_LIMIT", angular_limit);
    unsigned char single_search{};
    if (!eye_count || !load(object + 225, single_search) || single_search) {
        // This flag bypasses native optical-eye visibility. Never enable it.
        put(p, "F22_MWS_NATIVE_REASON", 6);
        return;
    }
    if (!initialize_pool(api, object)) {
        put(p, "F22_MWS_NATIVE_REASON", 7);
        return;
    }
    const bool powered = get(p, "F22_MWS_SUPPLY") > .5;
    // The common optical computation has no electrical gate. Our powered bus
    // owns scheduling; no native voltage or detection flags are fabricated.
    std::vector<Contact> found;
    unsigned max_hits{};
    std::size_t raw_count{};
    if (powered) {
        api.scan(reinterpret_cast<void *>(object));
        if (!collect(api, object, now, found, &max_hits) || !load(object + 216, raw_count)) {
            put(p, "F22_MWS_NATIVE_REASON", 5);
            return;
        }
    } else if (was_powered) {
        api.clear(reinterpret_cast<void *>(object));approach.tracks.clear();
    }
    approach.expire(now);unsigned threat_count{};
    for(auto &c:found) {c.threat=approach.observe(c.id,c.time,c.world);if(c.threat)++threat_count;}
    std::stable_sort(found.begin(),found.end(),[](const Contact&a,const Contact&b){return a.threat!=b.threat?a.threat>b.threat:a.id<b.id;});
    was_powered = powered;
    put(p, "F22_MWS_NATIVE_READY", 1);
    put(p, "F22_MWS_NATIVE_REASON", 0);
    put(p, "F22_MWS_NATIVE_TIME", now);
    put(p, "F22_MWS_NATIVE_COUNT", found.size());
    put(p, "F22_MWS_NATIVE_RAW_COUNT", raw_count);
    put(p, "F22_MWS_NATIVE_MAX_HITS", max_hits);
    put(p, "F22_MWS_NATIVE_THREAT_COUNT", threat_count);
    for (std::size_t i = 0; i < 16; ++i) {
        auto prefix = std::string("F22_MWS_NATIVE_") + (i < 9 ? "0" : "") + std::to_string(i + 1) + "_";
        const auto *c = i < found.size() ? &found[i] : nullptr;
        put(p, prefix + "VALID", c ? 1 : 0);
        put(p, prefix + "SOURCE", c ? c->id : 0);
        put(p, prefix + "TIME", c ? c->time : 0);
        put(p, prefix + "AZ", c ? c->az : 0);
        put(p, prefix + "EL", c ? c->el : 0);
        put(p, prefix + "THREAT", c && c->threat ? 1 : 0);
    }
}
} // namespace NativeMWS
