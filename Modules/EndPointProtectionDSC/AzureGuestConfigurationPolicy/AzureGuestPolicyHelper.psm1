function New-EPDSCAzureGuestConfigurationPolicyPackage
{
    [CmdletBinding()]
    param()

    Write-Host "Connecting to Azure..." -NoNewLine
    Connect-AzAccount | Out-Null
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Compiling Configuration into a MOF file..." -NoNewLine
    & "$PSScriptRoot/../Examples/EPAntivirusStatus/MonitorAntivirus.ps1" | Out-Null
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Generating Guest Configuration Package..." -NoNewLine
    $package = New-GuestConfigurationPackage -Name MonitorAntivirus `
                                  -Configuration "$env:Temp/MonitorAntivirus/localhost.mof"
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Publishing Package to Azure Storage..." -NoNewLine
    $Url = Publish-EPDSCPackage
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Generating Guest Configuration Policy..." -NoNewLine
    Import-LocalizedData -BaseDirectory "$PSScriptRoot/ParameterFiles/" `
        -FileName "EPAntivirusStatus.Params.psd1" `
        -BindingVariable ParameterValues
    $policy = New-GuestConfigurationPolicy `
        -ContentUri $Url `
        -DisplayName 'Monitor Antivirus.' `
        -Description 'Audit if a given Antivirus Software is not enabled on Windows machine.' `
        -Path './policies' `
        -Platform 'Windows' `
        -Version 1.0.0 `
        -Parameter $ParameterValues
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Publishing Guest Configuration Policy..." -NoNewLine
    $publishedPolicies = Publish-GuestConfigurationPolicy -Path '.\policies'
    Write-Host "Done" -ForegroundColor Green
}

function Publish-EPDSCPackage 
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param()

    $resourceGroupName = 'EPDSCPolicyFiles'
    $resourceGroup     = Get-AzResourceGroup $resourceGroupName -ErrorAction "SilentlyContinue"
    if ($null -eq $resourceGroup)
    {
        $resourceGroup = New-AzResourceGroup -Name $resourceGroupName `
            -Location "centralus"
    }

    $storageAccountName   = 'epdscstorage'
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

    $storageContainerName = 'epdscitems'
    $storageContainer = Get-AzStorageContainer $storageContainerName `
        -Context $storageContext -ErrorAction "SilentlyContinue"
    if ($null -eq $storageContainer)
    {
        $storageContainer = New-AzStorageContainer -Name $storageContainerName `
            -Context $storageContext
    }

    # Upload file
    $blobName = "monitorantivirus"
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