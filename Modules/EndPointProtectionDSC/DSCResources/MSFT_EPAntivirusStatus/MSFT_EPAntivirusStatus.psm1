function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AntivirusName,

        [Parameter()]
        [System.String]
        [ValidateSet("Running", "Stopped")]
        $Status = "Running",

        [Parameter()]
        [System.String]
        [ValidateSet("Absent", "Present")]
        $Ensure
    )

    Write-Verbose -Message "Getting Information about Antivirus {$AntivirusName}"
    $Reasons = @()

    $AntivirusInfo = Get-EPDSCInstalledAntivirus -AntivirusName $AntivirusName

    $nullReturn = $PSBoundParameters
    $nullReturn.Ensure = "Absent"
    if ($null -eq $AntivirusInfo)
    {
        Write-Verbose -Message "Could not obtain Information about Antivirus {$AntivirusName}"

        # Antivirus should be installed but it's not
        if ($Ensure -eq 'Present')
        {
                $Reasons += @{
                    Code = "epantivirusstatus:epantivirusstatus:antivirusnotinstalled"
                    Phrase = "Antivirus {$AntivirusName} should be installed but it's NOT."
                }
        }
        $nullReturn.Reasons = $Reasons
        return $nullReturn
    }

    # Antivirus should not be installed but it is
    if ($Ensure -eq 'Absent')
    {
        $Reasons += @{
            Code = "epantivirusstatus:epantivirusstatus:antivirusinstalled"
            Phrase = "Antivirus {$AntivirusName} is installed but it should NOT."
        }
    }

    try
    {
        $executablePathParts = $AntivirusInfo.pathToSignedReportingExe.Split("\")
        $executableName = $executablePathParts[$executablePathParts.Length -1].Split('.')[0]
        $process = Get-EPDSCProcessByReportingExecutable -ExecutableName $executableName

        $statusValue = "Running"
        if ($null -eq $process)
        {
            $statusValue = "Stopped"
        }

        if ($Status -ne $statusValue)
        {
            # Antivirus Agent should be running but its not
            if ($Status -eq 'Running')
            {
                $Reasons += @{
                    Code = "epantivirusstatus:epantivirusstatus:agentnotrunning"
                    Phrase = "Antivirus Agent for {$AntivirusName} is not running and it SHOULD be."
                }
            }
            # Antivirus is running and it should not
            else
            {
                $Reasons += @{
                    Code = "epantivirusstatus:epantivirusstatus:agentrunning"
                    Phrase = "Antivirus Agent for {$AntivirusName} is running and it should NOT be."
                }
            }
        }

        $result = @{
            AntivirusName = $AntivirusName
            Status        = $statusValue
            Ensure        = "Present"
            Reasons       = $Reasons
        }
    }
    catch
    {
        Write-Verbose -Message "Could not retrieve process runnign for Antivirus {$AntivirusName}"
        return $nullReturn
    }
    return $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AntivirusName,

        [Parameter()]
        [System.String]
        [ValidateSet("Running", "Stopped")]
        $Status = "Running",

        [Parameter()]
        [System.String]
        [ValidateSet("Absent", "Present")]
        $Ensure
    )

    Write-Verbose -Message "Calling the Set-TargetResource function for Antivirus {$AntivirusName}"

}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AntivirusName,

        [Parameter()]
        [System.String]
        [ValidateSet("Running", "Stopped")]
        $Status = "Running",

        [Parameter()]
        [System.String]
        [ValidateSet("Absent", "Present")]
        $Ensure,

        [Parameter()]
        [Array]
        $Reasons
    )

    Write-Verbose -Message "Testing Settings of Antivirus {$AntivirusName}"

    $CurrentValues = Get-TargetResource @PSBoundParameters

    $result = $true
    if ($CurrentValues.Status -ne $Status -or $CurrentValues.Ensure -ne $Ensure)
    {
        $result = $false

        # Display the reasons for non-compliance
        Write-Verbose -Message 'The current VM is not in compliance due to:'
        foreach ($reason in $CurrentValues.Reasons)
        {
            Write-Verbose -Message $reason.Phrase
        }
    }
    Write-Verbose -Message "Test-TargetResource returned $result"
    return $result
}

Export-ModuleMember -Function *-TargetResource
