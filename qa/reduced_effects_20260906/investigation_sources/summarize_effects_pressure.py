"""Summarize completed quality comparisons using every full ten-second segment."""
from pathlib import Path
import argparse, hashlib, json, runpy, statistics
ROOT=Path(__file__).resolve().parents[1]
analyzer=runpy.run_path(str(ROOT/'tools/analyze_polish_performance.py'))

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path);args=parser.parse_args()
    directory=args.directory.resolve()
    assert (ROOT/'.godot/effects_quality_comparison').resolve() in directory.parents
    receipt=json.loads((directory/'exit_receipt.json').read_bytes())
    assert receipt['complete'] and receipt['lock_released'] and receipt['source_unchanged']
    config=json.loads((directory/'configuration.json').read_bytes())
    assert not config['preflight'] and config['seconds']>=60 and config['repeats']>=3
    evidence=[]
    for sample in receipt['samples']:
        path=directory/sample['report'];report=json.loads(path.read_bytes())
        assert sample['quality_metadata_valid'] and report['effects_quality_verified'] and report['effects_quality_violations']==0
        quality=analyzer['quality_metadata'](report)
        assert quality['effects_quality']==sample['effects_quality']
        segments=analyzer['segments'](report['raw_frame_ms'])
        full=[row for row in segments if row['complete_ten_seconds']]
        assert len(full)>=6
        evidence.append({'report':sample['report'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'camera_mode':sample['camera_mode'],**quality,
            'checks':report['checks'],'failures':report['failures'],'full_window':{key:report[key] for key in ['fps','p95_ms','p99_ms']},'first10':full[0],
            'lowest10_fps':min(row['fps'] for row in full),'highest10_p95_ms':max(row['p95_ms'] for row in full),'highest10_p99_ms':max(row['p99_ms'] for row in full),
            'interim_sustained_30_passed':all(row['fps']>=30 and row['p95_ms']<=50 for row in full),
            'final_sustained_60_passed':all(row['fps']>=60 and row['p95_ms']<=16.7 and row['p99_ms']<=33.3 for row in full),
            'sample_end_count':report['sample_end']['count'],'all_segments':segments})
    groups=[]
    for camera in config['cameras']:
        for quality in ['standard','reduced']:
            selected=[row for row in evidence if row['camera_mode']==camera and row['effects_quality']==quality]
            assert len(selected)==config['repeats']
            groups.append({'camera_mode':camera,'effects_quality':quality,'reports':[row['report'] for row in selected],
                'full_window_median':{key:statistics.median(row['full_window'][key] for row in selected) for key in ['fps','p95_ms','p99_ms']},
                'first10_median':{key:statistics.median(row['first10'][key] for row in selected) for key in ['fps','p95_ms','p99_ms']},
                'lowest10_fps_each':[row['lowest10_fps'] for row in selected],'sample_end_counts':[row['sample_end_count'] for row in selected],
                'interim_sustained_30_passed':all(row['interim_sustained_30_passed'] for row in selected),'final_sustained_60_passed':all(row['final_sustained_60_passed'] for row in selected)})
    output={'schema':1,'scope':'Every full ten-second wall-clock segment after the existing 300-physics-tick warmup; natural combat attrition is retained. No sustained 200-enemy or deterministic replay claim.',
        'checks':sum(row['checks'] for row in evidence),'failures':sum(len(row['failures']) for row in evidence),'groups':groups,'samples':evidence}
    (directory/'pressure_summary.json').write_bytes((json.dumps(output,ensure_ascii=False,indent=2)+'\n').encode())
    print(json.dumps({key:value for key,value in output.items() if key not in ['samples']},ensure_ascii=False))
if __name__=='__main__':main()
