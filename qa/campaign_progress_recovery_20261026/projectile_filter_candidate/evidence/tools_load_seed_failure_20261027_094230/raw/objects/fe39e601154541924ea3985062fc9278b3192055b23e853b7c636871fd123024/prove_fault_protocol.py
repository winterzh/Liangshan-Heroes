"""Default read-only; --prove runs only current candidate write-denial and native-oplock cases.

The same unmodified production CFG and worker paths run indices 9 and 12 in two
new profiles. This receipt authorizes mechanics, never the full nineteen matrix.
"""
from pathlib import Path
import importlib.util
import sys

sys.dont_write_bytecode = True
source = Path(__file__).resolve().with_name("run_persistence19.py")
spec = importlib.util.spec_from_file_location("persistence19_protocol_host", source)
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)

if __name__ == "__main__": host.main(proof_mode=True)
