"""Independent diagnostic of actual submitted Float32 triangles. A positive browser self-check is not mesh acceptance."""
from pathlib import Path
import hashlib,json,math,struct,subprocess,sys
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(sys.argv[1]).resolve()
assert not (E/'mesh_diagnostic.json').exists()
report=json.loads((E/'browser_report.json').read_text(encoding='utf-8'));trace=json.loads((E/'trace.json').read_text(encoding='utf-8'));fixture=json.loads((E/'fixture.json').read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
def project(p):return [p[0]-p[1],.5*(p[0]+p[1])-p[2]]
for row in fixture['provenance']:assert sha(R/row['path'])==row['sha256']
for row in fixture['sources']:assert sha(R/row['file'])==row['sha256']
legs=next(row for row in fixture['sources'] if row['kind']=='legs');image=Image.open(R/legs['file'])
minimum=1e9;bad=0;total=0;max_point=0;min_source_bottom_gap=1e9;max_source_bottom_gap=0
for row in trace:
    mesh=report['meshSources'][row['meshKey']];raw=row['submittedPositions'];points=list(zip(raw[::2],raw[1::2]));source=[[f32(p[0]/1254)*1254,f32(p[1]/1254)*1254] for p in mesh['sourceVertices']]
    sole=fixture['legLandmarks'][row['leg']][row['direction']][3];assert image.getpixel(tuple(sole))[3]>=64
    mapped=None
    for i in range(0,len(mesh['indices']),3):
        indices=mesh['indices'][i:i+3];a,b,c=[points[k] for k in indices];area=cross(a,b,c);minimum=min(minimum,area);bad+=area<=0;total+=1
        sa,sb,sc=[source[k] for k in indices];den=cross(sa,sb,sc);w=[cross(sole,sb,sc)/den,cross(sa,sole,sc)/den,cross(sa,sb,sole)/den]
        if min(w)>=-1e-7 and max(w)<=1+1e-7:mapped=[sum(w[k]*[a,b,c][k][j] for k in range(3)) for j in range(2)]
    assert mapped is not None
    actual=[(mapped[j]-row['origin'][j])/row['magnification']+row['cameraWorld'][j] for j in range(2)]
    expected=[v*fixture['params']['model_to_world_scale'] for v in project(row['sole'])]
    max_point=max(max_point,math.dist(actual,expected))
video=E/report['video']['file'];assert sha(video)==report['video']['sha256']
command=['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_type,codec_name,width,height,nb_read_frames','-of','json',str(video)]
media=json.loads(subprocess.check_output(command));assert len(media['streams'])==1 and media['streams'][0]['codec_type']=='video'
result={'scope':'Independent diagnostic of recorded WebGL mesh, not native/game/art acceptance. Negative triangles are rejected by this candidate topology check; this does not diagnose all physical cloth occlusion.',
    'trace_rows':len(trace),'submitted_triangles_checked':total,'nonpositive_triangles':bad,'minimum_signed_canvas_area':minimum,
    'maximum_sole_reference_mapping_error_world':max_point,'float32_uv_used':True,'video_decode':media,'media_command':command,
    'browser_self_check_passed':report['browserChecksPassed'],'topology_check_passed':bad==0,'mesh_accepted':False,'production_adopted':False,'source_hashes_match':True}
with (E/'mesh_diagnostic.json').open('x',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['video_decode','media_command']}))
