$script:Method      = "DELETE"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)$'
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

    while ($vm.State -ne "Off") {
        try {
            Stop-VM -VM $vm -Force -Confirm:$false
        }
        catch {
            Send-Response -Response $Response -StatusCode 500 -Message "Failed to stop VM: $_"
            return
        }
        Start-Sleep -Seconds 5
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    }

    Log-Message "Deleting VM $vmName"

    try {
        Remove-VM -VM $vm -Force -Confirm:$false
    }
    catch {
        Send-Response -Response $Response -StatusCode 500 -Message "Failed to delete VM: $_"
        return
    }

    Send-Response -Response $Response -StatusCode 200 -Message "VM deleted"
}
