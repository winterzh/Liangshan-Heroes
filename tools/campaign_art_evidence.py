"""Read-only portable legacy evidence and reviewed native SpriteFrames gates."""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path, PurePosixPath

from PIL import Image
import build_directional_spriteframes as builder

MAPPING = 'tools/contracts/art_provenance_recovery_20260907/mapping.json'
MAPPING_SHA256 = '80d1b811443329787319298db58edbafb724eac37b78e586049e2e38061df71e'
NATIVE = {
    'song_jiang': ('35638ef35081e48dd4c05acd4b32f3460bd8531f08547664beb69d6cef8eff15',
                   '1c00e0d97c4ccad601081f8e76565fbd795390acf63e6ca690d3239a7d943c56'),
    'lin_chong': ('e16ddf97a05da1a991adbc37520154209e4463336701313f703058198e9c67ea',
                  '962dca1b2a27e5abd503821385d84523860487f34f18dbf4f82cf6741efe9a3b'),
}


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def contained(root, relative):
    if not isinstance(relative, str) or not relative or '\\' in relative or ':' in relative:
        raise ValueError('Expected a canonical repository-relative path')
    pure = PurePosixPath(relative)
    if pure.is_absolute() or '..' in pure.parts: raise ValueError('Path escape')
    path = root / relative
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()): raise ValueError('Symlink/path escape')
    return path


def legacy_path(root, value, expected_sha256=None):
    """Return only a pinned migrated file; no auto-search or historical writes.

    Existing local inputs remain first, so deletion/drift cannot be hidden by a
    migrated alias. Missing entries return their original unresolved path.
    Production paths are never redirected by the evidence migration.
    """
    text = str(value).replace('\\', '/').removeprefix('//?/')
    raw = Path(text)
    local = raw if raw.is_absolute() else root / raw
    # A readable old machine path must not hide a nonportable recovery. Only
    # live repository inputs are allowed to bypass the explicit migration map.
    if local.resolve().is_relative_to(root.resolve()) and local.exists():
        if expected_sha256 is None or local.is_file() and sha(local) == expected_sha256:
            return local
    unresolved = root / 'tools/contracts/art_provenance_recovery_20260907/missing' / hashlib.sha256(text.encode()).hexdigest()
    if raw.is_absolute(): local = unresolved
    if text.startswith('res://') or text.startswith('assets/') and not (Path(text).suffix in ('.json', '.txt', '.md') and expected_sha256):
        return local
    try:
        mapping_path = contained(root, MAPPING)
        if sha(mapping_path) != MAPPING_SHA256: return local
        mapping = json.loads(mapping_path.read_text(encoding='utf-8'))
        entry = next((row for row in mapping['entries'] if row['original'] == text), None)
        if entry is not None:
            if expected_sha256 is not None and entry['sha256'] != expected_sha256: return unresolved
            target = contained(root, entry['target'])
            if not entry['target'].startswith('tools/contracts/art_provenance_recovery_20260907/'):
                return local
            if not target.is_file() or sha(target) != entry['sha256']: return local
            if not entry['owners'] or not all(sha(contained(root, owner['manifest'])) == owner['manifest_sha256']
                                               for owner in entry['owners']): return local
            return target
        directory = next((row for row in mapping.get('directories', []) if row['original'] == text), None)
        if directory is not None:
            target = contained(root, directory['target'])
            if not directory['target'].startswith('tools/contracts/art_provenance_recovery_20260907/'):
                return local
            if sha(contained(root, directory['owner'])) != directory['owner_sha256']: return local
            if not directory['files'] or not all(sha(contained(root, item['path'])) == item['sha256']
                                                for item in directory['files']): return local
            return target
    except (OSError, ValueError, KeyError, TypeError): pass
    return local


