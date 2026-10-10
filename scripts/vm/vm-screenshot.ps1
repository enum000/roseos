param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$WaitSeconds = 0
)
$ErrorActionPreference = 'Stop'
$vbm = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if ($WaitSeconds -gt 0) { Start-Sleep -Seconds $WaitSeconds }
& $vbm controlvm $Name screenshotpng $Out
if ($LASTEXITCODE -ne 0) { throw "screenshot of '$Name' failed" }
Write-Output $Out
