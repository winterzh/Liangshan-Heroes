# RNG parse correction R1

The first actual run failed before random draws because the preload constant was treated as a script class, so Codec.resource_path did not parse. R1 reads the script resource through the existing codec instance. The original module, pins, contract, runner and failed run remain unchanged under scratchpad/run_gameplay_rng.

Original failed run: 20260906T180630045299Z, writer PID 20576, exit 1. This revision keeps the exact seven-seed cross-process behavior requirements; only source paths and the invalid resource access are changed. It is still source-mode only and has no Battle caller. Run run_qa.py with --godot; --run uses a fresh isolated pair of processes.
