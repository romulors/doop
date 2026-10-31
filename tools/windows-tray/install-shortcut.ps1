# Creates the "Doop" desktop shortcut. wscript has no console, so nothing flashes on launch.
$repo = Split-Path (Split-Path $PSScriptRoot)
$link = (New-Object -ComObject WScript.Shell).CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Doop.lnk")
$link.TargetPath = "$env:WINDIR\System32\wscript.exe"
$link.Arguments = "`"$PSScriptRoot\doop.vbs`""
$link.IconLocation = "$repo\desktop\src-tauri\icons\icon.ico,0"
$link.WorkingDirectory = $PSScriptRoot
$link.Description = 'Iniciar o Doop'
$link.Save()
