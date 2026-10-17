# Undo the Craft Office launcher + file associations.
# Run:  powershell -ExecutionPolicy Bypass -File "C:\Users\iwin\CraftOffice\Revert-CraftOffice.ps1"
$classes = 'HKCU:\Software\Classes'
$map = @{
  'CraftOffice.WordCraft' = '.docx'
  'CraftOffice.GridCraft' = '.xlsx'
  'CraftOffice.DeckCraft' = '.pptx'
  'CraftOffice.PdfCraft'  = '.pdf'
}
foreach ($progid in $map.Keys) {
  $ext = $map[$progid]
  Remove-Item -Path "$classes\$progid" -Recurse -Force -ErrorAction SilentlyContinue
  $owp = "$classes\$ext\OpenWithProgids"
  if (Test-Path $owp) { Remove-ItemProperty -Path $owp -Name $progid -Force -ErrorAction SilentlyContinue }
  Write-Output "Removed $progid ($ext)"
}
Remove-Item "$env:USERPROFILE\Desktop\Office Craft.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\Craft Office.lnk" -Force -ErrorAction SilentlyContinue
Write-Output "Removed Office Craft desktop shortcut."
Get-Process -Name wordcraft,gridcraft,deckcraft,pdfcraft -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Output "Stopped any running Craft apps."
Write-Output "Tabbed host files (CraftTabs.ps1/.vbs), CraftOffice.hta, recent.json, craft-mcp.json remain in C:\Users\iwin\CraftOffice until you delete the folder."
Write-Output "If you registered the Craft MCP servers, remove them with: claude mcp remove wordcraft; claude mcp remove gridcraft; claude mcp remove deckcraft; claude mcp remove pdfcraft"
Write-Output "Done. (Your ONLYOFFICE defaults were never changed.)"
Write-Output "To also delete the launcher files: Remove-Item 'C:\Users\iwin\CraftOffice' -Recurse -Force"
