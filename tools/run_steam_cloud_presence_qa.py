#!/usr/bin/env python3
"""Run production Steam Cloud/Presence GDScript against a SDK-contract fake.

Uses the shared RTS runner's fresh allowlisted source snapshot, import gate,
explicit private Godot profile, STEAM_DISABLED=1 and CAMPAIGN_QA=1. No native
Steam extension is copied or loaded; HOME and real profiles are never changed.
Python only orchestrates Godot and validates completion receipts, not gameplay.

Example: python3 tools/run_steam_cloud_presence_qa.py --godot /path/to/Godot
"""
from __future__ import annotations

import sys

from run_rts_refinement_qa import main


if __name__ == "__main__":
    sys.exit(main(suites=["steam_cloud_regression_qa.gd", "steam_presence_regression_qa.gd"]))
