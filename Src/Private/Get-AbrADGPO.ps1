function Get-AbrADGPO {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Microsoft Active Directory Group Policy Objects information.
    .DESCRIPTION

    .NOTES
        Version:        0.7.11
        Author:         Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         rebelinux
    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param (
        [Parameter (
            Position = 0,
            Mandatory)]
            [string]
            $Domain
            )

    begin {
        Write-PscriboMessage "Discovering Active Directory Group Policy Objects information for $($Domain.ToString().ToUpper())."
    }

    process {
        try {
            Section -Style Heading5 "Group Policy Objects" {
                Paragraph "The following section provides a summary of the Group Policy Objects for domain $($Domain.ToString().ToUpper())."
                BlankLine
                $OutObj = @()
                $GPOs = Invoke-Command -Session $TempPssSession -ScriptBlock {Get-GPO -Domain $using:Domain -All}
                Write-PscriboMessage "Discovered Active Directory Group Policy Objects information on $Domain. (Group Policy Objects)"
                if ($GPOs) {
                    if ($InfoLevel.Domain -eq 1) {
                        try {
                            foreach ($GPO in $GPOs) {
                                try {
                                    Write-PscriboMessage "Collecting Active Directory Group Policy Objects '$($GPO.DisplayName)'."
                                    $inObj = [ordered] @{
                                        'GPO Name' = $GPO.DisplayName
                                        'GPO Status' = ($GPO.GpoStatus -creplace  '([A-Z\W_]|\d+)(?<![a-z])',' $&').trim()
                                        'Security Filtering' =  &{
                                            $GPOSECFILTER = Invoke-Command -Session $TempPssSession -ScriptBlock {(Get-GPPermission -DomainName $using:Domain -All -Guid ($using:GPO).ID | Where-Object {$_.Permission -eq 'GpoApply'}).Trustee.Name}
                                            if ($GPOSECFILTER) {

                                                return $GPOSECFILTER

                                            } else {'No Security Filtering'}
                                        }
                                    }
                                    $OutObj += [pscustomobject]$inobj
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Group Policy Objects)"
                                }
                            }

                            if ($HealthCheck.Domain.GPO) {
                                $OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'} | Set-Style -Style Warning -Property 'GPO Status'
                                $OutObj | Where-Object { $_.'Security Filtering' -like 'No Security Filtering'} | Set-Style -Style Warning -Property 'Security Filtering'
                            }

                            $TableParams = @{
                                Name = "GPO - $($Domain.ToString().ToUpper())"
                                List = $false
                                ColumnWidths = 45, 25, 30
                            }

                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $OutObj | Sort-Object -Property 'GPO Name' | Table @TableParams
                            if ($HealthCheck.Domain.GPO -and (($OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'}) -or ($OutObj | Where-Object { $_.'Security Filtering' -like 'No Security Filtering'}))) {
                                Paragraph "Health Check:" -Italic -Bold -Underline
                                BlankLine
                                if (($OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'})) {
                                    Paragraph "Best Practices: Ensure 'All Settings Disabled' GPO are removed from Active Directory." -Italic -Bold
                                    BlankLine
                                }
                                if (($OutObj | Where-Object { $_.'Security Filtering' -like 'No Security Filtering'})) {
                                    Paragraph "Corrective Actions: Determine which 'No Security Filtering' Group Policies should be deleted and delete them." -Italic -Bold
                                }
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Group Policy Objects)"
                        }
                    }
                    if ($InfoLevel.Domain -ge 2) {
                        try {
                            foreach ($GPO in $GPOs) {
                                Section -ExcludeFromTOC -Style NOTOCHeading6 "$($GPO.DisplayName)" {
                                    try {
                                        Write-PscriboMessage "Collecting Active Directory Group Policy Objects '$($GPO.DisplayName)'. (Group Policy Objects)"
                                        $inObj = [ordered] @{
                                            'GPO Status' = ($GPO.GpoStatus -creplace  '([A-Z\W_]|\d+)(?<![a-z])',' $&').trim()
                                            'GUID' = $GPO.Id
                                            'Created' = $GPO.CreationTime.ToString("MM/dd/yyyy")
                                            'Modified' = $GPO.ModificationTime.ToString("MM/dd/yyyy")
                                            'Description' = ConvertTo-EmptyToFiller $GPO.Description
                                            'Owner' = $GPO.Owner
                                            # Todo: Find a way to extract wmifilter Name
                                            'WMI Filter' = &{
                                                $WMIFilter = Invoke-Command -Session $TempPssSession -ScriptBlock {((Get-Gpo -DomainName $using:Domain  -Name $using:GPO.DisplayName).WMifilter.Name)}
                                                if ($WMIFilter) {
                                                    $WMIFilter
                                                } else {'--'}
                                            }
                                            'Security Filtering' =  &{
                                                $GPOSECFILTER = Invoke-Command -Session $TempPssSession -ScriptBlock {(Get-GPPermission -DomainName $using:Domain -All -Guid ($using:GPO).ID | Where-Object {$_.Permission -eq 'GpoApply'}).Trustee.Name}
                                                if ($GPOSECFILTER) {

                                                    return $GPOSECFILTER

                                                } else {'No Security Filtering'}
                                            }
                                        }

                                        $OutObj = [pscustomobject]$inobj

                                        if ($HealthCheck.Domain.GPO) {
                                            $OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'} | Set-Style -Style Warning -Property 'GPO Status'
                                            $OutObj | Where-Object {$Null -eq $_.'Owner'} | Set-Style -Style Warning -Property 'Owner'
                                            $OutObj | Where-Object { $_.'Security Filtering' -like 'No Security Filtering'} | Set-Style -Style Warning -Property 'Security Filtering'
                                        }

                                        $TableParams = @{
                                            Name = "GPO - $($GPO.DisplayName)"
                                            List = $true
                                            ColumnWidths = 40, 60
                                        }

                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $OutObj | Table @TableParams
                                        if ($HealthCheck.Domain.GPO -and (($OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'}) -or ($OutObj | Where-Object { $_.'Security Filtering' -like 'No Security Filtering'}))) {
                                            Paragraph "Health Check:" -Italic -Bold -Underline
                                            BlankLine
                                            if (($OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'})) {
                                                Paragraph "Best Practices: Ensure 'All Settings Disabled' GPO are removed from Active Directory." -Italic -Bold
                                                BlankLine
                                            }
                                            if (($OutObj | Where-Object { $_.'Security Filtering' -like 'No Security Filtering'})) {
                                                Paragraph "Corrective Actions: Determine which 'No Security Filtering' Group Policies should be deleted and delete them." -Italic -Bold
                                            }
                                        }
                                    }
                                    catch {
                                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Group Policy Objects)"
                                    }
                                }
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Group Policy Objects)"
                        }
                    }
                    try {
                        $PATH = "\\$Domain\SYSVOL\$Domain\Policies\PolicyDefinitions"
                        $CentralStore = Invoke-Command -Session $TempPssSession -ScriptBlock {Test-Path $using:PATH}
                        if ($PATH) {
                            Section -Style Heading6 "Central Store Repository" {
                                $OutObj = @()
                                Write-PscriboMessage "Discovered Active Directory Central Store information on $Domain. (Central Store)"
                                $inObj = [ordered] @{
                                    'Domain' = $Domain.ToString().ToUpper()
                                    'Configured' = ConvertTo-TextYN $CentralStore
                                    'Central Store Path' = "\\$Domain\SYSVOL\$Domain\Policies\PolicyDefinitions"
                                }
                                $OutObj = [pscustomobject]$inobj

                                if ($HealthCheck.Domain.GPO) {
                                    $OutObj | Where-Object { $_.'Configured' -eq 'No'} | Set-Style -Style Warning -Property 'Configured'
                                }

                                $TableParams = @{
                                    Name = "GPO Central Store - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 25, 15, 60
                                }

                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Table @TableParams
                                if ($HealthCheck.Domain.GPO -and ($OutObj | Where-Object { $_.'Configured' -eq 'No'})) {
                                    Paragraph "Health Check:" -Italic -Bold -Underline
                                    BlankLine
                                    Paragraph "Best Practices: Ensure Central Store is deployed to centralized GPO repository." -Italic -Bold
                                }
                            }
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (GPO Central Store)"
                    }
                    try {
                        if ($GPOs) {
                            Write-PscriboMessage "Discovered Active Directory Group Policy Objects information on $Domain. (Group Policy Objects)"
                            $OutObj = @()
                            foreach ($GPO in $GPOs) {
                                try {
                                    [xml]$Gpoxml =  Invoke-Command -Session $TempPssSession -ScriptBlock {Get-GPOReport -Domain $using:Domain -ReportType Xml -Guid ($using:GPO).Id}
                                    $UserScripts = $Gpoxml.GPO.User.ExtensionData | Where-Object { $_.Name -eq 'Scripts' }
                                    if ($UserScripts.extension.Script) {
                                        foreach ($Script in $UserScripts.extension.Script) {
                                            try {
                                                Write-PscriboMessage "Collecting Active Directory Group Policy Objects with Logon/Logoff Script '$($GPO.DisplayName)'."
                                                $inObj = [ordered] @{
                                                    'GPO Name' = $GPO.DisplayName
                                                    'GPO Status' = ($GPO.GpoStatus -creplace  '([A-Z\W_]|\d+)(?<![a-z])',' $&').trim()
                                                    'Type' = $Script.Type
                                                    'Script' = $Script.command
                                                }
                                                $OutObj += [pscustomobject]$inobj
                                            }
                                            catch {
                                                Write-PscriboMessage -IsWarning $_.Exception.Message
                                            }
                                        }
                                    }
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (GPO with Logon/Logoff Script Item)"
                                }
                            }
                        }
                        if ($OutObj) {
                            Section -Style Heading6 "User Logon/Logoff Script" {
                                if ($HealthCheck.Domain.GPO) {
                                    $OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'} | Set-Style -Style Warning -Property 'GPO Status'
                                }

                                $TableParams = @{
                                    Name = "GPO with Logon/Logoff Script - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 20, 15, 15, 50
                                }

                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'GPO Name' | Table @TableParams
                            }
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (GPO with Logon/Logoff Script Section)"
                    }
                    try {
                        if ($GPOs) {
                            $OutObj = @()
                            Write-PscriboMessage "Discovered Active Directory Group Policy Objects information on $Domain. (Group Policy Objects)"
                            foreach ($GPO in $GPOs) {
                                try {
                                    [xml]$Gpoxml =  Invoke-Command -Session $TempPssSession -ScriptBlock {Get-GPOReport -Domain $using:Domain -ReportType Xml -Guid ($using:GPO).Id}
                                    $ComputerScripts = $Gpoxml.GPO.Computer.ExtensionData | Where-Object { $_.Name -eq 'Scripts' }
                                    if ($ComputerScripts.extension.Script) {
                                        foreach ($Script in $ComputerScripts.extension.Script) {
                                            try {
                                                Write-PscriboMessage "Collecting Active Directory Group Policy Objects with Startup/Shutdown Script '$($GPO.DisplayName)'."
                                                $inObj = [ordered] @{
                                                    'GPO Name' = $GPO.DisplayName
                                                    'GPO Status' = ($GPO.GpoStatus -creplace  '([A-Z\W_]|\d+)(?<![a-z])',' $&').trim()
                                                    'Type' = $Script.Type
                                                    'Script' = $Script.command
                                                }
                                                $OutObj += [pscustomobject]$inobj
                                            }
                                            catch {
                                                Write-PscriboMessage -IsWarning "$($_.Exception.Message) (GPO with Computer Startup/Shutdown Script Item)"
                                            }
                                        }
                                    }
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (GPO with Computer Startup/Shutdown Script)"
                                }
                            }
                        }
                        if ($OutObj) {
                            Section -Style Heading6 "Computer Startup/Shutdown Script" {
                                if ($HealthCheck.Domain.GPO) {
                                    $OutObj | Where-Object { $_.'GPO Status' -like 'All Settings Disabled'} | Set-Style -Style Warning -Property 'GPO Status'
                                }

                                $TableParams = @{
                                    Name = "GPO with Startup/Shutdown Script - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 20, 15, 15, 50
                                }

                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'GPO Name' | Table @TableParams
                            }

                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (GPO with Computer Startup/Shutdown Script Section)"
                    }
                }
                if ($HealthCheck.Domain.GPO) {
                    try {
                        $OutObj = @()
                        if ($GPOs) {
                            Write-PscriboMessage "Discovered Active Directory Group Policy Objects information on $Domain. (Group Policy Objects)"
                            foreach ($GPO in $GPOs) {
                                try {
                                    [xml]$Gpoxml =  Invoke-Command -Session $TempPssSession -ScriptBlock {Get-GPOReport -Domain $using:Domain -ReportType Xml -Guid ($using:GPO).Id}
                                    if (($Null -ne $Gpoxml.GPO.Name) -and ($Null -eq $Gpoxml.GPO.LinksTo.SOMPath)) {
                                        Write-PscriboMessage "Collecting Active Directory Unlinked Group Policy Objects '$($Gpoxml.GPO.Name)'."
                                        $inObj = [ordered] @{
                                            'GPO Name' = $Gpoxml.GPO.Name
                                            'Created' = ($Gpoxml.GPO.CreatedTime).ToString().split("T")[0]
                                            'Modified' = ($Gpoxml.GPO.ModifiedTime).ToString().split("T")[0]
                                            'Computer Enabled' = ConvertTo-TextYN $gpoxml.GPO.Computer.Enabled
                                            'User Enabled' = ConvertTo-TextYN $gpoxml.GPO.User.Enabled
                                        }
                                        $OutObj += [pscustomobject]$inobj
                                    }
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Unlinked Group Policy Objects Item)"
                                }
                            }
                        }
                        if ($OutObj) {
                            Section -Style Heading6 "Unlinked GPO" {
                                if ($HealthCheck.Domain.GPO) {
                                    $OutObj | Set-Style -Style Warning
                                }

                                $TableParams = @{
                                    Name = "Unlinked GPO - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 40, 15, 15, 15, 15
                                }

                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'GPO Name' | Table @TableParams
                                Paragraph "Health Check:" -Italic -Bold -Underline
                                BlankLine
                                Paragraph "Corrective Actions: Remove Unused GPO from Active Directory." -Italic -Bold
                            }
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Unlinked Group Policy Objects Section)"
                    }
                    try {
                        $OutObj = @()
                        if ($GPOs) {
                            Write-PscriboMessage "Discovered Active Directory Group Policy Objects information on $Domain. (Group Policy Objects)"
                            foreach ($GPO in $GPOs) {
                                try {
                                    [xml]$Gpoxml =  Invoke-Command -Session $TempPssSession -ScriptBlock {Get-GPOReport -Domain $using:Domain -ReportType Xml -Guid ($using:GPO).Id}
                                    if (($Null -eq ($Gpoxml.GPO.Computer.ExtensionData)) -and ($Null -eq ($Gpoxml.GPO.User.extensionData))) {
                                        Write-PscriboMessage "Collecting Active Directory Empty Group Policy Objects '$($Gpoxml.GPO.Name)'."
                                        $inObj = [ordered] @{
                                            'GPO Name' = $Gpoxml.GPO.Name
                                            'Created' = ($Gpoxml.GPO.CreatedTime).ToString().split("T")[0]
                                            'Modified' = ($Gpoxml.GPO.ModifiedTime).ToString().split("T")[0]
                                            'Description' = ConvertTo-EmptyToFiller $Gpoxml.GPO.Description
                                        }
                                        $OutObj += [pscustomobject]$inobj
                                    }
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Empty Group Policy Objects Item)"
                                }
                            }
                        }
                        if ($OutObj) {
                            Section -Style Heading6 "Empty GPOs" {
                                if ($HealthCheck.Domain.GPO) {
                                    $OutObj | Set-Style -Style Warning
                                }

                                $TableParams = @{
                                    Name = "Empty GPO - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 35, 15, 15, 35
                                }

                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'GPO Name' | Table @TableParams
                                Paragraph "Health Check:" -Italic -Bold -Underline
                                BlankLine
                                Paragraph "Corrective Actions: No User and Computer parameters are set: Remove Unused GPO in Active Directory." -Italic -Bold
                            }
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Empty Group Policy Objects Section)"
                    }
                    try {
                        $OutObj = @()
                        Write-PscriboMessage "Discovered Active Directory Group Policy Objects information on $Domain. (Group Policy Objects)"
                        $DC = Invoke-Command -Session $TempPssSession {Get-ADDomain -Identity $using:Domain | Select-Object -ExpandProperty ReplicaDirectoryServers | Select-Object -First 1}
                        Write-PscriboMessage "Discovered Active Directory Domain Controller $DC in $Domain. (Group Policy Objects)"
                        $OUs = Invoke-Command -Session $TempPssSession -ScriptBlock {Get-ADOrganizationalUnit -Server $using:DC -Filter * | Select-Object -Property DistinguishedName}
                        if ($OUs) {
                            foreach ($OU in $OUs) {
                                try {
                                    $GpoEnforced = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-GPInheritance -Domain $using:Domain -Server $using:DC -Target ($using:OU).DistinguishedName | Select-Object -ExpandProperty GpoLinks }
                                    if ($GpoEnforced.Enforced -eq "True") {
                                        Write-PscriboMessage "Collecting Active Directory Enforced owned Group Policy Objects'$($GpoEnforced.DisplayName)'."
                                        $TargetCanonical = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-ADObject -Server $using:DC -Identity ($using:GpoEnforced).Target -Properties * | Select-Object -ExpandProperty CanonicalName }
                                        $inObj = [ordered] @{
                                            'GPO Name' = $GpoEnforced.DisplayName
                                            'Enforced' = ConvertTo-TextYN $GpoEnforced.Enforced
                                            'Order' = $GpoEnforced.Order
                                            'Target' = $TargetCanonical
                                        }
                                        $OutObj += [pscustomobject]$inobj
                                    }
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Enforced Group Policy Objects Item)"
                                }
                            }
                        }

                        if ($OutObj) {
                            Section -Style Heading6 "Enforced GPO" {
                                if ($HealthCheck.Domain.GPO) {
                                    $OutObj | Set-Style -Style Warning
                                }

                                $TableParams = @{
                                    Name = "Enforced GPO - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 35, 15, 15, 35
                                }

                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'GPO Name' | Table @TableParams
                                Paragraph "Health Check:" -Italic -Bold -Underline
                                BlankLine
                                Paragraph "Corrective Actions: Review use of enforcement and blocked policy inheritance in Active Directory." -Italic -Bold

                            }
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Enforced Group Policy Objects Table)"
                    }
                    # Code taken from Jeremy Saunders
                    # https://github.com/jeremyts/ActiveDirectoryDomainServices/blob/master/Audit/FindOrphanedGPOs.ps1
                    try {
                        $DC = Invoke-Command -Session $TempPssSession {Get-ADDomain -Identity $using:Domain | Select-Object -ExpandProperty ReplicaDirectoryServers | Select-Object -First 1}
                        $DCPssSession = New-PSSession $DC -Credential $Credential -Authentication $Options.PSDefaultAuthentication
                        $DomainInfo =  Invoke-Command -Session $TempPssSession {Get-ADDomain $using:Domain -ErrorAction Stop}
                        $GPOPoliciesSYSVOLUNC = "\\$Domain\SYSVOL\$Domain\Policies"
                        $OrphanGPOs = @()
                        $GPOPoliciesADSI = (Get-ADObjectSearch -DN "CN=Policies,CN=System,$($DomainInfo.DistinguishedName)" -Filter { objectClass -eq "groupPolicyContainer" } -Properties "Name" -SelectPrty 'Name' -Session $DCPssSession).Name.Trim("{}") | Sort-Object
                        if ($DCPssSession) {
                            Remove-PSSession -Session $DCPssSession
                        }
                        $GPOPoliciesSYSVOL = (Invoke-Command -Session $TempPssSession -ScriptBlock {Get-ChildItem $using:GPOPoliciesSYSVOLUNC | Sort-Object}).Name.Trim("{}")
                        $SYSVOLGPOList = @()
                        ForEach ($GPOinSYSVOL in $GPOPoliciesSYSVOL) {
                            If ($GPOinSYSVOL -ne "PolicyDefinitions") {
                                $SYSVOLGPOList += $GPOinSYSVOL
                            }
                        }
                        $MissingADGPOs = Compare-Object $SYSVOLGPOList $GPOPoliciesADSI -passThru | Where-Object { $_.SideIndicator -eq '<=' }
                        $MissingSYSVOLGPOs = Compare-Object $GPOPoliciesADSI $SYSVOLGPOList -passThru | Where-Object { $_.SideIndicator -eq '<=' }
                        $OrphanGPOs += $MissingADGPOs
                        $OrphanGPOs += $MissingSYSVOLGPOs
                        if ($OrphanGPOs) {
                            Section -Style Heading6 "Orphaned GPO" {
                                Paragraph "The following table summarizes the group policy objects that are orphaned or missing in the AD database or in the SYSVOL directory."
                                BlankLine
                                $OutObj = @()
                                Write-PscriboMessage "Discovered orphaned gpo information on $Domain. (Orphaned GPO)"
                                foreach ($OrphanGPO in $OrphanGPOs) {
                                    $inObj = [ordered] @{
                                        'Name' = Switch (($GPOs | Where-Object {$_.id -eq $OrphanGPO}).DisplayName) {
                                            $Null {'Unknown'}
                                            default {($GPOs | Where-Object {$_.id -eq $OrphanGPO}).DisplayName}
                                        }
                                        'Guid' = $OrphanGPO
                                        'AD DN Database' = &{
                                            if ($OrphanGPO -in $MissingADGPOs) {
                                                return "Missing"
                                            } else {'Valid'}
                                        }
                                        'AD DN Path' = &{
                                            if ($OrphanGPO -in $MissingADGPOs) {
                                                return "CN={$($OrphanGPO)},CN=Policies,CN=System,$($DomainInfo.DistinguishedName) (Missing)"
                                            } else {"CN={$($OrphanGPO)},CN=Policies,CN=System,$($DomainInfo.DistinguishedName) (Valid)"}
                                        }
                                        'SYSVOL Guid Directory' = &{
                                            if ($OrphanGPO -in $MissingSYSVOLGPOs) {
                                                return "Missing"
                                            } else {'Valid'}
                                        }
                                        'SYSVOL Guid Path' = &{
                                            if ($OrphanGPO -in $MissingSYSVOLGPOs) {
                                                return "\\$Domain\SYSVOL\$Domain\Policies\{$($OrphanGPO)} (Missing)"
                                            } else {"\\$Domain\SYSVOL\$Domain\Policies\{$($OrphanGPO)} (Valid)"}
                                        }
                                    }
                                    $OutObj = [pscustomobject]$inobj

                                    if ($HealthCheck.Domain.GPO) {
                                        $OutObj | Where-Object { $_.'AD DN Database' -eq 'Missing'} | Set-Style -Style Warning -Property 'AD DN Database','AD DN Path'
                                        $OutObj | Where-Object { $_.'SYSVOL Guid Directory' -eq 'Missing'} | Set-Style -Style Warning -Property 'SYSVOL Guid Directory','SYSVOL Guid Path'
                                    }

                                    $TableParams = @{
                                        Name = "Orphaned GPO - $($Domain.ToString().ToUpper())"
                                        List = $true
                                        ColumnWidths = 40, 60
                                    }

                                    if ($Report.ShowTableCaptions) {
                                        $TableParams['Caption'] = "- $($TableParams.Name)"
                                    }
                                    $OutObj | Table @TableParams
                                    if ($HealthCheck.Domain.GPO -and (($OutObj | Where-Object { $_.'AD DN Database' -eq 'Missing'}) -or ($OutObj | Where-Object { $_.'SYSVOL Guid Directory' -eq 'Missing'}))) {
                                        Paragraph "Health Check:" -Italic -Bold -Underline
                                        BlankLine
                                        if ($OutObj | Where-Object { $_.'AD DN Database' -eq 'Missing'}) {
                                            Paragraph "Corrective Actions: Evaluate orphaned group policies objects that exist in SYSVOL but not in AD or the Group Policy Management Console (GPMC). These take up space in SYSVOL and bandwidth during replication." -Italic -Bold
                                            BlankLine
                                        }
                                        if ($OutObj | Where-Object { $_.'SYSVOL Guid Directory' -eq 'Missing'}) {
                                            Paragraph "Corrective Actions: Evaluate orphaned group policies folders and files that exist in AD or the Group Policy Management Console (GPMC) but not in SYSVOL. These take up space in the AD database and bandwidth during replication." -Italic -Bold
                                            BlankLine
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Orphaned GPO)"
                    }
                }
            }
        }
        catch {
            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Group Policy Objects Section)"
        }
    }


    end {}

}