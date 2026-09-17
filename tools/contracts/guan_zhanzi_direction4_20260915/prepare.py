"""Reproduce metadata and copy original imagegen PNG bytes; never paint/re-encode."""
from pathlib import Path
import json, hashlib, shutil, math, re
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CONTRACT = Path(__file__).resolve().parent
NATIVE = Path.home()/'.codex/generated_images/01a09ddf-abdc-75a2-b03d-7117d813ff8b'
PROD = ROOT/'assets/characters/guan_zhanzi_direction4_20260915'
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    PROD.mkdir(parents=True,exist_ok=True)
    jobs=[]
    for name in ['jobs.json','jobs_extra.json']:
        jobs += json.loads((CONTRACT/name).read_text(encoding='utf-8'))
    lineage={'schema':'native_direction4_generation_lineage_v1','character':'guan_zhanzi',
             'original_reference':{'path':'assets/anim/guan_zhanzi_idle_se.png','sha256':sha(ROOT/'assets/anim/guan_zhanzi_idle_se.png')},'jobs':[]}
    ref=ROOT/'assets/anim/guan_zhanzi_idle_sw.png'
    lineage['jobs'].append({'key':'original_sw','repository_path':ref.relative_to(ROOT).as_posix(),'sha256':sha(ref),'method':'existing_project_reference','prompt':'Existing accepted southwest identity and costume reference.','references':['original']})
    sources={}
    template=(ROOT/'assets/characters/sun_li_direction4_20260913/se.png.import').read_text(encoding='utf-8')
    for j in jobs:
        dst=PROD/(j['selected']+'.png') if j['selected'] else CONTRACT/'generated'/(j['key']+'.png')
        dst.parent.mkdir(exist_ok=True)
        if not dst.exists(): shutil.copyfile(NATIVE/j['file'],dst)
        assert sha(dst)==sha(NATIVE/j['file']),j['key']
        im=Image.open(dst)
        lineage['jobs'].append({'key':j['key'],'repository_path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst),'method':'built_in_imagegen','prompt':j['prompt'],'references':j['references'],'native_size':list(im.size),'mode':im.mode,'status':'selected_partial_atlas' if j['selected'] else 'rejected_or_intermediate'})
        if not j['selected']: continue
        assert im.mode=='RGBA',dst
        path=dst.relative_to(ROOT).as_posix()
        limit=768 if im.size==(1024,1536) else max(im.size)
        factor=min(1,limit/max(im.size))
        size=[round(x*factor) for x in im.size]
        sources[j['selected']]={'path':path,'sha256':sha(dst),'job':j['key'],'mode':im.mode,'native_size':list(im.size),'import_limit':limit,'imported_size':size,'imported_size_verified':False,'full_atlas':True,'alpha_zero_fraction':im.getchannel('A').histogram()[0]/(im.width*im.height)}
        # Stable Godot base32 UID and cache path, without borrowing another asset UID.
        number=int(hashlib.sha256(path.encode()).hexdigest()[:15],16)
        uid=''
        alphabet='abcdefghijklmnopqrstuvwxyz012345'
        while number: uid=alphabet[number%32]+uid;number//=32
        cache='res://.godot/imported/'+dst.name+'-'+hashlib.md5(('res://'+path).encode()).hexdigest()+'.ctex'
        meta=re.sub(r'uid="[^"]+"','uid="uid://'+uid+'"',template)
        meta=re.sub(r'res://\.godot/imported/[^"\]]+',cache,meta)
        meta=meta.replace('res://assets/characters/sun_li_direction4_20260913/se.png','res://'+path)
        meta=meta.replace('process/size_limit=768','process/size_limit='+str(limit))
        descriptor=Path(str(dst)+'.import')
        if descriptor.exists():
            existing=re.search(r'uid="[^"]+"',descriptor.read_text(encoding='utf-8'))
            if existing: meta=re.sub(r'uid="[^"]+"',existing.group(0),meta)
        descriptor.write_text(meta,encoding='utf-8',newline='\n')

    # Authored sampling areas contain whole sprites. Entire rejected cell groups
    # remain explicitly accounted for; no alpha pixels are cleared to split them.
    regions={
      'se':[(0,0,570,420),(570,0,454,408),(0,420,580,390),None,(0,810,590,390),None,(0,1200,520,336),(520,1200,504,336)],
      'sw':[(0,0,500,408),(500,0,524,408),(0,408,510,400),(510,408,514,400),(0,808,500,392),(500,808,524,392),(0,1200,510,336),(510,1200,514,336)],
      'ne':[(0,0,560,382),(560,0,464,382),(0,382,580,414),(580,382,444,414),(0,796,590,404),(590,796,434,404),None,None],
      'nw':[(0,0,520,385),(520,0,504,385),(0,385,540,420),(540,385,484,420),(0,805,535,395),(535,805,489,395),(0,1200,510,336),(510,1200,514,336)],
      'supplement':[(0,0,550,540),(550,0,474,540),(0,540,530,540),(530,540,494,540),(0,1080,525,456),(525,1080,499,456)]}
    pivots={
      'se':[(292,392),(731,378),None,None,(286,1130),None,(278,1419),(763,1406)],
      'sw':[None,(720,380),(303,758),(745,771),(306,1121),(726,1121),(277,1430),(748,1380)],
      'ne':[(257,351),(725,345),None,(741,751),(300,1115),(768,1118),None,None],
      'nw':[(302,352),(744,342),None,(751,779),(331,1120),(785,1136),(283,1415),None],
      'supplement':[(275,487),(719,476),(266,1009),(778,997),(281,1343),(779,1343)]}
    names=['idle','walk_a','walk_b','windup','strike','hurt','fall','down']
    replace={('se','walk_b'):('supplement',0),('sw','idle'):('supplement',3),('ne','walk_b'):('supplement',1),('nw','walk_b'):('supplement',2),('ne','down'):('supplement',4),('nw','down'):('supplement',5)}
    singles={('se','windup'):('se_windup',1536,[670,1090]),('se','hurt'):('se_hurt',1536,[676,1090]),('ne','fall'):('ne_fall',1536,[650,835])}
    used=set();poses={}
    for direction in ['se','sw','ne','nw']:
        for idx,name in enumerate(names):
            skey,index=replace.get((direction,name),(direction,idx))
            if (direction,name) in singles:
                skey,virtual,pivot=singles[direction,name]
                im=Image.open(ROOT/sources[skey]['path'])
                region=(0,0,im.width,im.height)
            else:
                region=regions[skey][index];pivot=pivots[skey][index]
                virtual=640 if skey=='supplement' else 512
                used.add((skey,index))
            assert region is not None and pivot is not None,(direction,name)
            src=sources[skey];sx=src['imported_size'][0]/src['native_size'][0];sy=src['imported_size'][1]/src['native_size'][1]
            # Tight rectangle within the authored cell, including weak alpha.
            im=Image.open(ROOT/src['path']);x,y,w,h=region
            bb=im.getchannel('A').crop((x,y,x+w,y+h)).getbbox(); assert bb
            x0=max(x,x+bb[0]-2);y0=max(y,y+bb[1]-2);x1=min(x+w,x+bb[2]+2);y1=min(y+h,y+bb[3]+2)
            r=[math.floor(x0*sx),math.floor(y0*sy),math.ceil(x1*sx)-math.floor(x0*sx),math.ceil(y1*sy)-math.floor(y0*sy)]
            vs=max(round(virtual*sx),r[2],r[3]);left=(vs-r[2])/2;top=(vs-r[3])/2
            anchor=[(pivot[0]*sx-r[0])+left,(pivot[1]*sy-r[1])+top]
            poses[name+'_'+direction]={'source':skey,'region_raw':[x0,y0,x1-x0,y1-y0],'pivot':pivot,'virtual_size_native':virtual,'region':r,'virtual_size_imported':vs,'margin':[left,top,vs-r[2],vs-r[3]],'draw_offset_px':[vs*.5-anchor[0],vs*.82-anchor[1]],'draw_scale':1.1}
    for skey,areas in regions.items():
        unused=[]
        for idx,reg in enumerate(areas):
            if reg is not None and (skey,idx) not in used: unused.append({'region':list(reg),'reason':'Rejected facing, repeated stride, or replaced by independent pose.'})
        if skey=='se': unused.append({'region':[590,408,434,792],'reason':'Windup boot and hurt head overlapped between rows; both replaced with independent PNGs.'})
        if skey=='ne': unused.append({'region':[0,1200,1024,336],'reason':'Crowded falling frame and incorrect front-facing terminal pose; replaced with independent sources.'})
        sources[skey]['unused_regions']=unused
    states={'idle':['idle'],'walk':['walk_a','walk_b','walk_a','walk_b'],'attack':['windup','windup','strike','strike','idle'],'hurt':['hurt'],'death':['hurt','fall','down','down']}
    manifest={'schema':'native_direction4_spriteframes_v1','character':'guan_zhanzi','sources':sources,'poses':poses,'states':states,'resources':[f'assets/anim/guan_zhanzi_{s}_{d}.tres' for d in ['se','sw','ne','nw'] for s in states]}
    (ROOT/'assets/direction4/guan_zhanzi_20260915.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (CONTRACT/'generation.json').write_text(json.dumps(lineage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Prepared',len(sources),'unmodified PNG sources and',len(poses),'poses.')

if __name__=='__main__': main()
