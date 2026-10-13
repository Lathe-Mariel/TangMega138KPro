$b = [System.IO.File]::ReadAllBytes("c:\Git\TangMega138KPro\sdcard2dvi\sdcard\antena.bmp")
$off = 54; $w = 1280; $h = 720
function region($x0,$y0,$x1,$y1) {
  $r=0;$g=0;$bl=0;$n=0
  for($y=$y0;$y -lt $y1;$y++) {
    for($x=$x0;$x -lt $x1;$x++) {
      $p=$off+(($h-1-$y)*$w+$x)*3
      $bl+=$b[$p];$g+=$b[$p+1];$r+=$b[$p+2];$n++
    }
  }
  return ("R=" + [math]::Round($r/$n) + " G=" + [math]::Round($g/$n) + " B=" + [math]::Round($bl/$n))
}
Write-Output ("top-left:     " + (region 0 0 400 200))
Write-Output ("top-right:    " + (region 880 0 1280 200))
Write-Output ("center:       " + (region 440 260 840 460))
Write-Output ("bottom-left:  " + (region 0 520 400 720))
Write-Output ("bottom-right: " + (region 880 520 1280 720))
$nR=0;$nG=0;$nB=0
for($i=0;$i -lt $w*$h;$i++) {
  $p=$off+$i*3; $bl=$b[$p];$g=$b[$p+1];$r=$b[$p+2]
  if($r -gt $g -and $r -gt $bl){$nR++}
  elseif($g -gt $r -and $g -gt $bl){$nG++}
  elseif($bl -gt $r -and $bl -gt $g){$nB++}
}
Write-Output ("dominant: R=" + $nR + " G=" + $nG + " B=" + $nB + " (total=" + ($w*$h) + ")")
