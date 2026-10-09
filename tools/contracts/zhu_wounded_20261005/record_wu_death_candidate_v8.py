"""Record native Wu death lineage/import qualification and the rejected fog fixture."""
from pathlib import Path
import hashlib, json, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / 'qa/zhu_wounded_20261005'
EXTERNAL = ROOT.parent / 'qa-ordinary-posture-20261006'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def dump(path, value):
    assert not path.exists(), path
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))

def main():
    lineage_path = ROOT/'tools/contracts/zhu_wounded_20261005/generation_wu_song_death_v8.json'
    lineage = read(lineage_path)
    assert sha(ROOT/lineage['parent_lineage']) == lineage['parent_sha256']
    jobs = []
    for row in lineage['jobs']:
        path = ROOT/row['repository_path']
        assert sha(path) == row['sha256']
        assert sha(ROOT/row['request']) == row['request_sha256']
        assert row['method'] == 'built_in_imagegen' and not row['native_pixel_edits']
        for ref in row['references']:
            assert sha(ROOT/ref['path']) == ref['sha256']
        with Image.open(path) as image:
            assert list(image.size) == row['native_size'] and image.mode == 'RGBA'
            jobs.append({'path':row['repository_path'], 'sha256':row['sha256'],
                         'native_size':list(image.size), 'alpha_bbox':image.getchannel('A').getbbox(),
                         'selection':row['selection']})
    manifest_path = ROOT/'assets/direction4/ordinary_wu_song_20261007_death_v8.json'
    manifest = read(manifest_path)
    assert not manifest['production_qualified'] and not manifest['runtime_death_qualified']
    assert len(manifest['sources']) == 5 and len(manifest['poses']) == 12 and len(manifest['resources']) == 4
    for row in manifest['sources'].values():
        assert row['import_dimensions_verified'] and sha(ROOT/row['path']) == row['sha256']
    bootstrap = EXTERNAL/'texture_bootstrap_wu_song_death_v8_0c3445b5/receipt.json'
    assert read(bootstrap)['complete']
    dump(QA/'wu_death_native_review_v8.json', {
        'native_lineage_verified':True, 'native_pixel_edits':False, 'jobs':jobs,
        'lineage':lineage_path.relative_to(ROOT).as_posix(), 'lineage_sha256':sha(lineage_path),
        'manifest':manifest_path.relative_to(ROOT).as_posix(), 'manifest_sha256':sha(manifest_path),
        'native_import_receipt':str(bootstrap), 'native_import_receipt_sha256':sha(bootstrap),
        'selected_sources':5, 'selected_poses':12, 'resources':4,
        'visually_viewed':['death_se_v8.png','death_sw3_v8.png','death_ne3_v8.png','death_nw2_v8.png'],
        'selection_notes':[
            'SE impact missing second blade is excluded; fatal/fall/final rest selected.',
            'NW2 wrong-heading fatal is excluded; exact same-character qualified v7 hurt_nw used for fatal recoil.',
            'SW3 and NE3 fix heading or missing/cross-boundary blades. Rejected ancestors retained.',
            'Three real poses and four slots: fatal/fall/rest/rest; terminal hold is deliberate.',
            'AtlasTexture metadata only; collapse uses fixed adult anatomical scale rather than standing-height stretching.'
        ],
        'runtime_qualified':False, 'production_qualified':False,
        'scope':'Native lineage, dimensions/import and raw-art selection only. Actual skills/death pilot remains pending; not production adoption, continuous animation or release.'
    })
    failed_run = EXTERNAL/'ordinary_final_actions_v8_f2904419'
    failed = read(failed_run/'receipt.json')
    assert not failed['complete'] and failed['lock_released'] and failed['steps'][-1]['exit_code'] != 0
    copies = []
    target_dir = QA/'ordinary_final_actions_rejected_v8_frames'
    target_dir.mkdir(exist_ok=False)
    for name in ['lin_chong_0_ne_cast.png','lin_chong_0_ne_effect.png']:
        source = failed_run/'skills'/name
        target = target_dir/name
        shutil.copy2(source, target)
        assert sha(source) == sha(target)
        copies.append({'path':target.relative_to(ROOT).as_posix(),'sha256':sha(target)})
    dump(QA/'ordinary_final_actions_rejected_v8.json', {
        'qualified':False, 'reason':'Fog calculation was disabled but the old unexplored fog texture remained visible; actual actor viewport was black.',
        'failed_run':str(failed_run),'receipt_sha256':sha(failed_run/'receipt.json'),
        'owned_engine_exit_code':failed['steps'][-1]['exit_code'],'lock_released':True,
        'reviewed_native_viewports':copies,
        'replacement_harness':'qa/zhu_wounded_20261005/harness/ordinary_skills_death_v8a.gd',
        'correction':'Explicit visual fixture hides old fog layer and asserts actual actor visibility; original production scripts are unchanged.',
        'scope':'Partial mechanical assertions do not qualify rejected screenshots. Executed v8 producer and complete failure run retained.'
    })
    print(json.dumps({'native_jobs':len(jobs),'selected_sources':5,'poses':12,'resources':4,'rejected_fixture_retained':True}))

if __name__ == '__main__':
    main()
