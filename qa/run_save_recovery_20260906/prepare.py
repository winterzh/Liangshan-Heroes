"""Prepare R01 source copies only. Never starts Godot or edits the tested disk draft."""
import ast
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'run_save_store'
STORE_SHA='86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3'
RUNNER_SHA='233dcd47bfe99af5419c38a2a135060860dbf46719683521c8e5610776b73fd2'


def sha(raw): return hashlib.sha256(raw).hexdigest()


def main():
    original=(OLD/'run_save_store.gd').read_bytes()
    helper=(OLD/'run_qa.py').read_bytes()
    assert sha(original)==STORE_SHA and sha(helper)==RUNNER_SHA,'Reviewed originals drifted'
    tail=(HERE/'inspector_methods.gd.in').read_bytes()
    text=tail.decode('utf-8')
    assert not re.search(r'\b(?:save_payload|_save_locked|_write_new|_move_to_empty|store_buffer|store_string|flush|remove_absolute|rename_absolute|make_dir[^\s(]*)\s*\(',text),'New R01 methods must not write/move/remove/clear'
    for name,raw in [('store_original.gd',original),('store_r01.gd',original+tail),('process_runner_original.py',helper)]:
        (HERE/name).write_bytes(raw)
    assert (HERE/'store_original.gd').read_bytes()==original
    assert (HERE/'store_r01.gd').read_bytes()==original+tail
    names=['store_original.gd','store_r01.gd','inspector_methods.gd.in','qa_driver.gd','process_runner_original.py','prepare.py','run_qa.py']
    for name in names:
        if name.endswith('.py'):ast.parse((HERE/name).read_text(encoding='utf-8'))
    pins={'schema':1,'original_store_sha256':STORE_SHA,'original_process_runner_sha256':RUNNER_SHA,
        'raw_sha256':{name:sha((HERE/name).read_bytes()) for name in names},'original_prefix_bytes':len(original),
        'r01_first_line':len(original.splitlines())+2,'source_prefix_exact':True,'new_methods_read_only_static':True,
        'godot_run':False,'gdscript_parse_or_runtime_verified':False,'production_or_original_modified':False}
    (HERE/'pins.json').write_text(json.dumps(pins,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(pins))


if __name__=='__main__':main()
