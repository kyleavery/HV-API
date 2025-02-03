$script:Method      = "POST"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)/reboot$'
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

    Log-Message "Rebooting VM $vmName"

    if ($vm.State -eq 'Off') {
        while ($vm.State -ne 'Running') {
            try {
                Start-VM -VM $vm -ErrorAction Stop
            }
            catch {
                Send-Response -Response $Response -StatusCode 500 -Message "Failed to start VM: $_"
                return
            }
            Start-Sleep -Seconds 5
            $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        }
    }
    else {
        try {
            Restart-VM -VM $vm -Force -Confirm:$false
        }
        catch {
            Send-Response -Response $Response -StatusCode 500 -Message "Failed to reboot VM: $_"
            return
        }
    }

    Send-Response -Response $Response -StatusCode 200 -Message "VM rebooted"
}
