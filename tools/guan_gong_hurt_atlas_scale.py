"""Create guan_gong hurt production atlas from retained native web PNG."""
from __future__ import annotations
import hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/art_full_20260916/guan_gong_hurt_direction4_source.png'
OUTPUT=ROOT/'assets/characters/art_full_20260916/guan_gong_hurt_direction4.png'
SOURCE_SHA256='3aa55a3bfe741c8e867820a7e5883ebd8bac913e642a972e8781fa3303dd6f0d'
NATIVE_SIZE=(1254,1254); TARGET_SIZE=(2508,2508)
def main()->int:
 actual=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
 if actual!=SOURCE_SHA256: raise SystemExit(f'source SHA mismatch: {actual}')
 image=Image.open(SOURCE).convert('RGBA')
 if image.size!=NATIVE_SIZE: raise SystemExit(f'unexpected native size: {image.size}')
 output=image.resize(TARGET_SIZE,Image.Resampling.LANCZOS)
 OUTPUT.parent.mkdir(parents=True,exist_ok=True)
 output.save(OUTPUT,format='PNG',optimize=False)
 print({'source':str(SOURCE),'output':str(OUTPUT),'source_sha256':actual,'output_sha256':hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),'native_size':image.size,'production_size':output.size,'alpha_extrema':output.getchannel('A').getextrema()})
 return 0
if __name__=='__main__': raise SystemExit(main())
