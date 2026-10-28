// GPL-3.0-or-later. Standalone SAR compute/copy feasibility experiment.
// Uses its own D3D11 device/context. Never attaches to or writes into DCS.
#include <array>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstdint>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;
namespace {
constexpr char shader[] = R"(
struct Pulse { float4 ray; float4 reference; };
StructuredBuffer<Pulse> pulses : register(t0);
StructuredBuffer<float2> profiles : register(t1);
RWTexture2D<float2> result : register(u0);
cbuffer Control : register(b0) {
 uint count, bins, width, height;
 float rangeStart, rangeStep, gridStart, gridStep;
 float phaseK, pad0, pad1, pad2;
};
[numthreads(8,8,1)]
void main(uint3 thread : SV_DispatchThreadID) {
 if(thread.x>=width || thread.y>=height)return;
 float3 q=float3(gridStart+thread.x*gridStep,gridStart+thread.y*gridStep,0);
 float2 sum=0;
 for(uint p=0;p<count;++p) {
  Pulse pulse=pulses[p];
  // Rationalized range difference avoids subtracting two ~12km FP32 ranges.
  float delta=2*dot(pulse.ray.xyz,q)+dot(q,q);
  float distance=delta/(sqrt(pulse.ray.w*pulse.ray.w+delta)+pulse.ray.w)+pulse.reference.x;
  float index=(distance-rangeStart)/rangeStep;
  int lower=(int)floor(index);
  if(lower<0 || lower+1>=(int)bins)continue;
  float2 value=lerp(profiles[p*bins+lower],profiles[p*bins+lower+1],frac(index));
  float s,c;sincos(phaseK*distance,s,c);
  sum+=float2(value.x*c-value.y*s,value.x*s+value.y*c);
 }
 result[thread.xy]=sum/count;
}
)";
struct Header {
  std::array<char, 8> magic{};
  std::uint32_t pulses{}, bins{}, width{}, height{};
  float range_start{}, range_step{}, grid_start{}, grid_step{}, phase_k{};
};
static_assert(sizeof(Header) == 44);
struct Pulse {
  std::array<float, 8> value{};
};
struct Control {
  std::uint32_t pulses{}, bins{}, width{}, height{};
  float range_start{}, range_step{}, grid_start{}, grid_step{};
  float phase_k{}, pad0{}, pad1{}, pad2{};
};
static_assert(sizeof(Control) == 48);
using Pixel = std::complex<float>;
static_assert(sizeof(Pixel) == 8);
void require(bool ok, const char *reason) {
  if (!ok)
    throw std::runtime_error(reason);
}
void check(HRESULT result, const char *reason) {
  require(SUCCEEDED(result), reason);
}
template <class T>
void read(std::ifstream &stream, T *output, std::size_t count) {
  stream.read(reinterpret_cast<char *>(output),
              static_cast<std::streamsize>(sizeof(T) * count));
  require(static_cast<bool>(stream), "Truncated research input");
}
struct Input {
  Header header;
  std::vector<Pulse> pulses;
  std::vector<Pixel> profiles, gold;
};
Input load(const char *path) {
  std::ifstream stream(path, std::ios::binary);
  require(static_cast<bool>(stream), "Cannot open research input");
  Input input;
  read(stream, &input.header, 1);
  const auto &h = input.header;
  require(h.magic == std::array<char, 8>{'F', '2', '2', 'S', 'A', 'R', '1', 0},
          "Wrong input format");
  require(h.pulses > 0 && h.pulses <= 1024 && h.bins > 1 && h.bins <= 8192,
          "Input exceeds pulse/range budget");
  require(h.width > 0 && h.width <= 1024 && h.height > 0 && h.height <= 1024,
          "Input exceeds pixel budget");
  for (float value :
       {h.range_start, h.range_step, h.grid_start, h.grid_step, h.phase_k})
    require(std::isfinite(value), "Nonfinite input geometry");
  require(h.range_step > 0 && h.grid_step > 0, "Invalid sample spacing");
  input.pulses.resize(h.pulses);
  input.profiles.resize(static_cast<std::size_t>(h.pulses) * h.bins);
  input.gold.resize(static_cast<std::size_t>(h.width) * h.height);
  read(stream, input.pulses.data(), input.pulses.size());
  read(stream, input.profiles.data(), input.profiles.size());
  read(stream, input.gold.data(), input.gold.size());
  return input;
}
struct Device {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  D3D_FEATURE_LEVEL level{};
  std::string adapter;
  Device() {
    const std::array levels{D3D_FEATURE_LEVEL_11_0};
    check(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
                            levels.data(), static_cast<UINT>(levels.size()),
                            D3D11_SDK_VERSION, &device, &level, &context),
          "D3D11 hardware device");
    ComPtr<IDXGIDevice> dxgi;
    check(device.As(&dxgi), "DXGI device");
    ComPtr<IDXGIAdapter> gpu;
    check(dxgi->GetAdapter(&gpu), "DXGI adapter");
    DXGI_ADAPTER_DESC desc{};
    check(gpu->GetDesc(&desc), "DXGI description");
    for (wchar_t ch : desc.Description)
      if (ch && ch < 128)
        adapter += static_cast<char>(ch);
  }
};
template <class T>
ComPtr<ID3D11ShaderResourceView> buffer(Device &gpu,
                                        const std::vector<T> &data) {
  D3D11_BUFFER_DESC desc{};
  desc.ByteWidth = static_cast<UINT>(data.size() * sizeof(T));
  desc.Usage = D3D11_USAGE_IMMUTABLE;
  desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
  desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  desc.StructureByteStride = sizeof(T);
  D3D11_SUBRESOURCE_DATA initial{data.data(), 0, 0};
  ComPtr<ID3D11Buffer> resource;
  check(gpu.device->CreateBuffer(&desc, &initial, &resource),
        "Create structured input");
  ComPtr<ID3D11ShaderResourceView> view;
  check(gpu.device->CreateShaderResourceView(resource.Get(), nullptr, &view),
        "Create input view");
  return view;
}
ComPtr<ID3D11ComputeShader> compile(Device &gpu) {
  ComPtr<ID3DBlob> code, errors;
  const auto result =
      D3DCompile(shader, sizeof(shader) - 1, "F22 standalone SAR", nullptr,
                 nullptr, "main", "cs_5_0",
                 D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_WARNINGS_ARE_ERRORS,
                 0, &code, &errors);
  if (FAILED(result) && errors)
    std::cerr << static_cast<const char *>(errors->GetBufferPointer());
  check(result, "Compile SAR shader");
  ComPtr<ID3D11ComputeShader> compiled;
  check(gpu.device->CreateComputeShader(code->GetBufferPointer(),
                                        code->GetBufferSize(), nullptr,
                                        &compiled),
        "Create compute shader");
  return compiled;
}
struct Images {
  ComPtr<ID3D11Texture2D> compute, display, staging;
  ComPtr<ID3D11UnorderedAccessView> output;
  Images(Device &gpu, const Header &h) {
    D3D11_TEXTURE2D_DESC desc{};
    desc.Width = h.width;
    desc.Height = h.height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R32G32_FLOAT;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
    check(gpu.device->CreateTexture2D(&desc, nullptr, &compute),
          "Create owned SAR texture");
    check(
        gpu.device->CreateUnorderedAccessView(compute.Get(), nullptr, &output),
        "Create owned UAV");
    desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
    check(gpu.device->CreateTexture2D(&desc, nullptr, &display),
          "Create display texture without UAV");
    desc.BindFlags = 0;
    desc.Usage = D3D11_USAGE_STAGING;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    check(gpu.device->CreateTexture2D(&desc, nullptr, &staging),
          "Create standalone readback");
  }
};
struct Result {
  double ser{}, maximum_error{}, submit_readback_ms{};
};
Result run(Device &gpu, const Input &input) {
  const auto &h = input.header;
  auto pulse_view = buffer(gpu, input.pulses),
       profile_view = buffer(gpu, input.profiles);
  auto program = compile(gpu);
  Images images(gpu, h);
  Control control{h.pulses,     h.bins,        h.width,
                  h.height,     h.range_start, h.range_step,
                  h.grid_start, h.grid_step,   h.phase_k};
  D3D11_BUFFER_DESC desc{};
  desc.ByteWidth = sizeof(control);
  desc.Usage = D3D11_USAGE_IMMUTABLE;
  desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
  D3D11_SUBRESOURCE_DATA initial{&control, 0, 0};
  ComPtr<ID3D11Buffer> constants;
  check(gpu.device->CreateBuffer(&desc, &initial, &constants),
        "Create constants");
  auto *cb = constants.Get();
  auto *output = images.output.Get();
  std::array<ID3D11ShaderResourceView *, 2> views{pulse_view.Get(),
                                                  profile_view.Get()};
  const auto start = std::chrono::steady_clock::now();
  gpu.context->CSSetShader(program.Get(), nullptr, 0);
  gpu.context->CSSetConstantBuffers(0, 1, &cb);
  gpu.context->CSSetShaderResources(0, 2, views.data());
  gpu.context->CSSetUnorderedAccessViews(0, 1, &output, nullptr);
  gpu.context->Dispatch((h.width + 7) / 8, (h.height + 7) / 8, 1);
  output = nullptr;
  views.fill(nullptr);
  gpu.context->CSSetUnorderedAccessViews(0, 1, &output, nullptr);
  gpu.context->CSSetShaderResources(0, 2, views.data());
  gpu.context->CSSetShader(nullptr, nullptr, 0);
  gpu.context->CopyResource(images.display.Get(), images.compute.Get());
  gpu.context->CopyResource(images.staging.Get(), images.display.Get());
  D3D11_MAPPED_SUBRESOURCE mapped{};
  check(gpu.context->Map(images.staging.Get(), 0, D3D11_MAP_READ, 0, &mapped),
        "Read own display copy");
  const auto elapsed = std::chrono::duration<double, std::milli>(
                           std::chrono::steady_clock::now() - start)
                           .count();
  double signal = 0, error = 0, maximum = 0;
  for (std::uint32_t y = 0; y < h.height; ++y) {
    const auto *row = reinterpret_cast<const Pixel *>(
        static_cast<const std::byte *>(mapped.pData) + y * mapped.RowPitch);
    for (std::uint32_t x = 0; x < h.width; ++x) {
      const Pixel expected =
          input.gold[static_cast<std::size_t>(y) * h.width + x];
      const double difference = std::norm(std::complex<double>(row[x]) -
                                          std::complex<double>(expected));
      signal += std::norm(expected);
      error += difference;
      maximum = std::max(maximum, std::sqrt(difference));
    }
  }
  gpu.context->Unmap(images.staging.Get(), 0);
  return {10 * std::log10(signal / error), maximum, elapsed};
}
} // namespace
int main(int argc, char **argv) {
  try {
    require(argc == 2, "Usage: f22_sar_gpu_probe gpu-input-N.bin");
    const auto input = load(argv[1]);
    Device gpu;
    const auto cold = run(gpu, input);
    const auto warm1 = run(gpu, input);
    const auto warm2 = run(gpu, input);
    const auto result = run(gpu, input);
    std::cout << "{\"adapter\":\"" << gpu.adapter
              << "\",\"width\":" << input.header.width
              << ",\"height\":" << input.header.height
              << ",\"pulses\":" << input.header.pulses
              << ",\"complex_signal_to_error_db\":" << result.ser
              << ",\"maximum_complex_error\":" << result.maximum_error
              << ",\"cold_submit_and_blocking_own_readback_ms\":"
              << cold.submit_readback_ms
              << ",\"warm_submit_and_blocking_own_readback_ms\":["
              << warm1.submit_readback_ms << "," << warm2.submit_readback_ms
              << "," << result.submit_readback_ms << "]"
              << ",\"dcs_integration_tested\":false}\n";
    require(std::isfinite(result.ser) && result.ser > 40,
            "GPU/reference complex error exceeds research limit");
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
