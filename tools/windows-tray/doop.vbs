' wscript has no console, so PowerShell starts with a hidden one instead of flashing or leaving a window.
folder = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & folder & "\doop-tray.ps1""", 0, False
