// GPL-3.0-or-later. SAR research kernels, not a DCS render callback.
#ifndef GROUP_X
#define GROUP_X 8
#endif
#ifndef GROUP_Y
#define GROUP_Y 8
#endif
#ifndef UNROLL_COUNT
#define UNROLL_COUNT 1
#endif
#ifndef PROFILE_TEXTURE
#define PROFILE_TEXTURE 0
#endif
#ifndef LINEAR_SAMPLE
#define LINEAR_SAMPLE 0
#endif
#ifndef ORIGINAL_LOOP
#define ORIGINAL_LOOP 0
#endif
#ifndef STREAMED
#define STREAMED 0
#endif
#ifndef PIXELS_X
#define PIXELS_X 1
#endif

struct Pulse { float4 ray; float4 reference; };
StructuredBuffer<Pulse> pulses : register(t0);
#if PROFILE_TEXTURE
Texture2D<float2> profiles : register(t1);
SamplerState profileSampler : register(s0);
#else
StructuredBuffer<float2> profiles : register(t1);
#endif
Texture2D<float2> previous : register(t2);
RWTexture2D<float2> result : register(u0);
cbuffer Control : register(b0) {
    uint count, bins, width, height;
    float rangeStart, rangeStep, gridStart, gridStep;
    float phaseK, pad0, pad1, pad2;
    uint first, span, pad3, pad4;
};

float2 sampleProfile(uint pulse, float index, int lower) {
#if PROFILE_TEXTURE
#if LINEAR_SAMPLE
    return profiles.SampleLevel(profileSampler,
        float2((index + .5) / bins, (pulse + .5) / count), 0);
#else
    return lerp(profiles.Load(int3(lower, pulse, 0)),
                profiles.Load(int3(lower + 1, pulse, 0)), frac(index));
#endif
#else
    return lerp(profiles[pulse * bins + lower],
                profiles[pulse * bins + lower + 1], frac(index));
#endif
}

float2 evaluate(Pulse pulse, uint p, float3 q) {
    float delta = 2 * dot(pulse.ray.xyz, q) + dot(q, q);
    float distance = delta / (sqrt(pulse.ray.w * pulse.ray.w + delta) + pulse.ray.w)
                   + pulse.reference.x;
    float index = (distance - rangeStart) / rangeStep;
    int lower = (int)floor(index);
    if (lower < 0 || lower + 1 >= (int)bins) return 0;
    float2 value = sampleProfile(p, index, lower);
    float s, c;
    sincos(phaseK * distance, s, c);
    return float2(value.x * c - value.y * s, value.x * s + value.y * c);
}
float2 contribution(uint p, float3 q) { return evaluate(pulses[p], p, q); }

[numthreads(GROUP_X, GROUP_Y, 1)]
void main(uint3 thread : SV_DispatchThreadID) {
#if PIXELS_X == 2
    // Independent pixels reuse one pulse load, keeping each pixel's sum ordered.
    uint2 at = uint2(thread.x * 2, thread.y);
    if (at.x >= width || at.y >= height) return;
    uint2 next = at + uint2(1, 0);
    float3 q0 = float3(gridStart + at.x * gridStep, gridStart + at.y * gridStep, 0);
    float3 q1 = float3(gridStart + next.x * gridStep, gridStart + next.y * gridStep, 0);
    float2 sum0 = first == 0 ? 0 : previous.Load(int3(at, 0));
    float2 sum1 = first == 0 ? 0 : previous.Load(int3(next, 0));
    uint end = min(first + span, count);
    [loop]
    for (uint p = first; p < end; ++p) {
        Pulse pulse = pulses[p];
        sum0 += evaluate(pulse, p, q0);
        if (next.x < width) sum1 += evaluate(pulse, p, q1);
    }
    result[at] = end == count ? sum0 / count : sum0;
    if (next.x < width) result[next] = end == count ? sum1 / count : sum1;
#else
    if (thread.x >= width || thread.y >= height) return;
    float3 q = float3(gridStart + thread.x * gridStep, gridStart + thread.y * gridStep, 0);
#if ORIGINAL_LOOP
    // Preserve the original reference's operation and summation order.
    float2 sum = STREAMED && first > 0 ? previous.Load(int3(thread.xy, 0)) : 0;
    uint end = STREAMED ? min(first + span, count) : count;
    for (uint p = STREAMED ? first : 0; p < end; ++p) {
        Pulse pulse = pulses[p];
        float delta = 2 * dot(pulse.ray.xyz, q) + dot(q, q);
        float distance = delta / (sqrt(pulse.ray.w * pulse.ray.w + delta) + pulse.ray.w)
                       + pulse.reference.x;
        float index = (distance - rangeStart) / rangeStep;
        int lower = (int)floor(index);
        if (lower < 0 || lower + 1 >= (int)bins) continue;
        float2 value = sampleProfile(p, index, lower);
        float s, c;
        sincos(phaseK * distance, s, c);
        sum += float2(value.x * c - value.y * s, value.x * s + value.y * c);
    }
    result[thread.xy] = end == count ? sum / count : sum;
#else
    float2 sum = first == 0 ? 0 : previous.Load(int3(thread.xy, 0));
    uint end = min(first + span, count);
    [loop]
    for (uint p = first; p < end; p += UNROLL_COUNT) {
        [unroll]
        for (uint j = 0; j < UNROLL_COUNT; ++j) {
            if (p + j < end) sum += contribution(p + j, q);
        }
    }
    // Intermediate surfaces retain the unnormalized complex sum. Normalize
    // once, after exactly the same histories as the full reconstruction.
    result[thread.xy] = end == count ? sum / count : sum;
#endif
#endif
}
