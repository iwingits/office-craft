# Craft Office - tabbed host (v3). Browser-style dynamic tabs.
#  - New tools launch ONLY from the Home tab (create tiles).
#  - Each opened tool is its own closable, reorderable tab; multiple allowed.
#  - Tools embed hidden then show in place (no pop-out flash).
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr c, IntPtr p);
  [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x,int y,int w,int ht,bool r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
  public struct RECT { public int L,T,R,B; }
  public static IntPtr FindMain(uint t){ IntPtr b=IntPtr.Zero; long ba=0;
    EnumWindows((h,l)=>{ uint p; GetWindowThreadProcessId(h,out p); if(p!=t)return true;
      if(!IsWindowVisible(h))return true; if(GetParent(h)!=IntPtr.Zero)return true;
      StringBuilder cn=new StringBuilder(256); GetClassName(h,cn,256); string c=cn.ToString();
      if(c=="Winit Thread Event Target"||c=="IME"||c=="MSCTFIME UI")return true;
      RECT r; GetWindowRect(h,out r); long a=(long)(r.R-r.L)*(long)(r.B-r.T); if(a>ba){ba=a;b=h;} return true;
    },IntPtr.Zero); return b; }
  // Find the winit render window by class, even before it is shown (lets us reparent pre-flash).
  public static IntPtr FindReal(uint t){ IntPtr b=IntPtr.Zero; long ba=0;
    EnumWindows((h,l)=>{ uint p; GetWindowThreadProcessId(h,out p); if(p!=t)return true;
      if(GetParent(h)!=IntPtr.Zero)return true;
      StringBuilder cn=new StringBuilder(256); GetClassName(h,cn,256); string c=cn.ToString();
      if(c!="Window Class")return true;
      RECT r; GetWindowRect(h,out r); long a=(long)(r.R-r.L)*(long)(r.B-r.T); if(a>=ba){ba=a;b=h;} return true;
    },IntPtr.Zero); return b; }

  // --- WinEvent catch: get notified the instant the tool window is shown, hide it off-screen there ---
  public delegate void WinEventDelegate(IntPtr hHook, uint ev, IntPtr hwnd, int idObj, int idChild, uint th, uint t);
  [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint emin, uint emax, IntPtr hmod, WinEventDelegate cb, uint pid, uint tid, uint flags);
  [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr h);
  public static IntPtr Captured;
  static WinEventDelegate _cb; static IntPtr _hook;
  static void Proc(IntPtr hHook, uint ev, IntPtr hwnd, int idObj, int idChild, uint th, uint t){
    if(idObj != 0) return;                 // OBJID_WINDOW only
    if(Captured != IntPtr.Zero) return;
    if(GetParent(hwnd) != IntPtr.Zero) return;
    StringBuilder cn=new StringBuilder(256); GetClassName(hwnd,cn,256);
    if(cn.ToString() != "Window Class") return;
    ShowWindow(hwnd, 0);                    // SW_HIDE immediately
    MoveWindow(hwnd, -32000, -32000, 100, 100, false);
    Captured = hwnd;
  }
  public static void StartCatch(uint pid){ Captured=IntPtr.Zero; _cb=new WinEventDelegate(Proc);
    _hook=SetWinEventHook(0x8000, 0x8002, IntPtr.Zero, _cb, pid, 0, 0); } // CREATE..SHOW, OUT_OF_CONTEXT
  public static void StopCatch(){ if(_hook!=IntPtr.Zero){ UnhookWinEvent(_hook); _hook=IntPtr.Zero; } _cb=null; }
}
"@
[System.Windows.Forms.Application]::EnableVisualStyles()
# give the process its own taskbar identity so it shows our icon, not PowerShell's
try{ Add-Type -Namespace Native -Name Shell -MemberDefinition '[System.Runtime.InteropServices.DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID(string id);' -ErrorAction SilentlyContinue; [Native.Shell]::SetCurrentProcessExplicitAppUserModelID('OfficeCraft.App') | Out-Null }catch{}
try{ Add-Type -Namespace Native -Name Dwm -MemberDefinition '[System.Runtime.InteropServices.DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int val, int sz);' -ErrorAction SilentlyContinue }catch{}
$GWL=-16
$STRIP=(0x00C00000 -bor 0x00040000 -bor 0x00020000 -bor 0x00010000 -bor 0x00080000 -bor 0x00800000 -bor 0x00400000 -bor [int]0x80000000)
$WS_CHILD=0x40000000; $WS_VISIBLE=0x10000000; $SW_HIDE=0; $SW_SHOW=5

