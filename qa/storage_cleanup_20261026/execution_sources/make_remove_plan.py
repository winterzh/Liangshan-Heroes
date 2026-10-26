import gzip, json, hashlib, zipfile
from pathlib import Path
OUT=Path(r'D:\CodexTemp\shuihu-cleanup-20261026')

def main():
    evidence=json.loads((OUT/'archive_verification.json').read_text(encoding='utf-8'))
    with zipfile.ZipFile(evidence['archive'],'r') as z:
        raw=z.read('manifest.json')
    manifest=json.loads(raw)
    allowed=json.loads((OUT/'candidate_roots.json').read_text(encoding='utf-8'))
    if manifest['roots']!=allowed:raise RuntimeError('Root mismatch')
    path=OUT/'remove_plan.jsonl.gz'
    with gzip.open(path,'wt',encoding='utf-8') as f:
        for row in manifest['files']:
            matches=[root for root in allowed if row['path'].startswith(root+'/')]
            if len(matches)!=1:raise RuntimeError('File outside exact roots')
            if '.godot' in row['path'][len(matches[0])+1:].split('/'):raise RuntimeError('Cache target')
            record={**row,'root':matches[0],'utc_ticks':row['mtime_ns']//100+621355968000000000}
            f.write(json.dumps(record,ensure_ascii=False,separators=(',',':'))+'\n')
    with path.open('rb') as f:plan_sha=hashlib.file_digest(f,'sha256').hexdigest()
    binding={'archive_sha256':evidence['archive_sha256'],'manifest_sha256':hashlib.sha256(raw).hexdigest(),
             'plan_sha256':plan_sha,'files':len(manifest['files']),'roots':len(allowed)}
    (OUT/'remove_plan_binding.json').write_text(json.dumps(binding,indent=2),encoding='utf-8')
    print(json.dumps(binding))

if __name__=='__main__':main()
