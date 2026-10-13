$b = [System.IO.File]::ReadAllBytes("c:\Git\TangMega138KPro\sdcard2dvi\sdcard\antena.bmp")
$off = 54
Write-Output "first 6 bytes of pixel data (file order):"
for($i=0;$i -lt 6;$i++){ Write-Output ("  byte[" + ($off+$i) + "] = " + $b[$off+$i]) }
Write-Output "--- pixel0 (standard BMP = BGR): B G R ---"
Write-Output ("  B=" + $b[54] + " G=" + $b[55] + " R=" + $b[56])
Write-Output ("  pixel1: B=" + $b[57] + " G=" + $b[58] + " R=" + $b[59])
Write-Output "--- pixel0 (if RGB): R G B ---"
Write-Output ("  R=" + $b[54] + " G=" + $b[55] + " B=" + $b[56])
