Import-Module Hyper-V
Import-Module Microsoft.PowerShell.Security


$script:Method      = "PUT"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)/file$'
$script:Handler     = {
    param(
        [System.Net.HttpListenerRequest] $Request,
        [System.Net.HttpListenerResponse] $Response,
        [hashtable] $Matches,
        [hashtable] $Config
    )

    $vmName = $Matches.vmName

    $destinationPath = $Request.Headers.Get("Destination-Path")

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

    $guestSvc = Get-VMIntegrationService -VMName $vmName -Name "Guest Service Interface"
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

    $hostFilePath = Join-Path $Config.TempPath $([System.IO.Path]::GetRandomFileName())
    Log-Message "Uploading file to $hostFilePath"

    $hostFile = New-Object System.IO.FileStream($hostFilePath, [System.IO.FileMode]::Create)
    $Request.InputStream.CopyTo($hostFile)
    $hostFile.Close()

    Log-Message "Copying file to $destinationPath on $vmName"

    try {
        Copy-VMFile -Name $vmName -SourcePath $hostFilePath -DestinationPath $destinationPath `
                    -CreateFullPath -FileSource Host -Force
    }
    catch {
        Remove-Item -Path $hostFilePath -Force -ErrorAction SilentlyContinue
        Send-Response -Response $Response -StatusCode 500 -Message "Failed to upload file: $_"
        return
    }

    Remove-Item -Path $hostFilePath -Force -ErrorAction SilentlyContinue

    Send-Response -Response $Response -StatusCode 200 -Message "File uploaded"
}
