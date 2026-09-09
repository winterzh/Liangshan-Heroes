"""Verify exact package footage, final streams, source PNG identity and delivery metadata."""
import hashlib, json, pathlib, re, shutil, struct, subprocess, sys
HERE=pathlib.Path(__file__).resolve().parent
REPO=HERE.parents[2]
SHA="cf746f1a0864355df7f80cd4f18c6882088f4b7e"
PACK_SHA="f22a44e96b7a0f4b42f599b1d9177e53312bcb3cbd5a6c48484172b21369dc2d"
def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda:stream.read(1024*1024),b""): h.update(block)
    return h.hexdigest()
def meta(path):
    return {"path":path.relative_to(HERE).as_posix(),"size_bytes":path.stat().st_size,"sha256":digest(path)}
def probe(path):
    return json.loads(subprocess.check_output(["ffprobe","-v","error","-show_format","-show_streams","-of","json",str(path)]))
def write(name,data):
    (HERE/name).write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
sources=[]
for shot in ("zhu","naval","defense"):
    folder=HERE/"raw"/"verified"/shot
    clip=folder/(shot+".avi")
    receipt=json.loads((folder/"render_receipt.json").read_text(encoding="utf-8"))
    capture=json.loads((folder/(shot+"_capture_log.json")).read_text(encoding="utf-8"))
    log=(folder/"console.log").read_text(encoding="utf-8")
    errors=[line for line in log.splitlines() if re.search(r"(SCRIPT ERROR|^ERROR:|Parse Error|Failed loading resource)",line)]
    details=probe(clip)
    v=next(s for s in details["streams"] if s["codec_type"]=="video")
    assert receipt["returncode"]==0 and receipt["pack_sha256"]==PACK_SHA
    assert not errors, (shot,errors)
    assert (v["width"],v["height"],v["r_frame_rate"])==(1920,1080,"30/1")
    sources.append({**meta(clip),"shot":shot,"source_sha":SHA,"pack_sha256":PACK_SHA,"recording_date":"2026-09-09",
      "width":v["width"],"height":v["height"],"fps":v["r_frame_rate"],"frames":v.get("nb_frames"),
      "duration_seconds":details["format"].get("duration"),"render_exit_code":0,"render_errors":errors,
      "driver_sha256":receipt["driver_sha256"],"elapsed_seconds":receipt["elapsed_seconds"],
      "capture_log_sha256":digest(folder/(shot+"_capture_log.json")),"console_log_sha256":digest(folder/"console.log"),
      "commands":[r for r in capture["orders"] if r["action"] not in ("state","scene_start")],
      "scope":capture["scope"]})
write("source_capture_summary.json",{"schema":2,"recording_date":"2026-09-09","steam_build_id":25200149,
 "release_head":"1102a9b629142524061a1b1fc005407c8da5fc07","source_sha":SHA,"pack_sha256":PACK_SHA,
 "source_package":"../../../.godot/steam_latest_release_20260909/steamcmd/content/LiangshanHeroes.exe",
 "method":"Godot 4.6.3 Movie Maker with the verified published EXE mounted as main PCK, using its matching prepared editor host and DLLs; isolated APPDATA.",
 "scope":"Normal movement, paid training/building, skill learning/casting; defense uses the existing standard 30-wave AI-friendly option. Game speed 1, multiplier flags off. Camera/display controls only. Native game audio.",
 "reuse":"No September 7 gameplay or screenshot is used in this deliverable.",
 "excluded":"raw/zhu is an interrupted first attempt from a host missing Steam DLLs. It is retained for diagnosis and supplies no final frames or audio.",
 "sources":sources})
(HERE/"screenshots").mkdir(exist_ok=True)
choices=[
 ("01_campaign_army.png","zhu",40,"Song Jiang, Lin Chong and troops engaging a visible enemy near the northern mine.",True),
 ("02_naval_fleet.png","naval",5,"Liangshan fleet moving together near the waterside fort.",False),
 ("03_liangshan_base.png","defense",40,"Liangshan base, buildings and early standard-defense preparations.",False),
 ("04_camp_construction.png","zhu",10,"Normal worker house construction and camp economy.",False),
 ("05_naval_combat.png","naval",35,"Liangshan boats exchanging attacks with government boats.",True)]
shots=[]
for name,shot,second,description,combat in choices:
    src=HERE/"raw"/"verified"/shot/(shot+f"_{second:03d}.png")
    dst=HERE/"screenshots"/name
    shutil.copyfile(src,dst)
    w,h=struct.unpack(">II",dst.read_bytes()[16:24])
    assert (w,h)==(1920,1080) and digest(src)==digest(dst)
    shots.append({**meta(dst),"width":w,"height":h,"source":src.relative_to(HERE).as_posix(),
      "source_sha256":digest(src),"capture_second":second,"source_commit":SHA,"steam_build_id":25200149,
      "unchanged_viewport_png":True,"description":description,"combat_visible":combat,
      "visual_review":"PENDING: direct image inspection is separate from automated file identity checks."})
