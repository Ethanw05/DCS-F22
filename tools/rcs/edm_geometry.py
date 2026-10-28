"""Read-only, offline EDM geometry candidate extraction. Run with Blender Python.

This adapter does not import an add-on, alter an EDM, or change DCS signatures.
The pose interpretation is experimental until compared with the DCS model viewer.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys

import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
PARSER_COMMIT = "13cc40b32cd4a39d4337d7beb6e79365a8149770"
MAX_NODES = 4096
MAX_VERTICES = 2_000_000
MAX_TRIANGLES = 2_000_000
BAY_ARGUMENTS = (600, 601, 602)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def external_output(path):
    path = Path(path).resolve()
    if path == ROOT or ROOT in path.parents:
        raise ValueError("Derived model outputs must be outside the repository")
    if path.exists():
        raise ValueError("Output already exists; choose a new output directory")
    return path


def read_model(source, reader, expected_hashes):
    """Reject changed dependencies, parser recovery and unconsumed file data."""
    reader = Path(reader).resolve()
    for name, expected in expected_hashes.items():
        if sha256(reader / name) != expected:
            raise ValueError("EDM parser dependency differs: " + name)
    source = Path(source).resolve()
    if not 5 <= source.stat().st_size <= 64 * 1024 * 1024:
        raise ValueError("EDM input outside the 5-byte..64-MiB limit")
    sys.path.insert(0, str(reader))
    from edm.parser import EDMFileParser
    diagnostics = io.StringIO()
    with source.open("rb") as stream, contextlib.redirect_stdout(diagnostics):
        parser = EDMFileParser(stream)
        model = parser.parse()
        if stream.tell() != source.stat().st_size:
            raise ValueError("EDM parser did not consume the entire file")
    if diagnostics.getvalue():
        raise ValueError("EDM parser emitted a warning or used recovery")
    if model.version != 10 or model.extra_render_items:
        raise ValueError("Only fully parsed EDM v10 render buckets are supported")
    if not 0 < len(model.nodes) <= MAX_NODES:
        raise ValueError("Scene node budget exceeded")
    return model


def parent_selectors(vertices, parent_count):
    values = np.asarray(vertices, dtype=np.float64)
    if values.ndim != 2 or values.shape[1] < 4 or not np.isfinite(values).all():
        raise ValueError("Invalid vertex positions/parent selectors")
    if np.any(values[:, 3] < 0) or np.any(values[:, 3] >= parent_count):
        raise ValueError("Parent selector outside the parent table")
    selectors = values[:, 3].astype(np.int64)
    if np.any(values[:, 3] != selectors):
        raise ValueError("Fractional parent selector")
    if np.any(selectors < 0) or np.any(selectors >= parent_count):
        raise ValueError("Parent selector outside the parent table")
    return values[:, :3], selectors


def triangle_indices(indices, selectors):
    indices = np.asarray(indices)
    if indices.dtype.kind not in "iu":
        raise ValueError("Triangle indices must be integers")
    if indices.size % 3 or indices.size > MAX_TRIANGLES * 3:
        raise ValueError("Invalid triangle count")
    if np.any(indices < 0) or np.any(indices >= len(selectors)):
        raise ValueError("Triangle references a missing vertex")
    faces = indices.reshape((-1, 3))
    face_parents = selectors[faces]
    if np.any(face_parents != face_parents[:, :1]):
        raise ValueError("Triangle spans different rigid parents")
    return faces


def checked_quaternion(value):
    if len(value) != 4 or not np.isfinite(value).all() or np.linalg.norm(value) < 1e-12:
        raise ValueError("Invalid animation quaternion")
    return Quaternion(value).normalized()


def interpolate(keys, argument, rotation=False):
    if not keys or len(keys) > 4096:
        raise ValueError("Missing/excessive animation keys")
    frames = [key.frame for key in keys]
    if not np.isfinite(frames).all() or any(b <= a for a, b in zip(frames, frames[1:])):
        raise ValueError("Animation keys must have finite, strictly increasing frames")
    if argument <= frames[0]:
        value = keys[0].value
    elif argument >= frames[-1]:
        value = keys[-1].value
    else:
        index = int(np.searchsorted(frames, argument))
        left, right = keys[index - 1], keys[index]
        fraction = (argument - left.frame) / (right.frame - left.frame)
        if rotation:
            return checked_quaternion(left.value).slerp(checked_quaternion(right.value), fraction)
        value = (1.0 - fraction) * np.asarray(left.value) + fraction * np.asarray(right.value)
    if not np.isfinite(value).all():
        raise ValueError("Nonfinite animation value")
    return checked_quaternion(value) if rotation else Vector(value)


def matrix_from_edm(values):
    if len(values) != 16 or not np.isfinite(values).all():
        raise ValueError("Invalid EDM matrix")
    return Matrix([values[i:i + 4] for i in range(0, 16, 4)]).transposed()


def local_pose(node, arguments):
    if node.type in ("Node", "ArgVisibilityNode"):
        return Matrix.Identity(4)
    if node.type == "TransformNode":
        return matrix_from_edm(node.matrix)
    if node.type not in ("ArgAnimationNode", "ArgPositionNode", "ArgRotationNode"):
        raise ValueError("Unsupported pose node: " + node.type)
    if node.scale_data or node.bone_transform is not None:
        raise ValueError("Scale/skinned animation requires a separate validated adapter")
    if len(node.pos_data) > 1 or len(node.rot_data) > 1:
        raise ValueError("Multiple animation channels are not qualified")
    base = node.base
    position = Vector(base.position)
    rotation = Quaternion((1, 0, 0, 0))
    for argument, keys in node.pos_data:
        position += interpolate(keys, arguments.get(argument, 0.0))
    for argument, keys in node.rot_data:
        rotation = interpolate(keys, arguments.get(argument, 0.0), True)
    # Candidate convention from the reverse-engineered EDM specification.
    # Keep Quat2; dropping it changes the side-bay door pose in this model.
    return (matrix_from_edm(base.matrix) @ Matrix.Translation(position)
            @ checked_quaternion(base.quat1).to_matrix().to_4x4()
            @ rotation.to_matrix().to_4x4() @ Matrix.Diagonal((*base.scale, 1.0))
            @ checked_quaternion(base.quat2).to_matrix().to_4x4())


def world_poses(nodes, arguments):
    result, visible = [], []
    for start in range(len(nodes)):
        chain, seen, index = [], set(), start
        for _ in range(len(nodes) + 1):
            if index == -1:
                break
            if not 0 <= index < len(nodes) or index in seen:
                raise ValueError("Invalid/cyclic scene parent chain")
            seen.add(index)
            chain.append(index)
            index = nodes[index].parent_idx
        matrix, shown = Matrix.Identity(4), True
        for index in reversed(chain):
            node = nodes[index]
            matrix = matrix @ local_pose(node, arguments)
            for argument, ranges in getattr(node, "vis_data", []):
                value = arguments.get(argument, 0.0)
                shown = shown and any(low <= value <= high for low, high in ranges)
        result.append(np.asarray(matrix, dtype=np.float64))
        visible.append(shown)
    return result, visible


def extract(model, arguments):
    """Use each vertex's parent selector; index_start can be zero for all parents."""
    poses, visible = world_poses(model.nodes, arguments)
    vertices, triangles, owners, offset = [], [], [], 0
    total_vertices = sum(len(node.vertex_data) for node in model.render_nodes)
    if total_vertices > MAX_VERTICES or len(model.render_nodes) > MAX_NODES:
        raise ValueError("Render geometry budget exceeded")
    for node in model.render_nodes:
        if node.type != "RenderNode" or not node.parents:
            raise ValueError("Unsupported render node")
        material = model.materials[node.material_id]
        if not material.vertex_format or material.vertex_format.size_of(0) != 4:
            raise ValueError("Position/parent channel must have four floats")
        positions, selectors = parent_selectors(node.vertex_data, len(node.parents))
        faces = triangle_indices(node.index_data, selectors)
        for selector, parent in enumerate(node.parents):
            if not 0 <= parent.node < len(poses):
                raise ValueError("Render parent does not exist")
            if not visible[parent.node]:
                continue
            selected_faces = faces[selectors[faces[:, 0]] == selector]
            if not len(selected_faces):
                continue
            used, remap = np.unique(selected_faces, return_inverse=True)
            points = np.column_stack((positions[used], np.ones(len(used))))
            transformed = (poses[parent.node] @ points.T).T[:, :3]
            vertices.append(transformed)
            triangles.append(remap.reshape((-1, 3)) + offset)
            owners.extend([parent.node] * len(selected_faces))
            offset += len(used)
    if not vertices:
        raise ValueError("No visible geometry")
    points, faces = np.concatenate(vertices), np.concatenate(triangles)
    if len(faces) > MAX_TRIANGLES or not np.isfinite(points).all():
        raise ValueError("Invalid/excessive posed geometry")
    return points, faces, np.asarray(owners, dtype=np.int32)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--edm", type=Path, required=True)
    parser.add_argument("--reader", type=Path, required=True)
    parser.add_argument("--dependency-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--arguments", type=Path, required=True,
                        help="Explicit JSON argument values; all unlisted arguments are zero")
    options = parser.parse_args(argv)
    output = external_output(options.output)
    arguments = {int(key): float(value) for key, value in json.loads(options.arguments.read_text()).items()}
    if len(arguments) > 1024 or not np.isfinite(list(arguments.values())).all():
        raise ValueError("Invalid argument profile")
    source_hash = sha256(options.edm)
    dependency = json.loads(options.dependency_manifest.read_text())
    if dependency["commit"] != PARSER_COMMIT:
        raise ValueError("Unrecognized parser revision")
    model = read_model(options.edm, options.reader, dependency["sha256"])
    output.mkdir(parents=True)
    states = []
    for mask in range(8):
        posed_arguments = dict(arguments)
        posed_arguments.update({arg: float((mask >> bit) & 1) for bit, arg in enumerate(BAY_ARGUMENTS)})
        vertices, faces, owners = extract(model, posed_arguments)
        name = "bay-" + format(mask, "03b")
        np.savez_compressed(output / (name + ".npz"), vertices=vertices,
                            triangles=faces, owners=owners)
        states.append({"name": name, "arguments": posed_arguments,
                       "vertices": len(vertices), "triangles": len(faces),
                       "bounds_m": [vertices.min(axis=0).tolist(), vertices.max(axis=0).tolist()],
                       "sha256": sha256(output / (name + ".npz"))})
    if source_hash != sha256(options.edm):
        raise ValueError("Input EDM changed during extraction")
    manifest = {"schema": 1, "kind": "experimental_geometry_candidates",
                "source_edm_sha256": source_hash, "parser_commit": PARSER_COMMIT,
                "coordinate_frame": "EDM body frame, metres, Y up; no axis correction",
                "pose_qualified_in_DCS": False, "states": states,
                "limitations": ["Reverse-engineered transform/visibility interpretation",
                                "No attached weapon models or radar material properties",
                                "No runtime DCS RCS consumer or multiplayer integration"]}
    (output / "geometry.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"output": str(output), "states": len(states),
                      "triangles_per_state": states[0]["triangles"]}))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None)
