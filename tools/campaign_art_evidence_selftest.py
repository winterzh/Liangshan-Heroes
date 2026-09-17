"""Isolated mutation tests for migration and native SpriteFrames acceptance.

Copies only enumerated inputs into TemporaryDirectory; all mutations occur there.
No production art generation, Godot, Git, history mutation or cache writes.
"""
from __future__ import annotations
import argparse
import json
import shutil
import tempfile
from pathlib import Path

import campaign_art_evidence as evidence
import campaign_direction4_coverage_audit as audit

ROOT = Path(__file__).resolve().parents[1]


def run():
    checks = []
    protected = {}
    def check(name, ok):
        checks.append({'name': name, 'passed': bool(ok)})
        if not ok: raise AssertionError(name)
    with tempfile.TemporaryDirectory(prefix='campaign_art_evidence_') as directory:
        root = Path(directory)
        def copy(relative):
            source = ROOT / relative
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            protected[relative] = evidence.sha(source)
            return target
        for character in evidence.NATIVE:
            manifest_rel = f'assets/direction4/{character}_20260906.json'
            lineage_rel = f'tools/contracts/{character}_direction4_20260906/generation.json'
            manifest = json.loads(copy(manifest_rel).read_text(encoding='utf-8'))
            lineage = json.loads(copy(lineage_rel).read_text(encoding='utf-8'))
            copy(lineage['original_reference']['path'])
            for job in lineage['jobs']:
                if job['repository_path']: copy(job['repository_path'])
                for artifact in job.get('generator_artifacts', []): copy(artifact['path'])
            for source in manifest['sources'].values():
                copy(source['path'])
                copy(source['path'] + '.import')
            for resource in manifest['resources']: copy(resource)
        accepted = evidence.native_provenance_index(root)
        check('reviewed Song Jiang 16 and Lin Chong 20 TRES accepted in isolated root',
              len(accepted) == 36 and all(row['provenance_compliant'] for row in accepted.values()))
        resource = root / 'assets/anim/song_jiang_walk_se.tres'
        pristine = resource.read_bytes()
        resource.write_bytes(pristine.replace(b'SubResource("walk_se")}', b'SubResource("idle_se")}'))
        check('valid but incorrect authored frame order rejected',
              evidence.spriteframes_geometry(root, resource) and not evidence.native_provenance_index(root)['assets/anim/song_jiang_walk_se.tres']['provenance_compliant'])
        resource.write_bytes(pristine)
        resource.write_bytes(pristine.replace(b'&"default"', b'&"other"'))
        check('missing default animation is not exact geometry', not evidence.spriteframes_geometry(root, resource))
        resource.write_bytes(pristine)
        resource.write_bytes(pristine.replace(b'Rect2(32.0, 28.5, 64, 57)', b'Rect2(32.0, 28.5, 63, 57)'))
        check('nonsquare padded atlas is not exact geometry', not evidence.spriteframes_geometry(root, resource))
        resource.write_bytes(pristine)
        lineage_path = root / 'tools/contracts/song_jiang_direction4_20260906/generation.json'
        original_lineage = lineage_path.read_bytes()
        lineage_path.write_bytes(original_lineage + b'\n')
        changed = evidence.native_provenance_index(root)
        check('lineage byte drift rejects all character actions without rejecting other character',
              all(not v['provenance_compliant'] for k, v in changed.items() if '/song_jiang_' in k)
              and all(v['provenance_compliant'] for k, v in changed.items() if '/lin_chong_' in k))
        lineage_path.write_bytes(original_lineage)
        source_path = root / 'assets/characters/song_jiang_direction4_20260906/idle_se.png'
        pristine_source = source_path.read_bytes()
        source_path.unlink()
        check('missing native PNG dependency rejects geometry and source chain',
              not evidence.spriteframes_geometry(root, resource)
              and not evidence.native_provenance_index(root)['assets/anim/song_jiang_walk_se.tres']['provenance_compliant'])
        source_path.write_bytes(pristine_source)
        unknown = root / 'assets/anim/unreviewed_walk_se.tres'
        unknown.write_bytes(pristine)
        check('unknown valid SpriteFrames do not gain native provenance',
              evidence.spriteframes_geometry(root, unknown) and 'assets/anim/unreviewed_walk_se.tres' not in evidence.native_provenance_index(root))
        previous_root = audit.ROOT
        try:
            audit.ROOT = root
            profile = audit.combat('song_jiang')
            check('generic resolution selects four exact TRES when PNG is absent',
                  all(p.endswith('.tres') for p in audit.expected_paths(profile, 'walk')[0]))
            shadow = root / 'assets/anim/song_jiang_walk_se.png'
            shadow.write_bytes(b'invalid PNG keeps runtime priority')
            check('malformed higher-priority PNG cannot be hidden by valid TRES',
                  audit.expected_paths(profile, 'walk')[0][0].endswith('.png'))
            shadow.unlink()
            check('death design lookup preserves death and missing Song Jiang hurt is not idle',
                  all('_death_' in p for p in audit.expected_paths(profile, 'down')[0])
                  and all('_hurt_' in p and not (root / p).exists() for p in audit.expected_paths(profile, 'hurt')[0]))
        finally: audit.ROOT = previous_root

        mapping = json.loads(copy(evidence.MAPPING).read_text(encoding='utf-8'))
        entry = next(row for row in mapping['entries'] if row['original'].startswith('qa/') and row['original'].endswith('manual_visual_review.json'))
        recovered = copy(entry['target'])
        for owner in entry['owners']: copy(owner['manifest'])
        check('original SHA migration resolves without a historical directory',
              evidence.legacy_path(root, entry['original']) == recovered)
        payload = recovered.read_bytes()
        recovered.write_bytes(payload + b'\n')
        check('migrated byte drift rejected', evidence.legacy_path(root, entry['original']) != recovered)
        recovered.write_bytes(payload)
        original_map = (root / evidence.MAPPING).read_bytes()
        (root / evidence.MAPPING).write_bytes(original_map + b'\n')
        check('unreviewed mapping byte drift rejected', evidence.legacy_path(root, entry['original']) != recovered)
        (root / evidence.MAPPING).write_bytes(original_map)
        owner_path = root / entry['owners'][0]['manifest']
        owner_bytes = owner_path.read_bytes()
        owner_path.write_bytes(owner_bytes + b'\n')
        check('changed owning production manifest rejects migrated chain', evidence.legacy_path(root, entry['original']) != recovered)
        owner_path.write_bytes(owner_bytes)
        previous_pin = evidence.MAPPING_SHA256
        try:
            altered = json.loads(original_map)
            chosen = next(row for row in altered['entries'] if row['original'] == entry['original'])
            chosen['target'] = '../escape.json'
            (root / evidence.MAPPING).write_text(json.dumps(altered), encoding='utf-8')
            evidence.MAPPING_SHA256 = evidence.sha(root / evidence.MAPPING)
            rejected_path = evidence.legacy_path(root, entry['original'])
            check('even a separately pinned malformed map cannot escape repository',
                  rejected_path.resolve().is_relative_to(root.resolve()) and not rejected_path.exists())
        finally:
            evidence.MAPPING_SHA256 = previous_pin
            (root / evidence.MAPPING).write_bytes(original_map)
        check('runtime PNG paths cannot be redirected through historical mapping',
              evidence.legacy_path(root, 'assets/anim/missing.png') == root / 'assets/anim/missing.png')
        outside = root.parent / (root.name + '_external.txt')
        try:
            outside.write_text('readable external file is not portable evidence', encoding='utf-8')
            check('readable external path is rejected without a fixed recovery record',
                  evidence.legacy_path(root, str(outside)) != outside)
        finally: outside.unlink(missing_ok=True)
        check('restored isolated inputs accept all 36 authored resources',
              all(row['provenance_compliant'] for row in evidence.native_provenance_index(root).values()))
    check('real enumerated inputs remain byte-identical',
          all(evidence.sha(ROOT / relative) == expected for relative, expected in protected.items()))
    return {'kind': 'campaign_art_evidence_isolated_selftest', 'passed': True,
            'checks': checks, 'check_count': len(checks), 'real_inputs_protected': len(protected),
            'production_written': False, 'godot_run': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    try: result = run()
    except Exception as error: result = {'passed': False, 'error': f'{type(error).__name__}: {error}'}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__': raise SystemExit(main())
