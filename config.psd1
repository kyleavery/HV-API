@{
    HostConfig = @{
        IP         = ""
        Port       = 1234
        MaxThreads = 20
    }

    LogFile = "C:\HVAPI\debug.log"
    TempPath = "C:\HVAPI\tmp"

    ProtectedVmPrefixes = @("TMPL")

    VMRootPath      = "C:\VMs"
    VHDPath         = "C:\VHDX"
    TemplateVHDPath = "C:\VHDX"
    TemplateNames   = @("WIN_11")
    TemplatePrefix  = "TMPL"

    HyperVModules = @("Hyper-V", "Microsoft.PowerShell.Security")

    BasicAuth = @{
        Username = "admin"
        Password = "password"
    }
}
