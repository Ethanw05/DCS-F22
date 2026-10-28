// GPL-3.0-or-later. Standalone, correctness-gated SAR performance experiments.
// GPU timestamps exclude the later validation readback. No DCS process access.
#include "sar-research/ProbeRuntime.h"
#include <filesystem>
#include <iostream>
#include <sstream>

using namespace SarProbe;
namespace {
constexpr unsigned trials = 11;
struct Variant {
  const char *name;
  unsigned x = 8, y = 8, unroll = 1;
  bool original = true, texture = false, linear = false, optimize = false,
       streamed = false;
  unsigned pixels_x = 1;
};
constexpr std::array variants{
    Variant{"original_8x8"},
    Variant{"original_32x4", 32, 4},
    Variant{"original_16x16", 16, 16},
    Variant{"original_32x8", 32, 8},
    Variant{"unroll4_32x4_o3", 32, 4, 4, false, false, false, true},
    Variant{"unroll4_16x16_o3", 16, 16, 4, false, false, false, true},
    Variant{"unroll8_32x4_o3", 32, 4, 8, false, false, false, true},
    Variant{"texture_load_32x4_o3", 32, 4, 4, false, true, false, true},
    Variant{"texture_linear_32x4_o3", 32, 4, 4, false, true, true, true},
    Variant{"texture_load_8x8_original", 8, 8, 1, true, true},
    Variant{"texture_load_32x4_original", 32, 4, 1, true, true},
    Variant{"texture_load_16x16_original", 16, 16, 1, true, true},
    Variant{"two_pixels_8x8_texture", 8, 8, 1, false, true, false, true, false,
            2},
    Variant{"two_pixels_16x8_texture", 16, 8, 1, false, true, false, true,
            false, 2},
    Variant{"two_pixels_32x4_texture", 32, 4, 1, false, true, false, true,
            false, 2}};
std::string read_shader() {
  std::ifstream stream(std::filesystem::path(F22_SAR_KERNEL_FILE),
                       std::ios::binary);
  require(static_cast<bool>(stream), "Cannot read research shader");
  std::ostringstream text;
  text << stream.rdbuf();
  require(text.str().size() < 65536, "Research shader capacity");
  return text.str();
}
ComPtr<ID3D11ComputeShader> compile(Device &gpu, const std::string &source,
                                    Variant v) {
  const std::array<std::string, 8> values{
      std::to_string(v.x),      std::to_string(v.y),
      std::to_string(v.unroll), v.texture ? "1" : "0",
      v.linear ? "1" : "0",     v.original ? "1" : "0",
      v.streamed ? "1" : "0",   std::to_string(v.pixels_x)};
  const std::array<D3D_SHADER_MACRO, 9> macros{
      {{"GROUP_X", values[0].c_str()},
       {"GROUP_Y", values[1].c_str()},
       {"UNROLL_COUNT", values[2].c_str()},
       {"PROFILE_TEXTURE", values[3].c_str()},
       {"LINEAR_SAMPLE", values[4].c_str()},
       {"ORIGINAL_LOOP", values[5].c_str()},
       {"STREAMED", values[6].c_str()},
       {"PIXELS_X", values[7].c_str()},
       {nullptr, nullptr}}};
  ComPtr<ID3DBlob> code, errors;
  const UINT flags = D3DCOMPILE_ENABLE_STRICTNESS |
                     D3DCOMPILE_WARNINGS_ARE_ERRORS |
                     (v.optimize ? D3DCOMPILE_OPTIMIZATION_LEVEL3
                                 : D3DCOMPILE_OPTIMIZATION_LEVEL1);
  const auto status = D3DCompile(source.data(), source.size(),
                                 "SAR optimization", macros.data(), nullptr,
                                 "main", "cs_5_0", flags, 0, &code, &errors);
  if (FAILED(status) && errors)
    std::cerr << static_cast<const char *>(errors->GetBufferPointer());
  check(status, "Compile research variant");
  ComPtr<ID3D11ComputeShader> shader;
  check(gpu.device->CreateComputeShader(
            code->GetBufferPointer(), code->GetBufferSize(), nullptr, &shader),
        "Create research variant");
  return shader;
}
struct Resources {
  Header h;
  ComPtr<ID3D11ShaderResourceView> pulses, profiles, profile_texture;
  ComPtr<ID3D11SamplerState> sampler;
  std::array<Surface, 2> surfaces;
  ComPtr<ID3D11Texture2D> display, staging;
  ComPtr<ID3D11Buffer> full;
  Resources(Device &gpu, const Input &input)
      : h(input.h), pulses(buffer(gpu, input.pulses)),
        profiles(buffer(gpu, input.profiles)),
        surfaces{Surface(gpu, h.width, h.height),
                 Surface(gpu, h.width, h.height)},
        full(constants(gpu, h, 0, h.pulses)) {
    D3D11_TEXTURE2D_DESC desc{};
    desc.Width = h.bins;
    desc.Height = h.pulses;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R32G32_FLOAT;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_IMMUTABLE;
    desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    D3D11_SUBRESOURCE_DATA initial{input.profiles.data(),
                                   h.bins * sizeof(Pixel), 0};
    ComPtr<ID3D11Texture2D> texture;
    check(gpu.device->CreateTexture2D(&desc, &initial, &texture),
          "Create profile texture");
    check(gpu.device->CreateShaderResourceView(texture.Get(), nullptr,
                                               &profile_texture),
          "Create profile texture view");
    D3D11_SAMPLER_DESC sample{};
    sample.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    sample.AddressU = sample.AddressV = sample.AddressW =
        D3D11_TEXTURE_ADDRESS_CLAMP;
    sample.MaxLOD = D3D11_FLOAT32_MAX;
    check(gpu.device->CreateSamplerState(&sample, &sampler),
          "Create profile sampler");
    desc.Width = h.width;
    desc.Height = h.height;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
    check(gpu.device->CreateTexture2D(&desc, nullptr, &display),
          "Create display copy");
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    check(gpu.device->CreateTexture2D(&desc, nullptr, &staging),
          "Create validation staging texture");
  }
  void bind(Device &gpu, Variant v, ID3D11ComputeShader *shader,
            ID3D11Buffer *control, unsigned out) {
    std::array<ID3D11ShaderResourceView *, 3> views{
        pulses.Get(), v.texture ? profile_texture.Get() : profiles.Get(),
        surfaces[1 - out].srv.Get()};
    auto *target = surfaces[out].uav.Get();
    auto *sampling = sampler.Get();
    gpu.context->CSSetShader(shader, nullptr, 0);
    gpu.context->CSSetShaderResources(0, 3, views.data());
    gpu.context->CSSetUnorderedAccessViews(0, 1, &target, nullptr);
    gpu.context->CSSetSamplers(0, 1, &sampling);
    gpu.context->CSSetConstantBuffers(0, 1, &control);
  }
  void dispatch(Device &gpu, Variant v) const {
    const auto group_width = v.x * v.pixels_x;
    gpu.context->Dispatch((h.width + group_width - 1) / group_width,
                          (h.height + v.y - 1) / v.y, 1);
  }
  static void unbind(Device &gpu) {
    std::array<ID3D11ShaderResourceView *, 3> views{};
    ID3D11UnorderedAccessView *target = nullptr;
    gpu.context->CSSetUnorderedAccessViews(0, 1, &target, nullptr);
    gpu.context->CSSetShaderResources(0, 3, views.data());
    gpu.context->CSSetShader(nullptr, nullptr, 0);
  }
  void publish(Device &gpu, unsigned out) const {
    gpu.context->CopyResource(display.Get(), surfaces[out].texture.Get());
  }
  std::vector<Pixel> readback(Device &gpu) const {
    std::vector<Pixel> image(static_cast<std::size_t>(h.width) * h.height);
    gpu.context->CopyResource(staging.Get(), display.Get());
    D3D11_MAPPED_SUBRESOURCE mapped{};
    check(gpu.context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped),
          "Read validation image");
    for (unsigned y = 0; y < h.height; ++y) {
      const auto *row = reinterpret_cast<const Pixel *>(
          static_cast<const std::byte *>(mapped.pData) + y * mapped.RowPitch);
      std::copy_n(row, h.width,
                  image.begin() + static_cast<std::size_t>(y) * h.width);
    }
    gpu.context->Unmap(staging.Get(), 0);
    return image;
  }
};
struct Report {
  Variant variant;
  ComPtr<ID3D11ComputeShader> shader;
  Quality cpu, baseline;
  std::vector<double> compute_ms, copy_ms;
};
std::vector<Report> prepare(Device &gpu, Resources &resources,
                            const Input &input, const std::string &source,
                            std::vector<Pixel> &baseline) {
  std::vector<Report> reports;
  reports.reserve(variants.size());
  for (const auto variant : variants) {
    Report report{};
    report.variant = variant;
    report.shader = compile(gpu, source, variant);
    for (unsigned warm = 0; warm < 3; ++warm) {
      resources.bind(gpu, variant, report.shader.Get(), resources.full.Get(),
                     0);
      resources.dispatch(gpu, variant);
      Resources::unbind(gpu);
    }
    resources.publish(gpu, 0);
    auto image = resources.readback(gpu);
    if (baseline.empty())
      baseline = image;
    report.cpu = compare(image, input.gold);
    report.baseline = compare(image, baseline);
    require(report.cpu.ser > 40, "Variant failed CPU accuracy guard");
    reports.push_back(std::move(report));
  }
  return reports;
}
void measure(Device &gpu, Resources &resources, std::vector<Report> &reports) {
  const auto size = static_cast<unsigned>(reports.size());
  Clock clock(gpu, trials * size * 4);
  clock.begin(gpu);
  for (unsigned trial = 0; trial < trials; ++trial)
    for (unsigned i = 0; i < size; ++i) {
      auto &report = reports[(i + trial) % size];
      const auto offset = (trial * size + i) * 4;
      resources.bind(gpu, report.variant, report.shader.Get(),
                     resources.full.Get(), 0);
      clock.stamp(gpu, offset);
      resources.dispatch(gpu, report.variant);
      clock.stamp(gpu, offset + 1);
      Resources::unbind(gpu);
      clock.stamp(gpu, offset + 2);
      resources.publish(gpu, 0);
      clock.stamp(gpu, offset + 3);
    }
  clock.end(gpu);
  (void)resources.readback(gpu);
  const auto times = clock.collect(gpu);
  for (unsigned trial = 0; trial < trials; ++trial)
    for (unsigned i = 0; i < size; ++i) {
      const auto offset = (trial * size + i) * 4;
      reports[(i + trial) % size].compute_ms.push_back(times[offset + 1] -
                                                       times[offset]);
      reports[(i + trial) % size].copy_ms.push_back(times[offset + 3] -
                                                    times[offset + 2]);
    }
}
void write_report(const Report &report) {
  std::cout << "{\"name\":\"" << report.variant.name
            << "\",\"gpu_median_ms\":" << median(report.compute_ms)
            << ",\"gpu_max_ms\":"
            << *std::max_element(report.compute_ms.begin(),
                                 report.compute_ms.end())
            << ",\"copy_gpu_median_ms\":" << median(report.copy_ms)
            << ",\"cpu_ser_db\":" << report.cpu.ser
            << ",\"baseline_ser_db\":" << report.baseline.ser
            << ",\"quality_preserving\":"
            << (report.baseline.different_pixels == 0 ? "true" : "false")
            << ",\"different_pixels_from_original\":"
            << report.baseline.different_pixels << ",\"gpu_samples_ms\":[";
  for (std::size_t i = 0; i < report.compute_ms.size(); ++i)
    std::cout << (i ? "," : "") << report.compute_ms[i];
  std::cout << "]}";
}
struct BatchReport {
  const char *name{};
  unsigned span{}, stages{};
  unsigned samples{};
  double total_ms{}, elapsed_ms{}, median_ms{}, maximum_ms{};
  Quality cpu, baseline;
};
void queue_batches(Device &gpu, Resources &resources, Variant variant,
                   ID3D11ComputeShader *program,
                   const std::vector<ComPtr<ID3D11Buffer>> &controls,
                   Clock *clock = nullptr, unsigned first_stamp = 0) {
  for (unsigned stage = 0; stage < controls.size(); ++stage) {
    resources.bind(gpu, variant, program, controls[stage].Get(), stage % 2);
    if (clock)
      clock->stamp(gpu, first_stamp + stage * 2);
    resources.dispatch(gpu, variant);
    if (clock)
      clock->stamp(gpu, first_stamp + stage * 2 + 1);
    Resources::unbind(gpu);
  }
}
struct BatchTimes {
  double sum{}, elapsed{}, median{}, maximum{};
};
BatchTimes batch_times(const std::vector<double> &times, unsigned count,
                       unsigned repeat) {
  require(times.size() == static_cast<std::size_t>(count) * repeat * 2,
          "Batch timing size");
  std::vector<double> samples, totals, elapsed;
  samples.reserve(count * repeat);
  totals.reserve(repeat);
  elapsed.reserve(repeat);
  for (unsigned trial = 0; trial < repeat; ++trial) {
    double total = 0;
    for (unsigned stage = 0; stage < count; ++stage) {
      const auto offset = (trial * count + stage) * 2;
      const auto duration = times[offset + 1] - times[offset];
      samples.push_back(duration);
      total += duration;
    }
    totals.push_back(total);
    elapsed.push_back(times[(trial + 1) * count * 2 - 1] -
                      times[trial * count * 2]);
  }
  return {median(totals), median(elapsed), median(samples),
          *std::max_element(samples.begin(), samples.end())};
}
BatchReport streamed(Device &gpu, Resources &resources, const Input &input,
                     const std::string &source,
                     const std::vector<Pixel> &baseline, unsigned span,
                     bool texture) {
  Variant variant{texture ? "streamed_texture_32x4" : "streamed_buffer_32x4",
                  32,
                  4,
                  1,
                  true,
                  texture,
                  false,
                  false,
                  true};
  auto program = compile(gpu, source, variant);
  std::vector<ComPtr<ID3D11Buffer>> controls;
  const auto count = (input.h.pulses + span - 1) / span;
  controls.reserve(count);
  for (unsigned first = 0; first < input.h.pulses; first += span)
    controls.push_back(
        constants(gpu, input.h, first, std::min(span, input.h.pulses - first)));
  queue_batches(gpu, resources, variant, program.Get(), controls);
  resources.publish(gpu, (count - 1) % 2);
  (void)resources.readback(gpu);
  constexpr unsigned repeat = 7;
  Clock clock(gpu, count * 2 * repeat);
  clock.begin(gpu);
  for (unsigned trial = 0; trial < repeat; ++trial)
    queue_batches(gpu, resources, variant, program.Get(), controls, &clock,
                  trial * count * 2);
  resources.publish(gpu, (count - 1) % 2);
  clock.end(gpu);
  const auto image = resources.readback(gpu);
  const auto timing = batch_times(clock.collect(gpu), count, repeat);
  const auto quality = compare(image, baseline);
  require(quality.different_pixels == 0,
          "Streamed image is not bitwise identical to full reconstruction");
  return {variant.name,  span,           count,
          repeat,        timing.sum,     timing.elapsed,
          timing.median, timing.maximum, compare(image, input.gold),
          quality};
}
void write_batch(const BatchReport &report) {
  std::cout << "{\"name\":\"" << report.name
            << "\",\"histories_per_batch\":" << report.span
            << ",\"stages\":" << report.stages
            << ",\"trials\":" << report.samples
            << ",\"gpu_sum_median_ms\":" << report.total_ms
            << ",\"gpu_batch_median_ms\":" << report.median_ms
            << ",\"queued_collection_elapsed_median_ms\":" << report.elapsed_ms
            << ",\"gpu_batch_max_ms\":" << report.maximum_ms
            << ",\"cpu_ser_db\":" << report.cpu.ser
            << ",\"different_pixels_from_original\":"
            << report.baseline.different_pixels << "}";
}
void run(const Input &input) {
  Device gpu;
  Resources resources(gpu, input);
  const auto source = read_shader();
  std::vector<Pixel> baseline;
  auto reports = prepare(gpu, resources, input, source, baseline);
  measure(gpu, resources, reports);
  std::array<BatchReport, 8> batches{};
  const std::array<unsigned, 4> spans{16, 32, 64, 31};
  for (std::size_t i = 0; i < batches.size(); ++i)
    batches[i] = streamed(gpu, resources, input, source, baseline,
                          spans[i % spans.size()], i >= spans.size());
  std::cout << "{\"adapter\":\"" << gpu.name << "\",\"width\":" << input.h.width
            << ",\"height\":" << input.h.height
            << ",\"histories\":" << input.h.pulses
            << ",\"gpu_timestamp_disjoint\":false,\"validation_readback_"
               "excluded\":true,\"dcs_tested\":false,\"variants\":[";
  for (std::size_t i = 0; i < reports.size(); ++i) {
    if (i)
      std::cout << ",";
    write_report(reports[i]);
  }
  std::cout << "],\"streamed\":[";
  for (std::size_t i = 0; i < batches.size(); ++i) {
    if (i)
      std::cout << ",";
    write_batch(batches[i]);
  }
  std::cout << "]}\n";
}
} // namespace
int main(int argc, char **argv) {
  try {
    require(argc == 2, "Usage: f22_sar_optimization_probe gpu-input-N.bin");
    run(load(argv[1]));
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
