Add-Type -AssemblyName System.Drawing
# Office Craft logo: four rounded tiles (blue/green/orange/red), ONLYOFFICE-style.
$colors = @{
  tl = '#4a7dc9'  # blue  (Document)
  tr = '#2e9e5b'  # green (Spreadsheet)
  bl = '#e06c3a'  # orange(Presentation)
  br = '#d64a4a'  # red   (PDF)
}
function RoundRect($g,$rect,$rad,$brush){
  $p=New-Object System.Drawing.Drawing2D.GraphicsPath
  $d=$rad*2
  $p.AddArc($rect.X,$rect.Y,$d,$d,180,90)
  $p.AddArc($rect.Right-$d,$rect.Y,$d,$d,270,90)
  $p.AddArc($rect.Right-$d,$rect.Bottom-$d,$d,$d,0,90)
  $p.AddArc($rect.X,$rect.Bottom-$d,$d,$d,90,90)
  $p.CloseFigure()
  $g.FillPath($brush,$p)
  $p.Dispose()
}
function RenderPng([int]$S){
  $bmp=New-Object System.Drawing.Bitmap($S,$S,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $pad=[math]::Round($S*0.10)
  $gap=[math]::Max(1,[math]::Round($S*0.06))
  $rad=[math]::Max(1,[math]::Round($S*0.07))
  $area=$S-2*$pad
  $tile=[math]::Round(($area-$gap)/2)
  $x0=$pad; $y0=$pad; $x1=$pad+$tile+$gap; $y1=$pad+$tile+$gap
  $defs=@(
    @($x0,$y0,$colors.tl), @($x1,$y0,$colors.tr),
    @($x0,$y1,$colors.bl), @($x1,$y1,$colors.br)
  )
  foreach($d in $defs){
    $rect=New-Object System.Drawing.Rectangle([int]$d[0],[int]$d[1],[int]$tile,[int]$tile)
    $br=New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($d[2]))
    RoundRect $g $rect $rad $br
    $br.Dispose()
  }
  $g.Dispose()
  $ms=New-Object System.IO.MemoryStream
  $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  return ,$ms.ToArray()
}
$sizes=@(16,24,32,48,64,128,256)
$pngs=@{}
foreach($s in $sizes){ $pngs[$s]=RenderPng $s }
# assemble .ico (PNG-compressed entries, Vista+)
$out="C:\Users\iwin\CraftOffice\OfficeCraft.ico"
$fs=New-Object System.IO.FileStream($out,[System.IO.FileMode]::Create)
$bw=New-Object System.IO.BinaryWriter($fs)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)  # ICONDIR
$offset=6 + 16*$sizes.Count
foreach($s in $sizes){
  $data=$pngs[$s]
  $wb=if($s -ge 256){0}else{$s}
  $bw.Write([byte]$wb); $bw.Write([byte]$wb)   # width,height
  $bw.Write([byte]0); $bw.Write([byte]0)        # colors, reserved
  $bw.Write([uint16]1); $bw.Write([uint16]32)   # planes, bpp
  $bw.Write([uint32]$data.Length)               # bytes in res
  $bw.Write([uint32]$offset)                     # offset
  $offset += $data.Length
}
foreach($s in $sizes){ $bw.Write($pngs[$s]) }
$bw.Flush(); $fs.Close()
# also save a 128px PNG for the Home page logo
$png128="C:\Users\iwin\CraftOffice\OfficeCraft_logo.png"
[System.IO.File]::WriteAllBytes($png128,$pngs[128])
"wrote $out ($((Get-Item $out).Length) bytes) and $png128"