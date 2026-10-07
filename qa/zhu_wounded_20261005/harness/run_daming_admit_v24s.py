# Unexecuted v24s sibling: immutable executed r2 qualification plus own-only barrier one-shot listener lifecycle repair.
# Source/runtime5102, q1 boundary, OwnedSlot, full A/B/C and continuous60-second natural idle retained; no old profile retry.
# Candidate v24r derives from immutable executed v24o4; no older producer is overwritten.
# This file is prepared only. Native import/regression/A/B/C must still prove qualification.
"""Run one fresh frozen three-process Daming admission Session batch.

No automatic retries. Any native failure, foreign-engine resumption, integrity
failure or deadline stops only this producer's child and preserves the batch.
The root task must review and prepare a new sibling attempt/profile to retry.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
CASES = ("A_half_save", "B_continue_resave", "C_verify_resave")
AUTHORIZED_DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
ENGINE_ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")
SCOPE = "Real manual admission half-progress, full Session disk save/exit, independent complete install/continue/resave and independent generation-two complete install/native no-duplicate effects. No public campaign entry, fire/rescue/production/ships/natural result/reward/performance/device/release qualification."
# Exact restored installed companion files of the qualified v24i native world.
# These are source-side .import/.uid metadata, not .godot cache or runtime patches.
QUALIFIED_CACHED_CONTENT_VERSION = 'source-v1:b77b36b6ef91e7cd569c4a8c49096ae1e02bf2b0f92cc68bde4f806ac146367e'
QUALIFIED_NATIVE_WORLD_ARTIFACT_SHA256 = 'f936f08d03f26761dba247656c66047281f2155cbcaadbd05270f6d19091c8fd'
QUALIFIED_CACHED_INSTALLED_FILE_COUNT = 5100
CURRENT_CANDIDATE_INSTALLED_FILE_COUNT = 5102
INHERITED_EXECUTED_PRODUCER_SHA256 = 'f6506b67db21885f1afe6abde0d2e76b284dbe4673612add931360e5f93afb5d'
EXECUTED_DAMING_A_B_C_HARNESS_SHA256 = '2aade96b57e83b03e9c43cd21d9fd29490534778deb05ec98204c3a1ec1da74f'
INHERITED_EXECUTED_R2_SHA256 = '1b486f16c955d5a54b7e7e15e570fc66e3573cc9f02581d6027e5a73be725fb4'
V24S_DAMING_HARNESS_SHA256 = '76ed6f114de755b398112778ddabf5af820a30237b75070a5a2aaaea188b87db'
V24S_DAMING_SCENE_SHA256 = 'd7e1475d5e2b5add7cf008ac163b1eb909b6a6889641eff6ddb5821500851dee'
BOUNDARY_HARNESS_SHA256 = "91e393e8cea2ffa4dc465ebadc1156349d967149999be53a2ae4c71268c96a1d"
BOUNDARY_SCENE_SHA256 = "56854ee5fdb931ece82abd6d056db19507d23e67c135b7020bbb69a016ec889f"
BOUNDARY_MANIFEST_SHA256 = "e14eb9a77f971d3e6a44e5a57b384aba87612b86e53216160f6e43cf34b6e4e6"
CANDIDATE_CHANGED_PATHS = {"scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd"}
CANDIDATE_ADDED_PATHS = {"scripts/run_scenery_json_boundary.gd", "scripts/run_scenery_json_boundary.gd.uid"}
BOUNDARY_CASES = {"actual_v24p_pending", "gao", "daming", "level1", "level2", "level3", "level4", "level6", "level7", "classic_liangshan", "classic_none"}
QUALIFIED_CACHED_IMPORT_EXTRAS = [{'path': 'addons/godotsteam/godotsteam.gdextension.uid', 'bytes': 20, 'sha256': '6fb59f98ea040050435e25755f1f1ad036992d1f6af93a41c5fd7ef7c249796f'}, {'path': 'addons/steam_stats_reader/reader.gdextension.uid', 'bytes': 19, 'sha256': '688a3296ccaeacf191e6ccf35b8ad51c130b973ac8e6982a8aa31b4d8c459fd4'}, {'path': 'assets/characters/deng_fei_wounded_20261005/passing_b2_sw_v4.png.import', 'bytes': 995, 'sha256': '535bcdf62430ff3b7e5f5738e63fa9494d6d4ceeca2030128bac582ad116749f'}, {'path': 'assets/characters/deng_fei_wounded_20261005/passing_b3_sw_v4.png.import', 'bytes': 996, 'sha256': '08ee94a1534cef143c0c6491940cb00fbff76adcad2ab508ce6a01279fb29762'}, {'path': 'assets/characters/deng_fei_wounded_20261005/passing_b_sw_v4.png.import', 'bytes': 993, 'sha256': '65480ed6c6a7796848060508984f5439517b805059b8e56a052e04ed5f8ec0ce'}, {'path': 'assets/characters/deng_fei_wounded_20261005/posture_v3.png.import', 'bytes': 978, 'sha256': 'b35ac2a9d30f0014ff48eba4dde48f5801316f79cc99f4acd2b240e45ec56530'}, {'path': 'assets/characters/deng_fei_wounded_20261005/proportion_v2.png.import', 'bytes': 986, 'sha256': 'a56d47e63f364cbc0bd2829c0a6c52712bfe72abdff295325983b6a3bc370891'}, {'path': 'assets/characters/huang_xin_wounded_20261005/idle_single_sw_v4.png.import', 'bytes': 1000, 'sha256': 'af8b00dae83f5aa7a8d3d6d91ff65363f7f3925a083198a3121caf4403a0984b'}, {'path': 'assets/characters/huang_xin_wounded_20261005/passing_b_idlefix_sw_v4.png.import', 'bytes': 1018, 'sha256': 'ae02949f8de653f6e9fea7913417740abc5d793715b5632d3064c5f02cd702ae'}, {'path': 'assets/characters/huang_xin_wounded_20261005/posture_v3.png.import', 'bytes': 979, 'sha256': '35fb24a24a3ef00b3424db7a8b18858e2aeeaf1a3ddf69c50987fa2855dee5e9'}, {'path': 'assets/characters/huang_xin_wounded_20261005/proportion_v2.png.import', 'bytes': 987, 'sha256': '956ae0b92e2dee992d795bc25118739dc0d0c6095406c5d025dd551ecae0500b'}, {'path': 'assets/characters/huang_xin_wounded_20261005/walk_b_ne_v4.png.import', 'bytes': 985, 'sha256': '7793d49e28f64890a20bc4da60a7c1d14cd00de2001a9e12d020eb5fb068562f'}, {'path': 'assets/characters/lin_chong_traits_20261006/idle_spacing_v4.png.import', 'bytes': 993, 'sha256': 'a499b806f9eb91c133762324960ea8e535ee23ad7ee8d1ce5ac94f777346e2db'}, {'path': 'assets/characters/lin_chong_traits_20261006/idle_v4.png.import', 'bytes': 968, 'sha256': '104c5a4b83e6b258bd8ebe2b036c70805625f2c49159729aaf1576fea10d0058'}, {'path': 'assets/characters/qin_ming_wounded_20261005/passing_a_ne_v4.png.import', 'bytes': 993, 'sha256': 'a9dc2d82c3641cf48f6f838dccf5c8aa4de9ff3e6903d5e35809d2172998e000'}, {'path': 'assets/characters/qin_ming_wounded_20261005/posture_v3.png.import', 'bytes': 977, 'sha256': 'a144baa351dbf1bdfa5b44986c2602a01b170216c79586f14235778b5a8caf66'}, {'path': 'assets/characters/qin_ming_wounded_20261005/proportion_v2.png.import', 'bytes': 987, 'sha256': '023a64462d31eeb15d4be627882a3929d36b8b6c11b94049bdc9005190851ec5'}, {'path': 'assets/characters/shi_qian_wounded_20261005/idle_walk.png.import', 'bytes': 975, 'sha256': '6cc74aafd6254324daf6ee10f51164361c963bd8de6b96b361113f9e45a9759e'}, {'path': 'assets/characters/shi_qian_wounded_20261005/native_references/gait_edit_rejected.png.import', 'bytes': 1019, 'sha256': '8ed604045c38c3bead6aee8437abb051dad98f17009eac7172e73a981005fe32'}, {'path': 'assets/characters/shi_qian_wounded_20261005/native_references/opposite_step_rejected.png.import', 'bytes': 1031, 'sha256': '503b3c6dc6603058d5faed37efdca8a4cf4665a3d5784c642876ab775925550e'}, {'path': 'assets/characters/shi_qian_wounded_20261005/native_references/opposite_step_se_only.png.import', 'bytes': 1029, 'sha256': '9f99c5a99dca9d6be100ef9c7e5a24a0f178a65c237b19d0f31e7cfcff62c149'}, {'path': 'assets/characters/shi_qian_wounded_20261005/native_references/step_b_rejected.png.import', 'bytes': 1011, 'sha256': 'a2a10dbd73afc0ebfa3429706915a84e97022479d06c1b1ca3ef67a643000b76'}, {'path': 'assets/characters/shi_qian_wounded_20261005/native_references/sw_initial_rejected.png.import', 'bytes': 1023, 'sha256': 'f8550c7a6bfe0c179ed97fff3a25e457931b62668fbeb8b00d319b25091ca907'}, {'path': 'assets/characters/shi_qian_wounded_20261005/posture_v3.png.import', 'bytes': 977, 'sha256': '20001f320dddaa27de5a8ac70d990bd4d3cc953a97f4e16a10304d1b3fb0c4f6'}, {'path': 'assets/characters/shi_qian_wounded_20261005/proportion_reference_v2.png.import', 'bytes': 1017, 'sha256': 'fa3ca1bb51d91a752df62b94eb98312c4cecd3a64d0c5752cfdd7e6b6861a45a'}, {'path': 'assets/characters/shi_qian_wounded_20261005/se_v2.png.import', 'bytes': 963, 'sha256': 'b40ebf538c14349ef5d418a9e210c194ed6449ac07e834e8b2c4ae28c7646034'}, {'path': 'assets/characters/shi_qian_wounded_20261005/step_b_ne.png.import', 'bytes': 975, 'sha256': '90b18ce8ee8b0569966b1c931bb645e59eb8d1bfaec44c7ae9ece85850b6b9d1'}, {'path': 'assets/characters/shi_qian_wounded_20261005/step_b_nw.png.import', 'bytes': 975, 'sha256': '11df7099117461d3f097c52b3b9a28f4d62d2f505a83d7b319e3852eedb1f56f'}, {'path': 'assets/characters/shi_qian_wounded_20261005/step_b_sw.png.import', 'bytes': 974, 'sha256': '9c3dfcfc3886c7ad36c979e45d7ba6cd6f441cf4bd202b89b6ee859707b547b6'}, {'path': 'assets/characters/shi_qian_wounded_20261005/sw_b3_v2.png.import', 'bytes': 972, 'sha256': '548b6fdfb74ed3138fadc713c0c718c81cba7da413f96bd335cd84a5208f5e2b'}, {'path': 'assets/characters/shi_qian_wounded_20261005/sw_b_v2.png.import', 'bytes': 968, 'sha256': 'a642cfded33ae38665908f51906dbc4d066e1bdee6c9f916af6ac5228e43bb1c'}, {'path': 'assets/characters/shi_qian_wounded_20261005/walk_a_traits_atlas_v4.png.import', 'bytes': 1014, 'sha256': '14fe97a6af925c5a556991f327327a8dcd9722e2ac943dd0f16c400ba7054f44'}, {'path': 'assets/characters/shi_qian_wounded_20261005/walk_b_geometry_atlas_v4.png.import', 'bytes': 1020, 'sha256': '14c069df4b5f3beef17ac5a7205ed2d13f22380608fa63e4cbb4c6b97e7d9779'}, {'path': 'assets/characters/shi_qian_wounded_20261005/walk_b_geometry_nw_v4.png.import', 'bytes': 1011, 'sha256': '4e7710025d1920a9eb04a75b1a188fed7064cce93eaaa1423e91190eddb75259'}, {'path': 'assets/characters/shi_qian_wounded_20261005/walk_b_padded_atlas_v4.png.import', 'bytes': 1014, 'sha256': 'ee6ad9c2d08544f680f2a01f2d9e45c6fba961b1799f998c43d9f5d0c6991a64'}, {'path': 'assets/characters/shi_qian_wounded_20261005/walk_b_swap_atlas_v4.png.import', 'bytes': 1007, 'sha256': '85069b9a5741c4dc4a40a390dc1d39f09fb997ca0dfd3004a68002a33b23ae17'}, {'path': 'assets/characters/shi_qian_wounded_20261005/walk_v2.png.import', 'bytes': 969, 'sha256': '2f8ef3e980f0060c55abbe9ffd32749fd5f5bcc8221f61e96a82285100d71789'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/idle_matched_v4.png.import', 'bytes': 992, 'sha256': '9b299a1012a50a28f0f753702c53e609d796682b13da0cdcc32e33532c404291'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/idle_v2.png.import', 'bytes': 968, 'sha256': 'e21a8f5e132977720e1f045ee942ceb645eee10a5e1539ac93515e3b1fc8be29'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/idle_v3.png.import', 'bytes': 968, 'sha256': '36b668537bee228f201531be1a78b658e406b7b6a1f66f43d4294c0ca9bbb351'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/idle_walk.png.import', 'bytes': 974, 'sha256': 'f6ee4e95d8f4b40d4e0fb32c33280c6f8295bb8331bc910a5ca40f3f15176bb2'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/passing_b4_sw_v4.png.import', 'bytes': 995, 'sha256': '2ce7beefb4718c327fbe6b157cab70cf3f79fc4ea5729b147173e4ee3904b354'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/passing_b_ne_v4.png.import', 'bytes': 992, 'sha256': '5607edb8bcac4d68669ae3c76ea39c8b01442b7f735c456fdd1140fce7bca0f2'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/passing_b_sw_v4.png.import', 'bytes': 992, 'sha256': '1a6f3165c3f0b8322d75d34a8b85e441d829d2b00d990a24c33ccf61e93fa2a4'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/posture_v3.png.import', 'bytes': 977, 'sha256': '9aaff8311282cc57236faf1e6e832769c6d241604673ba776bdec96fd55c1c5d'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/proportion_v2.png.import', 'bytes': 986, 'sha256': 'ed0d6c9f68291095457ceed89c41279f7ca3afcd4942288a46360dcfc39457f7'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/step_a_se_guide_v3.png.import', 'bytes': 1001, 'sha256': 'a84e1695706acb931654dec1c225022ecffdde61c914355fbcf9be93b3932734'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/step_b_body_se_v4.png.import', 'bytes': 998, 'sha256': 'e9e3023886b8d63ca206871c7d6c40dae9330c27165d37d847ffe78a1a8db20a'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/step_b_priority_v3.png.import', 'bytes': 1000, 'sha256': '1d956e099f80dbafd370c58219ebcbb6058117c4ecd76f8d045f7f21a1202a79'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/step_b_se2_v3.png.import', 'bytes': 986, 'sha256': '7188101e5d41211c9deb34f1cbf2b6e09220563f73bd443e10e44e3f044bacef'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/step_b_se_guide_v3.png.import', 'bytes': 1001, 'sha256': '2f3c696a3e9819b38b7781d3d4f3187b11b4134aa578e1450d6934d65eea2f88'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/step_b_se_v3.png.import', 'bytes': 982, 'sha256': 'e52d67c4ef0c9b6f3aabd3a31caad808919540f8f4e229db7e2805b57d3f722b'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/walk_a_matched_nw_v4.png.import', 'bytes': 1007, 'sha256': 'fba0eacd44d306be2b1f50551099ee8fbdd1725eb2ef1a03680c6cd5787b4f04'}, {'path': 'assets/characters/shi_xiu_wounded_20261005/walk_b_v3.png.import', 'bytes': 974, 'sha256': '70df7e54787f708abc0efbb625dc7744ba55fb7e1d1399cca82902a4e80dded6'}, {'path': 'assets/characters/wang_ying_wounded_20261005/idle_v3.png.import', 'bytes': 970, 'sha256': '599ff74827ad84a4bef25635d306a8a5035ea3c2c6c988be8028c0241c8f8b2d'}, {'path': 'assets/characters/wang_ying_wounded_20261005/posture_v3.png.import', 'bytes': 978, 'sha256': 'ee35c4525e849f45a936aeefcd3e86dbd24961ea69349f87fc5ef46678f3e9f5'}, {'path': 'assets/characters/wang_ying_wounded_20261005/proportion_v2.png.import', 'bytes': 988, 'sha256': 'd901a597f9bc24dbd1b045cf8a0efe7e28eb056af95dd18902563174a0d55fa2'}, {'path': 'assets/characters/wang_ying_wounded_20261005/walk_a2_ne_v4.png.import', 'bytes': 988, 'sha256': '51004855ad6e679c619c31cb95a5ae407b846cecc5f28b650ed2e6cba889aa3d'}, {'path': 'assets/characters/wang_ying_wounded_20261005/walk_b2_se_v4.png.import', 'bytes': 988, 'sha256': '3e74aaf01230d39c65aaf8b62348572f13c7f9e1f4e1811d4c5dad3596ba1625'}, {'path': 'assets/characters/wang_ying_wounded_20261005/walk_b_se_v4.png.import', 'bytes': 985, 'sha256': '0ca598a5c5508ae1f94cc24260c00a46f0bee633c5d78e605c73289a33500c45'}, {'path': 'assets/characters/wu_song_traits_20261006/idle_v4.png.import', 'bytes': 967, 'sha256': '5e0f2ddcccc72944a3e80abd2d1edb817b810820bac65069f43b3eeb1e1ce023'}, {'path': 'assets/characters/yang_lin_wounded_20261005/posture_v3.png.import', 'bytes': 978, 'sha256': '7a6b1c58f4e8f85ca2e8b0faba76f6d8aa4df7458e2301297fbb5957e594cd16'}, {'path': 'assets/characters/yang_lin_wounded_20261005/proportion_fix_v2.png.import', 'bytes': 999, 'sha256': '439e98c9f491ca05ef286cf3153d6f7227c332407e65e58648480740b95ed940'}, {'path': 'assets/characters/yang_lin_wounded_20261005/proportion_v2.png.import', 'bytes': 987, 'sha256': 'e03c0afa60cd9264f347b3effb750b8f38629814850cb74d8f1ef1efaabd76fb'}, {'path': 'assets/characters/yang_lin_wounded_20261005/walk_b_sw_v4.png.import', 'bytes': 983, 'sha256': '466e0524e8f28ceae2cd4fc8523bd147470b21cbb4ef68b358f093b6c3fb0e6e'}, {'path': 'assets/ui/items/health_potion.svg.import', 'bytes': 1055, 'sha256': '679ea2959aa606c3f4975c915fa5c6250689b8e49a2f9c52a6cc9851b5e35a32'}, {'path': 'scripts/continue_flow.gd.uid', 'bytes': 20, 'sha256': '85bfa5a68cd5b34656d9e4e130cf707e8fce778eb468ffa9e82a438acc2e48fc'}, {'path': 'scripts/portrait_atlas_regions.gd.uid', 'bytes': 20, 'sha256': 'fda6e8a42293d3bcc085fada0b72bb42df12d3a8c5621e541a9cb5dade3af7d4'}, {'path': 'scripts/run_campaign_level_state.gd.uid', 'bytes': 20, 'sha256': '24326d7db8a917c496070e78e23af387ebb540633c921ba21665e21a72ac4db6'}, {'path': 'scripts/run_campaign_mission_state.gd.uid', 'bytes': 19, 'sha256': '021204cbfd4a1a37d03039377b2a84c7b6e9fc70a9246713fcd99f22b25fbefe'}, {'path': 'scripts/run_campaign_presentation_state.gd.uid', 'bytes': 20, 'sha256': '1cb4576f52f9ce9cfa15f619813dc02d504ef3449a53567202a03c498008cc14'}, {'path': 'scripts/run_daming_lighting_state.gd.uid', 'bytes': 20, 'sha256': '4adeb888a0fe481db350d335cb1a860d3445051a41fc9f46bba67853faa29f7c'}, {'path': 'scripts/run_level1_world_factory.gd.uid', 'bytes': 20, 'sha256': '0d068f311cc8f8a7bccff59666370ca8a7f6c8dc74016167f58dde09fa97fdfc'}, {'path': 'scripts/run_level3_world_factory.gd.uid', 'bytes': 20, 'sha256': '573d2382a56d2bb0aee2fba1a764a7550042217cb1fc1f1c5ccdaca94bbcba62'}, {'path': 'scripts/run_level5_unit_contract.gd.uid', 'bytes': 20, 'sha256': '4acc3a29a8f8185ea2d289bbeadddd8ff15548d7bec012be83dbe2e30bc984bb'}, {'path': 'scripts/run_level5_world_factory.gd.uid', 'bytes': 20, 'sha256': '39d29bed9873c6d81c7506dffec39bf976804b59cbc0df15619956de0822756b'}, {'path': 'scripts/run_level8_unit_contract.gd.uid', 'bytes': 19, 'sha256': '748355133a6bf932bbc8e44741e421c6ddb3e1074c9c6bc0c3015c7fe63b3c49'}, {'path': 'scripts/run_level8_world_factory.gd.uid', 'bytes': 19, 'sha256': 'c6db27ad0eec1ae1463e1665d6a9660598e4eb1d12e91c8d2777bf122277b945'}, {'path': 'scripts/run_local_lifecycle.gd.uid', 'bytes': 20, 'sha256': '20d4df1c6b57971f86bc6cd190aabf786ed298a0de9ddbb5215dac5f3b311b19'}, {'path': 'scripts/run_official_restore_profile.gd.uid', 'bytes': 20, 'sha256': 'a6b5eb83f9b1d63322a3579957ec1bf010953ea52e16f2a5fbc3f19c2948f3b4'}, {'path': 'scripts/steam_cloud.gd.uid', 'bytes': 20, 'sha256': 'a85e2ea1ec6c57e27a67d9ee765b6c6440b3298947d35519e53dfc99259bbb45'}, {'path': 'scripts/steam_persistent_outbox.gd.uid', 'bytes': 20, 'sha256': '049f52c9d29a19acf6df8d364c0170b947b0ea39080c982ba28c93ef0bbeade7'}, {'path': 'scripts/steam_persistent_outbox_state.gd.uid', 'bytes': 20, 'sha256': '1fb03667a66aa7fb7450f5e4e28633c7fc7ed4a585d7bf94f9e7246e5ba3fefe'}, {'path': 'scripts/steam_persistent_outbox_store.gd.uid', 'bytes': 20, 'sha256': 'f0b7142558c794e91660bcca3f40c92e3bae949e1d132623b715894b916a4993'}, {'path': 'scripts/steam_presence.gd.uid', 'bytes': 20, 'sha256': '0e70a7233261d402cf6f2edd799160eebc13da14a18c234b6f34f70176f842aa'}, {'path': 'scripts/steam_stats_observer.gd.uid', 'bytes': 20, 'sha256': '8cf6b781ba5a7e9e04f6379723457b04aa99f2ffa7a59fff752f845518d576d2'}, {'path': 'scripts/steam_stats_reader.gd.uid', 'bytes': 20, 'sha256': '6f18265c13889f4482541666d4e6e53b33f62a495428b8efdbcea599f0209db4'}, {'path': 'scripts/zhujiazhuang_recovery_hint.gd.uid', 'bytes': 20, 'sha256': '7846b8d5dee2a8339fe9b1192ecd2e4a3e36b3838578620c74908566b5b2e15c'}]
PREDECESSOR_EXECUTED_PRODUCER_SHA256 = '5a7f54b7b209aeaf448485c4bb3417eeb161715ac7f38a1049e82af5e23d484e'
IMPORT_METADATA_CORRECTION_FAILURE_RECEIPT_SHA256 = '63fd5a49231957e4e7c0a1e9a09a47c38c740a7e86bc931a6fd01dd987de9fa3'



class BatchFailure(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise BatchFailure(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def dump_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def no_reparse(path):
    path = Path(path).absolute()
    for ancestor in [path, *path.parents]:
        if ancestor.exists() or ancestor.is_symlink():
            info = ancestor.lstat()
            require(not ancestor.is_symlink() and not getattr(info, "st_file_attributes", 0) & 0x400,
                    "link/reparse path refused: " + str(ancestor))
    return path


def relative_path(value):
    require(isinstance(value, str) and value and "\\" not in value and ":" not in value,
            "invalid receipt relative path")
    require(not Path(value).is_absolute() and all(p not in ("", ".", "..") for p in value.split("/")),
            "unsafe receipt relative path: " + value)
    return value


def cim_processes(process_id=None):
    # Fail closed on observation errors; never interpret an empty tool result as
    # a vanished process. The returned JSON has an explicit ok and array shape.
    selection = (f'$all=Get-CimInstance Win32_Process -Filter "ProcessId={int(process_id)}" -ErrorAction Stop; '
                 if process_id is not None else '$all=Get-CimInstance Win32_Process -ErrorAction Stop; ')
    query = ("$ErrorActionPreference='Stop'; " + selection +
             '$rows=@($all | Select-Object ProcessId,Name,ExecutablePath,CommandLine); '
             '@{ok=$true;rows=$rows}|ConvertTo-Json -Depth 4 -Compress')
    completed = subprocess.run(["powershell.exe", "-NoProfile", "-Command", query],
                               check=True, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=20)
    payload = json.loads(completed.stdout.strip())
    require(payload.get("ok") is True and isinstance(payload.get("rows"), list),
            "CIM observation missing explicit success/array")
    return payload["rows"]


def engine_rows(owned_pid=None):
    rows = cim_processes()
    return [{"pid": int(row["ProcessId"]), "name": row.get("Name", "")}
            for row in rows
            if re.match(r"^(?:Godot|Liangshan|水浒)", row.get("Name", ""), re.I)
            and int(row["ProcessId"]) != owned_pid]


def installed_identity(project):
    """Mirror the fixed installed-input canonicalization; QA tools are outside it.

    The real native Provider must independently return this exact content digest
    in every process. This Python value never replaces runtime identity checks.
    """
    provider = project / "scripts/run_content_identity.gd"
    match = re.search(r'const INPUT_RULES_JSON := """(.*?)"""', provider.read_text(encoding="utf-8"), re.S)
    require(match is not None, "installed rules literal unavailable")
    rules_text = match.group(1)
    rules = json.loads(rules_text)
    files, directories, folded = {}, {}, {}

    def register(relative):
        relative_path(relative)
        require(relative.lower() not in folded or folded[relative.lower()] == relative,
                "installed input case alias")
        folded[relative.lower()] = relative
        no_reparse(project / relative)

    def file(relative):
        if relative == rules["derived"]:
            return
        register(relative)
        target = project / relative
        require(target.is_file(), "installed input not a file: " + relative)
        files[relative] = {"path": relative, "bytes": target.stat().st_size, "sha256": sha(target)}

    def walk(relative, depth=0):
        require(depth <= rules["max_depth"], "installed input depth limit")
        register(relative)
        directories[relative] = True
        for child in sorted((project / relative).iterdir(), key=lambda item: item.name):
            no_reparse(child)
            name = relative + "/" + child.name
            if child.is_dir():
                if child.name not in rules["skip_directories"]:
                    walk(name, depth + 1)
            else:
                file(name)

    for name in rules["root_files"]:
        target = project / name
        if target.is_file(): file(name)
        else:
            require(name not in rules["required_files"] and not target.exists(), "required root file absent")
            directories["@file/" + name] = False
    for name in rules["roots"]:
        target = project / name
        if target.is_dir(): walk(name)
        else:
            require(name not in rules["required_roots"] and not target.exists(), "required runtime root absent")
            directories[name] = False
    file("scripts/run_content_identity.gd")
    for name in rules["optional_content"]:
        if (project / name).is_file() and name not in files: file(name)
        require(not (project / name).is_dir(), "optional content has directory type")
    rules_sha = hashlib.sha256(rules_text.encode("utf-8")).hexdigest()
    canonical = rules["header"] + "\nrules\t" + rules_sha + "\n"
    for name in sorted(directories): canonical += f"D\t{name}\t{int(directories[name])}\n"
    for name in sorted(files):
        row = files[name]
        canonical += f"F\t{name}\t{row['bytes']}\t{row['sha256']}\n"
    for name in rules["optional_content"]: canonical += f"O\t{name}\t{int(name in files)}\n"
    total = sum(row["bytes"] for row in files.values())
    require(0 < len(files) <= rules["max_files"] and total <= rules["max_bytes"], "installed identity size budget")
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return {"content_version": "source-v1:" + digest, "rules_sha256": rules_sha,
            "file_count": len(files), "total_bytes": total,
            "files": [files[name] for name in sorted(files)], "directories": directories}


class Runner:
    def __init__(self, args, run):
        self.args, self.run = args, run
        self.root, self.project = args.source_root, run / "project"
        self.child = None
        self.locked = False
        self.lock = self.root / ".godot/redraw_rejection_source.lock"
        self.inputs = []
        self.baseline_inputs = []
        self.candidate_rows = {}
        self.boundary = None
        self.installed = None
        self.cache_installed = None
        self.shared = None
        self.native = None
        self.code_pins = {}
        self.reports = {}
        self.receipt = {"schema": "daming_admit_batch_v24s", "complete": False, "run": str(run),
                        "project": str(self.project), "source_root": str(self.root),
                        "scope": SCOPE, "private_runtime_patches": 0, "qa_harness_added": True,
                        "public_campaign_continue_qualified": False, "natural_victory_qualified": False,
                        "reward_once_qualified": False, "deadline_utc": args.deadline_utc.isoformat(),
                        "producer_sha256": sha(Path(__file__)), "steps": [], "reports": {}}

    def limit(self):
        if dt.datetime.now(dt.timezone.utc) >= self.args.deadline_utc:
            raise BatchFailure("authorized_six_am_wrap_deadline")

    def pause(self, seconds=5):
        self.limit()
        remaining = (self.args.deadline_utc - dt.datetime.now(dt.timezone.utc)).total_seconds()
        time.sleep(max(0.0, min(seconds, remaining)))
        self.limit()

    @contextlib.contextmanager
    def stage(self, label):
        step_dir = self.run / "steps" / f"{len(self.receipt['steps']):02d}_{label}"
        step_dir.mkdir(parents=True, exist_ok=False)
        step = {"case": label, "complete": False, "step_dir": str(step_dir),
                "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                "started_ns": time.monotonic_ns()}
        try:
            yield step
            step["complete"] = True
        except BaseException as exc:
            step["failure"] = {"type": type(exc).__name__, "message": str(exc)}
            raise
        finally:
            step["finished_ns"] = time.monotonic_ns()
            step["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
            self.receipt["steps"].append(step)
            dump_new(step_dir / "receipt.json", step)

    def copy_checked(self, source, dest, expected_sha=None):
        self.limit()
        no_reparse(source); no_reparse(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Path(source).open("rb") as reader, dest.open("xb") as writer:
            while True:
                self.limit()
                block = reader.read(1024 * 1024)
                if not block: break
                writer.write(block)
        if expected_sha is not None:
            require(sha(source) == sha(dest) == expected_sha, "copy changed: " + str(source))

    def input_integrity(self, private=False):
        self.limit()
        for row in self.inputs:
            self.limit()
            path = self.root / row["path"]
            require(path.is_file() and sha(path) == row["sha256"] and path.stat().st_size == row["bytes"],
                    "source input drift: " + row["path"])
            if private:
                path = self.project / row["path"]
                require(path.is_file() and sha(path) == row["sha256"] and path.stat().st_size == row["bytes"],
                        "private input drift: " + row["path"])
        require(sha(self.args.godot) == self.receipt["godot_sha256"], "Godot binary drift")
        for source, digest in self.code_pins.items(): require(sha(source) == digest, "proposal/helper drift: " + source)
        if private:
            for row in self.receipt["added_qa_files"]:
                require(sha(self.project / row["path"]) == row["sha256"], "private QA harness drift")
            require(self.shared.native_dependencies() == self.native, "source native manifest/file drift")
            for row in self.receipt["native_installed_files"]:
                require(sha(self.project / row["path"]) == row["sha256"] and (self.project / row["path"]).stat().st_size == row["bytes"], "private native binding/binary drift")
            for row in QUALIFIED_CACHED_IMPORT_EXTRAS:
                cached_path = Path(self.cache["project"]) / row["path"]
                private_path = self.project / row["path"]
                require(sha(cached_path) == sha(private_path) == row["sha256"]
                        and cached_path.stat().st_size == private_path.stat().st_size == row["bytes"],
                        "qualified imported metadata companion drift")
            actual = installed_identity(self.project)
            require(actual == self.installed, "entire candidate installed runtime identity drift/addition")
            require(actual["file_count"] == CURRENT_CANDIDATE_INSTALLED_FILE_COUNT, "candidate full runtime5102 count drift")

    def preflight(self):
        with self.stage("preflight") as step:
            self.limit()
            baseline = read(self.args.source_receipt)
            require(baseline.get("complete") is True and baseline.get("private_runtime_patches") == 0,
                    "source receipt is not qualified zero-patch source")
            require(Path(baseline["source_root"]).resolve() == self.root, "source receipt repository mismatch")
            self.baseline_inputs = baseline["source_files"]
            self.inputs = self.baseline_inputs
            grouped = {}
            for row in self.inputs: grouped.setdefault(row["path"], []).append(row)
            duplicates = {p: rows for p, rows in grouped.items() if len(rows) > 1}
            expected_duplicates = {
                "assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png",
                "assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png.import",
                "assets/characters/wu_song_traits_20261006/idle_spacing_v4.png",
                "assets/characters/wu_song_traits_20261006/idle_spacing_v4.png.import"}
            require(len(self.inputs) == 5039 and len(grouped) == 5035 and set(duplicates) == expected_duplicates
                    and all(len(rows) == 2 and rows[0] == rows[1] for rows in duplicates.values()),
                    "qualified raw manifest5039rows/5035distinct and four exact registered duplicate rows required")
            self.receipt["manifest_inventory"] = {"raw_rows": 5039, "distinct_paths": 5035,
                                                   "identical_duplicate_paths": sorted(duplicates)}
            for row in self.inputs:
                relative_path(row["path"])
                require(isinstance(row["bytes"], int) and row["bytes"] >= 0 and re.fullmatch(r"[0-9a-f]{64}", row["sha256"]), "input row invalid")
            cache = read(self.args.cache_receipt)
            require(cache.get("source_files") == self.baseline_inputs and Path(cache["source_root"]).resolve() == self.root,
                    "cache/source receipt frozen inputs differ")
            import_steps = [row for row in cache.get("steps", []) if row.get("case") == "import" and row.get("exit_code") == 0 and not row.get("stop_reason")]
            require(len(import_steps) == 1, "cache has no unique successful import evidence")
            cache_log = Path(cache["run"]) / "import.log"
            require(cache_log.is_file() and sha(cache_log) == import_steps[0]["log_sha256"] and not ENGINE_ERRORS.search(cache_log.read_text(encoding="utf-8", errors="replace")), "cached import log absent/changed/errored")
            engine_pin = read(self.root / "qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json")
            require(engine_pin.get("complete") is True and engine_pin.get("private_runtime_patches") == 0, "qualified engine/native anchor invalid")
            self.receipt.update(source_receipt=str(self.args.source_receipt), source_receipt_sha256=sha(self.args.source_receipt),
                                cache_receipt=str(self.args.cache_receipt), cache_receipt_sha256=sha(self.args.cache_receipt),
                                engine_anchor_sha256=sha(self.root / "qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json"),
                                source_files=self.inputs, godot_sha256=engine_pin["godot_sha256"],
                                cache_project=cache["project"], cached_import_log_sha256=sha(cache_log))
            self.cache = cache
            require(sha(self.args.cached_native_world) == QUALIFIED_NATIVE_WORLD_ARTIFACT_SHA256,
                    "qualified native world artifact changed")
            native_world_envelope = read(self.args.cached_native_world)
            require(isinstance(native_world_envelope, dict) and isinstance(native_world_envelope.get("original"), dict),
                    "qualified native world artifact lacks original whole world")
            native_world = native_world_envelope["original"]
            require(native_world["content_version"] == QUALIFIED_CACHED_CONTENT_VERSION
                    and native_world["engine_sha256"] == self.receipt["godot_sha256"]
                    and native_world["profile"]["context"] == {"level_id": "level8", "mode": "campaign", "waves": 0},
                    "qualified native whole-world content/engine/profile proof mismatched")
            self.code_pins[str(self.args.cached_native_world)] = sha(self.args.cached_native_world)
            self.receipt["cached_native_world_provenance"] = {
                "path": str(self.args.cached_native_world), "sha256": sha(self.args.cached_native_world),
                "original_content_version": native_world["content_version"],
                "original_engine_sha256": native_world["engine_sha256"],
                "predecessor_executed_producer_sha256": PREDECESSOR_EXECUTED_PRODUCER_SHA256,
                "import_metadata_correction_failure_receipt_sha256": IMPORT_METADATA_CORRECTION_FAILURE_RECEIPT_SHA256}
            cache_project = no_reparse(Path(cache["project"]).resolve())
            require(cache_project.is_dir() and not cache_project.is_relative_to(self.root), "qualified private cache root invalid")
            self.cache_installed = installed_identity(cache_project)
            require(self.cache_installed["file_count"] == QUALIFIED_CACHED_INSTALLED_FILE_COUNT
                    and self.cache_installed["content_version"] == native_world["content_version"],
                    "actual qualified cached complete installed identity not proven by original native world")
            for row in QUALIFIED_CACHED_IMPORT_EXTRAS:
                relative_path(row["path"])
                require(row["path"].endswith((".import", ".uid")) and not row["path"].startswith((".godot/", "tools/", "qa/")),
                        "corrected extra metadata suffix/root refused")
                path = cache_project / row["path"]
                no_reparse(path)
                require(path.is_file() and path.stat().st_size == row["bytes"] and sha(path) == row["sha256"],
                        "explicit qualified import/UID companion source changed: " + row["path"])
            self.receipt["qualified_cached_installed_identity"] = self.cache_installed
            self.receipt["qualified_cached_import_extras"] = QUALIFIED_CACHED_IMPORT_EXTRAS
            helper = self.root / "tools/run_steam_integration_qa.py"
            # Vendor source_inputs describes the historical reader build, not
            # the live profile/bootstrap helper. Pin the committed live helper;
            # native package manifests/binary hashes still match both anchors.
            committed_helper = subprocess.check_output(["git", "show", "HEAD:tools/run_steam_integration_qa.py"], cwd=self.root)
            working_helper = helper.read_bytes().replace(b"\r\n", b"\n")
            require(committed_helper.replace(b"\r\n", b"\n") == working_helper,
                    "native bootstrap helper has uncommitted source drift")
            self.receipt["live_helper_provenance"] = {"path": "tools/run_steam_integration_qa.py",
                "sha256": sha(helper), "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=self.root, text=True).strip(),
                "historical_reader_build_helper_sha256": engine_pin["native_dependencies"]["steam_stats_reader"]["source_inputs"]["tools/run_steam_integration_qa.py"]}
            self.code_pins[str(helper)] = sha(helper)
            proposal = Path(__file__).resolve().parent
            require(sha(proposal / "run_daming_admit_v24o4.py") == INHERITED_EXECUTED_PRODUCER_SHA256, "immutable executed producer changed")
            require(sha(proposal / "daming_admit_cross_process_v24o.gd") == EXECUTED_DAMING_A_B_C_HARNESS_SHA256, "original executed A/B/C harness changed")
            require(sha(proposal / "run_daming_admit_v24r2.py") == INHERITED_EXECUTED_R2_SHA256, "immutable executed r2 producer changed")
            require(sha(proposal / "daming_admit_cross_process_v24s.gd") == V24S_DAMING_HARNESS_SHA256 and sha(proposal / "daming_admit_cross_process_v24s.tscn") == V24S_DAMING_SCENE_SHA256, "reviewed v24s harness/scene changed")
            self.verify_failed_boundary_ancestry()
            self.select_candidate(grouped, cache_project)
            self.select_boundary()
            owned_tool = self.root / "tools/owned_slot_retry_qa.gd"
            require(owned_tool.is_file(), "original OwnedSlot regression unavailable")
            committed_owned_tool = subprocess.check_output(["git", "show", "HEAD:tools/owned_slot_retry_qa.gd"], cwd=self.root)
            require(committed_owned_tool.replace(b"\r\n", b"\n") == owned_tool.read_bytes().replace(b"\r\n", b"\n"), "OwnedSlot original tool has uncommitted drift")
            self.code_pins[str(owned_tool)] = sha(owned_tool)
            for name in ["run_daming_admit_v24s.py", "daming_admit_cross_process_v24s.gd", "daming_admit_cross_process_v24s.tscn", "run_daming_admit_v24r2.py", "run_daming_admit_v24r1.py", "run_daming_admit_v24r.py", "run_daming_admit_v24o4.py", "daming_admit_cross_process_v24o.gd", "daming_admit_cross_process_v24o.tscn"]:
                self.code_pins[str(proposal / name)] = sha(proposal / name)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": digest} for p, digest in self.code_pins.items()]
            self.input_integrity()
            spec = importlib.util.spec_from_file_location("daming_v24o_shared_native", helper)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            require(module.ROOT.resolve() == self.root, "native helper bound to a different source root")
            self.shared = module
            self.native = module.native_dependencies()
            require(self.native == cache["native_dependencies"] == engine_pin["native_dependencies"], "native manifests not identical to qualified/cache anchor")
            step.update(inputs=5041, baseline_inputs=5039, cache_import_qualified=True, godot_sha256=self.receipt["godot_sha256"])



    def verify_failed_boundary_ancestry(self):
        older = Path(__file__).resolve().with_name("run_daming_admit_v24r.py")
        require(sha(older) == "4ff6bb7de05d1b433fbb91edecb6827c96800f6149076796cadbbca9fade9bb6", "immutable executed v24r producer changed")
        evidence = Path("E:/ChatGPT/qa-world-restore-20261007/daming_admit_v24r_c67b91f3")
        paths = [evidence / "receipt.json", evidence / "native_evidence/json_boundary/report.json", evidence / "steps/06_json_boundary/native.log"]
        expected = ["e05676f4f92ae5c68904c34d7386c36a92c9a9babfbbdfcc9d7e14b63f1072c6", "cce2fd06a58f88247a86e7a3d8c01cf04b56a6cde8668779e8021f85dbbdd35b", "563d92e2143d29d950be782b55d809107a8a8b667f81d0e81752088a3b25684f"]
        for path, digest in zip(paths, expected):
            no_reparse(path)
            require(path.is_file() and (digest is None or sha(path) == digest), "original failed native evidence missing/changed")
            self.code_pins[str(path)] = sha(path)
        old_receipt, old_report = read(paths[0]), read(paths[1])
        require(old_receipt.get("complete") is False and old_report.get("passed") is False
                and len(old_report.get("checks", [])) == 267
                and [row.get("label") for row in old_report["checks"] if row.get("passed") is not True] == ["reject gao/wrong node kind"],
                "historical failed267-check boundary no longer matches its original failed fixture")
        self.receipt["historical_failed_boundary"] = {"qualified": False, "complete": False,
            "source_producer_sha256": sha(older), "run": str(evidence), "checks": 267,
            "sole_failed_label": "reject gao/wrong node kind",
            "files": [{"path": str(path), "sha256": self.code_pins[str(path)]} for path in paths],
            "correction": "New sibling q1 selects an actual differing installed entrance/night node; rejection assertion and production candidate unchanged."}

    def select_candidate(self, baseline_grouped, cache_project):
        receipt = read(self.args.candidate_receipt)
        require(isinstance(receipt, dict) and isinstance(receipt.get("files"), list), "candidate receipt shape invalid")
        rows = receipt["files"]
        wanted = CANDIDATE_CHANGED_PATHS | CANDIDATE_ADDED_PATHS
        require(len(rows) == 4 and {row.get("path") for row in rows} == wanted, "candidate must declare only two changed code and helper/UID additions")
        self.candidate_rows = {row["path"]: row for row in rows}
        for path, row in self.candidate_rows.items():
            relative_path(path)
            require(type(row.get("bytes")) is int and row["bytes"] > 0 and re.fullmatch(r"[0-9a-f]{64}", row.get("after_sha256", "")), "candidate row bytes/SHA invalid")
            actual = self.root / path
            no_reparse(actual)
            require(actual.is_file() and actual.stat().st_size == row["bytes"] and sha(actual) == row["after_sha256"], "current candidate ROOT path changed: " + path)
            if path in CANDIDATE_CHANGED_PATHS:
                require(path in baseline_grouped and row.get("before_sha256") == baseline_grouped[path][0]["sha256"]
                        and row["before_sha256"] != row["after_sha256"]
                        and sha(cache_project / path) == row["before_sha256"], "candidate beforeSHA does not match real qualified donor: " + path)
            else:
                require(row.get("before_sha256") is None and path not in baseline_grouped
                        and path not in {r["path"] for r in self.cache_installed["files"]}
                        and not (cache_project / path).exists(), "helper/UID not new in qualified source/runtime")
        self.inputs = []
        for row in self.baseline_inputs:
            current = self.candidate_rows.get(row["path"])
            self.inputs.append({"path": row["path"], "bytes": current["bytes"], "sha256": current["after_sha256"]} if current else dict(row))
        for path in sorted(CANDIDATE_ADDED_PATHS):
            row = self.candidate_rows[path]
            self.inputs.append({"path": path, "bytes": row["bytes"], "sha256": row["after_sha256"]})
        require(len(self.inputs) == 5041 and len({row["path"] for row in self.inputs}) == 5037, "current raw5041/distinct5037 inventory changed")
        self.code_pins[str(self.args.candidate_receipt)] = sha(self.args.candidate_receipt)
        self.receipt["qualified_baseline_source_files"] = self.baseline_inputs
        self.receipt["source_files"] = self.inputs
        self.receipt["manifest_inventory"]["qualified_baseline_raw_rows"] = 5039
        self.receipt["manifest_inventory"]["qualified_baseline_distinct_paths"] = 5035
        self.receipt["manifest_inventory"].update(raw_rows=5041, distinct_paths=5037)
        self.receipt["candidate_source_bridge"] = {"receipt": str(self.args.candidate_receipt),
            "receipt_sha256": sha(self.args.candidate_receipt), "files": rows,
            "private_runtime_patches": 0, "scope": "Frozen actual ROOT candidate source; two code changes and helper/UID additions only."}

    def select_boundary(self):
        if self.args.boundary_harness is None:
            self.receipt["json_boundary_regression_requested"] = False
            return
        gd = self.args.boundary_harness
        scene = gd.with_suffix(".tscn")
        no_reparse(scene)
        require(gd.suffix == ".gd" and gd.is_file() and scene.is_file(), "boundary GD and same-name scene required")
        require(sha(gd) == BOUNDARY_HARNESS_SHA256 and sha(scene) == BOUNDARY_SCENE_SHA256
                and sha(self.args.boundary_manifest) == BOUNDARY_MANIFEST_SHA256, "reviewed boundary harness/scene/fixture-manifest changed")
        require("res://tools/" + gd.name in scene.read_text(encoding="utf8"), "boundary scene must reference its fixed tools harness")
        manifest = read(self.args.boundary_manifest)
        require(isinstance(manifest, dict) and manifest.get("schema") == "native_ownership_json_boundary_fixtures_v24q"
                and isinstance(manifest.get("maps"), list), "fixed boundary fixture manifest schema invalid")
        require(len(manifest["maps"]) == 9 and {row.get("case") for row in manifest["maps"]} == BOUNDARY_CASES - {"actual_v24p_pending", "classic_none"}, "all nine explicit original map fixtures required")
        rows = [manifest["original_payload"], manifest["normalized_payload"], *manifest["maps"]]
        for row in rows:
            require(isinstance(row, dict) and isinstance(row.get("path"), str) and re.fullmatch(r"[0-9a-f]{64}", row.get("sha256", "")), "boundary fixture path/SHA absent")
            path = Path(row["path"])
            require(path.is_absolute(), "fixture path must be absolute")
            no_reparse(path)
            require(path.is_file() and 0 < path.stat().st_size <= 67108864 and sha(path) == row["sha256"], "boundary original fixture bytes/SHA changed")
            self.code_pins[str(path)] = row["sha256"]
        for path in [gd, scene, self.args.boundary_manifest]: self.code_pins[str(path)] = sha(path)
        self.boundary = {"gd": gd, "scene": scene, "manifest": manifest}
        self.receipt["json_boundary_regression_requested"] = True
        self.receipt["original_boundary_fixture_manifest"] = {"path": str(self.args.boundary_manifest), "sha256": sha(self.args.boundary_manifest), "document": manifest}

    def prepare_regression_inputs(self, additions):
        tool = self.root / "tools/owned_slot_retry_qa.gd"
        require(not (self.project / "tools/owned_slot_retry_qa.gd").exists(), "baseline unexpectedly includes OwnedSlot additional tool")
        self.copy_checked(tool, self.project / "tools/owned_slot_retry_qa.gd", self.code_pins[str(tool)])
        additions.append({"path": "tools/owned_slot_retry_qa.gd", "bytes": tool.stat().st_size, "sha256": sha(tool), "kind": "original byte-exact OwnedSlot regression, outside runtime roots"})
        scene = self.project / "tools/owned_slot_retry_v24r.tscn"
        scene_bytes = b'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/owned_slot_retry_qa.gd" id="1"]\n[node name="OwnedSlotRetryV24R" type="Node"]\nscript = ExtResource("1")\n'
        with scene.open("xb") as stream: stream.write(scene_bytes)
        additions.append({"path": "tools/owned_slot_retry_v24r.tscn", "bytes": len(scene_bytes), "sha256": sha(scene), "kind": "explicit Node scene for unchanged original regression"})
        if self.boundary is None: return
        for source in [self.boundary["gd"], self.boundary["scene"]]:
            target = self.project / "tools" / source.name
            self.copy_checked(source, target, self.code_pins[str(source)])
            additions.append({"path": "tools/" + source.name, "bytes": target.stat().st_size, "sha256": sha(target), "kind": "external pure JSON boundary regression, outside runtime roots"})
        destination = self.run / "boundary_inputs"
        destination.mkdir(exist_ok=False)
        frozen = json.loads(json.dumps(self.boundary["manifest"]))
        rows = [frozen["original_payload"], frozen["normalized_payload"], *frozen["maps"]]
        files = []
        for index, row in enumerate(rows):
            source = Path(row["path"])
            target = destination / (str(index).zfill(2) + "_" + source.name)
            self.copy_checked(source, target, row["sha256"])
            files.append({"original_path": str(source), "path": str(target), "sha256": row["sha256"], "bytes": target.stat().st_size})
            row["path"] = str(target)
        manifest_path = destination / "fixtures_frozen.json"
        dump_new(manifest_path, frozen)
        self.code_pins[str(manifest_path)] = sha(manifest_path)
        for row in files: self.code_pins[row["path"]] = row["sha256"]
        self.boundary.update(frozen_manifest=manifest_path, files=files)
        self.receipt["frozen_boundary_fixtures"] = files
        self.receipt["frozen_boundary_manifest_sha256"] = sha(manifest_path)

    def execute_regressions(self):
        if self.boundary is not None:
            folder = self.output / "json_boundary"
            folder.mkdir(exist_ok=False)
            report_path = folder / "report.json"
            env = self.env.copy()
            nonce = uuid.uuid4().hex
            env.update(OWNERSHIP_JSON_PROFILE=str(self.profile), OWNERSHIP_JSON_REPORT=str(report_path),
                       OWNERSHIP_JSON_FIXTURES=str(self.boundary["frozen_manifest"]),
                       OWNERSHIP_JSON_ENGINE_SHA256=self.receipt["godot_sha256"],
                       OWNERSHIP_JSON_EXPECT_CONTENT=self.installed["content_version"], OWNERSHIP_JSON_NONCE=nonce,
                       DAMING_ADMIT_NONCE=nonce)
            def boundary_passed(step, log):
                require(step["exit_code"] == 0 and step["process_terminal"], "pure JSON boundary native process not terminal0")
                data = read(report_path)
                require(data.get("schema") == "native_ownership_json_boundary_report_v24q" and data.get("passed") is True
                        and isinstance(data.get("checks"), list) and data["checks"]
                        and all(isinstance(row, dict) and row.get("passed") is True for row in data["checks"]), "JSON boundary checks not fully passed")
                require(data.get("pid") == step["pid"] and data.get("nonce") == nonce
                        and data.get("content_version") == self.installed["content_version"]
                        and data.get("engine_sha256") == self.receipt["godot_sha256"], "boundary PID/nonce/actual native identity mismatch")
                userdata = no_reparse(Path(data["actual_user_data_dir"]).resolve())
                require(userdata.is_relative_to((self.profile / "appdata").resolve()), "boundary userdata escaped own private profile")
                require(data.get("harness_revision") == "v24q1", "new wrong-kind fixture revision not executed")
                negative_evidence = data.get("negative_node_kind_evidence")
                require(isinstance(negative_evidence, list) and len(negative_evidence) == 2
                        and {row.get("case") for row in negative_evidence} == {"gao", "daming"}, "exact two actual negative node-kind proofs missing")
                frozen_rows = {row["case"]: row for row in self.boundary["manifest"]["maps"]}
                frozen_files = {row["original_path"]: row for row in self.boundary["files"]}
                for row in negative_evidence:
                    fixture = frozen_rows[row["case"]]
                    expected_fixture = frozen_files[fixture["path"]]
                    require(Path(row["fixture_path"]).resolve() == Path(expected_fixture["path"]).resolve()
                            and row["fixture_sha256"] == expected_fixture["sha256"], "wrong-kind fixture provenance differs from actual frozen world")
                    require(row.get("owner_path") == "ownership/sprites/0" and row.get("original_kind") == "sprite"
                            and row.get("selected_kind") == ("entrance" if row["case"] == "gao" else "night")
                            and type(row.get("original_index")) is int and row["original_index"] > 0
                            and type(row.get("selected_index")) is int and row["selected_index"] > 0
                            and row["original_index"] != row["selected_index"]
                            and type(row.get("selected_parent")) is int and row["selected_parent"] >= 0,
                            "wrong-kind fixture is not an actual distinct legal non-root node")
                    for field in ["original_tagged_node_sha256", "selected_tagged_node_sha256", "source_map_sha256"]:
                        require(isinstance(row.get(field), str) and re.fullmatch(r"[0-9a-f]{64}", row[field]), "actual negative node tagged/map SHA proof missing")
                step["negative_node_kind_evidence"] = negative_evidence
                require(isinstance(data.get("cases"), list) and {row.get("case") for row in data["cases"]} == BOUNDARY_CASES
                        and len(data["cases"]) == len(BOUNDARY_CASES), "boundary full actual/L5/L8/six/std/none case set missing")
                expected = {str(self.boundary["frozen_manifest"]): sha(self.boundary["frozen_manifest"]), **{row["path"]: row["sha256"] for row in self.boundary["files"]}}
                observed = {}
                for row in data.get("provenance", []):
                    path = no_reparse(Path(row["path"]).resolve())
                    require(str(path) in expected and sha(path) == expected[str(path)] == row["sha256"], "boundary actually-read provenance mismatch")
                    if str(path) != str(self.boundary["frozen_manifest"]):
                        require(row.get("utf8_bytes") == path.stat().st_size, "boundary fixture read UTF8 byte count mismatch")
                    observed[str(path)] = row["sha256"]
                require(observed == expected, "boundary did not read every fixed manifest/source fixture")
                source_rows = data.get("source_files")
                expected_source_paths = {"scripts/run_scenery_state.gd", "scripts/run_scenery_json_boundary.gd", "scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd", "scripts/run_state_value_codec.gd"}
                require(isinstance(source_rows, list) and len(source_rows) == len(expected_source_paths)
                        and {row.get("path") for row in source_rows} == {"res://" + path for path in expected_source_paths}, "boundary exact five executed source rows missing")
                source_files = {row["path"]: row["sha256"] for row in source_rows}
                for path in expected_source_paths:
                    require(source_files["res://" + path] == sha(self.project / path), "boundary installed source pin mismatch: " + path)
                require(data.get("pure_fixed_validator") is True
                        and all(data.get(key) == 0 for key in ["battle_factory_calls", "deploy_or_tick_calls", "disk_slot_writes", "private_runtime_patches"])
                        and all(data.get(key) is False for key in ["full_world_continuation_qualified", "natural_result_qualified", "public_campaign_entry_qualified"])
                        and "NATIVE_OWNERSHIP_JSON_V24Q_COMPLETE " in log, "boundary pure-scope/terminal marker missing")
                step.update(report=str(report_path), report_sha256=sha(report_path), checks=len(data["checks"]), cases=sorted(BOUNDARY_CASES), actual_content_version=data["content_version"])
                self.receipt["json_boundary_report"] = {"path": str(report_path), "sha256": sha(report_path), "pid": step["pid"], "nonce": nonce, "checks": len(data["checks"]), "cases": sorted(BOUNDARY_CASES)}
            self.native_phase("json_boundary", ["--headless", "res://tools/" + self.boundary["scene"].name], env, 600, boundary_passed)
        env = self.env.copy()
        env.update(LSH_OWNED_SLOT_RETRY_QA="1", LSH_OWNED_SLOT_RETRY_PROFILE=str(self.profile), DAMING_ADMIT_NONCE=uuid.uuid4().hex)
        def owned_passed(step, log):
            require(step["exit_code"] == 0 and step["process_terminal"], "original OwnedSlot native process not terminal0")
            match = re.search(r"OWNED_SLOT_RETRY_QA ([0-9]+) true (.+)", log)
            require(match is not None, "original OwnedSlot successful terminal report marker missing")
            path = no_reparse(Path(match.group(2).strip()).resolve())
            require(path.name == "report.json" and path.parent.name == "owned_slot_retry_qa"
                    and path.is_relative_to((self.profile / "appdata").resolve()), "OwnedSlot report outside own original fixture directory")
            data = read(path)
            rows = data.get("checks")
            require(data.get("passed") is True and isinstance(rows, list) and rows
                    and int(match.group(1)) == len(rows)
                    and all(isinstance(row, dict) and isinstance(row.get("name"), str) and row["name"] and row.get("passed") is True for row in rows), "original OwnedSlot checks not all passed")
            mandatory = {"release retryable with committed action", "pending retry uses validated forward action", "prewrite missing pending retries frozen proposal", "owner_readback missing pending retries frozen proposal", "wrong token refused with unsafe flags", "different owner refused", "new object cannot adopt same PID proposal", "corrupt pending refuses automatic repair", "corrupt pending retained byte for byte", "different valid pending cannot replace original intent", "partial release without token stays unsafe", "session exposes pending disk transaction", "session refuses disposal while token is needed", "session will not save and quit an unrelated source", "original store still completes after disposal refusal", "session disposal allowed after transaction completes"}
            require(mandatory <= {row["name"] for row in rows}, "original OwnedSlot branch assertions missing")
            require(all(data.get(key) is False for key in ["real_steam", "production_slot_document", "full_world_flow"]), "OwnedSlot scope overclaim")
            for relative in ["scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd", "scripts/run_world_session.gd", "tools/owned_slot_retry_qa.gd"]:
                require(data.get("source_sha256", {}).get("res://" + relative) == sha(self.project / relative), "OwnedSlot actual executed source SHA mismatch: " + relative)
            self.copy_checked(path, Path(step["step_dir"]) / "report.json", sha(path))
            step.update(report=str(path), report_sha256=sha(path), checks=len(rows), original_tool_sha256=sha(self.project / "tools/owned_slot_retry_qa.gd"))
            self.receipt["owned_slot_retry_report"] = {"path": str(path), "sha256": sha(path), "pid": step["pid"], "checks": len(rows), "production_slot_document": False, "original_tool_unchanged": True}
        self.native_phase("owned_slot_retry", ["--headless", "res://tools/owned_slot_retry_v24r.tscn"], env, 600, owned_passed)

    def wait_prior(self):
        with self.stage("wait_fx_terminal") as step:
            while not self.args.prior_receipt.is_file():
                self.limit()
                require(self.args.prior_pid is not None, "FX receipt not terminal; --prior-pid required to verify live wait")
                rows = cim_processes(self.args.prior_pid)
                require(len(rows) == 1 and "run_fx_partition_v24n" in (rows[0].get("CommandLine") or ""), "specific prior FX process handle missing or identity changed without terminal receipt")
                step["last_live_prior_pid"] = int(rows[0]["ProcessId"])
                step["last_live_observation_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
                print("WAIT verified live FX producer", self.args.prior_pid, flush=True)
                self.pause()
            prior = read(self.args.prior_receipt)
            require(prior.get("complete") is True and prior.get("lock_released") is True and prior.get("private_runtime_patches") == 0 and prior.get("source_files") == self.baseline_inputs,
                    "FX terminal receipt failed or frozen inputs differ")
            require(prior.get("godot_sha256") == self.receipt["godot_sha256"] and prior.get("root_input_drift") == 0 and prior.get("private_input_drift") == 0,
                    "FX engine/source integrity qualification absent")
            for phase in ["component", "restart"]:
                report = prior.get("reports", {}).get(phase, {})
                require(report.get("passed") is True and report.get("checks") and all(row.get("passed") is True for row in report["checks"]), "FX native report not fully passed: " + phase)
                steps = [row for row in prior["steps"] if row.get("case") == phase and row.get("complete") is True]
                require(len(steps) == 1 and steps[0].get("exit_code") == 0 and not steps[0].get("stop_reason"), "FX phase no unique successful native exit")
                attempt = Path(steps[0]["attempt"])
                require(sha(attempt / "report.json") == steps[0]["report_sha256"] and read(attempt / "report.json") == report, "FX report bytes differ from terminal evidence")
                require(sha(attempt / "runtime.log") == steps[0]["log_sha256"] and not ENGINE_ERRORS.search((attempt / "runtime.log").read_text(encoding="utf-8", errors="replace")), "FX native log invalid")
            require(prior["reports"]["component"]["pid"] != prior["reports"]["restart"]["pid"], "FX restart not distinct process")
            if self.args.prior_pid is not None:
                rows = cim_processes(self.args.prior_pid)
                while rows:
                    require(len(rows) == 1 and "run_fx_partition_v24n" in (rows[0].get("CommandLine") or ""),
                            "prior PID was reused by a different process")
                    print("WAIT verified FX terminal producer process exit", self.args.prior_pid, flush=True)
                    self.pause()
                    rows = cim_processes(self.args.prior_pid)
            self.receipt.update(prior_receipt=str(self.args.prior_receipt), prior_receipt_sha256=sha(self.args.prior_receipt),
                                prior_scope="Qualified FX is the exact historical donor5039 inputs; new candidate helpers additionally require their own boundary/OwnedSlot/native ABC checks.")
            step.update(prior_complete=True, prior_sha256=sha(self.args.prior_receipt))

    def wait_idle(self):
        idle_since = None
        last_idle_notice = None
        while True:
            self.limit()
            rows = engine_rows()
            lock_busy = self.lock.exists()
            now = time.monotonic()
            if rows or lock_busy:
                idle_since = None
                last_idle_notice = None
                print("WAIT natural shared engine idle", rows, "lock_busy=", lock_busy,
                      "continuous_idle_seconds_reset=", 60, flush=True)
                self.pause()
                continue
            if idle_since is None:
                idle_since = now
            elapsed = now - idle_since
            if elapsed >= 60:
                print("IDLE natural shared engine and lock continuously observed idle",
                      round(elapsed, 3), "s", flush=True)
                return
            if last_idle_notice is None or now - last_idle_notice >= 10:
                print("WAIT continuous natural shared engine and lock idle",
                      round(elapsed, 3), "/ 60 s", flush=True)
                last_idle_notice = now
            self.pause(1)

    def acquire(self):
        while True:
            self.wait_idle()
            try:
                self.lock.parent.mkdir(parents=True, exist_ok=True)
                with self.lock.open("x", encoding="utf-8") as stream: stream.write(str(self.run))
                self.locked = True
            except FileExistsError:
                self.pause(); continue
            if not engine_rows(): return
            self.release()

    def release(self):
        if self.locked and self.lock.exists() and self.lock.read_text(encoding="utf-8") == str(self.run):
            self.lock.unlink()
        self.locked = False

    def prepare(self):
        with self.stage("freeze_private_project") as step:
            self.limit(); self.input_integrity()
            self.project.mkdir(exist_ok=False)
            cache_project = no_reparse(Path(self.cache["project"]).resolve())
            require(not cache_project.is_relative_to(self.root) and cache_project.is_dir(), "private cache root invalid")
            # Preflight already requires exactly the four known duplicate
            # pairs to be completely identical. Allocate each unique file once.
            for row in {r["path"]: r for r in self.baseline_inputs}.values():
                require(sha(cache_project / row["path"]) == row["sha256"] and (cache_project / row["path"]).stat().st_size == row["bytes"], "old cached source drift before reuse")
            for row in {r["path"]: r for r in self.inputs}.values():
                self.copy_checked(self.root / row["path"], self.project / row["path"], row["sha256"])
            cache_dir = cache_project / ".godot"
            require(cache_dir.is_dir(), "successful imported cache no longer present")
            copied_cache = []
            for source in sorted(cache_dir.rglob("*")):
                self.limit(); no_reparse(source)
                relative = source.relative_to(cache_dir)
                if source.is_dir(): (self.project / ".godot" / relative).mkdir(parents=True, exist_ok=True)
                else:
                    digest = sha(source)
                    self.copy_checked(source, self.project / ".godot" / relative, digest)
                    copied_cache.append({"path": relative.as_posix(), "bytes": source.stat().st_size, "sha256": digest})
            dump_new(self.run / "copied_cache_manifest.json", copied_cache)
            self.receipt["copied_cache_manifest_sha256"] = sha(self.run / "copied_cache_manifest.json")
            self.receipt["cache_only_reused"] = True
            self.receipt["native_dependencies"] = self.shared.install_native(self.project)
            require(self.receipt["native_dependencies"] == self.native, "native installation returned different pins")
            native_rows = []
            for source in sorted((self.project / "addons").rglob("*")):
                no_reparse(source)
                if source.is_file(): native_rows.append({"path": source.relative_to(self.project).as_posix(), "bytes": source.stat().st_size, "sha256": sha(source)})
            self.receipt["native_installed_files"] = native_rows
            # The raw 5039-row receipt omitted 88 installed .import/.uid source
            # companions already present in the qualified post-import project.
            # Freeze only the exact registered suffix/path/size/SHA list, never
            # waive additions after our own complete import.
            before_companions = installed_identity(self.project)
            require(before_companions["file_count"] == 5014, "unexpected candidate pre-companion runtime5014 inventory")
            baseline_rows = {row["path"]: row for row in before_companions["files"]}
            cached_rows = {row["path"]: row for row in self.cache_installed["files"]}
            extra_rows = {row["path"]: row for row in QUALIFIED_CACHED_IMPORT_EXTRAS}
            expected_rows = dict(cached_rows)
            for path, row in self.candidate_rows.items():
                expected_rows[path] = {"path": path, "bytes": row["bytes"], "sha256": row["after_sha256"]}
            require(len(expected_rows) == 5102 and len(extra_rows) == 88
                    and set(cached_rows) - set(baseline_rows) == set(extra_rows)
                    and set(baseline_rows) - set(cached_rows) == CANDIDATE_ADDED_PATHS
                    and all(baseline_rows[path] == expected_rows[path] for path in baseline_rows)
                    and all(extra_rows[path] == cached_rows[path] for path in extra_rows),
                    "candidate bridge or exact qualified 88 metadata gap changed")
            for row in QUALIFIED_CACHED_IMPORT_EXTRAS:
                self.copy_checked(cache_project / row["path"], self.project / row["path"], row["sha256"])
            correction = {"schema": "qualified_installed_import_companions_v24r", "raw_rows": 5041,
                          "distinct_raw_paths": 5037, "pre_companion_runtime_files": 5014,
                          "qualified_donor_runtime_files": 5100, "current_candidate_runtime_files": 5102, "additional_metadata_files": 88,
                          "allowed_suffixes": [".import", ".uid"], "files": QUALIFIED_CACHED_IMPORT_EXTRAS,
                          "cache_receipt": str(self.args.cache_receipt), "cache_receipt_sha256": sha(self.args.cache_receipt),
                          "cache_project": str(cache_project), "qualified_native_world": self.receipt["cached_native_world_provenance"],
                          "qualified_donor_content_version": self.cache_installed["content_version"],
                          "candidate_receipt_sha256": sha(self.args.candidate_receipt),
                          "private_runtime_patches": 0, "runtime_scripts_modified": 0,
                          "scope": "Restore exact source-side imported/UID companions of the previously qualified installed world before import. No late-addition guard waiver."}
            dump_new(self.run / "qualified_import_metadata_companions.json", correction)
            self.receipt["import_metadata_companions_manifest_sha256"] = sha(self.run / "qualified_import_metadata_companions.json")
            additions = []
            for name in ["daming_admit_cross_process_v24s.gd", "daming_admit_cross_process_v24s.tscn"]:
                source = Path(__file__).resolve().with_name(name)
                target = self.project / "tools" / name
                self.copy_checked(source, target, self.code_pins[str(source)])
                additions.append({"path": "tools/" + name, "bytes": target.stat().st_size, "sha256": sha(target), "kind": "explicit additional QA harness, outside installed runtime roots"})
            self.prepare_regression_inputs(additions)
            self.receipt["added_qa_files"] = additions
            self.installed = installed_identity(self.project)
            require(self.installed["file_count"] == CURRENT_CANDIDATE_INSTALLED_FILE_COUNT
                    and {row["path"]: row for row in self.installed["files"]} == expected_rows
                    and self.installed["directories"] == self.cache_installed["directories"]
                    and self.installed["rules_sha256"] == self.cache_installed["rules_sha256"]
                    and self.installed["content_version"] != self.cache_installed["content_version"],
                    "full5102 current runtime is not exact donor plus the four qualified candidate paths")
            self.receipt["candidate_runtime_bridge"] = {"baseline_content_version": self.cache_installed["content_version"],
                "current_content_version": self.installed["content_version"], "baseline_files": 5100,
                "current_files": 5102, "changed_paths": sorted(CANDIDATE_CHANGED_PATHS), "added_paths": sorted(CANDIDATE_ADDED_PATHS),
                "all_other_cached_runtime_rows_exact": True}
            self.receipt["installed_identity"] = self.installed
            self.input_integrity(True)
            self.profile = self.run / "profile"
            self.profile.mkdir(exist_ok=False)
            for key in ["appdata", "localappdata", "temp", "tmp"]: (self.profile / key).mkdir()
            self.output = self.run / "native_evidence"
            self.output.mkdir(exist_ok=False)
            self.receipt["private_profile"] = str(self.profile)
            self.env = os.environ.copy()
            mode_keys = {"LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR", "WORLD_SHADOW_ENABLED"}
            for key in list(self.env):
                if key.startswith(("LSH_", "ART_", "DAMING_ADMIT_")) or key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key in mode_keys: self.env.pop(key)
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]: self.env[key] = str(self.profile / key.lower())
            self.env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1",
                            DAMING_ADMIT_PROFILE=str(self.profile), DAMING_ADMIT_OUT=str(self.output),
                            DAMING_ADMIT_EXPECT_CONTENT=self.installed["content_version"],
                            DAMING_ADMIT_EXPECT_ENGINE=self.receipt["godot_sha256"])
            step.update(inputs=5041, baseline_inputs=5039, cache_files=len(copied_cache), qa_additions=additions,
                        content_version=self.installed["content_version"])

    def stop_owned(self):
        if self.child is not None and self.child.poll() is None:
            self.child.terminate()
            try: self.child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                # Only the exact Popen-owned child, never names/PIDs discovered via CIM.
                self.child.kill(); self.child.wait(timeout=15)

    def native_phase(self, label, arguments, env, timeout_seconds, validator):
        with self.stage(label) as step:
            log = Path(step["step_dir"]) / "native.log"
            step.update(command=[str(self.args.godot), "--path", str(self.project), *arguments],
                        profile=str(self.profile), process_nonce=env.get("DAMING_ADMIT_NONCE", ""),
                        stop_reason=None, exit_code=None, process_terminal=False)
            try:
                self.input_integrity(True); self.acquire(); self.input_integrity(True)
                self.limit()
                require(not engine_rows(), "foreign engine entered before child launch")
                print("RUN", label, self.run, flush=True)
                with log.open("xb") as stream:
                    self.child = subprocess.Popen(step["command"], cwd=self.project, env=env,
                                                  stdout=stream, stderr=subprocess.STDOUT,
                                                  creationflags=subprocess.CREATE_NO_WINDOW)
                    step.update(pid=self.child.pid, native_started_ns=time.monotonic_ns(),
                                native_started_utc=dt.datetime.now(dt.timezone.utc).isoformat())
                    started, last_notice = time.monotonic(), time.monotonic()
                    while self.child.poll() is None:
                        self.limit()
                        rows = engine_rows(self.child.pid)
                        if rows:
                            step.update(stop_reason="foreign_engine_resumed", foreign_engine_pids=rows)
                            raise BatchFailure("foreign_engine_resumed; entire batch/profile preserved, no retry")
                        if ENGINE_ERRORS.search(log.read_text(encoding="utf-8", errors="replace")):
                            step["stop_reason"] = "engine_or_script_error"
                            raise BatchFailure("native engineering error")
                        if time.monotonic() - started > timeout_seconds:
                            step["stop_reason"] = "own_stage_timeout"
                            raise BatchFailure("native own stage timeout")
                        if time.monotonic() - last_notice >= 25:
                            print("RUNNING", label, round(time.monotonic() - started), "s", flush=True)
                            last_notice = time.monotonic()
                        self.pause(0.5)
                    step.update(native_finished_ns=time.monotonic_ns(), exit_code=self.child.returncode,
                                process_terminal=self.child.poll() is not None)
                text = log.read_text(encoding="utf-8", errors="replace")
                require(not ENGINE_ERRORS.search(text), "native error in final log")
                validator(step, text)
                self.input_integrity(True)
            except BaseException as exc:
                if step["stop_reason"] is None:
                    step["stop_reason"] = "authorized_six_am_wrap_deadline" if "authorized_six_am" in str(exc) else "producer_or_validation_exception"
                raise
            finally:
                self.stop_owned()
                if self.child is not None:
                    step.update(pid=self.child.pid, exit_code=self.child.returncode,
                                process_terminal=self.child.poll() is not None,
                                native_finished_ns=step.get("native_finished_ns", time.monotonic_ns()))
                if log.exists(): step.update(log=str(log), log_sha256=sha(log), log_bytes=log.stat().st_size)
                self.child = None
                self.release()

    def evidence_path(self, report, path):
        if path.startswith("user://"):
            result = Path(report["actual_user_data_dir"]) / path.removeprefix("user://")
        else: result = Path(path)
        result = no_reparse(result.resolve())
        require(result.is_relative_to(self.run), "native evidence escaped owned batch")
        return result

    def verify_slot(self, report, handoff, generation):
        userdata = no_reparse(Path(report["actual_user_data_dir"]).resolve())
        require(userdata.is_relative_to((self.profile / "appdata").resolve()), "reported native userdata not isolated")
        path = userdata / "daming_admit_v24o/continue/v1/5088120/1" / f"record_{generation:010d}.json"
        require(path.is_file() and sha(path) == handoff["file_sha256"], "actual committed slot SHA missing/mismatched")
        envelope = read(path)
        require(envelope["magic"] == "LH_CLASSIC_CONTINUE_SLOT" and envelope["app"] == "5088120" and envelope["owner"] == "1" and int(envelope["revision"]) == generation, "disk envelope identity/revision mismatch")
        raw_payload = envelope["payload"].encode("utf-8")
        require(len(raw_payload) == int(envelope["payload_bytes"]) and hashlib.sha256(raw_payload).hexdigest() == envelope["payload_sha256"], "disk envelope payload hash invalid")
        require(json.loads(envelope["payload"]) == handoff["packet"], "handoff complete packet does not equal disk envelope payload")
        expected_prev = "0" * 64 if generation == 1 else self.reports[CASES[0]]["slot_sha256"]
        require(envelope["previous_sha256"] == expected_prev, "disk generation chain previous SHA mismatched")
        retained = self.run / "retained_slots"
        retained.mkdir(exist_ok=True)
        target = retained / f"generation_{generation}.json"
        if not target.exists(): self.copy_checked(path, target, handoff["file_sha256"])
        else: require(sha(target) == handoff["file_sha256"], "retained slot evidence drift")
        return {"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size,
                "retained_path": str(target), "generation": generation, "previous_sha256": envelope["previous_sha256"]}

    def validate_case(self, case, step, text):
        require(step["exit_code"] == 0 and step["process_terminal"] is True, "native case did not actually terminate successfully")
        path = self.output / case / "report.json"
        data = read(path)
        require(data.get("passed") is True and data.get("checks") and all(row.get("passed") is True for row in data["checks"]), "native case/report checks not fully passed")
        require(data["case"] == case and data["pid"] == step["pid"] and data["nonce"] == step["process_nonce"], "native PID/case/nonce mismatch")
        require(data["trusted"]["content_version"] == self.installed["content_version"] and data["trusted"]["engine_binary_sha256"] == self.receipt["godot_sha256"], "native actual content/engine differs from independently pinned inputs")
        require(data.get("teleports") == 0 and data.get("fixture_ticks") == 0 and data.get("progress_injections") == 0 and data.get("clock_acceleration") is False, "native fixture boundary violated")
        require(data.get("public_campaign_continue_qualified") is False and data.get("natural_victory_qualified") is False and data.get("reward_once_qualified") is False, "native scope overclaim")
        for row in data["evidence"]:
            target = self.evidence_path(data, row["path"])
            require(target.is_file() and sha(target) == row["sha256"], "native original evidence file changed/missing")
        labels = {row["label"] for row in data["checks"]}
        mandatory = {"producer pinned exact installed content and engine"}
        if case == CASES[0]:
            mandatory |= {"normal Battle launch already classifies actual Daming context", "native manual admission observed in partial-progress window", "HELD still contains actual incomplete admission", "complete Session save_held succeeds", "actual committed disk head matches receipt"}
            require(data["orders"] == 2, "A ordinary two-mover route not executed")
        else:
            mandatory |= {"correct preceding genuinely distinct process", "prior disk bytes and generation verified", "same frozen source and actual engine across processes", "actual Session prepare_restore succeeds", "actual Session commit_restore_async succeeds", "fresh full Core capture at real restored HELD", "complete whole-world envelope and field set exact", "whole-world schema/profile/context/content/engine envelope exact", "complete exact section keyset retained", "every non-payload mission wrapper field exact", "every non-payload root wrapper field exact", "full Root clock subfield schemas exact", "all complete non-root sections exact after independent install", "Mission complete wall age rebased within real prepare/capture intervals", "Root logical tick/cache phase and mount/HELD input clock contract exact", "all Root non-clock values/references/grids/economy exact", "every Session Campaign option installed exactly", "every Session setting installed exactly", "every installed profile flag exact after Session commit", "Session context and saved resume pause actually installed", "actual durable local lifecycle binding exact", "Steam-disabled Session active lease/context installed", "complete saved Visual root_node installed exactly at HELD"}
            require(data["orders"] == 0, "B/C driver issued gameplay orders")
        if case == CASES[1]: mandatory |= {"original natural native tick completes admission after resume", "admission event/report/control/marker effects occur exactly once", "Mission elapsed advances only by resumed fixed physics ticks", "complete Session save_held succeeds"}
        if case == CASES[2]: mandatory |= {"second generation independently read and no driver orders", "requested real uninterrupted ticks observed", "final running-world complete capture succeeds", "process C leaves generation-two disk slot intact"}
        hold_labels = ["A partial admission"] if case == CASES[0] else ["restored complete world", "B admitted resave" if case == CASES[1] else "C post-run final audit"]
        for hold_label in hold_labels:
            mandatory |= {hold_label + " actual barrier request", hold_label + " real healthy HELD", hold_label + " exact two owned one-shot barrier listeners"}
            for stage in ["before_connect", "after_wait"]:
                mandatory.add(hold_label + " " + stage + " both own barrier listeners cleared")
                for signal_name in ["capture_ready", "capture_rejected"]:
                    mandatory.add(hold_label + " " + stage + " " + signal_name + " only own listeners cleared")
        audits = [row["hold_connection_audit"] for row in data.get("observations", []) if "hold_connection_audit" in row]
        require(len(audits) == len(hold_labels) * 3, "actual hold connection lifecycle row count mismatch")
        require([(row.get("label"), row.get("stage")) for row in audits] == [(label, stage) for label in hold_labels for stage in ["before_connect", "installed", "after_wait"]], "actual hold connection lifecycle sequence mismatch")
        for audit in audits:
            require(set(audit.get("signals", {})) == {"capture_ready", "capture_rejected"}, "actual both barrier signal audit absent")
            if audit["stage"] == "installed":
                require(audit.get("ready_error") == 0 and audit.get("rejected_error") == 0, "actual barrier connect failed")
                targets = []
                for signal_name, method in [("capture_ready", "_on_held"), ("capture_rejected", "_on_rejected")]:
                    row = audit["signals"][signal_name]
                    require(row.get("own_count") == 1 and row.get("flags") == [4] and row.get("methods") == [method] and row.get("bound_counts") == [0] and row.get("unbound_counts") == [0], "actual exact one-shot callable/flags mismatch")
                    require(isinstance(row.get("targets"), list) and len(row["targets"]) == 1 and isinstance(row["targets"][0], int) and row["targets"][0] > 0, "actual callable target absent")
                    targets.append(row["targets"][0])
                require(targets[0] == targets[1], "barrier callbacks do not target same actual QA instance")
            else:
                for signal_name in ["capture_ready", "capture_rejected"]:
                    row = audit["signals"][signal_name]
                    require(row.get("own_after") == 0 and row.get("flags_after") == [] and row.get("other_before") == row.get("other_after") and row.get("other_unchanged") is True, "cleanup left own listener or changed another callback")
                    require(row.get("own_count") in [0, 1] and row.get("flags") == ([] if row["own_count"] == 0 else [4]), "unexpected stale own listener count/flags")
                    if audit["stage"] == "after_wait":
                        require(row["own_count"] == (0 if signal_name == "capture_ready" else 1), "actual success did not consume ready while retaining then clearing rejected one-shot")
        require(mandatory <= labels, "required original case coverage absent: " + str(sorted(mandatory - labels)))
        require("DAMING_ADMIT_V24O_COMPLETE " + case in text, "native terminal marker missing")
        handoff_name = "handoff_A.json" if case == CASES[0] else "handoff_B.json"
        handoff_path = Path(data["actual_user_data_dir"]) / "daming_admit_v24o" / handoff_name
        handoff = read(handoff_path)
        generation = 1 if case == CASES[0] else 2
        require(int(handoff["generation"]) == generation, "unexpected saved generation")
        if case != CASES[2]: require(handoff["pid"] == step["pid"] and handoff["nonce"] == step["process_nonce"] and handoff["mode"] == case, "saved handoff not from actual current native process")
        if case != CASES[0]:
            preceding = CASES[0] if case == CASES[1] else CASES[1]
            prior = self.reports[preceding]
            require(data["previous_pid"] == prior["pid"] and data["previous_nonce"] == prior["nonce"], "native preceding-process chain broken")
            require(step["pid"] not in [report["pid"] for report in self.reports.values()] and step["process_nonce"] not in [report["nonce"] for report in self.reports.values()], "native process/nonce reused")
            earlier_step = [row for row in self.receipt["steps"] if row["case"] == preceding][0]
            require(earlier_step["process_terminal"] and earlier_step["native_finished_ns"] <= step["native_started_ns"], "native processes overlap or predecessor terminal unverified")
        slot = self.verify_slot(data, handoff, generation)
        step.update(report=str(path), report_sha256=sha(path), checks=len(data["checks"]),
                    slot_sha256=slot["sha256"], slot=slot, actual_content_version=data["trusted"]["content_version"])
        self.reports[case] = {"pid": step["pid"], "nonce": step["process_nonce"], "report": str(path),
                              "report_sha256": sha(path), "checks": len(data["checks"]), "slot_sha256": slot["sha256"], "generation": generation}
        self.receipt["reports"][case] = self.reports[case]

    def execute(self):
        self.preflight(); self.wait_prior()
        with self.stage("wait_natural_engine_idle") as step:
            self.wait_idle(); step["foreign_engines_at_idle"] = engine_rows()
        self.prepare()
        import_env = self.env.copy()
        import_env.update(DAMING_ADMIT_CASE=CASES[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
        def imported(step, text): require(step["exit_code"] == 0 and step["process_terminal"], "complete native import did not exit zero")
        self.native_phase("import", ["--headless", "--editor", "--import", "--quit"], import_env, 900, imported)
        guard_env = self.env.copy()
        guard_env.update(DAMING_ADMIT_PROFILE=str(self.profile / "mismatch"), DAMING_ADMIT_CASE=CASES[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
        def guarded(step, text):
            require(step["exit_code"] == 2 and "PRIVATE_PROFILE_REQUIRED" in text and not (self.output / CASES[0]).exists(), "negative profile guard failed or wrote regular evidence")
            require(not list((self.profile / "appdata").rglob("handoff_A.json")), "negative guard wrote continuation handoff")
        self.native_phase("profile_guard", ["--headless", "res://tools/daming_admit_cross_process_v24s.tscn"], guard_env, 300, guarded)
        self.execute_regressions()
        for case in CASES:
            env = self.env.copy()
            env.update(DAMING_ADMIT_CASE=case, DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            self.native_phase(case, ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "1280x720", "--position", "30000,30000", "res://tools/daming_admit_cross_process_v24s.tscn"], env, 600,
                              lambda step, text, case=case: self.validate_case(case, step, text))
        with self.stage("final_source_native_and_slot_audit") as step:
            self.input_integrity(True)
            require(list(self.reports) == list(CASES), "A/B/C complete sequence missing")
            userdata = Path(read(self.output / CASES[2] / "report.json")["actual_user_data_dir"])
            profile_files = []
            for path in sorted((userdata / "daming_admit_v24o").rglob("*")):
                no_reparse(path)
                if path.is_file(): profile_files.append({"path": str(path), "bytes": path.stat().st_size, "sha256": sha(path)})
            dump_new(self.run / "isolated_slot_and_lifecycle_manifest.json", profile_files)
            step.update(independent_processes=3, isolated_profile_files=len(profile_files))
            self.receipt.update(complete=True, root_input_drift=0, private_input_drift=0,
                                source_native_drift=0, private_native_drift=0, independent_processes=3,
                                slot_and_lifecycle_manifest_sha256=sha(self.run / "isolated_slot_and_lifecycle_manifest.json"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt", "cached-native-world"]:
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--candidate-receipt", type=Path, help="Fixed four-path native ownership candidate receipt; default source-root QA receipt")
    parser.add_argument("--boundary-harness", type=Path, help="External pure JSON boundary GD; its same-name tscn is required")
    parser.add_argument("--boundary-manifest", type=Path, help="External exact source fixture manifest; required together with boundary harness")
    parser.add_argument("--deadline-utc", required=True)
    parser.add_argument("--prior-pid", type=int, help="Required only while the specified FX receipt is not terminal; exact live FX producer PID")
    args = parser.parse_args()
    if args.candidate_receipt is None:
        args.candidate_receipt = args.source_root / "qa/zhu_wounded_20261005/native_ownership_json_candidate_v24q.json"
    require((args.boundary_harness is None) == (args.boundary_manifest is None), "boundary harness and manifest must be supplied together")
    for field in ["candidate_receipt", "boundary_harness", "boundary_manifest"]:
        value = getattr(args, field)
        if value is not None:
            require(value.is_absolute(), "explicit absolute optional path required: " + field)
            no_reparse(value)
            setattr(args, field, value.resolve())
    args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
    require(args.deadline_utc.tzinfo is not None and args.deadline_utc <= AUTHORIZED_DEADLINE, "timezone-aware deadline may not extend the authorized 06:00 wrap")
    for field in ["source_root", "source_receipt", "cache_receipt", "godot", "work_root", "prior_receipt", "cached_native_world"]:
        value = getattr(args, field)
        require(value.is_absolute(), "explicit absolute path required: " + field)
        no_reparse(value)
        setattr(args, field, value.resolve())
    require(args.source_root.is_dir() and (args.source_root / "project.godot").is_file(), "source root not a Godot project")
    require(not args.work_root.is_relative_to(args.source_root) and args.work_root != args.source_root, "work root must be outside source checkout")
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("daming_admit_v24s_" + uuid.uuid4().hex[:8])
    run.mkdir(exist_ok=False)
    runner = Runner(args, run)
    code = 0
    try:
        runner.execute()
    except BaseException as exc:
        code = 1
        runner.receipt["complete"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        try: runner.stop_owned()
        except BaseException as exc:
            runner.receipt["complete"] = False
            runner.receipt["termination_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            code = 1
        try: runner.release()
        except BaseException as exc:
            runner.receipt["complete"] = False
            runner.receipt["lock_release_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            code = 1
        try:
            runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            runner.receipt["lock_released"] = False
            runner.receipt["lock_audit_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            code = 1
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"], "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
