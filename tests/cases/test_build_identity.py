"""Read exported identity as bounded PE data, without executing native code."""
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from host import ROOT

sys.path.insert(0, str(ROOT / 'tools'))
from native_identity import exported_identity
from package_identity import identity_matches


def image(token):
    data = bytearray(1536)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 60, 128)
    data[128:132] = b'PE\0\0'
    struct.pack_into('<H', data, 134, 1)
    struct.pack_into('<H', data, 148, 240)
    struct.pack_into('<H', data, 152, 0x20b)
    struct.pack_into('<II', data, 264, 0x1000, 128)
    struct.pack_into('<IIII', data, 400, 1024, 0x1000, 1024, 512)
    struct.pack_into('<IIIII', data, 532, 1, 1, 0x1040, 0x1044, 0x1048)
    struct.pack_into('<IIH', data, 576, 0x1100, 0x1060, 0)
    data[608:627] = b'f22_build_identity\0'
    encoded = token.encode('ascii') + b'\0'
    data[768:768 + len(encoded)] = encoded
    return data


class BuildIdentity(unittest.TestCase):
    def read(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'image.dll'
            path.write_bytes(data)
            return exported_identity(path)

    def test_data_export_matches_only_its_source_and_cache(self):
        token = 'F22_NATIVE_V1|source=abc|cache=def|compiler=fixture|config=Release|cxx=23'
        record = self.read(image(token))
        self.assertEqual(record['token'], token)
        self.assertTrue(identity_matches(record, 'abc', 'def'))
        self.assertFalse(identity_matches(record, 'changed', 'def'))
        self.assertFalse(identity_matches(record, 'abc', 'changed'))

    def test_truncation_or_forwarded_export_cannot_be_identity(self):
        with self.assertRaises(ValueError):
            self.read(b'MZ')
        data = image('F22_NATIVE_V1|source=a|cache=b')
        struct.pack_into('<I', data, 576, 0x1060)
        with self.assertRaises(ValueError):
            self.read(data)

    def test_absent_export_is_unidentified(self):
        data = image('F22_NATIVE_V1|source=a|cache=b')
        struct.pack_into('<II', data, 264, 0, 0)
        self.assertIsNone(self.read(data))
        self.assertFalse(identity_matches(None, 'a', 'b'))

    def test_export_name_and_string_are_bounded(self):
        data = image('F22_NATIVE_V1|source=a|cache=b')
        data[608:736] = b'X' * 128
        with self.assertRaises(ValueError):
            self.read(data)


if __name__ == '__main__':
    unittest.main()
