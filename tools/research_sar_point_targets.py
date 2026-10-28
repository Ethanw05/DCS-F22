"""Bounded synthetic phase-history experiment, independent of DCS.

Original frequency-domain point-scatterer model and range-profile
backprojection. Radar values are illustrative estimates, not APG-77 data.
No screenshots, ground-truth image pixels or upstream implementation code
are used to form the images. Run with Python, NumPy and Matplotlib.
"""
from pathlib import Path
import argparse
import json
import struct
import time

import numpy as np

C = 299_792_458.0
FC = 10e9
PULSES = 128
FREQUENCIES = 256
FFT_SAMPLES = 2048


def trajectory(length, motion=False, pulses=PULSES):
    x = np.linspace(-length / 2, length / 2, pulses)
    z = np.full(pulses, 2000.0)
    if motion:
        z += .2 * np.sin(np.linspace(0, 4 * np.pi, pulses))
    return np.column_stack((x, np.zeros(pulses), z))


def phase_history(positions, targets, bandwidth, center):
    frequency = np.linspace(FC - bandwidth / 2, FC + bandwidth / 2, FREQUENCIES)
    reference = float(np.linalg.norm(positions[len(positions) // 2] - center))
    samples = np.zeros((len(positions), FREQUENCIES), dtype=np.complex128)
    for target, amplitude in targets:
        distance = np.linalg.norm(positions - target, axis=1) - reference
        samples += amplitude * np.exp(-4j * np.pi / C * distance[:, None] * frequency)
    return frequency, samples, reference


def backproject(positions, frequency, samples, points, reference):
    spacing = frequency[1] - frequency[0]
    axis = np.fft.fftshift(np.fft.fftfreq(FFT_SAMPLES, spacing)) * C / 2
    profiles = np.fft.fftshift(np.fft.ifft(samples, n=FFT_SAMPLES, axis=1), axes=1)
    image = np.zeros(points.shape[0], dtype=np.complex128)
    for pulse, position in enumerate(positions):
        distance = np.linalg.norm(points - position, axis=1) - reference
        profile = profiles[pulse]
        value = np.interp(distance, axis, profile.real, left=0, right=0)
        value = value + 1j * np.interp(distance, axis, profile.imag, left=0, right=0)
        image += value * np.exp(4j * np.pi * frequency[0] / C * distance)
    return image * FFT_SAMPLES / (FREQUENCIES * len(positions))


def focus(positions, targets, bandwidth, points, center, assumed=None):
    frequency, samples, reference = phase_history(positions, targets, bandwidth, center)
    image = backproject(positions if assumed is None else assumed, frequency, samples, points, reference)
    return np.abs(image) ** 2


def main():
    output = Path(__file__).resolve().parents[1] / "out/sar-research"
    output.mkdir(exist_ok=True)
    center = np.array([0.0, 12000.0, 0.0])
    positions = trajectory(250)
    line = np.linspace(-16, 16, 641)
    cross_points = np.column_stack((line, np.full(line.size, center[1]), np.zeros(line.size)))
    pair = [(center + [-3, 0, 0], 1.0), (center + [3, 0, 0], 1.0)]
    full_cut = focus(positions, pair, 150e6, cross_points, center)
    short_cut = focus(trajectory(20), pair, 150e6, cross_points, center)
    middle = line.size // 2
    peaks = [np.max(full_cut[np.abs(line - offset) < .5]) for offset in (-3, 3)]
    valley_db = 10 * np.log10(full_cut[middle] / min(peaks))
    assert valley_db < -6, "Collected aperture failed to resolve two cross-range targets"
    assert short_cut[middle] > .5 * np.max(short_cut), "Short aperture unexpectedly resolved the pair"

    range_points = np.column_stack((np.zeros(line.size), center[1] + line, np.zeros(line.size)))
    range_pair = [(center + [0, -3, 0], 1.0), (center + [0, 3, 0], 1.0)]
    high_band = focus(positions, range_pair, 150e6, range_points, center)
    low_band = focus(positions, range_pair, 15e6, range_points, center)
    assert high_band[middle] < .25 * np.max(high_band)
    assert low_band[middle] > .5 * np.max(low_band)

    forward_center = np.array([12000.0, 0.0, 0.0])
    _, left, _ = phase_history(positions, [(forward_center + [0, -3, 0], 1)], 150e6, forward_center)
    _, right, _ = phase_history(positions, [(forward_center + [0, 3, 0], 1)], 150e6, forward_center)
    ambiguity = float(np.max(np.abs(left - right)))
    assert ambiguity < 1e-10, "Symmetric forward-looking range history should be ambiguous"

    grid_axis = np.linspace(-12, 12, 193)
    x, y = np.meshgrid(grid_axis, grid_axis)
    points = np.column_stack((x.ravel(), center[1] + y.ravel(), np.zeros(x.size)))
    started = time.perf_counter()
    detailed = focus(positions, pair, 150e6, points, center)
    elapsed = time.perf_counter() - started
    moving = trajectory(250, motion=True)
    compensated = focus(moving, [(center, 1)], 150e6, points, center)
    uncompensated = focus(moving, [(center, 1)], 150e6, points, center, positions)
    motion_gain = float(10 * np.log10(np.max(compensated) / np.max(uncompensated)))
    assert motion_gain > 3, "Motion compensation did not restore coherent focus"
    metrics = {
        "kind": "Synthetic point-target SAR experiment; no DCS integration qualification",
        "carrier_hz": FC, "bandwidth_hz": 150e6, "aperture_m": 250,
        "pulses": PULSES, "frequency_samples": FREQUENCIES,
        "phase_history_bytes": int(left.nbytes),
        "cross_range_pair_separation_m": 6,
        "cross_range_center_valley_db": float(valley_db),
        "forward_left_right_history_difference": ambiguity,
        "motion_compensation_peak_gain_db": motion_gain,
        "cpu_reference_grid": [193, 193], "cpu_reference_focus_s": elapsed,
        "estimated_slant_range_resolution_m": C / (2 * 150e6),
        "estimated_broadside_cross_range_resolution_m": (C / FC) * np.linalg.norm(center - positions[PULSES // 2]) / 500,
    }
    (output / "point-target-metrics.json").write_text(json.dumps(metrics, indent=2))
    gpu_input(output, positions, pair, center)
    render(output, line, full_cut, short_cut, high_band, low_band, grid_axis, detailed, uncompensated)
    print(json.dumps(metrics, indent=2))


def gpu_input(output, positions, targets, center, sizes=(193, 512)):
    frequency, samples, reference = phase_history(positions, targets, 150e6, center)
    frequency_step = frequency[1] - frequency[0]
    range_axis = np.fft.fftshift(np.fft.fftfreq(FFT_SAMPLES, frequency_step)) * C / 2
    profiles = np.fft.fftshift(np.fft.ifft(samples, n=FFT_SAMPLES, axis=1), axes=1)
    profiles = np.asarray(profiles * FFT_SAMPLES / FREQUENCIES, dtype=np.complex64)
    count = len(positions)
    pulses = np.zeros((count, 8), dtype=np.float32)
    pulses[:, :3] = center - positions
    exact_range = np.linalg.norm(center - positions, axis=1)
    pulses[:, 3] = exact_range
    pulses[:, 4] = exact_range - reference
    for size in sizes:
        axis = np.linspace(-12, 12, size)
        x, y = np.meshgrid(axis, axis)
        points = np.column_stack((x.ravel(), center[1] + y.ravel(), np.zeros(x.size)))
        gold = backproject(positions, frequency, samples, points, reference)
        header = struct.pack("<8sIIIIfffff", b"F22SAR1\0", count, FFT_SAMPLES, size, size,
                             range_axis[0], range_axis[1] - range_axis[0],
                             axis[0], axis[1] - axis[0], 4 * np.pi * frequency[0] / C)
        suffix = "" if count == PULSES else "-p%d" % count
        path = output / ("gpu-input-%d%s.bin" % (size, suffix))
        with path.open("wb") as stream:
            stream.write(header)
            stream.write(pulses.tobytes())
            stream.write(profiles.tobytes())
            stream.write(np.asarray(gold, dtype=np.complex64).tobytes())


def render(output, line, full_cut, short_cut, high_band, low_band, grid, image, motion):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(2, 2, figsize=(11, 8), constrained_layout=True)
    for ax, data, title in (
        (axes[0, 0], image, "Focused synthetic returns · 250 m aperture"),
        (axes[0, 1], motion, "One target · 20 cm motion error left uncompensated"),
    ):
        power = 10 * np.log10(np.maximum(data.reshape(193, 193), 1e-6))
        ax.imshow(power, origin="lower", extent=[grid[0], grid[-1], grid[0], grid[-1]],
                  cmap="gray", vmin=-35, vmax=3)
        ax.set(title=title, xlabel="Along-track offset (m)", ylabel="Ground-range offset (m)")
    for ax, curves, title, xlabel in (
        (axes[1, 0], ((full_cut, "250 m aperture"), (short_cut, "20 m aperture")),
         "Same bandwidth, different collected aperture", "Along-track offset (m)"),
        (axes[1, 1], ((high_band, "150 MHz bandwidth"), (low_band, "15 MHz bandwidth")),
         "Same aperture, different bandwidth", "Ground-range offset (m)"),
    ):
        for data, label in curves:
            ax.plot(line, 10 * np.log10(np.maximum(data / np.max(data), 1e-5)), label=label)
        ax.set(title=title, xlabel=xlabel, ylabel="Normalized power (dB)", ylim=(-35, 2))
        ax.legend()
        ax.grid(alpha=.25)
    fig.suptitle("SAR image-formation research · illustrative values, not APG-77 specifications")
    fig.savefig(output / "point-target-proof.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gpu-load-case", action="store_true",
                        help="Generate 1024 distinct pulse histories and a 512x512 CPU reference")
    options = parser.parse_args()
    if options.gpu_load_case:
        output = Path(__file__).resolve().parents[1] / "out/sar-research"
        output.mkdir(exist_ok=True)
        center = np.array([0.0, 12000.0, 0.0])
        pair = [(center + [-3, 0, 0], 1.0), (center + [3, 0, 0], 1.0)]
        gpu_input(output, trajectory(250, pulses=1024), pair, center, sizes=(512,))
    else:
        main()
