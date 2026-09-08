# Translation sources

`catalog.json` is the generated runtime catalogue. Chinese source strings are stable lookup keys; each entry contains `en`, `ja`, and `zh_TW`. Simplified Chinese is supplied by the key itself.

- `menu_settings.json`: navigation and settings.
- `ui.json`, `ui_extra.json`: HUD, editors, Workshop UI and remaining shared labels.
- `campaign.json`: campaigns, mission guidance, dialogue and reusable modes.
- `game_data.json`: units, skills, short biographies, star names and achievement labels.
- `lore_01.json` to `lore_05.json`: reviewed 108 biographies based on the 120-chapter edition. Source indices are 0–35, 36–59, 84–107, 72–83 and 60–71 respectively; keys contain the current reviewed Chinese text; chapter references live in `LoreData.CHAPTERS`.
- `glossary.json`: reviewed precedence for conflicting names and terms.
- `exclusions.json`: exact non-display strings excluded from source coverage.

Run `tools/build_localization.py` after editing a shard. The final build applies the glossary, converts Traditional Chinese using OpenCC, and checks unresolved duplicate translations with `--strict`. Run `tools/localization_catalog.py` to verify coverage and placeholders. Do not edit gameplay definitions to insert translated identifiers.

See `docs/LOCALIZATION_20260908.md` for the player flow, isolated QA and review limits.

- `text_review_ui.json`: edition references, adaptation labels and layout-related UI copy.

The 2026-09-08 text review and exact application receipts are in `qa/text_review_20260908/`; see `docs/TEXT_REVIEW_20260908.md` before replaying any historical replacements.
