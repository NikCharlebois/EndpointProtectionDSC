Configuration MonitorAntivirus
{
    Import-DscResource -ModuleName EndPointProtectionDSC -ModuleVersion 1.0.0.0

    Node MonitorAntivirus
    {
        EPAntivirusStatus AV
        {
            AntivirusName = "Windows Defender"
            Status        = "Stopped"
            Ensure        = "Present"
        }
    }
}

cd $env:Temp
MonitorAntivirus