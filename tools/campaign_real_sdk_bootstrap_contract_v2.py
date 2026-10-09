"""Read-only host descriptor/profile contract for the exported SDK probe V2.

No launcher, SDK object, export, ownership lease or execution admission lives
here. Callers still need a sealed real export, original successful durable
prior, specific review/admission and an owned terminal process consumer.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import stat
from typing import Any, Mapping

MAX_DESCRIPTOR_BYTES = 1048576
SHA = re.compile(r"[0-9a-f]{64}\Z")
NONCE = re.compile(r"[0-9a-f]{32}\Z")
ACCOUNT = re.compile(r"[1-9][0-9]{0,19}\Z")
DESCRIPTOR_FIELDS = frozenset({
    'schema', 'case', 'nonce', 'private_user_directory', 'executable',
    'executable_sha256', 'installed_identity', 'expected_account',
    'normal_startup_account_side_effects_acknowledged',
})
IDENTITY_FIELDS = frozenset({
    'ok', 'code', 'identity_schema', 'identity_scope', 'content_version',
    'source_sha256', 'engine_binary_sha256', 'source_mode', 'save_eligible',
    'save_code', 'rules_sha256', 'file_count', 'total_bytes', 'provider_sha256',
    'optional_content',
})
PRIVATE_KEYS = ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP')
CLEAR_KEYS = frozenset({
    'LEVEL', 'SCENARIO', 'CUSTOM_DEFENSE', 'STEAM_DISABLED', 'SKIRMISH',
    'SKIRMISH_AI', 'ARENA', 'AUTO_MICRO', 'AUTOMICRO', 'NEWHERO', 'SMOKE_TEST',
    'CAMPAIGN_QA', 'ABILITY_VIS_AUDIT', 'SCREENSHOT_DIR', 'GODOT_USER_HOME',
    'AI_FRIENDLY', 'AI_FRIENDLY_MULT', 'SCALE_ON', 'ENEMY_MULT', 'HERO_MULT',
    *PRIVATE_KEYS,
})


class ContractError(ValueError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ContractError(code)


def _pairs(rows: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in rows:
        require(key not in result, 'DUPLICATE_JSON_KEY')
        result[key] = value
    return result


def _constant(_: str) -> Any:
    raise ContractError('NONFINITE_JSON_CONSTANT')


def _float(token: str) -> float:
    value = float(token)
    require(math.isfinite(value), 'NONFINITE_JSON_NUMBER')
    return value


def _unicode_scalars(value: Any) -> None:
    if type(value) is str:
        require(not any(0xD800 <= ord(ch) <= 0xDFFF for ch in value),
                'JSON_UNPAIRED_SURROGATE')
    elif type(value) is dict:
        for key, item in value.items():
            _unicode_scalars(key)
            _unicode_scalars(item)
    elif type(value) is list:
        for item in value:
            _unicode_scalars(item)


def decode_descriptor(raw: bytes) -> dict[str, Any]:
    """Validate JSON syntax/UTF8 without accepting BOM or replacement decoding."""
    require(type(raw) is bytes and 0 < len(raw) <= MAX_DESCRIPTOR_BYTES,
            'DESCRIPTOR_BYTE_BUDGET')
    try:
        text = raw.decode('utf-8', errors='strict')
        require(not text.startswith('\ufeff') and text.encode('utf-8') == raw,
                'DESCRIPTOR_UTF8')
        value = json.loads(text, object_pairs_hook=_pairs, parse_constant=_constant,
                           parse_float=_float)
    except ContractError:
        raise
    except (UnicodeError, ValueError, RecursionError) as exc:
        raise ContractError('DESCRIPTOR_UTF8_OR_JSON') from exc
    require(type(value) is dict and set(value) == DESCRIPTOR_FIELDS,
            'DESCRIPTOR_EXACT_FIELDS')
    try:
        _unicode_scalars(value)
    except RecursionError as exc:
        raise ContractError('DESCRIPTOR_NESTING_BUDGET') from exc
    return value


def _digest(value: Any) -> bool:
    return type(value) is str and SHA.fullmatch(value) is not None


def validate_compiled_identity(value: Any, executable_sha256: str) -> None:
    """Validate shape only; this is never an independent native observation."""
    require(type(value) is dict and set(value) == IDENTITY_FIELDS,
            'IDENTITY_EXACT_FIFTEEN_FIELDS')
    require(value['ok'] is True and value['code'] == 'OK'
            and type(value['identity_schema']) is int and value['identity_schema'] == 1
            and value['identity_scope'] == 'installed_inputs'
            and value['source_mode'] is False and value['save_eligible'] is True
            and value['save_code'] == 'OK', 'COMPILED_IDENTITY_KIND')
    require(all(_digest(value[key]) for key in (
        'source_sha256', 'engine_binary_sha256', 'rules_sha256', 'provider_sha256')),
        'IDENTITY_SHA_FIELDS')
    require(value['content_version'] == 'source-v1:' + value['source_sha256']
            and value['engine_binary_sha256'] == executable_sha256,
            'IDENTITY_SOURCE_AND_EXECUTABLE')
    require(type(value['file_count']) is int and 0 < value['file_count'] <= 60000
            and type(value['total_bytes']) is int
            and 0 <= value['total_bytes'] <= 34359738368, 'IDENTITY_BUDGETS')
    rows = value['optional_content']
    require(type(rows) is list and len(rows) == 2, 'OPTIONAL_CONTENT_ROWS')
    for row, path in zip(rows, ('content/units.json', 'content/abilities.json')):
        require(type(row) is dict and set(row) == {'path', 'present', 'bytes', 'sha256'}
                and row['path'] == path and type(row['present']) is bool
                and type(row['bytes']) is int and 0 <= row['bytes'] <= 34359738368,
                'OPTIONAL_CONTENT_ROW')
        require((_digest(row['sha256']) if row['present'] else
                 row['bytes'] == 0 and row['sha256'] == ''), 'OPTIONAL_CONTENT_DIGEST')


def no_links(path: Path) -> None:
    """Check original paths before resolution, including Windows reparse points."""
    for item in (path, *path.parents):
        try:
            metadata = item.lstat()
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(metadata.st_mode)
                and not getattr(metadata, 'st_file_attributes', 0) & 0x400,
                'LINK_OR_REPARSE')


def exact_absolute_path(value: Any) -> Path:
    require(type(value) is str and bool(value) and '\x00' not in value,
            'ABSOLUTE_PATH_TYPE')
    path = Path(value)
    require(path.is_absolute() and '..' not in path.parts,
            'ABSOLUTE_PATH_COMPONENTS')
    no_links(path)
    return path


def read_descriptor(path: Path, expected_sha256: str) -> tuple[dict[str, Any], bytes]:
    path = exact_absolute_path(str(path))
    require(_digest(expected_sha256), 'DESCRIPTOR_SHA_TYPE')
    with path.open('rb') as stream:
        raw = stream.read(MAX_DESCRIPTOR_BYTES + 1)
    require(hashlib.sha256(raw).hexdigest() == expected_sha256, 'DESCRIPTOR_ORIGINAL_SHA')
    value = decode_descriptor(raw)
    no_links(path)
    with path.open('rb') as stream:
        second = stream.read(MAX_DESCRIPTOR_BYTES + 1)
    require(second == raw, 'DESCRIPTOR_PHYSICAL_BYTES_CHANGED')
    return value, raw


def verify_executable(path: Path, expected_sha256: str) -> None:
    """Check physical bytes against caller's original export pin; do not run it."""
    path = exact_absolute_path(str(path))
    require(_digest(expected_sha256) and path.is_file(), 'EXECUTABLE_FILE_PIN')
    before = path.stat()
    require(0 < before.st_size <= 1073741824, 'EXECUTABLE_BYTE_BUDGET')
    digest = hashlib.sha256()
    size = 0
    with path.open('rb') as stream:
        while block := stream.read(1048576):
            size += len(block)
            require(size <= before.st_size, 'EXECUTABLE_GREW')
            digest.update(block)
    no_links(path)
    after = path.stat()
    require(size == before.st_size == after.st_size
            and before.st_mtime_ns == after.st_mtime_ns
            and digest.hexdigest() == expected_sha256, 'EXECUTABLE_ORIGINAL_BYTES')


