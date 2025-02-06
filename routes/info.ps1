Import-Module Hyper-V
Import-Module Microsoft.PowerShell.Security


$script:Method      = "GET"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)$'
$script:Handler     = {
    param(
        [System.Net.HttpListenerRequest] $Request,
        [System.Net.HttpListenerResponse] $Response,
        [hashtable] $Matches,
        [hashtable] $Config
    )

    $vmName = $Matches.vmName

    $enableGuestServices = $Request.QueryString.Get("enableGuestServices")

    $vmInfo = @{
        state = 'Unknown'
        guest_services = $false
        ip = ''
    }

    foreach ($prefix in $Config.ProtectedVmPrefixes) {
        if ($vmName.StartsWith($prefix)) {
            Send-Response -Response $Response -StatusCode 403 -Message "Protected VM"
            return
        }
    }

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Send-Response -Response $Response -StatusCode 404 -Message "VM not found"
        return
    }

    if ($vm.State -eq 'Running') {
        $vmInfo.state = 'Running'
    }
    elseif ($vm.State -eq 'Off') {
        $vmInfo.state = 'Off'
    }
    elseif ($vm.State -eq 'Paused') {
        $vmInfo.state = 'Paused'
    }

    $guestSvc = Get-VMIntegrationService -VMName $vmName -Name "Guest Service Interface"
    if ($enableGuestServices -eq 'true') {
        while ($guestSvc.Enabled -eq $false) {
            try {
                Enable-VMIntegrationService -VMName $vmName -Name "Guest Service Interface" -ErrorAction Stop
                Start-Sleep -Seconds 5
                $guestSvc = Get-VMIntegrationService -VMName $vmName -Name "Guest Service Interface"
            }
            catch {
                Send-Response -Response $Response -StatusCode 500 -Message "Failed to enable Guest Service Interface: $_"
                return
            }
        }
    }

    if ($guestSvc.Enabled) {
        $vmInfo.guest_services = $true
    }

    $ipAddrs = $vm | Get-VMNetworkAdapter | Select-Object -ExpandProperty IPAddresses
    $vmInfo.ip = $ipAddrs | Where-Object { $_ -notmatch '^127\.' -and $_ -notmatch '^169\.254\.' -and $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1

    
    Send-Response -Response $Response -StatusCode 200 -Message ($vmInfo | ConvertTo-Json)
}
