' Launches the Craft Office tabbed host with no console window.
Set s = CreateObject("WScript.Shell")
s.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Users\iwin\CraftOffice\CraftTabs.ps1""", 0, False
