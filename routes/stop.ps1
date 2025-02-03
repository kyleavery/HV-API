$script:Method      = "POST"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)/stop$'
$script:Handler     = {
    param(
        [System.Net.HttpListenerRequest] $Request,
        [System.Net.HttpListenerResponse] $Response,
        [hashtable] $Matches,
        [hashtable] $Config
    )

    $vmName = $Matches.vmName

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

    Log-Message "Stopping VM $vmName"

    while ($vm.State -ne "Off") {
        try {
            Stop-VM -VM $vm -Confirm:$false
        }
        catch {
            Send-Response -Response $Response -StatusCode 500 -Message "Failed to stop VM: $_"
            return
        }
        Start-Sleep -Seconds 5
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    }

    Send-Response -Response $Response -StatusCode 200 -Message "VM stopped"
}
