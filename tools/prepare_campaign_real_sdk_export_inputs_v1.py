"""Generate three immutable SDK bootstrap export overlays; never run Godot/SDK.

The private exported entry uses scripts/scenes, which are production resource
roots. The current presets exclude tools/* even when a tool is main_scene.
Successful durable prior, full export/protection/admission remain mandatory
before any future native preparation or launch.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

from campaign_real_sdk_bootstrap_contract_v4 import no_links, require

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/campaign_progress_recovery_20261008'
LOGICAL='867bd2d1b78339f357200e4dca344d14fb38a05c39f3e7906fe3f11507b60209'
ALIASES={'probe':'scripts/qa_real_sdk_bootstrap_v3.gd',
         'scene':'scenes/qa_real_sdk_bootstrap_v3.tscn','project':'project.godot'}


def pin(path):
    path=Path(path);no_links(path);raw=path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def original(row):
    path=Path(row['path']);no_links(path);raw=path.read_bytes()
    require(len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256'],
            'ORIGINAL_SOURCE_PIN_CHANGED')
    require(pin(path)=={k:row[k] for k in ('path','bytes','sha256')},'ORIGINAL_SOURCE_CHANGED_DURING_READ')
    return raw


def patch_project(raw):
    pattern=rb'(?m)^run/main_scene="res://scenes/menu\.tscn"(?=\r?$)'
    require(len(re.findall(pattern,raw))==1,'ONE_ORIGINAL_MENU_MAIN_SCENE')
    return re.sub(pattern,b'run/main_scene="res://'+ALIASES['scene'].encode()+b'"',raw)


def check_preset(raw):
    text=raw.decode('utf-8',errors='strict')
    sections=re.split(r'(?m)(?=^\[preset\.\d+\]$)',text)
    selected=[s for s in sections if 'name="Windows Steam"' in s]
    require(len(selected)==1,'ONE_WINDOWS_STEAM_PRESET')
    selected=selected[0]
    for item in ('platform="Windows Desktop"','custom_features="steam"',
                 'export_filter="all_resources"','script_export_mode=2','binary_format/embed_pck=true'):
        require(item in selected,'STEAM_COMPILED_EMBEDDED_EXPORT_PRESET')
    exclude=re.search(r'^exclude_filter="([^"]*)"$',selected,re.M)
    require(exclude is not None and 'tools/*' in exclude.group(1).split(', '),
            'ORIGINAL_TOOLS_EXCLUSION_CONFIRMED')
    # Only these three exact known paths are introduced; do not broaden filters.
    from fnmatch import fnmatchcase
    filters=[f.strip() for f in exclude.group(1).split(',')]
    require(all(not any(fnmatchcase(path,f) for f in filters) for path in ALIASES.values()),
            'NEW_EXACT_ENTRY_PATHS_NOT_EXCLUDED')


def recipe():
    basis_path=QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json';basis_pin=pin(basis_path)
    basis=json.loads(original(basis_pin))
    # Use original V12's canonical implementation and all its own fixed pins.
    from run_durable_campaign_chain_v12 import canonical, verify_pin
    require(basis['source_spec_sha256']==LOGICAL==canonical(basis['spec']),
            'EXACT_DURABLE_V12_SOURCE_BASIS')
    for row in basis['spec']['pins']:verify_pin(row)
    inputs=deepcopy(basis['spec']['inputs'])
    bridge_pin=inputs['base_bridge'];bridge=json.loads(original(bridge_pin))
    require(bridge['complete'] is True and bridge['candidate_identity']==inputs['base_identity'],
            'ORIGINAL_COMPLETE_BASE_BRIDGE')
    base=Path(bridge['candidate_root']);no_links(base)
    def base_row(name):
        rows=[r for r in inputs['base_identity']['files'] if r['path']==name]
        require(len(rows)==1,'ONE_ORIGINAL_BASE_ROOT_FILE')
        return dict(rows[0],path=str(base/name))
    project_pin=base_row('project.godot');preset_pin=base_row('export_presets.cfg')
    require(not any(r['runtime_path'] in ALIASES.values()
                    for r in inputs['runtime_and_harness_overlays']), 'ENTRY_ALIASES_NOT_ALREADY_OVERRIDDEN')
    project=original(project_pin);preset=original(preset_pin);check_preset(preset)
    candidate=QA/'real_sdk_bootstrap_candidate_v3'
    gd_pin=pin(candidate/'real_sdk_bootstrap_v3.gd')
    scene_pin=pin(candidate/'real_sdk_bootstrap_v3.tscn')
    scene=original(scene_pin)
    old=b'res://tools/real_sdk_bootstrap_v3.gd'
    require(scene.count(old)==1,'ONE_ORIGINAL_PROBE_SCENE_ALIAS')
    result={'schema':'real_sdk_bootstrap_export_overlay_recipe_v1','basis':basis_pin,
            'durable_basis_logical_sha256':LOGICAL,'base_bridge':bridge_pin,
            'original_project':project_pin,'original_preset':preset_pin,
            'original_probe':gd_pin,'original_scene':scene_pin,
            'inputs':inputs,'aliases':ALIASES.copy(),'source_only':True,
            'exporter_implemented':False,'launcher_implemented':False,'native_started':False,
            'Godot_parsed':False,'compiled_export_sealed':False,'approved_stages':[],
            'SDK_reward_once_qualified':False,'original19_qualified':False,'overall_goal_qualified':False}
    return result,{'probe':original(gd_pin),'scene':scene.replace(old,b'res://'+ALIASES['probe'].encode()),
                   'project':patch_project(project)}


def prepare(output):
    spec,contents=recipe()
    output=Path(output);no_links(output)
    require(output.is_absolute() and output.parent==QA and not output.exists(),
            'EXCLUSIVE_SOURCE_ONLY_QA_OUTPUT')
    output.mkdir(exist_ok=False)
    names={'probe':'qa_real_sdk_bootstrap_v3.gd','scene':'qa_real_sdk_bootstrap_v3.tscn',
           'project':'sdk_bootstrap_project_v1.godot'}
    additions=[]
    for kind,raw in contents.items():
        path=output/names[kind]
        with path.open('xb') as stream:stream.write(raw)
        row=pin(path);require(original(row)==raw,'GENERATED_ORIGINAL_BYTES')
        additions.append(dict(row,runtime_path=ALIASES[kind]))
    spec['inputs']['runtime_and_harness_overlays']+=additions
    spec['inputs']['schema']='real_sdk_bootstrap_export_inputs_v1'
    spec['inputs']['execution_contract']={'kind':'normal_exported_SDK_bootstrap_only',
                                          'real_SDK':True,'main_scene':'res://'+ALIASES['scene'],
                                          'required_successful_all61_prior':True}
    spec['generated_overlays']=additions;spec['preparer']=pin(Path(__file__))
    with (output/'SOURCE_INPUTS.json').open('xb') as stream:
        stream.write((json.dumps(spec,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    return spec


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    value=prepare(args.output) if args.output else recipe()[0]
    print(json.dumps({'source_only':True,'prepared':bool(args.output),
                      'runtime_overlays':len(value['inputs']['runtime_and_harness_overlays']),
                      'aliases':value['aliases'],'native_started':False},ensure_ascii=False))
