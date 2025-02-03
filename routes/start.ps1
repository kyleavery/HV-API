$script:Method      = "POST"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)/start$'
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

    Log-Message "Starting VM $vmName"

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

    Send-Response -Response $Response -StatusCode 200 -Message "VM started"
}
