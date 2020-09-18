@{
    Name                 = 'AntivirusName'
    DisplayName          = 'Antivirus Name'
    Description          = "Name of the Antivirus Software to monitor."
    ResourceType         = "EPAntivirusStatus"
    ResourceId           = 'AntivirusName'
    ResourcePropertyName = "AntivirusName"
    DefaultValue         = 'Windows Defender'
    #AllowedValues = @('Avast','Windows Defender','CrowdStrike','Sentinel One')
}
