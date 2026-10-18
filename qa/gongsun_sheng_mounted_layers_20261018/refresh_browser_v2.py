"""Build a seat-registered canvas preview from the same immutable layer bindings."""
from pathlib import Path
import hashlib,json,re,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018/browser')
old=Q/'layer_preview_v1.html'
if not old.exists():shutil.copyfile(Q/'layer_preview.html',old)
s=old.read_text();s=s.replace('<script>','<script src="layer_data.js"></script>\n<script>',1)
options=[('drawn_recoil','持剑受击'),('drawn_recover','持剑恢复'),('sheathed_idle','藏剑待机'),('reach','取剑起手'),('draw_mid','部分出鞘'),('point','指剑'),('sheathed_recoil','藏剑受击'),('sheathed_recover','藏剑恢复'),('original','原合图受击参考'),('horse','仅固定马身')]
s=re.sub(r'<select id="mode">.*?</select>','<select id="mode">'+''.join('<option value="'+key+'">'+label+'</option>' for key,label in options)+'</select>',s,count=1)
a=s.index('const sourceFiles=');b=s.index('const images=',a)
s=s[:a]+'''const layerData=window.GSLayers;
const sourceFiles={horse:layerData.textures.horse_no_reins_v2.file,rein:layerData.textures.rein_material_v1.file,original:layerData.textures.original_recoil.file};
for(const [state,key] of Object.entries(layerData.states))sourceFiles[state]=layerData.textures[key].file;
const calibration=structuredClone(layerData.views);
for(const c of Object.values(calibration))c.rider={scale:c.rider_scale,offset:[0,0]};
'''+s[b:]
a=s.index('function riderTransform(');b=s.index('function drawImage(',a)
s=s[:a]+'''function riderTransform(d,phase){const c=calibration[d],p=c.phases[phase],sc=c.rider.scale;return{scale:sc,offset:c.seat_waist_target.map((value,i)=>value-p.manual_seat_waist_source[i]*sc+c.rider.offset[i])};}
function ribbon(ctx,a,b,width,sag){const sample=layerData.rein.sample_region,n=layerData.rein.segments,control=[(a[0]+b[0])/2,(a[1]+b[1])/2+2*sag];let prev=a;for(let i=1;i<=n;i++){const t=i/n,u=1-t,p=[u*u*a[0]+2*u*t*control[0]+t*t*b[0],u*u*a[1]+2*u*t*control[1]+t*t*b[1]],dx=p[0]-prev[0],dy=p[1]-prev[1],length=Math.hypot(dx,dy);ctx.save();ctx.translate(prev[0],prev[1]);ctx.rotate(Math.atan2(dy,dx));ctx.drawImage(images.rein,sample[0],sample[1],sample[2],sample[3],-.3,-width/2,length+.6,width);ctx.restore();prev=p;}}
function paintReins(ctx,d,phase,pose){const c=calibration[d],i=dirs.indexOf(d),origin=[(i%2)*627,Math.floor(i/2)*627],hand=c.phases[phase].manual_visible_rein_hand,a=point(d,c.horse.bit_source,c.horse.scale,c.horse.offset).map((value,j)=>value-origin[j]),b=point(d,hand,pose.scale,pose.offset).map((value,j)=>value-origin[j]);ribbon(ctx,a,b,layerData.rein.width_native,layerData.rein.sag_native);ribbon(ctx,[a[0]+3,a[1]+2],[b[0]+2,b[1]+1],layerData.rein.width_native,layerData.rein.sag_native+3);}
'''+s[b:]
s=s.replace("if(mode==='original'||mode==='old_recovery')","if(mode==='original')")
s=s.replace('const pose=riderTransform(d,mode);drawImage(ctx,images[mode],d,pose.scale,pose.offset);','const pose=riderTransform(d,mode);paintReins(ctx,d,mode,pose);drawImage(ctx,images[mode],d,pose.scale,pose.offset);')
s=s.replace('c.horse.rein,c.horse.scale,c.horse.offset','c.horse.bit_source,c.horse.scale,c.horse.offset')
s=s.replace("'5 张原始 PNG 已载入 · '","Object.keys(sourceFiles).length+' 张原始 PNG 已载入 · '")
s=s.replace("s.value=s.value==='recover'?'recoil':'recover';","const family=s.value.startsWith('sheathed')?'sheathed':'drawn';s.value=s.value===family+'_recover'?family+'_recoil':family+'_recover';")
s=s.replace('比例对同方向两帧固定，偏移仅用于定位。原 PNG 未修改。','马身固定；骑手比例对同方向八状态固定，按鞍位定位；皮革缰绳纹理连接到手。原 PNG 未修改。')
(Q/'layer_preview.html').write_text(s,encoding='utf-8')
data=json.loads((Q/'layer_bindings_v2.json').read_text());rows=[]
for row in data['textures'].values():
    src=R/row['canonical_source'];dst=E/row['file'];assert hashlib.sha256(src.read_bytes()).hexdigest()==row['sha256']
    if dst.exists():assert dst.read_bytes()==src.read_bytes()
    else:shutil.copyfile(src,dst)
    rows.append(row)
shutil.copyfile(Q/'layer_preview.html',E/'index.html');shutil.copyfile(Q/'layer_data.js',E/'layer_data.js')
with (Q/'browser_inputs_v2.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'scope':'Own browser canvas only, three-layer seat registration. Not native/Unit or whole sequence acceptance.','project':str(E),'html_sha256':hashlib.sha256((Q/'layer_preview.html').read_bytes()).hexdigest(),'bindings_sha256':hashlib.sha256((Q/'layer_bindings_v2.json').read_bytes()).hexdigest(),'files':rows},ensure_ascii=False,indent=2)+'\n')
capture=(Q/'capture_browser_preview_v3.py').read_text().replace("['original','recoil','recover']",str(['original']+list(data['states'])))
with (Q/'capture_browser_preview_v4.py').open('x',encoding='utf-8') as f:f.write(capture)
print(json.dumps({'states':len(data['states']),'loaded_pngs':len(rows),'fixed_seat':True,'independent_painted_reins':True}))
