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
    if ($guestSvc.Enabled) {
        $vmInfo.guest_services = $true
    }

    $ipAddrs = $vm | Get-VMNetworkAdapter | Select-Object -ExpandProperty IPAddresses
    $vmInfo.ip = $ipAddrs | Where-Object { $_ -notlike '127.*' } | Select-Object -First 1

    
    Send-Response -Response $Response -StatusCode 200 -Message ($vmInfo | ConvertTo-Json)
}
