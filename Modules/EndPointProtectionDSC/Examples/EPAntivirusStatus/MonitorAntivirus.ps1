Configuration MonitorAntivirus
{
    Import-DscResource -ModuleName EndPointProtectionDSC -ModuleVersion 1.0.0.0

    Node MonitorAntivirus
    {
        EPAntivirusStatus AV
        {
            AntivirusName = "Windows Defender"
            Status        = "Running"
            Ensure        = "Present"
        }
    }
}

cd $env:Temp
MonitorAntivirus