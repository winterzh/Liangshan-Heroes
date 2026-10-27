from pathlib import Path
R=Path(__file__).resolve().parents[2];Q=R/'qa/storage_cleanup_20261027';O=Path(__file__).parent
s=(R/'qa/storage_cleanup_20261026_round2/execution_sources/remove_duplicates.ps1').read_text(encoding='utf-8-sig')
s=s.replace("D:\\CodexTemp\\shuihu-cleanup-20261026-round2",str(O))
s=s.replace('$binding.all_git_blob_sha256_verified','$binding.retained_copy_sha256_verified')
s=s.replace('VerifiedDuplicateRemoval26','VerifiedImportRemoval27')
s=s.replace('!r.EndsWith("\\\\project",StringComparison.OrdinalIgnoreCase)','!r.EndsWith("\\\\project\\\\.godot\\\\imported",StringComparison.OrdinalIgnoreCase)')
s=s.replace('    if(sha!=row.GetProperty("git_blob_sha256").GetString())throw new IOException("Git bytes mismatch");\n','')
s=s.replace('Outside exact noncache allowlist','Outside exact duplicate import-cache allowlist')
assert 'git_blob_sha256' not in s and 'all_git_blob_sha256_verified' not in s
(Q/'remove_duplicates.ps1').write_text(s,encoding='utf8')
print('Prepared exact import-cache removal script; not executed.')
