# Doop tray icon: starts the dev servers, shows their status, opens and stops them.
# ASCII only: PowerShell 5.1
# reads BOM-less files as ANSI.
#   doop-tray.ps1                 start (or, if already running, just open the browser)
#   doop-tray.ps1 -Action stop    same as the menu's "Parar Doop e sair"
#   doop-tray.ps1 -Action restart same as the menu's "Reiniciar API"
param([ValidateSet('', 'stop', 'restart')][string]$Action = '')

$root = Split-Path (Split-Path $PSScriptRoot)
$iconPath = "$root\desktop\src-tauri\icons\icon.ico"
$webUrl = 'http://localhost:4300'
$apiUrl = 'http://localhost:4400/healthz'

$stopSignal = New-Object Threading.EventWaitHandle($false, 'AutoReset', 'Local\DoopTrayStop')
$restartSignal = New-Object Threading.EventWaitHandle($false, 'AutoReset', 'Local\DoopTrayRestart')
$mutex = New-Object Threading.Mutex($false, 'Local\DoopTray')
$first = $mutex.WaitOne(0)

if (-not $first) {
  if ($Action -eq 'stop') { [void]$stopSignal.Set() }
  elseif ($Action -eq 'restart') { [void]$restartSignal.Set() }
  else { Start-Process $webUrl }
  exit
}
if ($Action) { exit } # nothing running a tray to signal

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

function Test-Url($url) {
  try {
    $req = [Net.WebRequest]::Create($url)
    $req.Timeout = 2000
    $req.Proxy = $null
    $res = $req.GetResponse()
    $res.Close()
    return $true
  } catch { return $false }
}

function Start-Hidden($script, $scriptArgs, $log) {
  Start-Process node -ArgumentList (@("`"$root\$script`"") + $scriptArgs) -WorkingDirectory $root -WindowStyle Hidden `
    -RedirectStandardOutput "$root\data\$log.log" -RedirectStandardError "$root\data\$log.err.log" | Out-Null
}
function Start-Api { Start-Hidden 'node_modules\tsx\dist\cli.mjs' @('watch', '--env-file-if-exists=.env', 'server/index.ts') 'server' }
function Start-Web { Start-Hidden 'node_modules\vite\bin\vite.js' @() 'web' }

function Start-Doop {
  if (-not (Test-Url $apiUrl)) { Start-Api }
  if (-not (Test-Url $webUrl)) { Start-Web }
}

# Kills whole trees from the top: tsx watch keeps a dead child's slot, so killing
# only the port owner would leave it behind. Roots come from the port owner too,
# because processes started by hand carry a relative path in their command line.
# ponytail: taskkill /F skips the server's SIGTERM handler; PGlite has recovered from it on every restart so far.
function Stop-Tree($port, $pattern) {
  $all = @(Get-CimInstance Win32_Process)
  $ids = @($all | Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -like "*$root*" -and $_.CommandLine -match $pattern } | ForEach-Object { [int]$_.ProcessId })
  $ids += @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.OwningProcess })
  foreach ($id in ($ids | Select-Object -Unique)) {
    $top = $id
    while ($true) {
      $me = $all | Where-Object { $_.ProcessId -eq $top }
      $parent = $all | Where-Object { $me -and $_.ProcessId -eq $me.ParentProcessId -and $_.Name -eq 'node.exe' }
      if (-not $parent) { break }
      $top = [int]$parent.ProcessId
    }
    & taskkill.exe /T /F /PID $top 2>&1 | Out-Null
  }
}
function Stop-Api { Stop-Tree 4400 'server/index\.ts' }
function Stop-Web { Stop-Tree 4300 'vite' }

function New-Dot($color) {
  $bmp = New-Object Drawing.Bitmap 12, 12
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $brush = New-Object Drawing.SolidBrush $color
  $g.FillEllipse($brush, 1, 1, 10, 10)
  $g.Dispose()
  return $bmp
}
$dotOn = New-Dot ([Drawing.Color]::FromArgb(46, 160, 67))
$dotOff = New-Dot ([Drawing.Color]::Gray)

$tray = New-Object Windows.Forms.NotifyIcon
$tray.Icon = New-Object Drawing.Icon($iconPath, [Windows.Forms.SystemInformation]::SmallIconSize)
$tray.Text = 'Doop - iniciando'
$tray.Visible = $true

$menu = New-Object Windows.Forms.ContextMenuStrip
$open = $menu.Items.Add('Abrir Doop')
$open.Font = New-Object Drawing.Font($open.Font, [Drawing.FontStyle]::Bold)
$status = $menu.Items.Add('Iniciando...')
$status.Enabled = $false
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$restart = $menu.Items.Add('Reiniciar API (libera o Chrome)')
$quit = $menu.Items.Add('Parar Doop e sair')
$tray.ContextMenuStrip = $menu

$script:openWhenReady = $true

function Open-Doop {
  if ((Test-Url $apiUrl) -and (Test-Url $webUrl)) { Start-Process $webUrl; return }
  Start-Doop
  $script:openWhenReady = $true
  $timer.Interval = 1000
}
function Restart-Api {
  Stop-Api
  Start-Api
  $timer.Interval = 1000
}
function Quit-Doop {
  $timer.Stop()
  $tray.Text = 'Doop - parando'
  Stop-Api
  Stop-Web
  $tray.Visible = $false
  $tray.Dispose()
  [Windows.Forms.Application]::Exit()
}
function Update-Status {
  if ($stopSignal.WaitOne(0)) { Quit-Doop; return }
  if ($restartSignal.WaitOne(0)) { Restart-Api }
  $up = (Test-Url $apiUrl) -and (Test-Url $webUrl)
  $tray.Text = if ($up) { 'Doop - rodando' } else { 'Doop - parado' }
  $status.Text = if ($up) { 'Rodando' } else { 'Parado' }
  $status.Image = if ($up) { $dotOn } else { $dotOff }
  if ($up) {
    $timer.Interval = 10000
    if ($script:openWhenReady) {
      $script:openWhenReady = $false
      Start-Process $webUrl
    }
  }
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Update-Status })

$open.Add_Click({ Open-Doop })
$restart.Add_Click({ Restart-Api })
$quit.Add_Click({ Quit-Doop })
$tray.Add_DoubleClick({ Open-Doop })

Start-Doop
$timer.Start()
[Windows.Forms.Application]::Run()
$mutex.ReleaseMutex()