def validate_descriptor(value: dict[str, Any], *, expected_nonce: str,
                        expected_account: str, executable: Path,
                        executable_sha256: str, user_directory: Path,
                        installed_identity: dict[str, Any]) -> None:
    require(type(value) is dict and set(value) == DESCRIPTOR_FIELDS,
            'DESCRIPTOR_EXACT_FIELDS')
    require(value['schema'] == 'campaign_real_sdk_bootstrap_descriptor_v1'
            and value['case'] == 'bootstrap_only'
            and value['normal_startup_account_side_effects_acknowledged'] is True,
            'DESCRIPTOR_BOOTSTRAP_SCOPE')
    require(type(expected_nonce) is str and NONCE.fullmatch(expected_nonce) is not None
            and value['nonce'] == expected_nonce, 'EXACT_NONCE')
    require(type(expected_account) is str and ACCOUNT.fullmatch(expected_account) is not None
            and int(expected_account) <= 18446744073709551615
            and value['expected_account'] == expected_account, 'EXACT_ACCOUNT_INPUT')
    require(_digest(executable_sha256) and value['executable_sha256'] == executable_sha256,
            'EXACT_EXECUTABLE_SHA')
    require(exact_absolute_path(value['executable']) == exact_absolute_path(str(executable))
            and exact_absolute_path(value['private_user_directory'])
            == exact_absolute_path(str(user_directory)), 'EXACT_HOST_PATHS')
    validate_compiled_identity(value['installed_identity'], executable_sha256)
    validate_compiled_identity(installed_identity, executable_sha256)
    require(value['installed_identity'] == installed_identity, 'EXACT_HOST_IDENTITY')
    verify_executable(executable, executable_sha256)


