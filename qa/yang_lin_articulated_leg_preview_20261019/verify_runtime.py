"""Independent numeric checks of recorded browser draw commands and actual media."""
from pathlib import Path
import hashlib,json,math,struct,subprocess,sys
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(sys.argv[1]).resolve()
assert not (E/'independent_verification.json').exists()
fixture=json.loads((E/'fixture.json').read_text(encoding='utf-8'));params=fixture['params']
trace=json.loads((E/'trace.json').read_text(encoding='utf-8'));report=json.loads((E/'browser_report.json').read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
assert report['completed'] and report['buildId']==fixture['buildId']
assert report['renderFrames']>=100 and report['simulatedSeconds']>=12.39 and report['discardedWallSeconds']==0
for row in fixture['provenance']:assert sha(R/row['path'])==row['sha256']
for row in fixture['sources']:assert sha(R/row['file'])==row['sha256']
mapping={'se':[1,0],'sw':[0,1],'ne':[0,-1],'nw':[-1,0]}
campaign=R/'scripts/campaign_art.gd';text=campaign.read_text(encoding='utf-8')
assert 'var screen := Vector2(delta.x - delta.y, (delta.x + delta.y) * 0.5)' in text
def project(point):return [point[0]-point[1],.5*(point[0]+point[1])-point[2]]
def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
def expected_distance(t):
    value=0;start=0
    for section in report['timeline']:
        end=min(t,section['end'])
        if end>start:value+=(end-start)*section['speed']*params['baseline_world_speed']
        start=section['end']
        if start>=t:break
    return value
boot_source=next(s for s in fixture['sources'] if s['kind']=='legs');boots=Image.open(R/boot_source['file'])
groups={};states=set();max_bone=0;max_point=0;max_camera=0;max_distance=0;max_ground=0;min_reach=1e9
minimum_det=1e9;minimum_area=1e9;draws=0;triangles=0;coverage={};maximum_rounding_bound=0
for row in trace:
    direction,leg=row['direction'],row['leg'];states.add(row['mode'])
    expected_region=next(v['region'] for v in boot_source['regions'] if v['direction']==direction and v['leg']==leg)
    assert row['sourceRegion']==expected_region
    point=fixture['bootPoints'][leg][direction]['sole'];assert boots.getpixel(tuple(round(v) for v in point))[3]>=64
    commands=row['drawCommands'];assert [c['kind'] for c in commands]==['shoe','calf','thigh']
    for command in commands:
        cm=command['canvasMatrix'];det=cm[0]*cm[3]-cm[1]*cm[2];assert det>0
        minimum_det=min(minimum_det,det);draws+=1
        x,y,w,h=command['sourceRegion'];assert w>0 and h>0
        corners=[[cm[0]*px+cm[2]*py+cm[4],cm[1]*px+cm[3]*py+cm[5]] for px,py in [(x,y),(x+w,y),(x,y+h),(x+w,y+h)]]
        for a,b,c in [(corners[0],corners[1],corners[2]),(corners[1],corners[3],corners[2])]:
            area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);assert area>0;minimum_area=min(minimum_area,area);triangles+=1
    hx,kn,an,_=fixture['legLandmarks'][leg][direction];x,y,w,h=expected_region
    assert [c['sourceRegion'] for c in commands]==[[x,an[1]-14,w,y+h-an[1]+14],[x,kn[1]-18,w,an[1]+14-kn[1]+18],[x,y,w,kn[1]+18-y]]
    coverage.setdefault((direction,leg),[]).append(row['t'])
    m=commands[0]['canvasMatrix'];pixel=[m[0]*point[0]+m[2]*point[1]+m[4],m[1]*point[0]+m[3]*point[1]+m[5]]
    # Actual Canvas getTransform() coefficients in this Edge execution are float32.
    # Verify that rounding explicitly; do not turn renderer quantization into exact ground-lock proof.
    v=params['model_to_world_scale']*row['magnification'];bs=params['boot_scale'];pa=project(row['ankle'])
    camera_source=[c/params['model_to_world_scale'] for c in row['cameraWorld']]
    ideal=[v*bs,0,0,v*bs,row['origin'][0]+v*(pa[0]-bs*an[0]-camera_source[0]),row['origin'][1]+v*(pa[1]-bs*an[1]-camera_source[1])]
    rounded=[struct.unpack('f',struct.pack('f',value))[0] for value in ideal]
    assert m==rounded
    errors=[abs(a-b) for a,b in zip(m,ideal)]
    bound=math.hypot(errors[0]*abs(point[0])+errors[2]*abs(point[1])+errors[4],errors[1]*abs(point[0])+errors[3]*abs(point[1])+errors[5])/row['magnification']
    maximum_rounding_bound=max(maximum_rounding_bound,bound)
    actual=[(pixel[i]-row['origin'][i])/row['magnification']+row['cameraWorld'][i] for i in range(2)]
    expected=[v*params['model_to_world_scale'] for v in project(row['sole'])]
    max_point=max(max_point,distance(actual,expected))
    f=mapping[direction];camera=project([f[0]*row['distanceWorld'],f[1]*row['distanceWorld'],0])
    max_camera=max(max_camera,distance(camera,row['cameraWorld']))
    max_distance=max(max_distance,abs(expected_distance(row['t'])-row['distanceWorld']))
    max_bone=max(max_bone,abs(distance(row['hip'],row['knee'])-params['thigh_length_3d']),abs(distance(row['knee'],row['ankle'])-params['shin_length_3d']))
    min_reach=min(min_reach,params['thigh_length_3d']+params['shin_length_3d']-distance(row['hip'],row['ankle']))
    if row['mode'] in ['stance','held']:
        max_ground=max(max_ground,abs(row['sole'][2])*params['model_to_world_scale'])
        groups.setdefault((direction,leg,row['id']),[]).append(actual)