$script:catalog = @{
  WordCraft = 'C:\Users\iwin\wordcraft\wordcraft-0.7.0-windows-x64-portable\wordcraft.exe'
  GridCraft = 'C:\Users\iwin\gridcraft\gridcraft-0.7.0-windows-x64-portable\gridcraft.exe'
  DeckCraft = 'C:\Users\iwin\deckcraft\deckcraft-0.7.0-windows-x64-portable\deckcraft.exe'
  PdfCraft  = 'C:\Users\iwin\pdfcraft\pdfcraft-0.7.1-windows-x64-portable\pdfcraft.exe'
}
$script:colors = @{ WordCraft='#4a7dc9'; GridCraft='#2e9e5b'; DeckCraft='#e06c3a'; PdfCraft='#d64a4a' }
$script:tabs = New-Object System.Collections.ArrayList   # each: @{Id;Key;Title;Proc;Hwnd;Chip;Lbl}
$script:active = 'Home'      # 'Home' or a tab Id
$script:nextId = 1
$script:drag = $null
$script:recentPath = 'C:\Users\iwin\CraftOffice\recent.json'

function RouteKey($path){
  $ext = ([System.IO.Path]::GetExtension($path)).TrimStart('.').ToLower()
  if($ext -in @('docx','doc','rtf','odt','txt','md')){ return 'WordCraft' }
  if($ext -in @('xlsx','xls','csv','tsv','ods')){ return 'GridCraft' }
  if($ext -in @('pptx','ppt','odp')){ return 'DeckCraft' }
  if($ext -eq 'pdf'){ return 'PdfCraft' }
  return $null
}
function LoadRecents(){
  if(Test-Path $script:recentPath){ try{ return @((Get-Content $script:recentPath -Raw | ConvertFrom-Json)) }catch{ return @() } }
  return @()
}
function AddRecent($path){
  $r = @(LoadRecents | Where-Object { $_ -ne $path })
  $r = @($path) + $r
  if($r.Count -gt 12){ $r = $r[0..11] }
  ($r | ConvertTo-Json) | Set-Content $script:recentPath -Encoding UTF8
}

