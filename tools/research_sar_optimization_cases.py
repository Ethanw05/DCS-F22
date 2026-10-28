"""Generate bounded non-regular and empty-scene SAR validation inputs."""
from pathlib import Path

import numpy as np

import research_sar_point_targets as sar


def main():
    output = Path(__file__).resolve().parents[1] / "out/sar-research/optimization-cases"
    output.mkdir(parents=True, exist_ok=True)
    center = np.array([0.0, 12000.0, 0.0])
    positions = sar.trajectory(250, motion=True, pulses=129)
    positions[:, 1] += 2 * np.sin(np.linspace(0, 3 * np.pi, len(positions)))
    targets = [(center + [-5.3, 2.2, 0], 1 + .2j),
               (center, -.5 + .7j), (center + [3.2, -2.1, 0], .4 - .3j)]
    sar.gpu_input(output, positions, targets, center, sizes=(193,))
    # A single history and odd grid also exercise unused ping-pong contents,
    # partial groups and batches whose configured capacity exceeds collection.
    sar.gpu_input(output, sar.trajectory(250, pulses=1), [], center, sizes=(17,))


if __name__ == "__main__":
    main()
