"""PCK contracts use an isolated editor; release DLLs are checked in the real EXE.

Official export templates do not include the extended --script command.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def verify(run, windows, engine, env):
    report = {"complete":False,"steps":[],"modules":[],"verifier_sha256":sha(Path(__file__))}
    child = None
    try:
        host = run / "probe_host"
        host.mkdir()
        probe_engine = host / "Godot.exe"
        shutil.copyfile(engine, probe_engine)
        report["editor_sha256"] = sha(probe_engine)
        assert report["editor_sha256"] == sha(Path(engine))
        vendor = ROOT / "vendor/godotsteam"
        provenance = json.loads((vendor / "provenance.json").read_text(encoding="utf-8"))
        for row in provenance["files"]:
            if not row["path"].endswith(".dll"): continue
            source = vendor / row["path"]
            assert sha(source) == row["sha256"]
            shutil.copyfile(source, host / source.name)
        env = env.copy()
        env["STEAM_PACKAGE_REPORT"] = str(run / "package_report.json")
        exe = windows / "LiangshanHeroes.exe"
        for name, command in [
            ("package",[str(probe_engine),"--headless","--main-pack",str(exe),"--script",str(ROOT / "tools/steam_package_probe.gd")]),
            ("exe_smoke",[str(exe),"--headless","--max-fps","60","--quit-after","600"]),
        ]:
            print("RUN " + name,flush=True)
            started = time.time()
            with (run / (name + ".log")).open("wb") as output:
                child = subprocess.Popen(command,cwd=windows,env=env,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    if name == "exe_smoke":
                        # Inspect only this verifier's exact process, never another game.
                        query = "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)\n@(Get-Process -Id %d -ErrorAction Stop | ForEach-Object { $_.Modules } | Where-Object { $_.ModuleName -match 'godotsteam|steam_api64' } | Select-Object ModuleName,FileName) | ConvertTo-Json -Compress" % child.pid
                        for _ in range(15):
                            if child.poll() is not None: break
                            raw = subprocess.check_output(["powershell.exe","-NoProfile","-Command",query],text=True,encoding="utf-8",errors="replace",creationflags=subprocess.CREATE_NO_WINDOW).strip()
                            observed = json.loads(raw) if raw else []
                            if isinstance(observed,dict): observed = [observed]
                            if len(observed) == 2:
                                report["modules"] = observed
                                break
                            time.sleep(0.2)
                        expected = {"steam_api64.dll","libgodotsteam.windows.template_release.x86_64.dll"}
                        assert {m["ModuleName"] for m in report["modules"]} == expected, report["modules"]
                        report["release_pid"] = child.pid
                    code = child.wait(timeout=180)
                except BaseException:
                    child.kill(); child.wait(timeout=30); raise
            text = (run / (name + ".log")).read_text(encoding="utf-8",errors="replace")
            errors = [line for line in text.splitlines() if any(word in line for word in ["ERROR:","SCRIPT ERROR","Parse Error"])]
            step = {"name":name,"exit_code":code,"seconds":round(time.time()-started,2),"errors":errors}
            report["steps"].append(step)
            assert code == 0 and not errors, text[-4000:]
        package = json.loads((run / "package_report.json").read_text(encoding="utf-8"))
        assert package["passed"]
        for module in report["modules"]:
            path = Path(module["FileName"])
            assert path.resolve() == (windows / module["ModuleName"]).resolve()
            module["sha256"] = sha(path)
        report["checks"] = len(package["checks"])
        report["complete"] = True
        return report
    finally:
        if child is not None and child.poll() is None: child.kill(); child.wait(timeout=30)
        (run / "verification_report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
