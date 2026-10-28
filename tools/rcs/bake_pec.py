"""Offline single-reflection PEC physical-optics estimate; Blender Python required.

Coherent triangle integrals retain wavelength and phase. One centroid ray per
front-facing triangle approximates shadowing. This is not a full-wave solver,
SBR/multiple-bounce cavity model, RAM model, or production aircraft signature.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from edm_geometry import external_output, sha256, MAX_TRIANGLES, MAX_VERTICES

LIGHT_SPEED_M_S = 299_792_458.0
MAX_ASPECTS = 512
MAX_RAYS = 64_000_000
RAY_OFFSET_M = 0.00002


def direction(azimuth_deg, elevation_deg):
    azimuth, elevation = np.radians((azimuth_deg, elevation_deg))
    return np.array((math.cos(elevation) * math.cos(azimuth),
                     math.sin(elevation), math.cos(elevation) * math.sin(azimuth)))


def facets(vertices, faces):
    vertices, faces = np.asarray(vertices), np.asarray(faces)
    if vertices.ndim != 2 or vertices.shape[1] != 3 or not np.isfinite(vertices).all():
        raise ValueError("Invalid mesh positions")
    if faces.ndim != 2 or faces.shape[1] != 3 or faces.dtype.kind not in "iu":
        raise ValueError("Invalid mesh faces")
    if len(vertices) > MAX_VERTICES or len(faces) > MAX_TRIANGLES:
        raise ValueError("Mesh budget exceeded")
    if np.any(faces < 0) or np.any(faces >= len(vertices)):
        raise ValueError("Face references a missing vertex")
    points = vertices[faces]
    cross = np.cross(points[:, 1] - points[:, 0], points[:, 2] - points[:, 0])
    twice_area = np.linalg.norm(cross, axis=1)
    valid = twice_area > 1e-14
    if not np.any(valid):
        raise ValueError("No nondegenerate facets")
    return points[valid], cross[valid] / twice_area[valid, None], twice_area[valid] / 2


def triangle_integrals(points, normals, areas, q):
    """Integral exp(i*q.r) dS via the planar divergence theorem.

    The near-normal limit uses the centroid expansion to avoid cancellation.
    It is exact at normal incidence; the neglected term is O(phase_span**3).
    """
    centres = points.mean(axis=1)
    local = points - centres[:, None, :]
    phase = local @ q
    qt = q - (normals @ q)[:, None] * normals
    qt_squared = np.einsum("ij,ij->i", qt, qt)
    span = np.max(np.abs(phase), axis=1)
    near = span < 0.001
    result = np.empty(len(points), dtype=np.complex128)
    result[near] = areas[near] * (1 - np.sum(phase[near] ** 2, axis=1) / 24)
    far = ~near
    numerator = np.zeros(np.count_nonzero(far), dtype=np.complex128)
    for edge in range(3):
        a, b = local[far, edge], local[far, (edge + 1) % 3]
        vector = b - a
        coefficient = np.cross(vector, normals[far]) @ q
        midpoint_phase = ((a + b) * 0.5) @ q
        edge_phase = vector @ q
        numerator += coefficient * np.exp(1j * midpoint_phase) * np.sinc(edge_phase / (2 * np.pi))
    result[far] = numerator / (1j * qt_squared[far])
    return result * np.exp(1j * (centres @ q))


def visible_facets(points, normals, radar_direction, bvh, ray_distance):
    candidates = np.flatnonzero(normals @ radar_direction > 1e-8)
    centres = points[candidates].mean(axis=1)
    ray = Vector(radar_direction)
    visible = []
    for index, centre in zip(candidates, centres):
        start = Vector(centre + radar_direction * RAY_OFFSET_M)
        location, _normal, _index, _distance = bvh.ray_cast(start, ray, ray_distance)
        if location is None:
            visible.append(index)
    return np.asarray(visible, dtype=np.int64), len(candidates)


def estimate(points, normals, areas, selected, radar_direction, wavelength_m):
    if not math.isfinite(wavelength_m) or wavelength_m <= 0:
        raise ValueError("Wavelength must be positive and finite")
    integrals = triangle_integrals(points[selected], normals[selected], areas[selected],
                                   4 * np.pi / wavelength_m * radar_direction)
    amplitude = np.sum((normals[selected] @ radar_direction) * integrals)
    # Monostatic co-polar PEC PO: 4*pi/lambda^2 * |sum cos(theta)*I|^2.
    sigma = 4 * np.pi / wavelength_m ** 2 * abs(amplitude) ** 2
    if not np.isfinite(sigma):
        raise ValueError("Nonfinite PEC estimate")
    return float(sigma)


def bake_state(path, frequencies, aspects, ray_budget):
    with np.load(path, allow_pickle=False) as data:
        vertices, faces = data["vertices"], data["triangles"]
    points, normals, areas = facets(vertices, faces)
    bvh = BVHTree.FromPolygons(vertices.tolist(), faces.tolist(), all_triangles=True)
    ray_distance = float(np.linalg.norm(np.ptp(vertices, axis=0)) * 2 + 1)
    rows, rays = [], 0
    for azimuth, elevation in aspects:
        if rays + len(points) > ray_budget:
            raise ValueError("Offline ray budget exceeded; reduce the requested sweep")
        radar_direction = direction(azimuth, elevation)
        selected, cast_count = visible_facets(points, normals, radar_direction, bvh, ray_distance)
        rays += cast_count
        for frequency in frequencies:
            sigma = estimate(points, normals, areas, selected, radar_direction,
                             LIGHT_SPEED_M_S / (frequency * 1e9))
            rows.append({"azimuth_deg": azimuth, "elevation_deg": elevation,
                         "frequency_ghz": frequency, "pec_rcs_m2": sigma,
                         "illuminated_facets": len(selected)})
    return rows, rays, len(faces) - len(points)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--geometry", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--states", nargs="+", type=int, default=list(range(8)))
    parser.add_argument("--azimuth-step", type=int, default=30)
    parser.add_argument("--elevations", nargs="+", type=float, default=[-15, 0, 15])
    parser.add_argument("--frequencies-ghz", nargs="+", type=float, default=[3, 10])
    options = parser.parse_args(argv)
    output = external_output(options.output)
    if options.azimuth_step not in (5, 10, 15, 30, 45, 60, 90, 180):
        raise ValueError("Use a supported azimuth step between 5 and 180 degrees")
    if not 1 <= len(options.states) <= 8 or len(set(options.states)) != len(options.states):
        raise ValueError("Choose one to eight distinct states")
    if any(state not in range(8) for state in options.states):
        raise ValueError("Bay state must be 0..7")
    if not 1 <= len(options.elevations) <= 9 or not 1 <= len(options.frequencies_ghz) <= 8:
        raise ValueError("Elevation/frequency budget exceeded")
    if any(not math.isfinite(e) or not -90 <= e <= 90 for e in options.elevations):
        raise ValueError("Invalid elevation")
    if any(not math.isfinite(f) or not 1 <= f <= 40 for f in options.frequencies_ghz):
        raise ValueError("Frequency must be 1..40 GHz")
    aspects = [(a, e) for a in range(0, 360, options.azimuth_step) for e in options.elevations]
    if len(aspects) * len(options.states) > MAX_ASPECTS:
        raise ValueError("Aspect budget exceeded")
    manifest = json.loads(options.geometry.read_text())
    if manifest["kind"] != "experimental_geometry_candidates":
        raise ValueError("Wrong geometry schema")
    rows, rays, degenerate = [], 0, []
    for state in options.states:
        entry = manifest["states"][state]
        source = options.geometry.parent / (entry["name"] + ".npz")
        if sha256(source) != entry["sha256"]:
            raise ValueError("Geometry changed after extraction")
        values, cast_count, removed = bake_state(source, options.frequencies_ghz, aspects, MAX_RAYS - rays)
        rays += cast_count
        rows.append({"state": entry["name"], "samples": values})
        degenerate.append({"state": entry["name"], "removed_degenerate_facets": removed})
        print(json.dumps({"state": entry["name"], "samples": len(values), "rays": cast_count}), flush=True)
    result = {"schema": 1, "kind": "experimental_pec_single_reflection_estimate",
              "geometry_manifest_sha256": sha256(options.geometry),
              "source_edm_sha256": manifest["source_edm_sha256"], "rays": rays,
              "ray_offset_m": RAY_OFFSET_M, "geometry_cleanup": degenerate,
              "production_qualified": False, "multiplayer_connected": False,
              "limitations": ["PEC surfaces; no F-22 RAM, radome or material calibration",
                              "Centroid shadow rays; partially shadowed facets are approximated",
                              "No multiple reflection, cavity return or edge diffraction",
                              "Experimental EDM poses; attached stores absent",
                              "No DCS ownship-signature backend"], "states": rows}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None)
