param(
    [string]$ConfigFilePath = "$PSScriptRoot\config.psd1"
)

$config = Import-PowerShellDataFile $ConfigFilePath

. "$PSScriptRoot\common.ps1"

$ip         = $config.HostConfig.IP
$port       = $config.HostConfig.Port
$maxThreads = $config.HostConfig.MaxThreads

$routePath  = "$PSScriptRoot\routes"
$url        = "http://$ip`:$port/"

$routes = @()
Get-ChildItem -Path "$routePath\*.ps1" | ForEach-Object {
    . $_.FullName
    $routes += [PSCustomObject]@{
        Method      = $script:Method
        PathPattern = $script:PathPattern
        Handler     = $script:Handler
    }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()

$runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads)
$runspacePool.Open()

Write-Host "Server started on $url (Ctrl+C to stop)"

try {
    while ($listener.IsListening) {
        $contextTask = $listener.GetContextAsync()
        
        while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) { }
        
        if (-not $contextTask.IsCompleted) { continue }
        $context = $contextTask.GetAwaiter().GetResult()

        $powershell = [PowerShell]::Create()
        
        foreach ($module in $config.HyperVModules) {
            $powershell.AddCommand("Import-Module").AddArgument($module) | Out-Null
        }

        $powershell.AddScript(". '$PSScriptRoot\common.ps1'") | Out-Null

        $powershell.AddScript({
            param($context, $routes, $config)

            $request  = $context.Request
            $response = $context.Response

            try {
                $authHeader = $request.Headers["Authorization"]
                if (-not $authHeader -or -not ($authHeader -match "^Basic ")) {
                    throw "No credentials provided"
                }

                $encodedValue = $authHeader.Substring(6)
                $decodedBytes = [System.Convert]::FromBase64String($encodedValue)
                $decodedValue = [System.Text.Encoding]::ASCII.GetString($decodedBytes)

                $parts = $decodedValue.Split(":", 2)
                $username = $parts[0]
                $password = $parts[1]

                if ($($username -ne $Config.BasicAuth.Username) -or $($password -ne $Config.BasicAuth.Password)) {
                    throw "Invalid credentials"
                }
            }
            catch {
                Add-Content -Path $config.LogFile -Value "[$(Get-Date)] $_"
                $response.StatusCode = 401
                $response.AddHeader("WWW-Authenticate", 'Basic realm="PowerShellAPI"')
                $response.OutputStream.Close()
                return $null
            }

            try {
                $matched = $false
                foreach ($route in $routes) {
                    if ($request.HttpMethod -ne $route.Method) { continue }
                    
                    if ($request.Url.AbsolutePath -match $route.PathPattern) {
                        $matched = $true
                        & $route.Handler -Request $request -Response $response -Matches $Matches -Config $config
                        break
                    }
                }

                if (-not $matched) {
                    Send-Response -Response $response -StatusCode 404 -Message "Not Found"
                }
            }
            catch {
                Send-Response -Response $response -StatusCode 500 -Message "Internal Server Error: $_"
            }
            finally {
                $response.OutputStream.Close()
            }

            return $null
        }).AddArgument($context).AddArgument($routes).AddArgument($config)

        $powershell.RunspacePool = $runspacePool
        $null = $powershell.BeginInvoke()
    }
}
finally {
    Write-Host "`nServer stopping..."
    $listener.Stop()
    $listener.Close()
    $runspacePool.Close()
    $runspacePool.Dispose()
}
