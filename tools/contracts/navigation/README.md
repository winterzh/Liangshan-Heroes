# Segment traversal reference

`segment_before_66d27aa.txt` freezes the already optimized `_segment_open` at `66d27aaf7cb55cd139e0c75373f47ab17cdd0f11`, with CRLF normalized to LF. SHA-256: `dd28da8a1749a230b76428a88ec7ee70d86d438973a18bd95d53fb74b66d6ab1`. `tools/segment_endpoint_qa.gd` compares the next endpoint conversion change against this incremental baseline, including float32 neighbors of grid boundaries. The older reference below remains available unchanged.

`segment_before_7fbdc3a.txt` is the complete `_segment_open` function from commit `7fbdc3a5ce30d4dff0b7c64d11734bcf4e1a5917`, `scripts/game_map.gd`, with CRLF normalized to LF. SHA-256: `b056f62669523d9c1e22e81c37f03da1e48840d94dcbc451f486043f7f3fa82a`.

The QA script compiles this unchanged function as a GameMap subclass sharing the same collision grids. It compares production results, separation positions and paired CPU timings. This reference is test input, never the runtime implementation.
