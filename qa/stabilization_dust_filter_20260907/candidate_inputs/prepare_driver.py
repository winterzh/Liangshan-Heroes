"""Generate native pure-data functions from the exact original/candidate blocks."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    receipt = json.loads((HERE / 'source_receipt.json').read_text(encoding='utf-8'))
    functions = ''
    for name, block in [('reference', receipt['old_block']), ('candidate', receipt['new_block'])]:
        functions += 'func _' + name + '(dust: Array, delta: float) -> Array:\n\tvar _dust: Array = dust\n' + block + '\treturn _dust\n\n'
    template = (HERE / 'driver_template.gd.txt').read_text(encoding='utf-8')
    assert template.count('@@EXACT_FILTER_FUNCTIONS@@') == 1
    result = template.replace('@@EXACT_FILTER_FUNCTIONS@@', functions)
    raw = result.encode('utf-8')
    (HERE / 'data_smoke.gd').write_bytes(raw)
    details = {'source_receipt_sha256': hashlib.sha256((HERE / 'source_receipt.json').read_bytes()).hexdigest(),
               'driver_sha256': hashlib.sha256(raw).hexdigest(),
               'functions_from_exact_production_blocks': True, 'native_run': False,
               'scope': 'Pure dust-array transformation; no Unit._phys_body execution and no performance assertion'}
    (HERE / 'driver_receipt.json').write_bytes((json.dumps(details, indent=2)+'\n').encode('utf-8'))
    print(json.dumps(details))


if __name__ == '__main__': main()
