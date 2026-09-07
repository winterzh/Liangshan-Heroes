# QA comparison only; ordinary alpha compositing and rectangular reference selection.
# Every input is hashed before and after. No original pixels are rewritten.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$qaRoot = Join-Path $PSScriptRoot 'preview'
$assetRoot = Join-Path $root 'assets/characters/song_jiang_direction4_20260906'
$allInputs = @((Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'source') -Filter '*.png' -File).FullName)
$allInputs += @((Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'references') -Filter '*.png' -File).FullName)
$allInputs += @('idle_se.png','idle_sw.png','idle_ne.png','idle_nw.png','walk_atlas.png','walk_sw.png','attack_nw.png') | ForEach-Object { Join-Path $assetRoot $_ }
$before=@{}
foreach($path in $allInputs){$before[$path]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
$font=[System.Drawing.Font]::new('Arial',14)
$smallFont=[System.Drawing.Font]::new('Arial',11)
$outputs=@()
try {
 foreach($theme in @('light','dark')){
  $bg=if($theme -eq 'light'){[System.Drawing.Color]::FromArgb(250,249,244)}else{[System.Drawing.Color]::FromArgb(23,32,39)}
  $ink=if($theme -eq 'light'){[System.Drawing.Brushes]::Black}else{[System.Drawing.Brushes]::White}
  foreach($kind in @('walk','impact')){
   $rows=if($kind -eq 'walk'){4}else{1}
   $canvas=[System.Drawing.Bitmap]::new(1520,(100+$rows*400),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
   $g=[System.Drawing.Graphics]::FromImage($canvas)
   try {
    $g.Clear($bg)
    $g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawString("Song Jiang $kind - A reference / V1 / V2 / V3 - $theme",$font,$ink,20,12)
    $g.DrawString('QA only: fit each source into 350 x 330; no runtime scale, feet anchoring or production approval.',$smallFont,$ink,20,40)
    for($row=0;$row -lt $rows;$row++){
     $direction=if($kind -eq 'walk'){@('se','sw','ne','nw')[$row]}else{'nw'}
     for($col=0;$col -lt 4;$col++){
      $rect=$null
      $caption=''
      if($col -eq 0){
       if($kind -eq 'impact'){$path=Join-Path $assetRoot 'attack_nw.png';$caption='NW current windup A (RIGHT hand)'}
       elseif($direction -eq 'sw'){$path=Join-Path $assetRoot 'walk_sw.png';$caption='SW production A (independent)'}
       else {
        $path=Join-Path $assetRoot 'walk_atlas.png'
        $r=switch($direction){'se'{@(0,0,700,560)} 'ne'{@(0,560,700,639)} 'nw'{@(700,560,612,639)}}
        $rect=[System.Drawing.Rectangle]::new($r[0],$r[1],$r[2],$r[3])
        $caption=$direction.ToUpper()+' production A (atlas region)'
       }
      }else{
       $name=if($kind -eq 'walk'){"song_jiang_walk_b_${direction}_v$col.png"}else{"song_jiang_impact_nw_v$col.png"}
       $path=Join-Path (Join-Path $PSScriptRoot 'source') $name
       $caption=$direction.ToUpper()+" $kind V$col"
      }
      $x=$col*380
      $y=80+$row*400
      if(Test-Path -LiteralPath $path){
       $src=[System.Drawing.Image]::FromFile($path)
       try {
        if($null -eq $rect){$rect=[System.Drawing.Rectangle]::new(0,0,$src.Width,$src.Height)}
        $scale=[Math]::Min(350.0/$rect.Width,330.0/$rect.Height)
        $width=[single]($rect.Width*$scale);$height=[single]($rect.Height*$scale)
        $dst=[System.Drawing.RectangleF]::new([single]($x+(380-$width)/2),[single]($y+330-$height),$width,$height)
        $sourceRect=[System.Drawing.RectangleF]::new($rect.X,$rect.Y,$rect.Width,$rect.Height)
        $g.DrawImage($src,$dst,$sourceRect,[System.Drawing.GraphicsUnit]::Pixel)
       }finally{$src.Dispose()}
      }else{$caption+=' - no generation'}
      $g.DrawString($caption,$smallFont,$ink,($x+12),($y+338))
     }
    }
    $out=Join-Path $qaRoot ("${kind}_all_versions_${theme}.png")
    if(Test-Path -LiteralPath $out){throw "Output exists: $out"}
    $canvas.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
    $outputs += $out
   }finally{$g.Dispose();$canvas.Dispose()}
  }
 }
}finally{$font.Dispose();$smallFont.Dispose()}
$checks=foreach($path in $allInputs){
 $after=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
 [pscustomobject]@{path=$path;sha256_before=$before[$path].ToLower();sha256_after=$after.ToLower();unchanged=($before[$path] -eq $after)}
}
if(@($checks | Where-Object {-not $_.unchanged}).Count){throw 'Source changed during QA rendering'}
[pscustomobject]@{qa_only=$true;inputs=$checks;all_input_bytes_unchanged=$true;outputs=$outputs;fixture='normal alpha composite, only rectangle selection and fit-to-cell; no asset edits'} | ConvertTo-Json -Depth 6
