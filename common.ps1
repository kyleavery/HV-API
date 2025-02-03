function Get-RequestContent {
    param(
        [System.Net.HttpListenerRequest] $Request
    )
    $reader = New-Object System.IO.StreamReader($Request.InputStream)
    return $reader.ReadToEnd()
}

function Send-Response {
    param(
        [System.Net.HttpListenerResponse] $Response,
        [int] $StatusCode,
        [string] $Message
    )

    $Response.StatusCode = $StatusCode
    $buffer = [Text.Encoding]::UTF8.GetBytes($Message)
    $Response.ContentLength64 = $buffer.Length
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
}

function Log-Message {
    param(
        [Parameter(Position=0)]
        [string] $Message
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $Config.LogFile -Value "[$timestamp] $Message"
}

function Parse-Arguments {
    param([string]$argString)
    
    $args = @()
    $currentArg = ""
    $inQuotes = $false
    
    for ($i = 0; $i -lt $argString.Length; $i++) {
        $char = $argString[$i]
        
        if ($char -eq '"') {
            $inQuotes = !$inQuotes
        }
        elseif ($char -eq ' ' -and !$inQuotes) {
            if ($currentArg) {
                $args += $currentArg.Trim('"')
                $currentArg = ""
            }
        }
        else {
            $currentArg += $char
        }
    }
    
    if ($currentArg) {
        $args += $currentArg.Trim('"')
    }
    
    return ,$args
}
