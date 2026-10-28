"""Independent offline checks. Invoke once with Blender --background --factory-startup."""
from pathlib import Path
import math
import sys
from types import SimpleNamespace as Record
import unittest

import numpy as np
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/rcs"))
from edm_geometry import parent_selectors, triangle_indices, world_poses, interpolate
from bake_pec import facets, estimate, visible_facets, triangle_integrals


def plate():
    # Independent 2m x 1m plate in the XY plane, outward normal +Z.
    return np.array([[-1., -.5, 0], [1., -.5, 0], [1., .5, 0], [-1., .5, 0]]), np.array([[0, 1, 2], [0, 2, 3]])


def plate_sigma(theta_deg, phi_deg, wavelength):
    theta, phi = np.radians((theta_deg, phi_deg))
    k = 2 * np.pi / wavelength
    u, v = math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi)
    # NPS EC4630, Basic Theorems and Concepts, p28, analytic PEC rectangle.
    return (4 * np.pi * 4 / wavelength ** 2 * math.cos(theta) ** 2
            * np.sinc(k * 2 * u / np.pi) ** 2 * np.sinc(k * v / np.pi) ** 2)


class PhysicalOpticsChecks(unittest.TestCase):
    def test_rectangle_broadside_and_oblique_complex_phase(self):
        vertices, faces = plate()
        points, normals, areas = facets(vertices, faces)
        for theta in (0, .000001, 3, 17, 53):
            for phi in (0, 23, 90):
                for wavelength in (.03, .1, .3):
                    t, p = np.radians((theta, phi))
                    radar = np.array([math.sin(t) * math.cos(p), math.sin(t) * math.sin(p), math.cos(t)])
                    actual = estimate(points, normals, areas, np.array([0, 1]), radar, wavelength)
                    expected = plate_sigma(theta, phi, wavelength)
                    self.assertAlmostEqual(actual, expected, delta=max(1e-9, expected * 2e-8))

    def test_subdivision_and_translation_preserve_rcs(self):
        vertices, faces = plate()
        points, normals, areas = facets(vertices, faces)
        radar = np.array([.21, .13, math.sqrt(1 - .21 ** 2 - .13 ** 2)])
        original = estimate(points, normals, areas, np.array([0, 1]), radar, .031)
        expanded_vertices = np.vstack((vertices, [0., 0., 0.]))
        expanded_faces = np.array([[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]])
        points, normals, areas = facets(expanded_vertices + [71, -35, 98], expanded_faces)
        actual = estimate(points, normals, areas, np.arange(4), radar, .031)
        self.assertAlmostEqual(actual, original, delta=max(1e-10, original * 1e-8))

    def test_centroid_rays_hide_the_lower_of_two_plates(self):
        vertices, faces = plate()
        vertices = np.vstack((vertices, vertices + [0, 0, .25]))
        faces = np.vstack((faces, faces + 4))
        points, normals, _areas = facets(vertices, faces)
        tree = BVHTree.FromPolygons(vertices.tolist(), faces.tolist(), all_triangles=True)
        selected, count = visible_facets(points, normals, np.array([0., 0., 1.]), tree, 10)
        self.assertEqual(count, 4)
        self.assertEqual(selected.tolist(), [2, 3])

    def test_invalid_and_degenerate_geometry(self):
        with self.assertRaises(ValueError):
            facets(np.zeros((3, 3)), np.array([[0, 1, 2]]))
        with self.assertRaises(ValueError):
            facets(np.zeros((3, 3)), np.array([[0, 1, 9]]))
        vertices, faces = plate()
        points, normals, areas = facets(vertices, faces)
        with self.assertRaises(ValueError):
            estimate(points, normals, areas, np.array([0]), np.array([0, 0, 1]), float('nan'))


class GeometryChecks(unittest.TestCase):
    def test_parent_selectors_and_cross_parent_triangle_rejection(self):
        _positions, parents = parent_selectors([[0, 0, 0, 0], [1, 0, 0, 1], [0, 1, 0, 0]], 2)
        with self.assertRaises(ValueError):
            triangle_indices([0, 1, 2], parents)
        for selector in (-1, .5, 2, float('inf')):
            with self.assertRaises(ValueError):
                parent_selectors([[0, 0, 0, selector]], 2)
        with self.assertRaises(ValueError):
            triangle_indices([0., 1., 2.], np.array([0, 0, 0]))

    def test_hierarchy_quat2_and_visibility_are_retained(self):
        identity = np.eye(4).T.reshape(-1).tolist()
        q = (math.cos(math.pi / 4), 0, 0, math.sin(math.pi / 4))
        base = Record(matrix=identity, position=(2, 0, 0), quat1=(1, 0, 0, 0),
                      quat2=q, scale=(1, 1, 1))
        nodes = [Record(type='ArgRotationNode', parent_idx=-1, base=base,
                        pos_data=[], rot_data=[], scale_data=[], bone_transform=None),
                 Record(type='ArgVisibilityNode', parent_idx=0, vis_data=[(600, [(.5, 1)])])]
        poses, shown = world_poses(nodes, {600: 1})
        np.testing.assert_allclose(poses[1] @ [1, 0, 0, 1], [2, 1, 0, 1], atol=1e-6)
        self.assertEqual(shown, [True, True])
        self.assertEqual(world_poses(nodes, {600: 0})[1], [True, False])
        nodes[0].parent_idx = 1
        with self.assertRaises(ValueError):
            world_poses(nodes, {600: 1})

    def test_key_interpolation_clamps_and_uses_slerp(self):
        keys = [Record(frame=0, value=(1, 0, 0, 0)),
                Record(frame=1, value=(0, 0, 0, 1))]
        self.assertAlmostEqual(abs(interpolate(keys, .5, True).w), math.sqrt(.5), places=6)
        self.assertAlmostEqual(interpolate(keys, -2, True).w, 1)
        self.assertAlmostEqual(abs(interpolate(keys, 2, True).z), 1)
        keys[1].frame = 0
        with self.assertRaises(ValueError):
            interpolate(keys, .5, True)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise SystemExit(1)