write("screenshot_qa.json",{"schema":2,"all_original_png_identity_passed":True,"scope":"No crop, color edit, caption, generated content or retouch. Descriptions and combat labels require manual frame review.","screenshots":shots})
if '--capture-only' in sys.argv:
    print('Three sources and five screenshot identities verified.')
    raise SystemExit(0)
output=HERE/"LiangshanHeroes-Gameplay-20260909.mp4"
p=probe(output)
write("ffprobe.json",p)
v=next(s for s in p["streams"] if s["codec_type"]=="video")
a=next(s for s in p["streams"] if s["codec_type"]=="audio")
assert (v["width"],v["height"],v["r_frame_rate"])==(1920,1080,"30/1")
assert v["codec_name"]=="h264" and a["codec_name"]=="aac"
assert v["pix_fmt"]=="yuv420p" and v["color_range"]=="tv" and v["color_space"]=="bt709"
assert abs(float(v["duration"])-45)<0.01 and int(v["nb_frames"])==1350
decode=subprocess.run(["ffmpeg","-hide_banner","-v","warning","-i",str(output),"-f","null","-"],capture_output=True,text=True)
(HERE/"decode.log").write_text(decode.stderr,encoding="utf-8")
assert decode.returncode==0 and "Error" not in decode.stderr
loud=subprocess.run(["ffmpeg","-hide_banner","-i",str(output),"-af","loudnorm=I=-18:TP=-1.5:LRA=9:print_format=json","-f","null","-"],capture_output=True,text=True)
(HERE/"audio_analysis.log").write_text(loud.stderr,encoding="utf-8")
loudness=json.loads(loud.stderr[loud.stderr.rfind("{"):loud.stderr.rfind("}")+1])
black=subprocess.run(["ffmpeg","-hide_banner","-i",str(output),"-vf","blackdetect=d=0.3:pix_th=0.10:pic_th=0.98","-an","-f","null","-"],capture_output=True,text=True)
black_lines=[s for s in black.stderr.splitlines() if "black_start:" in s]
(HERE/"black_analysis.log").write_text(black.stderr,encoding="utf-8")
sample_frames=[60,270,480,630,780,960,1140,1275,1320]
select="+".join(f"eq(n,{n})" for n in sample_frames)
subprocess.run(["ffmpeg","-hide_banner","-loglevel","warning","-y","-i",str(output),"-vf",
 "select='"+select+"',scale=480:270:flags=lanczos,tile=3x3","-frames:v","1","-update","1",str(HERE/"contact_sheet.jpg")],check=True)
title=REPO/"marketing"/"steam_store_20260909_female"/"promotional"/"promo_1920x1080.png"
qa={"schema":2,"passed":False,"automated_checks_passed":True,"visual_review_pending":True,**meta(output),
 "steam_build_id":25200149,"source_sha":SHA,"pack_sha256":PACK_SHA,"frame_count":int(v["nb_frames"]),
 "video_duration_seconds":float(v["duration"]),"container_duration_seconds":float(p["format"]["duration"]),
 "resolution":[v["width"],v["height"]],"frame_rate":v["r_frame_rate"],"video_codec":v["codec_name"],
 "video_profile":v["profile"],"pixel_format":v["pix_fmt"],"color_range":v["color_range"],"color_space":v["color_space"],"video_bitrate_bps":int(v["bit_rate"]),"audio_codec":a["codec_name"],
 "audio_channels":a["channels"],"audio_sample_rate":a["sample_rate"],"full_decode_exit_code":decode.returncode,
 "decode_log":decode.stderr,"loudness_measurement":loudness,"black_sequences_over_0_3_seconds":black_lines,
 "contact_sheet_times":[n/30 for n in sample_frames],
 "title_card":{"source":"../promotional/promo_1920x1080.png","sha256":digest(title),"duration_seconds":3,
 "scope":"Approved main-image-derived 16:9 promotional illustration, never presented as gameplay or a Steam screenshot."},
 "limits":"No human full-video playback/listening claim. No Steam upload/transcode/playback verification in this recording subtask."}
write("final_qa.json",qa)
print(json.dumps({"automated_checks_passed":True,"output":str(output),"sha256":digest(output),"sources":len(sources),"screenshots":len(shots)},ensure_ascii=False))
