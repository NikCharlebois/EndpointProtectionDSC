function New-EPDSCAzureGuestConfigurationPolicyPackage
{
    [CmdletBinding()]
    param()

    $deploymentName = Read-Host "Pick a random Resource Group Name"

    Write-Host "Connecting to Azure..." -NoNewLine
    Connect-AzAccount | Out-Null
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Compiling Configuration into a MOF file..." -NoNewLine
    if (Test-Path 'MonitorAntivirus')
    {
        Remove-Item "MonitorAntivirus" -Recurse -Force -Confirm:$false
    }
    & "$PSScriptRoot/Configurations/MonitorAntivirus.ps1" | Out-Null
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Generating Guest Configuration Package..." -NoNewLine
    $package = New-GuestConfigurationPackage -Name MonitorAntivirus `
                                  -Configuration "$env:Temp/MonitorAntivirus/MonitorAntivirus.mof"
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Publishing Package to Azure Storage..." -NoNewLine
    $Url = Publish-EPDSCPackage -DeploymentName $deploymentName
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Generating Guest Configuration Policy..." -NoNewLine
    if (Test-Path 'policies')
    {
        Remove-Item "policies" -Recurse -Force -Confirm:$false
    }
    Import-LocalizedData -BaseDirectory "$PSScriptRoot/ParameterFiles/" `
        -FileName "EPAntivirusStatus.Params.psd1" `
        -BindingVariable ParameterValues
    $policy = New-GuestConfigurationPolicy `
        -ContentUri $Url `
        -DisplayName 'Monitor Antivirus' `
        -Description 'Audit if a given Antivirus Software is not enabled on Windows machine.' `
        -Path './policies' `
        -Platform 'Windows' `
        -Version 1.0.0 `
        -Parameter $ParameterValues -Verbose
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Publishing Guest Configuration Policy..." -NoNewLine
    $publishedPolicies = Publish-GuestConfigurationPolicy -Path ".\policies" -Verbose
    Write-Host "Done" -ForegroundColor Green
}

function Publish-EPDSCPackage 
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $DeploymentName
    )

    $storageContainerName = $DeploymentName.ToLower() + "ctn"
    $storageAccountName   = $DeploymentName.ToLower() + "str"
    $resourceGroupName = $DeploymentName

    $resourceGroup     = Get-AzResourceGroup $resourceGroupName -ErrorAction "SilentlyContinue"
    if ($null -eq $resourceGroup)
    {
        $resourceGroup = New-AzResourceGroup -Name $resourceGroupName `
            -Location "centralus"
    }

    $storageAccount = Get-AzStorageAccount -Name $storageAccountName `
        -ResourceGroupName $resourceGroupName -ErrorAction "SilentlyContinue"
    if ($null -eq $storageAccount)
    {
        $storageAccount = New-AzStorageAccount -Name $storageAccountName `
            -ResourceGroupName $resourceGroupName `
            -SkuName "Standard_LRS" `
            -Location "centralus"
    }

    # Get Storage Context
    $storageContext = Get-AzStorageAccount -ResourceGroupName $resourceGroupName `
        -Name $storageAccountName | `
        ForEach-Object { $_.Context }

    $storageContainer = Get-AzStorageContainer $storageContainerName `
        -Context $storageContext -ErrorAction "SilentlyContinue"
    if ($null -ne $storageContainer)
    {
        while ($null -ne $storageContainer)
        {
            Start-Sleep 2
            $storageContainer = Get-AzStorageContainer $storageContainerName `
                -Context $storageContext -ErrorAction "SilentlyContinue"
        }
        Remove-AzStorageContainer -Name $storageContainerName `
            -Context $storageContext -Force -Confirm:$false
    }

    $storageContainer = New-AzStorageContainer -Name $storageContainerName `
            -Context $storageContext -Permission Container

    # Upload file
    $blobName = "MonitorAntivirus.zip"
    $Blob = Set-AzStorageBlobContent -Context $storageContext `
        -Container $storageContainerName `
        -File $($env:Temp + "/MonitorAntivirus/MonitorAntivirus.zip") `
        -Blob $blobName `
        -Force

    # Get url with SAS token
    $StartTime = (Get-Date)
    $ExpiryTime = $StartTime.AddYears('3')  # THREE YEAR EXPIRATION
    $SAS = New-AzStorageBlobSASToken -Context $storageContext `
        -Container $storageContainerName `
        -Blob $blobName `
        -StartTime $StartTime `
        -ExpiryTime $ExpiryTime `
        -Permission rl `
        -FullUri

    # Output
    return $SAS
}