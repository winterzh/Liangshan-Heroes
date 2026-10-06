"""Derive exact one-cache cleanup guarded by completed production visual review."""
from pathlib import Path
import ast

ROOT=Path(__file__).resolve().parents[3]
def main():
    parent=ROOT/'tools/contracts/zhu_wounded_20261005/cleanup_failed_action_imports_v7.py'
    text=parent.read_text(encoding='utf-8').replace('two explicitly owned failed batches','one explicitly owned failed batch')
    text=text.replace("ap.add_argument('--keeper-receipt',type=Path,required=True);",
                      "ap.add_argument('--visual-review',type=Path,required=True);ap.add_argument('--keeper-receipt',type=Path,required=True);")
    old="assert not keeper['source_changes'] and not keeper['private_source_changes'] and keeper['result']['passed'] and keeper['result']['checks']==367"
    assert text.count(old)==1
    text=text.replace(old,"""assert keeper['root_input_drift']==keeper['private_input_drift']==0 and set(keeper['results'])=={'combat','death'}
assert all(row['passed'] for row in keeper['results'].values())
review=read(args.visual_review);assert review['passed'] and review['production_receipt_sha256']==sha(keeper_receipt)
for row in review['viewed']:assert sha(ROOT/row['path'])==row['sha256']""")
    text=text.replace("failed_names=['ordinary_chapter_actions_v6_5600c55f','ordinary_chapter_actions_v6a_5ea8ab6d']",
                      "failed_names=['ordinary_death_pilot_v10_5101dfd0']")
    text=text.replace("keeper['source_files']+keeper['candidate_inputs']:","keeper['source_files']+keeper['candidate_inputs']+keeper['new_inputs']:")
    start=text.index("for p in (kept_project.parent/'evidence')");end=text.index('protected[str(keeper_receipt)]',start)
    text=text[:start]+"""for result in keeper['results'].values():
 for row in result['screenshots']:
  p=Path(row['path']);assert sha(p)==row['sha256'];protected[str(p)]=row['sha256']
"""+text[end:]
    text=text.replace('Only two named failed action QA imported caches','Only the named failed v10 death QA imported cache')
    ast.parse(text)
    output=ROOT/'tools/contracts/zhu_wounded_20261005/cleanup_failed_death_imports_v14.py';assert not output.exists()
    output.write_bytes(text.encode('utf-8'))
    print('Prepared exact one-cache cleanup; no deletion performed.')

if __name__=='__main__':main()
