/* Browser-only painted-part preview. No production Unit or gameplay code is modified. */
(async function () {
  'use strict';
  const P=DATA.params, canvas=document.getElementById('stage'), ctx=canvas.getContext('2d');
  const dirs=['se','sw','ne','nw'], forward={se:[1,0,0],sw:[0,1,0],ne:[0,-1,0],nw:[-1,0,0]};
  const add=(a,b)=>a.map((v,i)=>v+b[i]), sub=(a,b)=>a.map((v,i)=>v-b[i]);
  const mul=(a,s)=>a.map(v=>v*s), dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
  const norm=a=>Math.hypot(...a), lerp=(a,b,t)=>add(mul(a,1-t),mul(b,t));
  const smooth=t=>t*t*(3-2*t), arch=t=>16*t*t*(1-t)*(1-t);
  const project=a=>[a[0]-a[1],.5*(a[0]+a[1])-a[2]];
  const copy=a=>a.slice(), ground=m=>m==='stance'||m==='held';
  const C=P.world_distance_per_cycle/P.model_to_world_scale, amp=C*P.stance_fraction/2;
  const images={}, sourceMap=Object.fromEntries(DATA.sources.map(s=>[s.kind,s]));
  let hashesOK=true;
  for (const source of DATA.sources) {
    if (window.crypto?.subtle) {
      const bytes=Uint8Array.from(atob(source.image.split(',')[1]),c=>c.charCodeAt(0));
      const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(v=>v.toString(16).padStart(2,'0')).join('');
      hashesOK=hashesOK&&hash===source.sha256;
    } else hashesOK=false;
    const image=new Image(); image.src=source.image; await image.decode();
    if(image.naturalWidth!==1254||image.naturalHeight!==1254)throw new Error('原图尺寸不符');
    images[source.kind]=image;
  }
  await document.fonts.ready;
  class Walker {
    constructor(direction) {
      this.direction=direction; this.F=forward[direction]; this.R=[-this.F[1],this.F[0],0];
      this.distance=0; this.hipZ=P.model_hip_height; this.wasMoving=true; this.serial=2;
      this.feet=['right','left'].map((leg,i)=>({leg,offset:i*.5,mode:'stance',id:i,
        position:this.contact(0,i*.5,i===0?1:-1),anchor:this.contact(0,i*.5,i===0?1:-1)}));
    }
    root(){return mul(this.F,this.distance/P.model_to_world_scale);}
    contact(cycle,offset,side) {return add(mul(this.F,(cycle-offset)*C+amp),mul(this.R,side*20));}
    beginSwing(foot,total,early=false) {
      const u=total-Math.floor(total), cycle=Math.floor(total), side=foot.leg==='right'?1:-1;
      foot.mode='swing';foot.start=copy(foot.position);foot.startTotal=total;
      foot.endTotal=early?total+.16:Math.max(cycle+1,total+.18);
      foot.target=this.contact(early?cycle:cycle+1,foot.offset,side);
    }
    restTarget(foot) {
      const side=foot.leg==='right'?1:-1;
      return add(add(this.root(),mul(this.R,side*20)),mul(this.F,side*8));
    }
    beginRecovery(foot) {
      foot.mode='settling';foot.start=copy(foot.position);foot.timer=0;
      foot.target=this.restTarget(foot);
    }
    advance(dt,speed,stats) {
      const moving=speed>1e-9;
      this.distance+=speed*dt;
      const cycles=this.distance/P.world_distance_per_cycle;
      if(!moving) {
        if(this.wasMoving) {
          // A planted foot stays planted while the airborne foot finishes its recovery.
          for(const foot of this.feet) {
            if(foot.position[2]>1e-6)this.beginRecovery(foot);
            else {foot.mode='held';foot.anchor=copy(foot.position);}
          }
        }
        if(!this.feet.some(f=>f.mode==='settling')) {
          const candidates=this.feet.filter(f=>norm(sub(f.position,this.restTarget(f)))>1e-6)
            .sort((a,b)=>norm(sub(b.position,this.restTarget(b)))-norm(sub(a.position,this.restTarget(a))));
          if(candidates.length)this.beginRecovery(candidates[0]);
        }
      }
      for(const foot of this.feet) {
        const old=copy(foot.position), oldId=foot.id, oldMode=foot.mode;
        const total=cycles+foot.offset, u=total-Math.floor(total), side=foot.leg==='right'?1:-1;
        if(moving&&!this.wasMoving) {
          if(u<P.stance_fraction&&foot.position[2]<1e-6) {
            foot.mode='stance';foot.anchor=copy(foot.position);
          } else this.beginSwing(foot,total,u<P.stance_fraction);
        }
        if(moving) {
          if(foot.mode==='stance'&&u>=P.stance_fraction)this.beginSwing(foot,total);
          if(foot.mode==='swing') {
            const t=Math.max(0,Math.min(1,(total-foot.startTotal)/(foot.endTotal-foot.startTotal)));
            foot.position=lerp(foot.start,foot.target,smooth(t));
            foot.position[2]=foot.start[2]*(1-smooth(t))+P.swing_height*arch(t);
            if(t>=1) {foot.position=copy(foot.target);foot.anchor=copy(foot.target);foot.mode='stance';foot.id=this.serial++;}
          } else if(foot.mode==='stance')foot.position=copy(foot.anchor);
        } else if(foot.mode==='settling') {
          foot.timer+=dt;const t=Math.min(1,foot.timer/.30);
          foot.position=lerp(foot.start,foot.target,smooth(t));
          foot.position[2]=foot.start[2]*(1-smooth(t))+P.recovery_lift*arch(t);
          if(t>=1){foot.position=copy(foot.target);foot.anchor=copy(foot.target);foot.mode='held';foot.id=this.serial++;}
        } else if(ground(foot.mode))foot.position=copy(foot.anchor);
        if(ground(oldMode)&&ground(foot.mode)&&oldId===foot.id)
          stats.maxStanceDrift=Math.max(stats.maxStanceDrift,norm(sub(old,foot.position))*P.model_to_world_scale);
        if(ground(foot.mode))stats.maxGroundHeight=Math.max(stats.maxGroundHeight,Math.abs(foot.position[2])*P.model_to_world_scale);
      }
      let ceiling=P.model_hip_height;
      for(const foot of this.feet) {
        const side=foot.leg==='right'?1:-1, hipXY=add(this.root(),mul(this.R,side*17));
        const bp=DATA.bootPoints[foot.leg][this.direction],delta=mul(sub(bp.sole,bp.ankle),P.boot_scale),z=25;
        const ankle=add(foot.position,[-.5*delta[0]+z-delta[1],.5*delta[0]+z-delta[1],z]);
        const horizontal=Math.hypot(ankle[0]-hipXY[0],ankle[1]-hipXY[1]);
        const reach=P.thigh_length_3d+P.shin_length_3d-3;
        if(horizontal>=reach)throw new Error('步幅超过三维腿长');
        ceiling=Math.min(ceiling,ankle[2]+Math.sqrt(reach*reach-horizontal*horizontal));
      }
      const eased=this.hipZ+(ceiling-this.hipZ)*(1-Math.exp(-dt/.045));
      this.hipZ=Math.min(ceiling,eased);
      this.wasMoving=moving;
    }
    pose(stats) {
      const root=this.root(), center=add(root,[0,0,this.hipZ]), poses=[];
      for(const foot of this.feet) {
        const side=foot.leg==='right'?1:-1, hip=add(center,mul(this.R,side*17));
        const bp=DATA.bootPoints[foot.leg][this.direction];
        const delta=mul(sub(bp.sole,bp.ankle),P.boot_scale), z=25;
        const ankleOffset=[-.5*delta[0]+z-delta[1],.5*delta[0]+z-delta[1],z];
        const ankle=add(foot.position,ankleOffset), v=sub(ankle,hip), distance=norm(v);
        if(!(distance>1e-6&&distance<P.thigh_length_3d+P.shin_length_3d))throw new Error('腿部目标超出三维骨长：'+distance);
        const axis=mul(v,1/distance), poleRaw=sub(this.F,mul(axis,dot(this.F,axis))), pole=mul(poleRaw,1/norm(poleRaw));
        const along=(P.thigh_length_3d**2-P.shin_length_3d**2+distance**2)/(2*distance);
        const height=Math.sqrt(P.thigh_length_3d**2-along**2), knee=add(add(hip,mul(axis,along)),mul(pole,height));
        stats.maxBoneError=Math.max(stats.maxBoneError,Math.abs(norm(sub(knee,hip))-P.thigh_length_3d),Math.abs(norm(sub(ankle,knee))-P.shin_length_3d));
        stats.minReachMargin=Math.min(stats.minReachMargin,P.thigh_length_3d+P.shin_length_3d-distance);
        poses.push({foot,hip,knee,ankle});
      }
      return {root,center,legs:poses};
    }
  }
  function sourceRegion(kind,direction,leg=null) {
    return sourceMap[kind].regions.find(r=>r.direction===direction&&r.leg===leg).region;
  }
  function segmentMatrix(s,e,a,b) {
    const sv=sub(e,s), tv=sub(b,a), sl=norm(sv), tl=norm(tv);
    if(tl<.01)throw new Error('投影骨段退化');
    const u=mul(sv,1/sl), n=[-u[1],u[0]], v=mul(tv,1/tl), m=[-v[1],v[0]], ax=tl/sl, w=P.part_width_scale;
    const aa=v[0]*ax*u[0]+m[0]*w*n[0], bb=v[1]*ax*u[0]+m[1]*w*n[0];
    const cc=v[0]*ax*u[1]+m[0]*w*n[1], dd=v[1]*ax*u[1]+m[1]*w*n[1];
    return [aa,bb,cc,dd,a[0]-aa*s[0]-cc*s[1],a[1]-bb*s[0]-dd*s[1]];
  }
  function affinePoint(m,p){return [m[0]*p[0]+m[2]*p[1]+m[4],m[1]*p[0]+m[3]*p[1]+m[5]];}
  function canvasMatrix(matrix,origin,camera,magnification) {
    const v=P.model_to_world_scale*magnification;
    return [v*matrix[0],v*matrix[1],v*matrix[2],v*matrix[3],origin[0]+v*(matrix[4]-camera[0]),origin[1]+v*(matrix[5]-camera[1])];
  }
  function drawPart(kind,region,matrix,origin,camera,magnification) {
    const m=canvasMatrix(matrix,origin,camera,magnification),[x,y,w,h]=region;
    ctx.save();ctx.setTransform(...m);ctx.drawImage(images[kind],x,y,w,h,x,y,w,h);ctx.restore();return m;
  }
  function drawActor(walker,pose,origin,mag,index,trace) {
    const direction=walker.direction,camera=project(pose.root), center=project(pose.center);
    const bodySource=DATA.torsoHip[direction],s=P.torso_scale;
    const torso=[s,0,0,s,center[0]-s*bodySource[0],center[1]-s*bodySource[1]], bodyRegion=sourceRegion('torso',direction);
    if(direction==='ne'||direction==='nw') {
      const [x,y,w,h]=bodyRegion;if(y+h>1150)drawPart('torso',[x,1150,w,y+h-1150],torso,origin,camera,mag);
    }
    const primitives=[];
    for(const leg of pose.legs) {
      const name=leg.foot.leg,hip=project(leg.hip),knee=project(leg.knee),ankle=project(leg.ankle);
      const tj=DATA.thighJoints[name][direction],sj=DATA.shinJoints[name][direction];
      primitives.push({kind:'thighs',region:sourceRegion('thighs',direction,name),matrix:segmentMatrix(tj[0],tj[1],hip,knee),depth:dot(leg.foot.position,[1,1,0]),layer:2});
      primitives.push({kind:'shins',region:sourceRegion('shins',direction,name),matrix:segmentMatrix(sj[0],sj[1],knee,ankle),depth:dot(leg.foot.position,[1,1,0]),layer:1});
      const bp=DATA.bootPoints[name][direction],bs=P.boot_scale;
      const matrix=[bs,0,0,bs,ankle[0]-bs*bp.ankle[0],ankle[1]-bs*bp.ankle[1]];
      primitives.push({kind:'boots',region:sourceRegion('boots',direction,name),matrix,depth:dot(leg.foot.position,[1,1,0]),layer:0,leg});
    }
    for(const primitive of primitives.sort((a,b)=>a.depth-b.depth||a.layer-b.layer)) {
      const matrix=drawPart(primitive.kind,primitive.region,primitive.matrix,origin,camera,mag);
      if(primitive.leg&&trace) {
        const leg=primitive.leg;
        trace.push({t:simTime,direction,leg:leg.foot.leg,mode:leg.foot.mode,id:leg.foot.id,sole:copy(leg.foot.position),root:copy(pose.root),restTarget:walker.restTarget(leg.foot),
                    hip:leg.hip,knee:leg.knee,ankle:leg.ankle,sourceRegion:primitive.region,canvasMatrix:matrix,origin:copy(origin),magnification:mag,
                    cameraWorld:mul(camera,P.model_to_world_scale),distanceWorld:walker.distance});
      }
    }
    let region=bodyRegion;if(direction==='ne'||direction==='nw')region=[region[0],region[1],region[2],Math.min(region[1]+region[3],1150)-region[1]];
    drawPart('torso',region,torso,origin,camera,mag);
    if(mag>1&&document.getElementById('points').checked)for(const leg of pose.legs) {
      const p=add(origin,mul(sub(project(leg.foot.position),camera),P.model_to_world_scale*mag));
      ctx.fillStyle=leg.foot.leg==='right'?'#e4bc55':'#6bc7d0';ctx.beginPath();ctx.arc(p[0],p[1],2.5,0,Math.PI*2);ctx.fill();
    }
    if(mag>1&&document.getElementById('bones').checked)for(const leg of pose.legs) {
      const points=[leg.hip,leg.knee,leg.ankle].map(p=>add(origin,mul(sub(project(p),camera),P.model_to_world_scale*mag)));
      ctx.strokeStyle=leg.foot.leg==='right'?'#e4bc55':'#6bc7d0';ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(...points[0]);ctx.lineTo(...points[1]);ctx.lineTo(...points[2]);ctx.stroke();
    }
  }
  function grid(walker,origin,mag,bounds) {
    const rootWorld=mul(walker.root(),P.model_to_world_scale),camera=project(rootWorld),cell=32;
    ctx.save();ctx.beginPath();ctx.rect(...bounds);ctx.clip();ctx.strokeStyle='#53634f';ctx.lineWidth=.65;ctx.globalAlpha=.55;
    for(let i=-8;i<=8;i++) {
      const x=(Math.floor(rootWorld[0]/cell)+i)*cell,y=(Math.floor(rootWorld[1]/cell)+i)*cell;
      for(const pair of [[[x,rootWorld[1]-280,0],[x,rootWorld[1]+280,0]],[[rootWorld[0]-280,y,0],[rootWorld[0]+280,y,0]]]) {
        const p=pair.map(v=>add(origin,mul(sub(project(v),camera),mag)));ctx.beginPath();ctx.moveTo(...p[0]);ctx.lineTo(...p[1]);ctx.stroke();
      }
    }
    ctx.restore();
  }
  const freshStats=()=>({maxStanceDrift:0,maxGroundHeight:0,maxBoneError:0,minReachMargin:1e9});
  let walkers=dirs.map(d=>new Walker(d)),stats=freshStats(),simTime=0,frameCount=0,walking=true,paused=false,qa=null,last=performance.now(),currentSpeed=P.baseline_world_speed;
  const timeline=[{end:2.7,speed:1,name:'normal'},{end:4.7,speed:.5,name:'half'},{end:5.7,speed:0,name:'stop_right_swing'},
    {end:7.7,speed:1,name:'resume'},{end:9.7,speed:1.5,name:'fast'},{end:10.7,speed:0,name:'stop_left_swing'},
    {end:12,speed:.5,name:'resume_half'},{end:13,speed:0,name:'final_settle'}];
  const captureAt=[{at:1.5,name:'normal'},{at:4.2,name:'half'},{at:5.5,name:'stopped_first'},
    {at:6.8,name:'resumed'},{at:8.9,name:'fast'},{at:10.5,name:'stopped_second'},{at:11.5,name:'resumed_half'},{at:12.95,name:'final_settled'}];
  function startQA() {
    walkers=dirs.map(d=>new Walker(d));stats=freshStats();simTime=0;frameCount=0;walking=true;paused=false;
    qa={running:true,startWall:performance.now(),trace:[],captures:[],discardedWallSeconds:0,sourceHashesMatch:hashesOK};
    if(window.MediaRecorder&&canvas.captureStream) {
      qa.videoChunks=[];qa.videoStream=canvas.captureStream(30);
      const type=MediaRecorder.isTypeSupported('video/webm;codecs=vp8')?'video/webm;codecs=vp8':'video/webm';
      qa.recorder=new MediaRecorder(qa.videoStream,{mimeType:type,videoBitsPerSecond:1500000});
      qa.recorder.ondataavailable=event=>{if(event.data.size)qa.videoChunks.push(event.data);};
      qa.recorder.start(500);
    }
    for(const id of ['walkToggle','pauseToggle','speed','test'])document.getElementById(id).disabled=true;
    document.getElementById('status').textContent='检查中：正常 → 半速 → 停止 → 恢复 → 加速 → 停止 → 恢复。';
  }
  function render() {
    ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#172019';ctx.fillRect(0,0,1600,520);
    ctx.font='17px Microsoft YaHei,sans-serif';ctx.fillStyle='#ded4b8';ctx.fillText(`平地位移预览   ${simTime.toFixed(2)}s   ${currentSpeed.toFixed(1)} 地图单位/s   细节6×`,20,27);
    const trace=qa?.running&&frameCount%4===0?qa.trace:null;
    for(let i=0;i<walkers.length;i++) {
      const walker=walkers[i],left=12+i*397,box=[left,47,385,453],origin=[left+192,420],pose=walker.pose(stats);
      ctx.fillStyle='#354238';ctx.fillRect(...box);grid(walker,origin,6,box);
      ctx.save();ctx.beginPath();ctx.rect(...box);ctx.clip();drawActor(walker,pose,origin,6,i,trace);ctx.restore();
      ctx.fillStyle='#e7dcbe';ctx.font='20px Microsoft YaHei,sans-serif';ctx.fillText(dirs[i].toUpperCase(),left+15,77);
      ctx.fillStyle='#c3ccbb';ctx.font='12px Microsoft YaHei,sans-serif';ctx.fillText('1×参考',left+315,75);
      drawActor(walker,pose,[left+337,134],1,i,null);
    }
  }
  function finishQA() {
    qa.running=false;walking=false;
    const elapsed=(performance.now()-qa.startWall)/1000;
    const allHeld=walkers.every(w=>w.feet.every(f=>f.mode==='held'&&Math.abs(f.position[2])<1e-8));
    const report={completed:true,buildId:DATA.buildId,driver:'setInterval(16ms), real wall clock, no virtual-time budget',scope:'Browser Canvas2D candidate only. Point locks/3D bones, not sole outline, native Unit, terrain or art acceptance.',
      sourceHashesMatch:qa.sourceHashesMatch,sourceImagesLoaded:Object.keys(images).length,renderFrames:frameCount,
      simulatedSeconds:simTime,wallSeconds:elapsed,discardedWallSeconds:qa.discardedWallSeconds,stats,
      finalFeetHeld:allHeld,finalRestPositions:walkers.map(w=>({direction:w.direction,root:w.root(),feet:w.feet.map(f=>({leg:f.leg,position:f.position,target:w.restTarget(f)}))})),timeline,trace:qa.trace,captures:qa.captures,
      browserChecksPassed:hashesOK&&frameCount>=100&&allHeld&&stats.maxStanceDrift<1e-6&&stats.maxGroundHeight<1e-6&&stats.maxBoneError<1e-6,
      strictSourceAlphaAccepted:false,nativeAccepted:false,productionAdopted:false};
    const deliver=()=>{
      document.getElementById('qa-evidence').textContent=JSON.stringify(report);
      if(new URLSearchParams(location.search).has('qa'))fetch('/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(report)}).catch(error=>{document.getElementById('status').textContent='本机结果保存失败：'+error.message;});
      document.getElementById('status').textContent='浏览器运行检查已完成。靴底单点/骨长结果可回读；透明边缘、自然步态和原生游戏验收仍未通过。';
      for(const id of ['walkToggle','pauseToggle','speed','test'])document.getElementById(id).disabled=false;
      document.getElementById('walkToggle').textContent='继续行走';window.dispatchEvent(new Event('qa-finished'));
    };
    if(qa.recorder) {
      const session=qa;
      document.getElementById('status').textContent='运行检查结束，正在保存本页画布录制……';
      session.recorder.onstop=()=>{
        const blob=new Blob(session.videoChunks,{type:session.recorder.mimeType}),reader=new FileReader();
        reader.onload=()=>{report.videoDataURL=reader.result;report.videoMimeType=blob.type;report.videoBytes=blob.size;
          const video=document.getElementById('recording');video.src=URL.createObjectURL(blob);video.hidden=false;
          session.videoStream.getTracks().forEach(track=>track.stop());deliver();};
        reader.readAsDataURL(blob);
      };
      session.recorder.stop();
    } else {report.videoUnavailable=true;deliver();}
  }
  function loop(now) {
    let dt=(now-last)/1000;last=now;if(dt<0)return;
    if(dt>.05){if(qa?.running)qa.discardedWallSeconds+=dt-.05;dt=.05;}
    if(paused)return;
    let remaining=dt;
    while(remaining>1e-8) {
      const section=qa?.running?timeline.find(s=>simTime<s.end-1e-8):null;
      if(qa?.running&&!section)break;
      let step=Math.min(remaining,1/120);if(section)step=Math.min(step,section.end-simTime);
      currentSpeed=section?section.speed*P.baseline_world_speed:(walking?Number(document.getElementById('speed').value)*P.baseline_world_speed:0);
      for(const walker of walkers){walker.advance(step,currentSpeed,stats);walker.pose(stats);}
      simTime+=step;remaining-=step;
    }
    frameCount++;render();
    if(qa?.running) {
      for(const capture of captureAt)if(simTime>=capture.at&&!qa.captures.some(c=>c.name===capture.name))
        qa.captures.push({name:capture.name,t:simTime,speed:currentSpeed,dataURL:canvas.toDataURL('image/png')});
      if(simTime>=13-1e-8)finishQA();
    }
    document.getElementById('speedValue').textContent=currentSpeed.toFixed(1);
    document.getElementById('phaseValue').textContent=(walkers[0].distance/P.world_distance_per_cycle%1).toFixed(3);
    document.getElementById('driftValue').textContent=stats.maxStanceDrift.toExponential(1);
    document.getElementById('framesValue').textContent=String(frameCount);
  }
  document.getElementById('walkToggle').onclick=()=>{walking=!walking;document.getElementById('walkToggle').textContent=walking?'停止行走':'继续行走';};
  document.getElementById('pauseToggle').onclick=()=>{paused=!paused;document.getElementById('pauseToggle').textContent=paused?'继续画面':'暂停画面';last=performance.now();};
  document.getElementById('test').onclick=startQA;
  document.getElementById('reference').textContent=JSON.stringify({baselineWorldSpeed:P.baseline_world_speed,
    currentLegacySilhouetteHeight:P.legacy_visible_height_reference,candidateWorldDistancePerCycle:P.world_distance_per_cycle,
    legacyWorldDistancePerCycleReference:P.legacy_world_distance_per_cycle_reference,
    displayScale:P.model_to_world_scale,projection:'x-y, .5*(x+y)-z',sourceScaleFixed:true,
    thighShin3D:[P.thigh_length_3d,P.shin_length_3d],sourceAlphaAccepted:false,nativeAccepted:false},null,2);
  document.getElementById('status').textContent='原图已读取。可停止/继续行走；原图透明边缘及原生验收仍待完成。';
  if(new URLSearchParams(location.search).has('qa'))startQA();
  last=performance.now();setInterval(()=>loop(performance.now()),16);
})().catch(error=>{document.getElementById('status').textContent='预览错误：'+error.message;
  document.getElementById('qa-evidence').textContent=JSON.stringify({completed:false,status:'error',error:error.stack||error.message});});
