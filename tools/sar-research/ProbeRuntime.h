// GPL-3.0-or-later. Bounded standalone research input and D3D11 helpers.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <complex>
#include <cstdint>
#include <cstring>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
#include <wrl/client.h>

namespace SarProbe {
using Microsoft::WRL::ComPtr;
using Pixel = std::complex<float>;
static_assert(sizeof(Pixel) == 8);
inline void require(bool ok, const char *reason) {
  if (!ok)
    throw std::runtime_error(reason);
}
inline void check(HRESULT code, const char *reason) {
  require(SUCCEEDED(code), reason);
}
struct Header {
  std::array<char, 8> magic{};
  std::uint32_t pulses{}, bins{}, width{}, height{};
  float range_start{}, range_step{}, grid_start{}, grid_step{}, phase_k{};
};
static_assert(sizeof(Header) == 44);
struct Pulse {
  std::array<float, 8> values{};
};
struct Control {
  std::uint32_t count{}, bins{}, width{}, height{};
  float range_start{}, range_step{}, grid_start{}, grid_step{};
  float phase_k{}, pad0{}, pad1{}, pad2{};
  std::uint32_t first{}, span{}, pad3{}, pad4{};
};
static_assert(sizeof(Control) == 64);
struct Input {
  Header h;
  std::vector<Pulse> pulses;
  std::vector<Pixel> profiles, gold;
};
template <class T>
inline void read(std::ifstream &stream, T *data, std::size_t count) {
  stream.read(reinterpret_cast<char *>(data),
              static_cast<std::streamsize>(sizeof(T) * count));
  require(static_cast<bool>(stream), "Truncated SAR input");
}
inline Input load(const char *path) {
  std::ifstream stream(path, std::ios::binary);
  require(static_cast<bool>(stream), "Cannot open SAR input");
  Input input;
  read(stream, &input.h, 1);
  const auto &h = input.h;
  require(h.magic == std::array<char, 8>{'F', '2', '2', 'S', 'A', 'R', '1', 0},
          "Wrong SAR input");
  require(h.pulses > 0 && h.pulses <= 1024 && h.bins > 1 && h.bins <= 8192,
          "SAR input capacity");
  require(h.width > 0 && h.width <= 1024 && h.height > 0 && h.height <= 1024,
          "SAR image capacity");
  for (float value :
       {h.range_start, h.range_step, h.grid_start, h.grid_step, h.phase_k})
    require(std::isfinite(value), "Nonfinite SAR geometry");
  require(h.range_step > 0 && h.grid_step > 0, "Invalid SAR spacing");
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
  std::string name;
  Device() {
    const D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;
    D3D_FEATURE_LEVEL obtained{};
    check(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
                            &level, 1, D3D11_SDK_VERSION, &device, &obtained,
                            &context),
          "Create hardware D3D11 device");
    ComPtr<IDXGIDevice> dxgi;
    check(device.As(&dxgi), "DXGI device");
    ComPtr<IDXGIAdapter> adapter;
    check(dxgi->GetAdapter(&adapter), "DXGI adapter");
    DXGI_ADAPTER_DESC desc{};
    check(adapter->GetDesc(&desc), "DXGI adapter description");
    for (wchar_t ch : desc.Description)
      if (ch && ch < 128)
        name += static_cast<char>(ch);
  }
};
template <class T>
inline ComPtr<ID3D11ShaderResourceView> buffer(Device &gpu,
                                               const std::vector<T> &data) {
  D3D11_BUFFER_DESC desc{};
  desc.ByteWidth = static_cast<UINT>(sizeof(T) * data.size());
  desc.Usage = D3D11_USAGE_IMMUTABLE;
  desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
  desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  desc.StructureByteStride = sizeof(T);
  D3D11_SUBRESOURCE_DATA initial{data.data(), 0, 0};
  ComPtr<ID3D11Buffer> resource;
  check(gpu.device->CreateBuffer(&desc, &initial, &resource),
        "Create input buffer");
  ComPtr<ID3D11ShaderResourceView> view;
  check(gpu.device->CreateShaderResourceView(resource.Get(), nullptr, &view),
        "Create input SRV");
  return view;
}
inline ComPtr<ID3D11Buffer> constants(Device &gpu, const Header &h,
                                      unsigned first, unsigned span) {
  require(first < h.pulses && span > 0 && span <= h.pulses - first,
          "Invalid pulse batch");
  Control value{h.pulses,
                h.bins,
                h.width,
                h.height,
                h.range_start,
                h.range_step,
                h.grid_start,
                h.grid_step,
                h.phase_k,
                0,
                0,
                0,
                first,
                span};
  D3D11_BUFFER_DESC desc{};
  desc.ByteWidth = sizeof(value);
  desc.Usage = D3D11_USAGE_IMMUTABLE;
  desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
  D3D11_SUBRESOURCE_DATA initial{&value, 0, 0};
  ComPtr<ID3D11Buffer> result;
  check(gpu.device->CreateBuffer(&desc, &initial, &result),
        "Create batch constants");
  return result;
}
struct Surface {
  ComPtr<ID3D11Texture2D> texture;
  ComPtr<ID3D11ShaderResourceView> srv;
  ComPtr<ID3D11UnorderedAccessView> uav;
  Surface(Device &gpu, unsigned width, unsigned height) {
    D3D11_TEXTURE2D_DESC desc{};
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R32G32_FLOAT;
    desc.SampleDesc.Count = 1;
    desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
    check(gpu.device->CreateTexture2D(&desc, nullptr, &texture),
          "Create complex surface");
    check(gpu.device->CreateShaderResourceView(texture.Get(), nullptr, &srv),
          "Create surface SRV");
    check(gpu.device->CreateUnorderedAccessView(texture.Get(), nullptr, &uav),
          "Create surface UAV");
  }
};
// Readback and GetData synchronization are confined to this standalone
// validator. Benchmark timestamps exclude the validation readback.
class Clock {
  ComPtr<ID3D11Query> disjoint_;
  std::vector<ComPtr<ID3D11Query>> stamps_;

public:
  Clock(Device &gpu, unsigned count) : stamps_(count) {
    require(count > 1 && count <= 4096, "Timestamp capacity");
    D3D11_QUERY_DESC desc{D3D11_QUERY_TIMESTAMP_DISJOINT, 0};
    check(gpu.device->CreateQuery(&desc, &disjoint_), "Create disjoint query");
    desc.Query = D3D11_QUERY_TIMESTAMP;
    for (auto &stamp : stamps_)
      check(gpu.device->CreateQuery(&desc, &stamp), "Create timestamp");
  }
  void begin(Device &gpu) { gpu.context->Begin(disjoint_.Get()); }
  void stamp(Device &gpu, unsigned index) {
    require(index < stamps_.size(), "Timestamp index");
    gpu.context->End(stamps_[index].Get());
  }
  void end(Device &gpu) { gpu.context->End(disjoint_.Get()); }
  std::vector<double> collect(Device &gpu) const {
    D3D11_QUERY_DATA_TIMESTAMP_DISJOINT data{};
    require(gpu.context->GetData(disjoint_.Get(), &data, sizeof(data),
                                 D3D11_ASYNC_GETDATA_DONOTFLUSH) == S_OK,
            "Timestamp query not complete");
    require(!data.Disjoint && data.Frequency > 0, "Disjoint GPU clock");
    std::vector<double> times;
    times.reserve(stamps_.size());
    UINT64 origin = 0;
    for (std::size_t i = 0; i < stamps_.size(); ++i) {
      UINT64 ticks = 0;
      require(gpu.context->GetData(stamps_[i].Get(), &ticks, sizeof(ticks),
                                   D3D11_ASYNC_GETDATA_DONOTFLUSH) == S_OK,
              "GPU timestamp not complete");
      if (i == 0)
        origin = ticks;
      require(ticks >= origin, "GPU clock reversed");
      times.push_back(static_cast<double>(ticks - origin) * 1000 /
                      static_cast<double>(data.Frequency));
    }
    return times;
  }
};
struct Quality {
  double ser{}, maximum{};
  std::size_t different_pixels{};
};
inline Quality compare(const std::vector<Pixel> &image,
                       const std::vector<Pixel> &reference) {
  require(image.size() == reference.size(), "Image comparison size");
  double signal = 0, error = 0, maximum = 0;
  std::size_t different = 0;
  for (std::size_t i = 0; i < image.size(); ++i) {
    const double delta = std::norm(std::complex<double>(image[i]) -
                                   std::complex<double>(reference[i]));
    require(std::isfinite(delta), "Nonfinite image");
    signal += std::norm(reference[i]);
    error += delta;
    maximum = std::max(maximum, std::sqrt(delta));
    if (std::memcmp(&image[i], &reference[i], sizeof(Pixel)) != 0)
      ++different;
  }
  return {error > 0 ? 10 * std::log10(signal / error) : 999, maximum,
          different};
}
inline double median(std::vector<double> values) {
  require(!values.empty(), "Empty timing sample");
  std::sort(values.begin(), values.end());
  return values[values.size() / 2];
}
} // namespace SarProbe