def spriteframes_geometry(root, path):
    """Validate the supported declarative AtlasTexture subset without Godot.

    Geometry is not provenance. An unregistered valid TRES remains unaccepted.
    Unknown syntax, scripts, empty/default-less actions and missing dependencies
    fail closed; native acceptance additionally reproduces every authored byte.
    """
    try:
        text = path.read_text(encoding='utf-8')
        if not text.startswith('[gd_resource type="SpriteFrames" ') or 'script =' in text: return False
        external = re.findall(r'\[ext_resource type="Texture2D" path="res://([^"\n]+)" id="([^"\n]+)"\]', text)
        if not external or len({ident for _, ident in external}) != len(external): return False
        for relative, _ in external:
            source = contained(root, relative)
            if source.suffix != '.png' or not source.is_file(): return False
            with Image.open(source) as image:
                if image.width <= 0 or image.height <= 0: return False
        ext_ids = {ident for _, ident in external}
        sections = re.findall(r'\[sub_resource type="AtlasTexture" id="([^"\n]+)"\]\s*(.*?)(?=\n\[|\Z)', text, re.S)
        valid_ids = set()
        for ident, body in sections:
            if ident in valid_ids: return False
            atlas = re.search(r'atlas = ExtResource\("([^"\n]+)"\)', body)
            region = re.search(r'region = Rect2\(([^)]+)\)', body)
            margin = re.search(r'margin = Rect2\(([^)]+)\)', body)
            if not atlas or atlas[1] not in ext_ids or not region or not margin: return False
            r = [float(v) for v in region[1].split(',')]
            m = [float(v) for v in margin[1].split(',')]
            if len(r) != 4 or len(m) != 4 or not all(math.isfinite(v) for v in r + m): return False
            if min(r + m) < 0 or min(r[2:]) <= 0 or r[2] + m[2] != r[3] + m[3]: return False
            scale = re.search(r'metadata/draw_scale = ([^\n]+)', body)
            if scale and not .25 <= float(scale[1]) <= 4: return False
            valid_ids.add(ident)
        resource = text.split('[resource]', 1)[1]
        if '"name": &"default"' not in resource: return False
        frames = re.findall(r'"texture": SubResource\("([^"\n]+)"\)', resource)
        return bool(frames and all(ident in valid_ids for ident in frames))
    except (OSError, ValueError, KeyError, IndexError): return False


def native_provenance_index(root):
    result = {}
    for character, (manifest_sha, lineage_sha) in NATIVE.items():
        relative = f'assets/direction4/{character}_20260906.json'
        lineage_rel = f'tools/contracts/{character}_direction4_20260906/generation.json'
        manifest_path, lineage_path = root / relative, root / lineage_rel
        if not manifest_path.is_file(): continue
        failures = []
        outputs = {}
        manifest = {}
        try:
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            if sha(manifest_path) != manifest_sha or sha(lineage_path) != lineage_sha:
                raise ValueError('reviewed_manifest_or_lineage_hash_mismatch')
            lineage = json.loads(lineage_path.read_text(encoding='utf-8'))
            original = lineage['original_reference']
            if sha(contained(root, original['path'])) != original['sha256']:
                raise ValueError('identity_reference_hash_mismatch')
            jobs = {job['key']: job for job in lineage['jobs']}
            for job in jobs.values():
                if not job['repository_path']: continue
                if sha(contained(root, job['repository_path'])) != job['sha256']:
                    raise ValueError('generation_source_or_reference_hash_mismatch')
                if not all(ref == 'original' or ref in jobs and jobs[ref]['repository_path'] for ref in job['references']):
                    raise ValueError('missing_generation_reference_chain')
                if job.get('method') == 'godot_3d_pose_reference':
                    if not job.get('generator_artifacts') or not all(sha(contained(root, r['path'])) == r['sha256'] for r in job['generator_artifacts']):
                        raise ValueError('missing_pose_reference_generator')
                elif not job.get('prompt', '').strip(): raise ValueError('missing_generation_prompt')
            for source in manifest['sources'].values():
                path = contained(root, source['path'])
                if sha(path) != source['sha256'] or source['sha256'] != jobs[source['job']]['sha256']:
                    raise ValueError('native_source_hash_mismatch')
                with Image.open(path) as image:
                    if image.mode != 'RGBA' or list(image.size) != source['native_size'] or image.getchannel('A').histogram()[0] / (image.width * image.height) <= .35:
                        raise ValueError('native_rgba_dimensions_or_transparency_failed')
                metadata = Path(str(path) + '.import').read_text(encoding='utf-8')
                if f"process/size_limit={source['import_limit']}" not in metadata or 'mipmaps/generate=true' not in metadata:
                    raise ValueError('native_import_contract_changed')
            previous_root = builder.ROOT
            try:
                builder.ROOT = root
                outputs = builder.render(manifest)
            finally: builder.ROOT = previous_root
        except (OSError, ValueError, KeyError, TypeError) as error:
            failures.append(str(error))
        for resource in manifest.get('resources', []):
            try:
                path = contained(root, resource)
                matches = resource in outputs and path.read_text(encoding='utf-8') == outputs[resource]
                valid = spriteframes_geometry(root, path)
            except (OSError, ValueError): matches = valid = False
            compliant = not failures and matches and valid
            result[resource] = {'tracked': True, 'manifest': relative,
                                'kind': 'reviewed_native_spriteframes', 'source_id': character,
                                'provenance_compliant': compliant,
                                'reason': 'native_lineage_and_authored_spriteframes_reproduced' if compliant else 'native_lineage_or_authored_resource_incomplete',
                                'source_failures': failures,
                                'resource_reproduced': matches, 'spriteframes_geometry_valid': valid}
    return result
