#!/usr/bin/env python3
"""Split the exported Godot 4.6 PCK into core and demand-loaded avatar packs.
Preserves imported paths/remaps and verifies original entry hashes. Only format
3 with an unencrypted directory at the end is supported; unknown formats fail.
"""
import hashlib, json, re, struct, sys
from pathlib import Path


def read_pack(path):
    data = path.read_bytes()
    if data[:4] != b'GDPC' or struct.unpack_from('<I', data, 4)[0] != 3:
        raise ValueError('Expected Godot PCK format 3')
    flags = struct.unpack_from('<I', data, 20)[0]
    if flags != 2:
        raise ValueError('Expected an unencrypted directory at the end')
    base, directory = struct.unpack_from('<QQ', data, 24)
    count = struct.unpack_from('<I', data, directory)[0]
    at = directory + 4
    entries = {}
    for _ in range(count):
        length = struct.unpack_from('<I', data, at)[0]; at += 4
        name = data[at:at+length].rstrip(b'\0').decode(); at += length
        offset, size = struct.unpack_from('<QQ', data, at); at += 16
        digest = data[at:at+16]; at += 16
        entry_flags = struct.unpack_from('<I', data, at)[0]; at += 4
        if entry_flags:
            raise ValueError('Encrypted/removed entries cannot be split')
        contents = data[base+offset:base+offset+size]
        if len(contents) != size or hashlib.md5(contents).digest() != digest:
            raise ValueError('Invalid entry: ' + name)
        entries[name] = contents
    return data[:base], entries


def write_pack(header, entries):
    result = bytearray(header)
    base = len(header)
    directory = []
    for name, contents in sorted(entries.items()):
        result.extend(b'\0' * (-len(result) % 16))
        offset = len(result) - base
        result.extend(contents)
        path = name.encode(); path += b'\0' * (-len(path) % 4)
        directory.append(struct.pack('<I', len(path)) + path + struct.pack('<QQ', offset, len(contents)) + hashlib.md5(contents).digest() + struct.pack('<I', 0))
    result.extend(b'\0' * (-len(result) % 16))
    struct.pack_into('<Q', result, 32, len(result))
    result.extend(struct.pack('<I', len(directory)))
    for entry in directory:
        result.extend(entry)
    return bytes(result)


def group(name):
    leaf = name.rsplit('/', 1)[-1]
    if '/characters/hair/' in name or leaf.startswith(('Hair_', 'T_Hair_')):
        return 'hair'
    if '/animations/' in name or leaf.startswith('UAL1_'):
        return 'animations'
    if 'Superhero_Male' in leaf or 'Superhero_Male' in name:
        return 'male'
    if 'Superhero_Female' in leaf or 'Superhero_Female' in name:
        return 'female'
    return 'core'


def split(web):
    path = web / 'index.pck'
    header, entries = read_pack(path)
    buckets = {key: {} for key in ('core', 'world', 'male', 'female', 'hair', 'animations')}
    world_paths = set()
    for name, contents in entries.items():
        if name.startswith(('assets/third_party/quaternius/nature/', 'assets/third_party/kenney/')):
            world_paths.add(name)
            if name.endswith('.import'):
                world_paths.update(re.findall(r'res://([^"\n]+)', contents.decode()))
    for name, contents in entries.items():
        buckets['world' if name in world_paths else group(name)][name] = contents
    manifest = {}
    dest = web / 'asset-packs'; dest.mkdir(exist_ok=True)
    for key in ('world', 'male', 'female', 'hair', 'animations'):
        if not buckets[key]:
            raise ValueError('Missing pack: ' + key)
        pack = write_pack(header, buckets[key])
        digest = hashlib.sha256(pack).hexdigest()
        name = f'{key}-{digest}.pck'
        (dest / name).write_bytes(pack)
        manifest[key] = {'file': 'asset-packs/' + name, 'sha256': digest, 'bytes': len(pack)}
    current_names = {Path(v['file']).name for v in manifest.values()}
    for old_pack in dest.glob('*.pck'):
        if old_pack.name not in current_names:
            old_pack.unlink()
    manifest_bytes = json.dumps(manifest, sort_keys=True).encode()
    buckets['core']['data/web_asset_packs.json'] = manifest_bytes
    (dest / 'manifest.json').write_bytes(manifest_bytes)
    original = path.stat().st_size
    path.write_bytes(write_pack(header, buckets['core']))
    # Validate that splitting neither drops nor mutates any exported resource.
    _, core = read_pack(path)
    combined = dict(core)
    for info in manifest.values():
        _, resources = read_pack(web / info['file'])
        if combined.keys() & resources.keys():
            raise ValueError('Duplicate entries across packs')
        combined.update(resources)
    combined.pop('data/web_asset_packs.json')
    if combined != entries:
        raise ValueError('Split pack resource inventory differs from export')
    html = web / 'index.html'
    text, count = re.subn(r'("index.pck"\s*:\s*)\d+', lambda m: m[1] + str(path.stat().st_size), html.read_text())
    if count != 1:
        raise ValueError('Cannot update PCK download size in HTML')
    html.write_text(text)
    print(f'WEB PACKS: core {path.stat().st_size:,} bytes (was {original:,}); ' + ', '.join(f'{k} {v["bytes"]:,}' for k, v in manifest.items()))
    return manifest


if __name__ == '__main__':
    split(Path(sys.argv[1]))
