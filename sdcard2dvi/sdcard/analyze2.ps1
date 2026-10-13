$b = [System.IO.File]::ReadAllBytes("c:\Git\TangMega138KPro\sdcard2dvi\sdcard\antena.bmp")
$off = 54; $w = 1280; $h = 720
$minR=255;$maxR=0;$minG=255;$maxG=0;$minB=255;$maxB=0
$dark=0; $darkX=@(); $darkY=@()
for($y=0;$y -lt $h;$y++){
  for($x=0;$x -lt $w;$x++){
    $p=$off+(($h-1-$y)*$w+$x)*3
    $bl=$b[$p];$g=$b[$p+1];$r=$b[$p+2]
    if($r -lt $minR){$minR=$r}; if($r -gt $maxR){$maxR=$r}
    if($g -lt $minG){$minG=$g}; if($g -gt $maxG){$maxG=$g}
    if($bl -lt $minB){$minB=$bl}; if($bl -gt $maxB){$maxB=$bl}
    $lum = 0.3*$r + 0.59*$g + 0.11*$bl
    if($lum -lt 60){ $dark++; if($darkX.Count -lt 2000){$darkX+=$x; $darkY+=$y} }
  }
}
Write-Output ("R range: $minR .. $maxR")
Write-Output ("G range: $minG .. $maxG")
Write-Output ("B range: $minB .. $maxB")
Write-Output ("dark pixels (lum<60): $dark")
if($darkX.Count -gt 0){
  $x0=($darkX | Measure-Object -Minimum).Minimum; $x1=($darkX | Measure-Object -Maximum).Maximum
  $y0=($darkY | Measure-Object -Minimum).Minimum; $y1=($darkY | Measure-Object -Maximum).Maximum
  Write-Output ("dark bbox: x=$x0..$x1  y=$y0..$y1  (w=" + ($x1-$x0+1) + " h=" + ($y1-$y0+1) + ")")
}
# unique colors (quantized to 32 levels/channel)
$uniq = @{}
for($i=0;$i -lt $w*$h;$i++){
  $p=$off+$i*3; $bl=$b[$p];$g=$b[$p+1];$r=$b[$p+2]
  $key = ([int]($r/8)) * 1024 + ([int]($g/8)) * 32 + ([int]($bl/8))
  $uniq[$key] = $true
}
Write-Output ("unique colors (quantized): " + $uniq.Count)