max_drift=max((max(distance(p,points[0]) for p in points) for points in groups.values() if len(points)>1),default=0)
assert len(coverage)==8
for times in coverage.values():
    assert len(times)>=90 and max(b-a for a,b in zip(times,times[1:]))<.2 and times[0]<.2 and times[-1]>12.8
assert len(trace)>=720 and len(groups)>20 and {'stance','swing','held','settling'}<=states
assert max(max_bone,max_camera,max_distance,max_ground)<1e-6
assert max_point<maximum_rounding_bound+1e-8 and max_drift<2*maximum_rounding_bound+1e-8
assert min_reach>0
video=E/report['video']['file'];assert sha(video)==report['video']['sha256']
command=['ffprobe','-v','error','-count_frames','-show_entries','stream=index,codec_type,codec_name,width,height,nb_read_frames,avg_frame_rate:format=duration,size','-of','json',str(video)]
media=json.loads(subprocess.check_output(command))
streams=media['streams'];assert len(streams)==1 and streams[0]['codec_type']=='video' and streams[0]['codec_name']=='vp8'
assert [streams[0]['width'],streams[0]['height']]==[1600,520] and int(streams[0]['nb_read_frames'])>=100
packet_command=['ffprobe','-v','error','-select_streams','v:0','-show_entries','packet=pts_time','-of','json',str(video)]
packets=json.loads(subprocess.check_output(packet_command))['packets'];pts=[float(p['pts_time']) for p in packets if 'pts_time' in p]
duration=max(pts)-min(pts);assert 12<=duration<=14
for capture in report['captures']:
    assert sha(E/capture['file'])==capture['sha256']
    with Image.open(E/capture['file']) as im:assert im.size==(1600,520)
result={'scope':'Independent replay of actual Canvas section transforms/corner triangles, 3D joints and video. Affine section orientation only; this does not prove seam continuity, inter-part overlap, whole sole contact, terrain or native/game acceptance.',
    'trace_rows':len(trace),'recorded_section_draws':draws,'positive_corner_triangles':triangles,'minimum_determinant':minimum_det,'minimum_corner_signed_area':minimum_area,'ground_contact_groups':len(groups),'states_observed':sorted(states),
    'canvas_shoe_coefficients_float32_verified':True,'maximum_analytic_rounding_bound_world':maximum_rounding_bound,
    'max_source_bone_length_error':max_bone,'max_painted_reference_mapping_error_world':max_point,
    'max_ground_reference_drift_world':max_drift,'max_ground_height_world':max_ground,
    'max_camera_reference_error_world':max_camera,'max_motion_distance_error_world':max_distance,'minimum_reach_margin_source':min_reach,
    'direction_source':{'path':'scripts/campaign_art.gd','sha256':sha(campaign),'logical_deltas':mapping},
    'video_media':media,'video_timestamp_span_seconds':duration,'media_commands':[command,packet_command],
    'numeric_and_media_checks_passed':True,'source_alpha_accepted':False,'natural_gait_accepted':False,'native_accepted':False,'production_adopted':False}
with (E/'independent_verification.json').open('x',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['video_media','media_commands','direction_source']}))
