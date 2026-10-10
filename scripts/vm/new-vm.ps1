param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Iso,
    [int]$DiskGB = 60,
    [int]$MemoryMB = 8192,
    [switch]$SecureBoot,
    [switch]$Recreate
)
$ErrorActionPreference = 'Stop'
$vbm = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
$base = Join-Path $env:USERPROFILE 'RoseOS\vms'
New-Item -ItemType Directory -Force -Path $base | Out-Null

function Invoke-VBox { & $vbm @args; if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args -join ' ') failed ($LASTEXITCODE)" } }

$exists = (& $vbm list vms) -match "^`"$([regex]::Escape($Name))`""
if ($exists) {
    if (-not $Recreate) { throw "VM '$Name' already exists. Use -Recreate to replace it." }
    $state = (& $vbm showvminfo $Name --machinereadable) -match '^VMState='
    if ($state -match '"(running|paused|stuck)"') {
        Invoke-VBox controlvm $Name poweroff
        Start-Sleep -Seconds 3
    }
    Invoke-VBox unregistervm $Name --delete
}

Invoke-VBox createvm --name $Name --ostype Debian_64 --register --basefolder $base
Invoke-VBox modifyvm $Name --memory $MemoryMB --cpus 4 --firmware efi --graphicscontroller vmsvga --vram 128 --nic1 nat --rtc-use-utc on
$disk = Join-Path $base "$Name\$Name.vdi"
Invoke-VBox createmedium disk --filename $disk --size ($DiskGB * 1024) --format VDI
Invoke-VBox storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 2
Invoke-VBox storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
if ($Iso) {
    Invoke-VBox storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso
} else {
    Invoke-VBox storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
}
if ($SecureBoot) {
    Invoke-VBox modifynvram $Name inituefivarstore
    Invoke-VBox modifynvram $Name enrollmssignatures
    Invoke-VBox modifynvram $Name enrollorclpk
    Invoke-VBox modifynvram $Name secureboot --enable
}
Write-Output "Created VM '$Name' (EFI, ${DiskGB}GB, ${MemoryMB}MB, SecureBoot=$($SecureBoot.IsPresent))"
