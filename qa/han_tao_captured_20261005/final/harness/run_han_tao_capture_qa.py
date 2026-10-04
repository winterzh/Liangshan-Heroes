"""Adapt the shared frozen/private Godot QA driver to Han Tao's captured pose.

Example: python -X utf8 -B tools/run_han_tao_capture_qa.py --repo <checkout>
 --work-root <external-root> --manifest han_tao=assets/direction4/han_tao_captured_20261005.json
 --cache-from <successful-private-character-run> --shared-checks --run
All shared lock, source freeze, engine-idle, profile and byte-drift guards remain active.
No packaging, platform publish, Git mutation or control of other tasks.
"""
from pathlib import Path
import json
import run_character_art_qa as driver

def parse_cases(repo, entries):
    if len(entries)!=1 or not entries[0].startswith('han_tao='):
        raise ValueError('Exactly one han_tao manifest is required')
    relative=driver.relative_source(repo,entries[0].split('=',1)[1])
    if not relative.startswith('assets/direction4/') or not relative.endswith('.json'):
        raise ValueError('Manifest must be under assets/direction4')
    manifest=json.loads((repo/relative).read_text(encoding='utf-8'))
    expected={f'assets/anim/han_tao_captured_{d}.tres' for d in ('se','sw','ne','nw')}
    if manifest.get('character')!='han_tao' or manifest.get('states')!={'captured':['captured']} or set(manifest.get('resources',[]))!=expected:
        raise ValueError('Wrong character/states/resources for this story-only QA')
    if set(manifest.get('poses',{}))!={f'captured_{d}' for d in ('se','sw','ne','nw')}:
        raise ValueError('Four independently sampled captured poses required')
    dependencies={relative}|expected
    for row in manifest['sources'].values():
        native=driver.relative_source(repo,row['path'])
        if not native.startswith('assets/characters/han_tao_captured_') or not native.endswith('.png') or driver.sha(repo/native)!=row['sha256']:
            raise ValueError('Native capture source differs')
        dependencies|={native,driver.relative_source(repo,native+'.import')}
    return [{'character':'han_tao','manifest':relative,'manifest_sha256':driver.sha(repo/relative),'dependencies':sorted(dependencies)}]

def verify_report(case, directory, visual):
    path=directory/'report.json';report=json.loads(path.read_text(encoding='utf-8'))
    if report.get('passed') is not True or report.get('failures') or report.get('character')!='han_tao' or report.get('manifest')!='res://'+case['manifest'] or report.get('checks',0)<50:
        raise RuntimeError('Han Tao capture behavioral report failed or incomplete')
    pairs={(r.get('state'),r.get('direction')) for r in report.get('resources',[])}
    if pairs!={('captured',d) for d in ('se','sw','ne','nw')}:
        raise RuntimeError('Missing captured resource direction')
    if not any(r.get('case')=='han_actual_capture' and r.get('actor_retained') is True and r.get('captured') is True and r.get('mission_event') is True and r.get('hp_before',0)>400 and r.get('hp_after',0)>0 and r.get('damage_ticks',0)>1 and r.get('hp_modified') is False for r in report.get('runtime',[])):
        raise RuntimeError('Missing actual chapter normal-damage capture proof')
    before,after=report['identity_before'],report['identity_after']
    if not before.get('ok') or not after.get('ok') or before['source_sha256']!=after['source_sha256'] or before['file_count']!=after['file_count'] or report['engine_time_scale']!=1.0 or not report['private_profile']['passed']:
        raise RuntimeError('Identity/time/private-profile proof failed')
    names=set()
    for row in report.get('screenshots',[]):
        screenshot=Path(row['path']).resolve()
        if not screenshot.is_relative_to(directory.resolve()) or not screenshot.is_file() or driver.sha(screenshot)!=row['sha256']:
            raise RuntimeError('Screenshot bytes/path differ')
        names.add(row['name'])
    expected={f'han_captured_{d}' for d in ('se','sw','ne','nw')}|{'han_opening','han_captured_matrix','han_capture_persistent','hu_retreated'}
    if visual and not expected<=names:raise RuntimeError('Required actual/matrix/persistent/retreat renders missing')
    return {'character':'han_tao','checks':report['checks'],'report_sha256':driver.sha(path),'screenshots':len(names),'identity':before}

def main():
    original_parser=driver.parser
    def parser():
        ap=original_parser()
        ap.set_defaults(qa_script=Path(__file__).with_name('han_tao_capture_direction4_qa.gd'))
        return ap
    driver.CHARACTERS=('han_tao',)
    driver.QA_DEST='tools/han_tao_capture_direction4_qa.gd'
    driver.TOOLS=driver.TOOLS+('tools/art_character_direction4_qa.gd','tools/han_tao_capture_body_fixture.gd','tools/run_character_art_qa.py','tools/run_han_tao_capture_qa.py','tools/build_directional_spriteframes.py','tools/character_art_lock_selftest.py')+tuple('tools/contracts/han_tao_captured_20261005/'+name for name in ('prepare.py','jobs.json','generation.json','generation_request.json','README.md'))
    driver.parse_cases=parse_cases
    driver.verify_character_report=verify_report
    driver.parser=parser
    return driver.main()
if __name__=='__main__':raise SystemExit(main())
