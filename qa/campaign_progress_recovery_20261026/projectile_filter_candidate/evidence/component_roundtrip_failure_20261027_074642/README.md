# Projectile component roundtrip assertion failure — 2026-10-27 07:46:42

PID 66268 exited 1 after 38.58 seconds with no engine/script errors. The native report has 44 checks: 43 passed and the compound typed-wire roundtrip check failed. It explicitly records `roundtrip_exact=true`, restored filter 4 and three graph records. Baseline rejection, candidate capture/prepare, paused attachment executing original ready, activation, all 12 negative cases and their fixture restoration checks passed. This failed attempt is not a full component pass.

The compound condition also called Codec.encode on both already captured wire objects. Its intermediate ok/code/path/budget results were not logged; this archive does not guess which operand failed. Any later corrected comparison belongs to a separate run.

All 12 run originals, including old worker9006/host/source manifests/Graph/bindings/report/log/receipt, are byte-exact under raw. Every receipt pin is mapped in source_map; named reference files were read back, native binaries retain recorded SHA only. No profile, business payload, executable, DLL, project assets or cache was copied. The receipt remains complete=false; source pins, actual child terminal, owned lock and idle lane passed and lock_released=true. No natural gameplay, full-source, combined-freeze, public entry or SDK qualification is granted.
