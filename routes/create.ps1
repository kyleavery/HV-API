Import-Module Hyper-V
Import-Module Microsoft.PowerShell.Security


$script:Method      = "POST"
$script:PathPattern = '^/api/v1/vm$'
$script:Handler     = {
    param(
        [System.Net.HttpListenerRequest] $Request,
        [System.Net.HttpListenerResponse] $Response,
        [hashtable] $Matches,
        [hashtable] $Config
    )

    $content = Get-RequestContent -Request $Request

    try {
        $json = $content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Send-Response -Response $Response -StatusCode 400 -Message "Invalid JSON: $_"
        return
    }

    $vmName   = $json.name
    $vmMemory = $json.memory * 1GB
    $vmCpu    = $json.cpu
    $vmSwitch = $json.switch
    $vmOs     = $json.os
    $vmTpm    = $json.tpm

    foreach ($prefix in $Config.ProtectedVmPrefixes) {
        if ($vmName.StartsWith($prefix)) {
            Send-Response -Response $Response -StatusCode 403 -Message "Protected VM name"
            return
        }
    }

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        Send-Response -Response $Response -StatusCode 409 -Message "VM already exists"
        return
    }

    $switch = Get-VMSwitch -Name $vmSwitch -ErrorAction SilentlyContinue
    if (-not $switch) {
        Send-Response -Response $Response -StatusCode 404 -Message "Switch not found"
        return
    }

    if ($Config.TemplateNames -notcontains $vmOs) {
        Send-Response -Response $Response -StatusCode 400 -Message "Unsupported OS: $vmOs"
        return
    }

    try {
        Copy-Item -Path "$($Config.TemplateVHDPath)\$($Config.TemplatePrefix)_$vmOs.vhdx" -Destination "$($Config.VHDPath)\$vmName.vhdx"

        $vm = New-VM -Name $vmName -Generation 2 -SwitchName $vmSwitch `
                     -Path $Config.VMRootPath `
                     -VHDPath "$($Config.VHDPath)\$vmName.vhdx"

        if (-not $vm) {
            Send-Response -Response $Response -StatusCode 500 -Message "Failed to create VM"
            return
        }

        $vm | Set-VMMemory -DynamicMemoryEnabled $true -MinimumBytes $($vmMemory / 2) -StartupBytes $vmMemory -MaximumBytes $vmMemory
        $vm | Set-VMProcessor -Count $vmCpu    
        $vm | Set-VMFirmware -EnableSecureBoot On
        if ($vmTpm) {
            $vm | Set-VMKeyProtector -NewLocalKeyProtector
            $vm | Enable-VMTPM
        }

        $vm | Start-VM
    }
    catch {
        Send-Response -Response $Response -StatusCode 500 -Message "Failed to create VM: $_"
        return
    }

    Send-Response -Response $Response -StatusCode 201 -Message "VM created"
}
