"""Read the bounded identity export from PE bytes without loading/executing a DLL."""
import struct


def exported_identity(path):
    maximum_bytes = 128 * 1024 * 1024
    with path.open('rb') as stream:
        data = stream.read(maximum_bytes + 1)
    if len(data) > maximum_bytes:
        raise ValueError('PE identity input exceeds 128 MiB policy')

    def unpack(fmt, offset):
        size = struct.calcsize(fmt)
        if offset < 0 or offset + size > len(data):
            raise ValueError('Truncated PE identity input')
        return struct.unpack_from(fmt, data, offset)

    if data[:2] != b'MZ':
        raise ValueError('Expected a Windows PE image')
    pe, = unpack('<I', 60)
    if data[pe:pe+4] != b'PE\0\0':
        raise ValueError('Invalid PE signature')
    sections, = unpack('<H', pe + 6)
    optional_size, = unpack('<H', pe + 20)
    magic, = unpack('<H', pe + 24)
    if magic != 0x20B or not 1 <= sections <= 96:
        raise ValueError('Expected the declared x64 PE format')
    export_rva, export_size = unpack('<II', pe + 24 + 112)
    if export_rva == 0 and export_size == 0:
        return None
    section_start = pe + 24 + optional_size

    def raw(rva, length=1):
        for index in range(sections):
            virtual_size, virtual_address, size, offset = unpack('<IIII', section_start + index*40 + 8)
            if virtual_address <= rva < virtual_address + max(virtual_size, size):
                relative = rva - virtual_address
                if relative + length <= size and offset + relative + length <= len(data):
                    return offset + relative
        raise ValueError('Identity RVA is outside file-backed PE sections')

    def string(rva, maximum):
        offset = raw(rva)
        for length in range(maximum):
            raw(rva, length+1)
            if data[offset+length] == 0:
                return data[offset:offset+length].decode('ascii')
        raise ValueError('Unterminated identity string')

    directory = raw(export_rva, 40)
    functions, names, function_rva, name_rva, ordinal_rva = unpack('<IIIII', directory + 20)
    if not 0 < names <= functions <= 4096:
        raise ValueError('Unsupported export table size')
    for index in range(names):
        name, = unpack('<I', raw(name_rva + index*4, 4))
        if string(name, 128) != 'f22_build_identity':
            continue
        ordinal, = unpack('<H', raw(ordinal_rva + index*2, 2))
        if ordinal >= functions:
            raise ValueError('Invalid identity ordinal')
        rva, = unpack('<I', raw(function_rva + ordinal*4, 4))
        if export_rva <= rva < export_rva + export_size:
            raise ValueError('Identity must be data, not a forwarded export')
        value = string(rva, 256)
        if not value.startswith('F22_NATIVE_V1|'):
            raise ValueError('Unrecognized native identity schema')
        return dict(token=value, rva=rva)
    return None
