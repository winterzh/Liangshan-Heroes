"""Append-only QA evidence archive; excludes every private user/profile directory."""
from pathlib import Path
import argparse, hashlib, json, os
ROOT=Path(__file__).resolve().parents[1]
SKIP_DIRS={'private_roaming','private_local','private_profile','profile','appdata','localappdata','project','legacy_project','frozen','candidate','generated_preview','__pycache__'}
ALLOW={'.json','.log','.png','.md','.py','.gd','.in','.patch'}

class Archive:
    def __init__(self,name,apply):
        self.dest=ROOT/'qa'/name;self.apply=apply;self.files={}
        mp=self.dest/'archive_manifest.json'
        self.previous=json.loads(mp.read_bytes())['files'] if mp.exists() else []
    def add(self,source,relative):
        source=ROOT/source;target=self.dest/relative
        if source.name in {'running_receipt.json','settings.cfg','campaign.cfg','screen.cfg','launch_plan.json'}:return
        assert source.is_file() and not source.is_symlink()
        raw=source.read_bytes()
        row={'source':source.relative_to(ROOT).as_posix(),'archive':target.relative_to(ROOT).as_posix(),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
        assert row['archive'] not in self.files or self.files[row['archive']]==row
        self.files[row['archive']]=row
        if target.exists():assert target.read_bytes()==raw,'Archive collision: '+str(target)
        elif self.apply:
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    def tree(self,source,relative,recursive=False,images=True,tools=False):
        directory=ROOT/source
        if not directory.exists():return
        def walked():
            def fail(error):raise error
            for parent,dirs,names in os.walk(directory,onerror=fail,followlinks=False):
                for name in dirs:
                    p=Path(parent)/name
                    assert not p.is_symlink() and not getattr(p.lstat(),'st_file_attributes',0)&0x400,'Archive source contains reparse directory'
                dirs[:]=[name for name in dirs if name not in SKIP_DIRS]
                for name in names:yield Path(parent)/name
        entries=walked() if recursive else directory.iterdir()
        for p in sorted(entries):
            if not p.is_file():continue
            rel=p.relative_to(directory)
            if any(part in SKIP_DIRS for part in rel.parts):continue
            if p.suffix not in ALLOW or (p.suffix=='.png' and not images):continue
            if p.suffix in {'.gd','.in','.py','.patch','.md'} and not tools:continue
            target=Path(relative)/rel
            if p.suffix in {'.gd','.in'}:target=Path(str(target)+'.txt')
            self.add(p.relative_to(ROOT),target)
    def finish(self):
        prior={r['archive']:r for r in self.previous}
        for key,row in prior.items():
            assert key not in self.files or self.files[key]==row
            self.files[key]=row
            assert hashlib.sha256((ROOT/key).read_bytes()).hexdigest()==row['sha256']
        rows=[self.files[k] for k in sorted(self.files)]
        if self.apply:
            self.dest.mkdir(exist_ok=True)
            (self.dest/'.gdignore').write_bytes(b'')
            (self.dest/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n*.log -whitespace\n*.patch -whitespace\n*.gd.txt -whitespace\n')
            (self.dest/'archive_manifest.json').write_bytes((json.dumps({'schema':1,'files':rows},ensure_ascii=False,indent=2)+'\n').encode())
        return {'directory':self.dest.relative_to(ROOT).as_posix(),'files':len(rows),'bytes':sum(r['bytes'] for r in rows),'applied':self.apply}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    effects=Archive('reduced_effects_20260906',args.apply)
    for base,label in [('scratchpad/reduced_effects_v2/runs','behavior_attempts'),('scratchpad/reduced_effects_ui/runs','gui_attempts'),('scratchpad/axes_freed_boundary/runs','axes_boundary')]:
        effects.tree(base,label,recursive=True,images=True,tools=True)
    # Public runner evidence has its own complete receipts; never copy private projects.
    for p in sorted((ROOT/'.godot/reduced_effects_qa').glob('*')):
        if p.is_dir() and (p/'receipt.json').exists():effects.tree(p.relative_to(ROOT),'public/'+p.name,recursive=True,images=True,tools=False)
    effects.tree('scratchpad/reduced_effects_application','application',recursive=True,images=False,tools=False)
    for p in sorted((ROOT/'.godot/effects_quality_comparison').glob('*')):
        if p.is_dir() and (p/'exit_receipt.json').exists():
            exit_receipt=json.loads((p/'exit_receipt.json').read_bytes())
            assert exit_receipt.get('lock_released') and exit_receipt.get('source_unchanged'),'Incomplete quality source guard'
            effects.tree(p.relative_to(ROOT),'quality_comparison/'+p.name,recursive=True,images=True,tools=True)
    for p in ['scratchpad/effects_quality_metadata_checks.json','scratchpad/reduced_effects_visual_review.json']:
        if (ROOT/p).exists():effects.add(p,Path(p).name)
    for folder in ['reduced_effects_v2','reduced_effects_ui','axes_freed_boundary']:
        effects.tree('scratchpad/'+folder,'investigation_sources/'+folder,tools=True,images=False)
    effects.tree('scratchpad/axes_freed_boundary/generated','investigation_sources/axes_freed_boundary/generated',tools=True,images=False)
    effects.tree('scratchpad/reduced_effects_public_static','public_static_review',tools=True,images=False)
    effects.add('scratchpad/reduced_effects_v2/generated/driver.gd','investigation_sources/reduced_effects_v2/generated/driver.gd.txt')
    for name in ['original_effect.gd.txt','fixed_effect.gd.txt']:
        effects.add('scratchpad/axes_freed_boundary/generated/'+name,'investigation_sources/axes_freed_boundary/generated/'+name)
    for p in ['scratchpad/run_effects_quality_comparison.py','scratchpad/check_effects_quality_metadata.py','scratchpad/run_reduced_legacy.py','scratchpad/run_axes_freed_boundary.py','scratchpad/summarize_effects_pressure.py']:
        effects.add(p,'investigation_sources/'+Path(p).name)
    physics=Archive('physics_cost_20260906',args.apply)
    for folder in ['physics_step_diag','native_sections_diag']:
        physics.tree('scratchpad/'+folder+'/runs',folder+'/runs',recursive=True,images=False,tools=True)
        physics.tree('scratchpad/'+folder,folder+'/tool_sources',recursive=False,images=False,tools=True)
        physics.tree('scratchpad/'+folder+'/generated',folder+'/tool_sources/generated',recursive=False,images=False,tools=True)
    for run in (ROOT/'scratchpad/physics_step_diag/runs').iterdir():
        if not run.is_dir():continue
        for name in ['battle_instrumented.bin','battle_original.bin','unit_instrumented.bin','unit_original.bin']:
            if (run/name).is_file():physics.add((run/name).relative_to(ROOT),'physics_step_diag/runs/'+run.name+'/source/'+name+'.gd.txt')
    for p in ['scratchpad/native_sections_next.md','scratchpad/first_use_hotspots.md']:
        physics.add(p,'analysis/'+Path(p).name)
    print(json.dumps([effects.finish(),physics.finish()],ensure_ascii=False))
if __name__=='__main__':main()
