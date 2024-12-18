function Invoke-AsBuiltReport.Microsoft.AD {
    <#
    .SYNOPSIS
        PowerShell script to document the configuration of Microsoft AD in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of Microsoft AD in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.9.1
        Author:         Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         rebelinux
        Credits:        Iain Brighton (@iainbrighton) - PScribo module

    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.AD
    #>

    # Do not remove or add to these parameters
    param (
        [String[]] $Target,
        [PSCredential] $Credential
    )

    #Requires -Version 5.1
    #Requires -PSEdition Desktop
    #Requires -RunAsAdministrator

    if ($psISE) {
        Write-Error -Message "You cannot run this script inside the PowerShell ISE. Please execute it from the PowerShell Command Window."
        break
    }

    Write-PScriboMessage -Plugin "Module" -IsWarning "Please refer to the AsBuiltReport.Microsoft.AD github website for more detailed information about this project."
    Write-PScriboMessage -Plugin "Module" -IsWarning "Do not forget to update your report configuration file after each new release."
    Write-PScriboMessage -Plugin "Module" -IsWarning "Documentation: https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.AD"
    Write-PScriboMessage -Plugin "Module" -IsWarning "Issues or bug reporting: https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.AD/issues"
    Write-PScriboMessage -Plugin "Module" -IsWarning "This project is community maintained and has no sponsorship from Microsoft, its employees or any of its affiliates."

    Try {
        $InstalledVersion = Get-Module -ListAvailable -Name AsBuiltReport.Microsoft.AD -ErrorAction SilentlyContinue | Sort-Object -Property Version -Descending | Select-Object -First 1 -ExpandProperty Version

        if ($InstalledVersion) {
            Write-PScriboMessage -IsWarning "AsBuiltReport.Microsoft.AD $($InstalledVersion.ToString()) is currently installed. With HoTfIx"
            $LatestVersion = Find-Module -Name AsBuiltReport.Microsoft.AD -Repository PSGallery -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Version
            if ($LatestVersion -gt $InstalledVersion) {
                Write-PScriboMessage -IsWarning "AsBuiltReport.Microsoft.AD $($LatestVersion.ToString()) is available."
                Write-PScriboMessage -IsWarning "Run 'Update-Module -Name AsBuiltReport.Microsoft.AD -Force' to install the latest version."
            }
        }
    } Catch {
        Write-PScriboMessage -IsWarning $_.Exception.Message
    }

    #Validate Required Modules and Features
    $CompInfo = Get-ComputerInfo
    $OSType = $CompInfo.OsProductType
    $OSName = $CompInfo.OSName

    Write-Host "Precheck OSName $OSName OSType $OSType"
    if ($OSType -eq 'Server' -or $OSType -eq 'DomainController') {
        # Win10 and 11 multisession reports as a Server on OSType. This works around that for now.
        If (($OSName -like "*Windows 10*") -OR ($OSName -like "*Windows 11*")) {
            $OSType = 'WorkStation'
        }
        Else {
            Get-RequiredFeature -Name RSAT-AD-PowerShell -OSType $OSType
            Get-RequiredFeature -Name RSAT-ADCS -OSType $OSType
            Get-RequiredFeature -Name RSAT-ADCS-mgmt -OSType $OSType
            Get-RequiredFeature -Name RSAT-DNS-Server -OSType $OSType
            Get-RequiredFeature -Name GPMC -OSType $OSType
        }
    }
    if ($OSType -eq 'WorkStation') {
        Get-RequiredFeature -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0' -OSType $OSType
        Get-RequiredFeature -Name 'Rsat.CertificateServices.Tools~~~~0.0.1.0' -OSType $OSType
        Get-RequiredFeature -Name 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0' -OSType $OSType
        Get-RequiredFeature -Name 'Rsat.Dns.Tools~~~~0.0.1.0' -OSType $OSType
    }

    Get-RequiredModule -Name PSPKI -Version '4.2.0'

    # Import Report Configuration
    $script:Report = $ReportConfig.Report
    $script:InfoLevel = $ReportConfig.InfoLevel
    $script:Options = $ReportConfig.Options

    # Used to set values to TitleCase where required
    $script:TextInfo = (Get-Culture).TextInfo

    if ($Healthcheck) {
        Section -Style TOC -ExcludeFromTOC 'DISCLAIMER' {
            Paragraph "The information contained in this report has been obtained through automation and observations. Opinions, recommendations and conclusions are disseminated using insight, knowledge, training and experience. This assessment was not intended to be exhaustive. However, we have done our best to capture the most relevant opportunities for improvement. It is expected that responsibility for the implementation of these recommendations will be reviewed and implemented by a person with the necessary knowledge, experience or expertise. In no event shall the author(s) be liable for damages of any kind (including, but not limited to, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use or inability to use these recommendations or the statements made in this documentation."
        }
        PageBreak
    }

    #---------------------------------------------------------------------------------------------#
    #                                 Connection Section                                          #
    #---------------------------------------------------------------------------------------------#
    foreach ($System in $Target) {

        if (Select-String -InputObject $System -Pattern "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
            throw "Please use the FQDN instead of an IP address to connect to the Domain Controller: $System"
        }

        Try {
            Write-PScriboMessage "Connecting to Domain Controller through PSSession $System"
            $script:TempPssSession = New-PSSession $System -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ErrorAction Stop -Name "Global:TempPssSession"
        } Catch {
            throw "Unable to connect to the Domain Controller through PSSession: $System"
        }

        Try {
            Write-PScriboMessage "Connecting to Domain Controller through CimSession '$System'."
            $script:TempCIMSession = New-CimSession $System -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ErrorAction Continue -Name "Global:TempCIMSession"
        } Catch {
            Write-PScriboMessage -IsWarning "Unable to connect to the Domain Controller through CimSession: $System"
        }

        Try {
            Write-PScriboMessage "Connecting to get Forest information from Domain Controller '$System'."
            $script:ADSystem = Invoke-Command -Session $TempPssSession { Get-ADForest -ErrorAction Stop }
        } Catch {
            throw "Unable to get Forest information from Domain Controller: $System"
        }

        $script:ForestInfo = $ADSystem.RootDomain.toUpper()
        [array]$RootDomains = $ADSystem.RootDomain
        [array]$ChildDomains = $ADSystem.Domains | Where-Object { $_ -ne $RootDomains }
        [string] $script:OrderedDomains = $RootDomains + $ChildDomains

        # Forest Section
        Get-AbrForestSection

        # Domain Section
        Get-AbrDomainSection

        # DNS Section
        Get-AbrDnsSection

        # PKI Section
        Get-AbrPKISection

        if ($TempPssSession) {
            # Remove used PSSession
            Write-PScriboMessage "Clearing PowerShell Session $($TempPssSession.Id)"
            Remove-PSSession -Session $TempPssSession
        }

        if ($TempCIMSession) {
            # Remove used CIMSession
            Write-PScriboMessage "Clearing CIM Session $($TempCIMSession.Id)"
            Remove-CimSession -CimSession $TempCIMSession
        }


    }#endregion foreach loop
}
