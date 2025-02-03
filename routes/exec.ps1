$script:Method      = "POST"
$script:PathPattern = '^/api/v1/vm/(?<vmName>[^/]+)/execute$'
$script:Handler     = {
    param(
        [System.Net.HttpListenerRequest] $Request,
        [System.Net.HttpListenerResponse] $Response,
        [hashtable] $Matches,
        [hashtable] $Config
    )

    $vmName = $Matches.vmName

    $username = $Request.Headers.Get("VM-Username")
    $password = $Request.Headers.Get("VM-Password")

    $scriptArgs = $Request.QueryString.Get("args")
    Log-Message "Script arguments: $scriptArgs"

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

    $script = Get-RequestContent -Request $Request

    $securePass  = ConvertTo-SecureString -AsPlainText $password -Force
    $creds = New-Object System.Management.Automation.PSCredential($username, $securePass)

    $parsedArgs = Parse-Arguments $scriptArgs
    Log-Message "Parsed script arguments: $parsedArgs"

    try {
        Log-Message "Executing script on VM '$vmName': $script"

        $result = Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock {
            param($inlineScript, $inlineArgs)

            $scriptBlock = [ScriptBlock]::Create($inlineScript)
            if ($inlineArgs -isnot [array]) {
                $inlineArgs = @($inlineArgs)
            }

            $output = & $scriptBlock @inlineArgs *>&1
            $output
        } -ArgumentList $script, $parsedArgs -ErrorAction Stop

        Log-Message "Result of script execution: $($result | Out-String)"

        Send-Response -Response $Response -StatusCode 200 -Message ($result | Out-String)
    }
    catch {
        Send-Response -Response $Response -StatusCode 500 -Message "Failed to execute script: $_"
    }
}
