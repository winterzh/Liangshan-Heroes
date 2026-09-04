"""Compatibility entrypoint for the fixed-rectangle candidate normalizer.

The former implementation used connected-component ownership and wrote zero
RGBA into pixels assigned to neighbouring figures.  That operation is outside
the reviewed Web-art rule and is intentionally unavailable.  Existing callers
must now provide an explicit ``--spec``, candidate ``--output-dir`` and
candidate ``--manifest`` accepted by :mod:`direction4_fixed_crop_normalize`.
"""
from __future__ import annotations

from direction4_fixed_crop_normalize import main


if __name__ == "__main__":
    raise SystemExit(main())