def isolated_environment(inherited: Mapping[str, str], *, profile: Path,
                         user_directory: Path, descriptor_path: Path,
                         descriptor_sha256: str) -> dict[str, str]:
    """Build env only. Caller must hold original private-profile/process lease."""
    profile = exact_absolute_path(str(profile))
    user_directory = exact_absolute_path(str(user_directory))
    descriptor_path = exact_absolute_path(str(descriptor_path))
    require(_digest(descriptor_sha256), 'DESCRIPTOR_SHA_TYPE')
    require(profile.is_dir(), 'PRIVATE_PROFILE_MISSING')
    require(user_directory.is_relative_to(profile / 'appdata')
            and user_directory != profile / 'appdata', 'USER_DIRECTORY_OUTSIDE_PRIVATE_APPDATA')
    expected_roots = {key.lower() for key in PRIVATE_KEYS}
    require({p.name for p in profile.iterdir()} == expected_roots, 'PRIVATE_PROFILE_EXACT_ROOTS')
    for key in PRIVATE_KEYS:
        directory = profile / key.lower()
        no_links(directory)
        require(directory.is_dir() and not any(directory.iterdir()), 'PRIVATE_ROOT_NOT_EMPTY')
    result: dict[str, str] = {}
    seen = set()
    for key, value in inherited.items():
        require(type(key) is str and type(value) is str and '\x00' not in key + value
                and key and '=' not in key, 'ENVIRONMENT_STRING')
        upper = key.upper()
        require(upper not in seen, 'CASE_ALIAS_ENVIRONMENT')
        seen.add(upper)
        if (upper in CLEAR_KEYS or upper.startswith(('LSH_', 'ART_', 'DAMING_', 'V25_'))
                or upper.endswith(('_TEST', '_QA', '_QA_MANIFEST', '_AUDIT'))):
            continue
        result[key] = value
    result.update({key: str(profile / key.lower()) for key in PRIVATE_KEYS})
    result['LSH_REAL_SDK_DESCRIPTOR'] = str(descriptor_path)
    result['LSH_REAL_SDK_DESCRIPTOR_SHA256'] = descriptor_sha256
    return result