# ---- theming (ONLYOFFICE-style light / dark) ----
$script:settingsPath = 'C:\Users\iwin\CraftOffice\settings.json'
function LoadTheme(){ if(Test-Path $script:settingsPath){ try{ $s=Get-Content $script:settingsPath -Raw | ConvertFrom-Json; if($s.theme){ return [string]$s.theme } }catch{} } return 'light' }
function SaveTheme($t){ (@{theme=$t} | ConvertTo-Json) | Set-Content $script:settingsPath -Encoding UTF8 }
$script:theme = LoadTheme
function C($hex){ [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Pal(){
  if($script:theme -eq 'dark'){
    return @{ formBg='#1b1d22'; tabbar='#15171b'; surface='#23262d'; text='#e8e8ea'; subtle='#9aa0ac'; accent='#6b7be6'; tabInactive='#2a2e36'; tabActive='#23262d'; recent='#aab4ff'; border='#343842'; closeFg='#aaa' }
  }
  return @{ formBg='#eceef1'; tabbar='#cfd3da'; surface='#ffffff'; text='#2b2f36'; subtle='#8a909b'; accent='#5b6bd6'; tabInactive='#dde1e7'; tabActive='#ffffff'; recent='#3b45a8'; border='#e2e5e9'; closeFg='#777' }
}
$script:iconCache=@{}
function GetIcon($key){
  if($script:iconCache.ContainsKey($key)){ return $script:iconCache[$key] }
  $bmp=$null
  try{ $exe=$script:catalog[$key]; if($exe){ $ic=[System.Drawing.Icon]::ExtractAssociatedIcon($exe); $bmp=New-Object System.Drawing.Bitmap($ic.ToBitmap(),(New-Object System.Drawing.Size(18,18))) } }catch{}
  $script:iconCache[$key]=$bmp; return $bmp
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Office Craft"; $form.Size = New-Object System.Drawing.Size(1180,760)
$form.StartPosition = "CenterScreen"; $form.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#eceef1')
try { $form.Icon=New-Object System.Drawing.Icon('C:\Users\iwin\CraftOffice\OfficeCraft.ico') } catch {}

$tabbar = New-Object System.Windows.Forms.Panel
$tabbar.Dock='Top'; $tabbar.Height=40; $tabbar.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#cfd3da')
$form.Controls.Add($tabbar)

$content = New-Object System.Windows.Forms.Panel
$content.Dock='Fill'; $content.BackColor=[System.Drawing.Color]::White
$form.Controls.Add($content); $content.BringToFront()

# ---- Home page ----
$homePanel = New-Object System.Windows.Forms.Panel
$homePanel.Dock='Fill'; $homePanel.BackColor=[System.Drawing.Color]::White
$content.Controls.Add($homePanel)
$logo=New-Object System.Windows.Forms.PictureBox
$logo.Size=New-Object System.Drawing.Size(48,48); $logo.Location=New-Object System.Drawing.Point(40,30); $logo.SizeMode='Zoom'
try{ $logo.Image=[System.Drawing.Image]::FromFile('C:\Users\iwin\CraftOffice\OfficeCraft_logo.png') }catch{}
$homePanel.Controls.Add($logo)
$h1=New-Object System.Windows.Forms.Label
$h1.Text="Office Craft"; $h1.Font=New-Object System.Drawing.Font("Segoe UI",22,[System.Drawing.FontStyle]::Bold)
$h1.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#2b2f36'); $h1.AutoSize=$true; $h1.Location=New-Object System.Drawing.Point(100,38)
$homePanel.Controls.Add($h1)
$h2=New-Object System.Windows.Forms.Label
$h2.Text="Open a new tool - it opens as a tab. You can open several, close them, and drag to reorder."
$h2.Font=New-Object System.Drawing.Font("Segoe UI",11); $h2.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#8a909b')
$h2.AutoSize=$true; $h2.Location=New-Object System.Drawing.Point(42,82)
$homePanel.Controls.Add($h2)
$tileDefs=@(
  @{key='WordCraft';cap='Document'}, @{key='GridCraft';cap='Spreadsheet'},
  @{key='DeckCraft';cap='Presentation'}, @{key='PdfCraft';cap='PDF'}
)
$tx=42
foreach($td in $tileDefs){
  $tile=New-Object System.Windows.Forms.Button
  $tile.Text=$td.cap; $tile.Size=New-Object System.Drawing.Size(150,110)
  $tile.Location=New-Object System.Drawing.Point($tx,138)
  $tile.FlatStyle='Flat'; $tile.FlatAppearance.BorderSize=0
  $tile.BackColor=[System.Drawing.ColorTranslator]::FromHtml($script:colors[$td.key]); $tile.ForeColor=[System.Drawing.Color]::White
  $tile.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
  $tile.TextAlign='BottomCenter'; $tile.Cursor='Hand'; $tile.Tag=$td.key
  $tile.Add_Click({ NewTool $this.Tag })
  $homePanel.Controls.Add($tile); $tx+=166
}

# Open-a-local-file button
$openBtn=New-Object System.Windows.Forms.Button
$openBtn.Text="Open a local file..."
$openBtn.Font=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$openBtn.Size=New-Object System.Drawing.Size(220,40)
$openBtn.Location=New-Object System.Drawing.Point(42,272)
$openBtn.FlatStyle='Flat'; $openBtn.FlatAppearance.BorderSize=0
$openBtn.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#5b6bd6'); $openBtn.ForeColor=[System.Drawing.Color]::White
$openBtn.Cursor='Hand'
$openBtn.Add_Click({ OpenDialog })
$homePanel.Controls.Add($openBtn)
$aboutBtn=New-Object System.Windows.Forms.Button
$aboutBtn.Text=([char]0x2139) + "  About"
$aboutBtn.Font=New-Object System.Drawing.Font("Segoe UI",10)
$aboutBtn.Size=New-Object System.Drawing.Size(120,40); $aboutBtn.Location=New-Object System.Drawing.Point(276,272)
$aboutBtn.FlatStyle='Flat'; $aboutBtn.FlatAppearance.BorderSize=1; $aboutBtn.Cursor='Hand'
$aboutBtn.Add_Click({ Activate 'About' })
$homePanel.Controls.Add($aboutBtn)

# Recent files section
$rh=New-Object System.Windows.Forms.Label
$rh.Text="Recent files"; $rh.Font=New-Object System.Drawing.Font("Segoe UI",13,[System.Drawing.FontStyle]::Bold)
$rh.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#2b2f36'); $rh.AutoSize=$true; $rh.Location=New-Object System.Drawing.Point(42,330)
$homePanel.Controls.Add($rh)
$recentsBox=New-Object System.Windows.Forms.Panel
$recentsBox.Location=New-Object System.Drawing.Point(42,362)
$recentsBox.Size=New-Object System.Drawing.Size(900,330)
$recentsBox.Anchor=([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom)
$recentsBox.AutoScroll=$true
$homePanel.Controls.Add($recentsBox)

function OpenDialog(){
  $dlg=New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter="All supported|*.docx;*.doc;*.rtf;*.odt;*.txt;*.md;*.xlsx;*.xls;*.csv;*.tsv;*.ods;*.pptx;*.ppt;*.odp;*.pdf|Documents|*.docx;*.doc;*.rtf;*.odt;*.txt;*.md|Spreadsheets|*.xlsx;*.xls;*.csv;*.tsv;*.ods|Presentations|*.pptx;*.ppt;*.odp|PDF|*.pdf|All files|*.*"
  if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ OpenPath $dlg.FileName }
}
function OpenPath($path){
  if(-not (Test-Path $path)){ [System.Windows.Forms.MessageBox]::Show("File not found:`n$path")|Out-Null; return }
  $key=RouteKey $path
  if($key -eq $null){ [System.Windows.Forms.MessageBox]::Show("Unsupported file type.")|Out-Null; return }
  AddRecent $path
  NewTool $key $path
  RefreshRecents
}
function RefreshRecents(){
  $recentsBox.Controls.Clear()
  $items=@(LoadRecents)
  if($items.Count -eq 0){
    $none=New-Object System.Windows.Forms.Label
    $none.Text="No recent files yet. Use 'Open a local file' above, or create a new one."
    $none.Font=New-Object System.Drawing.Font("Segoe UI",10); $none.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#9aa0ac')
    $none.AutoSize=$true; $none.Location=New-Object System.Drawing.Point(2,4)
    $recentsBox.Controls.Add($none); return
  }
  $y=0
  foreach($p in $items){
    $row=New-Object System.Windows.Forms.Label
    $row.Text=([System.IO.Path]::GetFileName($p)) + "    -    " + $p
    $row.Font=New-Object System.Drawing.Font("Segoe UI",10)
    $row.ForeColor=C (Pal).recent
    $row.AutoSize=$false; $row.AutoEllipsis=$true; $row.Size=New-Object System.Drawing.Size(880,26)
    $row.Location=New-Object System.Drawing.Point(2,$y)
    $row.TextAlign='MiddleLeft'; $row.Cursor='Hand'; $row.Tag=$p
    $row.Add_MouseEnter({ $this.ForeColor=C (Pal).accent })
    $row.Add_MouseLeave({ $this.ForeColor=C (Pal).recent })
    $row.Add_Click({ OpenPath $this.Tag })
    $recentsBox.Controls.Add($row)
    $y+=28
  }
}

# ---- Settings view (ONLYOFFICE-style) ----
$settingsPanel=New-Object System.Windows.Forms.Panel
$settingsPanel.Dock='Fill'; $settingsPanel.Visible=$false
$content.Controls.Add($settingsPanel)
$setTitle=New-Object System.Windows.Forms.Label
$setTitle.Text="Settings"; $setTitle.Font=New-Object System.Drawing.Font("Segoe UI",22,[System.Drawing.FontStyle]::Bold)
$setTitle.AutoSize=$true; $setTitle.Location=New-Object System.Drawing.Point(40,34)
$settingsPanel.Controls.Add($setTitle)
$setAppear=New-Object System.Windows.Forms.Label
$setAppear.Text="Appearance"; $setAppear.Font=New-Object System.Drawing.Font("Segoe UI",13,[System.Drawing.FontStyle]::Bold)
$setAppear.AutoSize=$true; $setAppear.Location=New-Object System.Drawing.Point(42,98)
$settingsPanel.Controls.Add($setAppear)
$setThemeLbl=New-Object System.Windows.Forms.Label
$setThemeLbl.Text="Interface theme"; $setThemeLbl.Font=New-Object System.Drawing.Font("Segoe UI",11)
$setThemeLbl.AutoSize=$true; $setThemeLbl.Location=New-Object System.Drawing.Point(44,138)
$settingsPanel.Controls.Add($setThemeLbl)
$btnLight=New-Object System.Windows.Forms.Button
$btnLight.Text="Light"; $btnLight.Size=New-Object System.Drawing.Size(150,56); $btnLight.Location=New-Object System.Drawing.Point(44,170)
$btnLight.FlatStyle='Flat'; $btnLight.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold); $btnLight.Cursor='Hand'
$btnLight.Add_Click({ SetTheme 'light' })
$settingsPanel.Controls.Add($btnLight)
$btnDark=New-Object System.Windows.Forms.Button
$btnDark.Text="Dark"; $btnDark.Size=New-Object System.Drawing.Size(150,56); $btnDark.Location=New-Object System.Drawing.Point(206,170)
$btnDark.FlatStyle='Flat'; $btnDark.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold); $btnDark.Cursor='Hand'
$btnDark.Add_Click({ SetTheme 'dark' })
$settingsPanel.Controls.Add($btnDark)
$setNote=New-Object System.Windows.Forms.Label
$setNote.Text="Theme applies to the Office Craft home, tabs and settings. Each tool keeps its own look."
$setNote.Font=New-Object System.Drawing.Font("Segoe UI",9); $setNote.AutoSize=$true; $setNote.Location=New-Object System.Drawing.Point(44,246)
$settingsPanel.Controls.Add($setNote)

# ---- About view ----
$aboutPanel=New-Object System.Windows.Forms.Panel
$aboutPanel.Dock='Fill'; $aboutPanel.Visible=$false
$content.Controls.Add($aboutPanel)
$aboutLogo=New-Object System.Windows.Forms.PictureBox
$aboutLogo.Size=New-Object System.Drawing.Size(64,64); $aboutLogo.Location=New-Object System.Drawing.Point(40,34); $aboutLogo.SizeMode='Zoom'
try{ $aboutLogo.Image=[System.Drawing.Image]::FromFile('C:\Users\iwin\CraftOffice\OfficeCraft_logo.png') }catch{}
$aboutPanel.Controls.Add($aboutLogo)
$aboutTitle=New-Object System.Windows.Forms.Label
$aboutTitle.Text="Office Craft"; $aboutTitle.Font=New-Object System.Drawing.Font("Segoe UI",22,[System.Drawing.FontStyle]::Bold)
$aboutTitle.AutoSize=$true; $aboutTitle.Location=New-Object System.Drawing.Point(116,42)
$aboutPanel.Controls.Add($aboutTitle)
$aboutSub=New-Object System.Windows.Forms.Label
$aboutSub.Text="A tabbed desktop shell for the ArtCraft Craft apps."
$aboutSub.Font=New-Object System.Drawing.Font("Segoe UI",10); $aboutSub.AutoSize=$true; $aboutSub.Location=New-Object System.Drawing.Point(118,80)
$aboutPanel.Controls.Add($aboutSub)
$aboutBody=New-Object System.Windows.Forms.Label
$aboutBody.Text=@"
Office Craft is a lightweight launcher that puts WordCraft, GridCraft, DeckCraft and
PdfCraft into one tabbed window. It does not do any editing itself - every tool is a
separate application.

Credits & acknowledgement
All four editing tools are made by ArtCraft - open-source, clean-room reimplementations
of Microsoft Word / Excel / PowerPoint / Acrobat, written in pure Rust. Office Craft is
only a thin wrapper around them; all the real work is theirs. Sincere thanks to the
ArtCraft team (storytold) for building and sharing these apps.

ArtCraft:   https://getartcraft.com
Source:     https://github.com/storytold
Community:  https://discord.gg/artcraft
"@
$aboutBody.Font=New-Object System.Drawing.Font("Segoe UI",10); $aboutBody.AutoSize=$true; $aboutBody.Location=New-Object System.Drawing.Point(42,126)
$aboutPanel.Controls.Add($aboutBody)

function StyleThemeButtons(){
  $p=Pal
  foreach($pair in @(@('light',$btnLight),@('dark',$btnDark))){
    $b=$pair[1]
    if($script:theme -eq $pair[0]){ $b.BackColor=C $p.accent; $b.ForeColor=[System.Drawing.Color]::White; $b.FlatAppearance.BorderSize=0 }
    else { $b.BackColor=C $p.tabInactive; $b.ForeColor=C $p.text; $b.FlatAppearance.BorderSize=1; $b.FlatAppearance.BorderColor=C $p.border }
  }
}
function ApplyTheme(){
  $p=Pal
  $form.BackColor=C $p.formBg
  $tabbar.BackColor=C $p.tabbar
  $content.BackColor=C $p.surface
  $homePanel.BackColor=C $p.surface
  $h1.ForeColor=C $p.text; $h2.ForeColor=C $p.subtle; $rh.ForeColor=C $p.text
  $openBtn.BackColor=C $p.accent; $openBtn.ForeColor=[System.Drawing.Color]::White
  $recentsBox.BackColor=C $p.surface
  foreach($r in $recentsBox.Controls){ $r.ForeColor=C $p.recent }
  $settingsPanel.BackColor=C $p.surface
  $setTitle.ForeColor=C $p.text; $setAppear.ForeColor=C $p.text; $setThemeLbl.ForeColor=C $p.text; $setNote.ForeColor=C $p.subtle
  $aboutPanel.BackColor=C $p.surface
  $aboutTitle.ForeColor=C $p.text; $aboutSub.ForeColor=C $p.subtle; $aboutBody.ForeColor=C $p.text
  $aboutBtn.BackColor=C $p.surface; $aboutBtn.ForeColor=C $p.text; $aboutBtn.FlatAppearance.BorderColor=C $p.border
  StyleThemeButtons
  StyleChips
  # match the OS title bar to the theme (DWM immersive dark mode)
  try{
    $dark = [int]([bool]($script:theme -eq 'dark'))
    foreach($attr in 20,19){ [Native.Dwm]::DwmSetWindowAttribute($form.Handle,$attr,[ref]$dark,4) | Out-Null }
  }catch{}
}
function SetTheme($t){ $script:theme=$t; SaveTheme $t; ApplyTheme }

function Fill($hwnd){
  $cs=$content.ClientSize
  [Win]::MoveWindow($hwnd,0,0,[int]($cs.Width-1),[int]($cs.Height-1),$true)|Out-Null
  [Win]::MoveWindow($hwnd,0,0,[int]$cs.Width,[int]$cs.Height,$true)|Out-Null
}
function Attach($hwnd){
  $st=[Win]::GetWindowLong($hwnd,$GWL); $new=($st -band (-bnot $STRIP)) -bor $WS_CHILD -bor $WS_VISIBLE
  [Win]::SetWindowLong($hwnd,$GWL,$new)|Out-Null
  [Win]::SetParent($hwnd,$content.Handle)|Out-Null
}
function HideAll(){ foreach($t in $script:tabs){ if([Win]::IsWindow($t.Hwnd)){ [Win]::ShowWindow($t.Hwnd,$SW_HIDE)|Out-Null } } }
function GetTab($id){ foreach($t in $script:tabs){ if($t.Id -eq $id){ return $t } } return $null }

function NewTool($key, $file){
  if(-not $script:catalog.ContainsKey($key)){ return }
  $form.Cursor='WaitCursor'
  if($file){ $proc=Start-Process -FilePath $script:catalog[$key] -ArgumentList ('"{0}"' -f $file) -PassThru }
  else { $proc=Start-Process -FilePath $script:catalog[$key] -PassThru }
  # Install a WinEvent hook: the instant the tool window is shown, the callback hides it off-screen.
  [Win]::StartCatch([uint32]$proc.Id)
  $hwnd=[IntPtr]::Zero
  for($i=0;$i -lt 800;$i++){
    [System.Windows.Forms.Application]::DoEvents()   # pump so the hook callback runs ASAP
    if([Win]::Captured -ne [IntPtr]::Zero){ $hwnd=[Win]::Captured; break }
    if($proc.HasExited){ break }
    Start-Sleep -Milliseconds 3
  }
  [Win]::StopCatch()
  if($hwnd -eq [IntPtr]::Zero){
    # fallback finders
    for($i=0;$i -lt 60;$i++){ if($proc.HasExited){ break }; $hwnd=[Win]::FindReal([uint32]$proc.Id); if($hwnd -eq [IntPtr]::Zero){ $hwnd=[Win]::FindMain([uint32]$proc.Id) }; if($hwnd -ne [IntPtr]::Zero){ break }; Start-Sleep -Milliseconds 20 }
  }
  if($hwnd -eq [IntPtr]::Zero){
    $form.Cursor='Default'
    [System.Windows.Forms.MessageBox]::Show("Could not open $key.")|Out-Null
    try{ if(-not $proc.HasExited){ $proc.Kill() } }catch{}; return
  }
  # reparent hidden immediately; the Home panel still covers the area, so no visible pop-out
  [Win]::ShowWindow($hwnd,$SW_HIDE)|Out-Null
  Attach $hwnd
  [Win]::ShowWindow($hwnd,$SW_HIDE)|Out-Null
  if($file){ $title=[System.IO.Path]::GetFileName($file) }
  else { $n=1; foreach($t in $script:tabs){ if($t.Key -eq $key){ $n++ } }; $title = if($n -gt 1){ "$key $n" } else { $key } }
  $tab=@{ Id=("tab{0}" -f $script:nextId); Key=$key; Title=$title; Proc=$proc; Hwnd=$hwnd; Chip=$null; Lbl=$null }
  $script:nextId++
  [void]$script:tabs.Add($tab)
  BuildTabs
  $form.Cursor='Default'
  Activate $tab.Id
}

function CloseTab($id){
  $t=GetTab $id; if($t -eq $null){ return }
  try{ if(-not $t.Proc.HasExited){ $t.Proc.Kill() } }catch{}
  $idx=$script:tabs.IndexOf($t)
  $script:tabs.Remove($t)
  BuildTabs
  if($script:active -eq $id){
    if($script:tabs.Count -gt 0){ $ni=[Math]::Max(0,$idx-1); Activate $script:tabs[$ni].Id }
    else { Activate 'Home' }
  }
}

function Activate($target){
  $script:active=$target
  if($target -eq 'Home'){ HideAll; $settingsPanel.Visible=$false; $aboutPanel.Visible=$false; $homePanel.Visible=$true; $homePanel.BringToFront(); RefreshRecents }
  elseif($target -eq 'Settings'){ HideAll; $homePanel.Visible=$false; $aboutPanel.Visible=$false; $settingsPanel.Visible=$true; $settingsPanel.BringToFront() }
  elseif($target -eq 'About'){ HideAll; $homePanel.Visible=$false; $settingsPanel.Visible=$false; $aboutPanel.Visible=$true; $aboutPanel.BringToFront() }
  else {
    $t=GetTab $target
    if($t -ne $null -and [Win]::IsWindow($t.Hwnd)){
      $homePanel.Visible=$false; $settingsPanel.Visible=$false; $aboutPanel.Visible=$false; HideAll
      if([Win]::GetParent($t.Hwnd) -ne $content.Handle){ Attach $t.Hwnd }
      [Win]::ShowWindow($t.Hwnd,$SW_SHOW)|Out-Null; Fill $t.Hwnd; [Win]::SetFocus($t.Hwnd)|Out-Null
    }
  }
  StyleChips
}

# ---------- tab bar rendering ----------
function StyleChips(){
  $p=Pal
  $all=@()
  if($script:homeChip){ $all += ,@($script:homeChip, ($script:active -eq 'Home')) }
  foreach($t in $script:tabs){ if($t.Chip){ $all += ,@($t.Chip, ($script:active -eq $t.Id)) } }
  if($script:gearChip){ $all += ,@($script:gearChip, ($script:active -eq 'Settings')) }
  foreach($pair in $all){
    $chip=$pair[0]; $on=$pair[1]
    $bg = if($on){ C $p.tabActive } else { C $p.tabInactive }
    $fg = if($on){ C $p.text } else { C $p.subtle }
    $chip.BackColor=$bg
    foreach($c in $chip.Controls){ $c.BackColor=$bg; $c.ForeColor=$fg }
  }
}
function BuildTabs(){
  $tabbar.Controls.Clear()
  # Home chip (fixed, not closable)
  $hc=New-Object System.Windows.Forms.Panel
  $hc.Size=New-Object System.Drawing.Size(74,40); $hc.Location=New-Object System.Drawing.Point(0,0)
  $hl=New-Object System.Windows.Forms.Label
  $hl.Text=([char]0x2302 + " Home"); $hl.Dock='Fill'; $hl.TextAlign='MiddleCenter'; $hl.Cursor='Hand'
  $hl.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
  $hl.Add_Click({ Activate 'Home' })
  $hc.Controls.Add($hl); $tabbar.Controls.Add($hc); $script:homeChip=$hc
  $x=76
  foreach($t in $script:tabs){
    $chip=New-Object System.Windows.Forms.Panel
    $chip.Size=New-Object System.Drawing.Size(150,40); $chip.Location=New-Object System.Drawing.Point($x,0)
    $chip.Tag=$t.Id
    $pic=New-Object System.Windows.Forms.PictureBox
    $pic.Size=New-Object System.Drawing.Size(18,18); $pic.Location=New-Object System.Drawing.Point(9,11)
    $pic.SizeMode='Zoom'; $pic.Tag=$t.Id; $pic.Cursor='Hand'
    $ico=GetIcon $t.Key; if($ico){ $pic.Image=$ico }
    $pic.Add_Click({ Activate $this.Tag })
    $lbl=New-Object System.Windows.Forms.Label
    $lbl.Text=$t.Title; $lbl.AutoEllipsis=$true
    $lbl.Location=New-Object System.Drawing.Point(32,0); $lbl.Size=New-Object System.Drawing.Size(90,40)
    $lbl.TextAlign='MiddleLeft'; $lbl.Cursor='Hand'; $lbl.Tag=$t.Id
    $lbl.Font=New-Object System.Drawing.Font("Segoe UI",9)
    $lbl.Add_MouseDown({ $script:drag=@{ Id=$this.Tag; StartX=[System.Windows.Forms.Cursor]::Position.X; Moved=$false } })
    $lbl.Add_MouseMove({ if($script:drag -ne $null -and [System.Windows.Forms.Control]::MouseButtons -eq 'Left'){ if([Math]::Abs([System.Windows.Forms.Cursor]::Position.X - $script:drag.StartX) -gt 8){ $script:drag.Moved=$true } } })
    $lbl.Add_MouseUp({ EndDrag $this.Tag })
    $x2=New-Object System.Windows.Forms.Label
    $x2.Text=[char]0x00D7; $x2.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
    $x2.Location=New-Object System.Drawing.Point(124,0); $x2.Size=New-Object System.Drawing.Size(22,40)
    $x2.TextAlign='MiddleCenter'; $x2.Cursor='Hand'; $x2.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#777'); $x2.Tag=$t.Id
    $x2.Add_Click({ CloseTab $this.Tag })
    $chip.Controls.Add($x2); $chip.Controls.Add($lbl); $chip.Controls.Add($pic)
    $tabbar.Controls.Add($chip)
    $t.Chip=$chip; $t.Lbl=$lbl
    $x+=152
  }
  # Settings gear (right-aligned, persistent)
  $gc=New-Object System.Windows.Forms.Panel
  $gc.Size=New-Object System.Drawing.Size(92,40)
  $gc.Location=New-Object System.Drawing.Point(([int]$tabbar.ClientSize.Width-92),0)
  $gc.Anchor=([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
  $gl=New-Object System.Windows.Forms.Label
  $gl.Text=([char]0x2699) + " Settings"; $gl.Dock='Fill'; $gl.TextAlign='MiddleCenter'; $gl.Cursor='Hand'
  $gl.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
  $gl.Add_Click({ Activate 'Settings' })
  $gc.Controls.Add($gl); $tabbar.Controls.Add($gc); $script:gearChip=$gc
  StyleChips
}
function EndDrag($id){
  $d=$script:drag; $script:drag=$null
  if($d -eq $null){ Activate $id; return }
  if(-not $d.Moved){ Activate $id; return }
  # reorder: find target index by cursor X within tab bar
  $curX = $tabbar.PointToClient([System.Windows.Forms.Cursor]::Position).X
  $target = $script:tabs.Count - 1
  for($i=0;$i -lt $script:tabs.Count;$i++){ $cx = 76 + $i*152 + 75; if($curX -lt $cx){ $target=$i; break } }
  $t=GetTab $id; if($t -eq $null){ return }
  $cur=$script:tabs.IndexOf($t)
  if($target -ne $cur){ $script:tabs.Remove($t); if($target -gt $script:tabs.Count){ $target=$script:tabs.Count }; $script:tabs.Insert($target,$t) }
  BuildTabs; Activate $script:active
}

# re-assert + resize
$reassert=New-Object System.Windows.Forms.Timer
$reassert.Interval=800
$reassert.Add_Tick({
  $t=GetTab $script:active
  if($t -ne $null -and -not $t.Proc.HasExited -and [Win]::IsWindow($t.Hwnd)){
    if([Win]::GetParent($t.Hwnd) -ne $content.Handle){ Attach $t.Hwnd; [Win]::ShowWindow($t.Hwnd,$SW_SHOW)|Out-Null; Fill $t.Hwnd }
  }
})
$content.Add_SizeChanged({ $t=GetTab $script:active; if($t -ne $null -and [Win]::IsWindow($t.Hwnd)){ Fill $t.Hwnd } })
$form.Add_Shown({ BuildTabs; ApplyTheme; Activate 'Home'; $reassert.Start() })
$form.Add_FormClosing({
  $reassert.Stop()
  foreach($t in $script:tabs){ try{ if(-not $t.Proc.HasExited){ $t.Proc.Kill() } }catch{} }
})
[void]$form.ShowDialog()

