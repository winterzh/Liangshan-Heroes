"""Re-register unchanged Gongsun actor PNGs against the adopted contact-A grip.

Only 20 body poses / 8 SpriteFrames and their manifest may change. Cart and
native PNG bytes remain fixed. This is phase stability, not new painted grips.
"""
import argparse, copy, hashlib, importlib.util, json, math, sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MANIFEST = ROOT / "assets/direction4/level1_gongsun_sheng_layered_20261030.json"
sys.path.insert(0,str(ROOT / "tools"))
spec=importlib.util.spec_from_file_location("layered_metadata",ROOT / "qa/liu_tang_layered_20261030/build_resources.py")
metadata=importlib.util.module_from_spec(spec); spec.loader.exec_module(metadata)

def digest(data): return hashlib.sha256(data).hexdigest()
def center(points): return [sum(p[i] for p in points)/len(points) for i in range(2)]

def intended():
    base=json.loads((HERE / "baseline/manifest.json").read_text(encoding="utf8"))
    landmarks=json.loads((HERE / "landmarks.json").read_text(encoding="utf8"))
    result=copy.deepcopy(base); metrics=[]
    for direction in ["se","sw","ne","nw"]:
        reference=base["poses"]["push_contact_a_"+direction]
        ref=reference["virtual_canvas_reference"]
        grip=center(landmarks["poses"]["push_contact_a_"+direction]["native_grips"])
        target=[(grip[i]-reference["pivot_native"][i])/ref for i in range(2)]
        for state in ["push_idle","push_contact_a","push_passing_a","push_contact_b","push_passing_b"]:
            key=state+"_"+direction; pose=result["poses"][key]; old=base["poses"][key]; row=landmarks["poses"][key]
            source=result["sources"][pose["source"]]
            raw=(ROOT/source["path"]).read_bytes()
            assert digest(raw)==source["sha256"]==row["source_sha256"]
            assert row["source"]==pose["source"]
            image=Image.open(ROOT/source["path"])
            for point in row["native_grips"]: assert image.getpixel(tuple(point))[3]>=64,key
            grip=center(row["native_grips"])
            pivot=[grip[i]-target[i]*ref for i in range(2)]
            x,y,w,h=pose["region"]; dx,dy=pivot[0]-x,pivot[1]-y
            canvas=math.ceil(max(ref,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            alpha=np.asarray(image)[y:y+h,x:x+w,3]; ys,_=np.nonzero(alpha>=64)
            assert len(ys)>1000
            pose.update(virtual_canvas_reference=ref,pivot_native=pivot,
                margin=[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],
                draw_scale=canvas/ref,draw_offset_px=[0,0],
                visible_top=(canvas*.82-dy+int(ys.min()))/canvas,
                operations="Unchanged native PNG; constant per-direction contact-A body scale; native visible-grip centroid registration. Legs remain authored; no foot pinning, warp, bitmap edit or cart motion.")
            old_grip=[(grip[i]-old["pivot_native"][i])/old["virtual_canvas_reference"] for i in range(2)]
            metrics.append({"pose":key,"reference_native":ref,"old_grip_per_body_size":old_grip,"new_grip_per_body_size":target,
                "old_head_y_per_body_size":(y+int(ys.min())-old["pivot_native"][1])/old["virtual_canvas_reference"],
                "new_head_y_per_body_size":(y+int(ys.min())-pivot[1])/ref,
                "original_source_sha256":source["sha256"]})
    result["body_registration"]={"method":"Contact-A grip centroid and constant native scale per direction", "landmarks":"qa/gongsun_grip_registration_20261030/landmarks.json", "native_pixels_changed":False,"shaft_occlusion_acceptance":False}
    result["runtime_acceptance"]="See qa/gongsun_grip_registration_20261030/README.md; retains original native-source QA; exact runtime scope separately recorded"
    for direction in ["se","sw","ne","nw"]:
        assert result["poses"]["cart_only_"+direction]==base["poses"]["cart_only_"+direction]
    return result,metrics

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--write",action="store_true");args=parser.parse_args()
    result,metrics=intended(); outputs=metadata.outputs(result)
    original=json.loads((HERE/"baseline/manifest.json").read_text(encoding="utf8"))
    old_outputs=metadata.outputs(original)
    changed=[name for name,data in outputs.items() if data!=old_outputs[name]]
    assert len(changed)==8 and all("_parked_cart_" not in name for name in changed)
    encoded=(json.dumps(result,ensure_ascii=False,indent=2)+"\n").encode()
    if args.write:
        assert MANIFEST.read_bytes() in [(HERE/"baseline/manifest.json").read_bytes(),encoded]
        for name,data in outputs.items(): assert (ROOT/name).read_bytes() in [old_outputs[name],data],name
        for name in changed: (ROOT/name).write_bytes(outputs[name])
        MANIFEST.write_bytes(encoded)
    assert MANIFEST.read_bytes()==encoded
    for name,data in outputs.items(): assert (ROOT/name).read_bytes()==data,name
    (HERE/"registration_metrics.json").write_bytes((json.dumps(metrics,indent=2)+"\n").encode())
    print(json.dumps({"body_poses":20,"spriteframes_changed":len(changed),"native_pixels_changed":False,"runtime_tested":False}))

if __name__=="__main__":main()
