function Get-AbrADDNSInfrastructure {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Microsoft AD Domain Name System Infrastructure information.
    .DESCRIPTION

    .NOTES
        Version:        0.9.1
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
        Write-PScriboMessage "Collecting Active Directory Domain Name System Infrastructure information for $Domain"
    }

    process {
        try {
            $DCs = Invoke-Command -Session $TempPssSession { Get-ADDomain -Identity $using:Domain | Select-Object -ExpandProperty ReplicaDirectoryServers | Where-Object { $_ -notin ($using:Options).Exclude.DCs } }
            if ($DCs) {
                Section -Style Heading3 "Infrastructure Summary" {
                    Paragraph "The following section provides a summary of the DNS Infrastructure configuration."
                    BlankLine
                    $OutObj = @()
                    foreach ($DC in $DCs) {
                        if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                            try {
                                $DNSSetting = Get-DnsServerSetting -CimSession $TempCIMSession -ComputerName $DC
                                $inObj = [ordered] @{
                                    'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                    'Build Number' = $DNSSetting.BuildNumber
                                    'IPv6' = ($DNSSetting.EnableIPv6)
                                    'DnsSec' = ($DNSSetting.EnableDnsSec)
                                    'ReadOnly DC' = ($DNSSetting.IsReadOnlyDC)
                                    'Listening IP' = $DNSSetting.ListeningIPAddress
                                }
                                $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                            } catch {
                                Write-PScriboMessage -IsWarning "DNS Infrastructure Summary Section: $($_.Exception.Message)"
                            }
                        } else {
                            Write-PScriboMessage -IsWarning "DNS Infrastructure Summary Section: Unable to connect to DC server $DC"
                        }
                    }

                    $TableParams = @{
                        Name = "Infrastructure Summary - $($Domain.ToString().ToUpper())"
                        List = $false
                        ColumnWidths = 30, 10, 9, 10, 11, 30
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                    #---------------------------------------------------------------------------------------------#
                    #                            DNS Aplication Partitions Section                                #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading4 "Application Directory Partition" {
                                Paragraph "The following section provides Directory Partition information."
                                BlankLine
                                foreach ($DC in $DCs) {
                                    if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                                        try {
                                            Section -ExcludeFromTOC -Style NOTOCHeading5 $($DC.ToString().ToUpper().Split(".")[0]) {
                                                $OutObj = @()
                                                $DNSSetting = Get-DnsServerDirectoryPartition -CimSession $TempCIMSession -ComputerName $DC
                                                foreach ($Partition in $DNSSetting) {
                                                    try {
                                                        $inObj = [ordered] @{
                                                            'Name' = $Partition.DirectoryPartitionName
                                                            'State' = Switch ($Partition.State) {
                                                                $Null { '--' }
                                                                0 { 'DNS_DP_OKAY' }
                                                                1 { 'DNS_DP_STATE_REPL_INCOMING' }
                                                                2 { 'DNS_DP_STATE_REPL_OUTGOING' }
                                                                3 { 'DNS_DP_STATE_UNKNOWN' }
                                                                default { $Partition.State }
                                                            }
                                                            'Flags' = $Partition.Flags
                                                            'Zone Count' = $Partition.ZoneCount
                                                        }
                                                        $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                    } catch {
                                                        Write-PScriboMessage -IsWarning "Directory Partitions Item Section: $($_.Exception.Message)"
                                                    }
                                                }
                                                $TableParams = @{
                                                    Name = "Directory Partitions - $($DC.ToString().ToUpper().Split(".")[0])"
                                                    List = $false
                                                    ColumnWidths = 40, 25, 25, 10
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $OutObj | Sort-Object -Property 'Name' | Table @TableParams
                                            }
                                        } catch {
                                            Write-PScriboMessage -IsWarning "Directory Partitions Table Section: $($_.Exception.Message)"
                                        }
                                    } else {
                                        Write-PScriboMessage -IsWarning "DNS Directory Partition Section: Unable to connect to DC server $DC"
                                    }
                                }
                            }
                        } catch {
                            Write-PScriboMessage -IsWarning "Directory Partitions Section: $($_.Exception.Message)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS RRL Section                                             #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading4 "Response Rate Limiting (RRL)" {
                                $OutObj = @()
                                foreach ($DC in $DCs) {
                                    if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                                        try {
                                            $DNSSetting = Get-DnsServerResponseRateLimiting -CimSession $TempCIMSession -ComputerName $DC
                                            $inObj = [ordered] @{
                                                'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                                'Status' = $DNSSetting.Mode
                                                'Responses Per Sec' = $DNSSetting.ResponsesPerSec
                                                'Errors Per Sec' = $DNSSetting.ErrorsPerSec
                                                'Window In Sec' = $DNSSetting.WindowInSec
                                                'Leak Rate' = $DNSSetting.LeakRate
                                                'Truncate Rate' = $DNSSetting.TruncateRate

                                            }
                                            $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                        } catch {
                                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Response Rate Limiting (RRL) Item)"
                                        }
                                    } else {
                                        Write-PScriboMessage -IsWarning "DNS Response Rate Limiting (RRL) Section: Unable to connect to DC server $DC"
                                    }
                                }

                                $TableParams = @{
                                    Name = "Response Rate Limiting - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 30, 10, 12, 12, 12, 12, 12
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            }
                        } catch {
                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Response Rate Limiting (RRL) Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Scanvenging Section                                     #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading4 "Scavenging Options" {
                                $OutObj = @()
                                foreach ($DC in $DCs) {
                                    if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                                        try {
                                            $DNSSetting = Get-DnsServerScavenging -CimSession $TempCIMSession -ComputerName $DC
                                            $inObj = [ordered] @{
                                                'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                                'NoRefresh Interval' = $DNSSetting.NoRefreshInterval
                                                'Refresh Interval' = $DNSSetting.RefreshInterval
                                                'Scavenging Interval' = $DNSSetting.ScavengingInterval
                                                'Last Scavenge Time' = Switch ($DNSSetting.LastScavengeTime) {
                                                    "" { "--"; break }
                                                    $Null { "--"; break }
                                                    default { ($DNSSetting.LastScavengeTime.ToString("MM/dd/yyyy")) }
                                                }
                                                'Scavenging State' = Switch ($DNSSetting.ScavengingState) {
                                                    "True" { "Enabled" }
                                                    "False" { "Disabled" }
                                                    default { $DNSSetting.ScavengingState }
                                                }
                                            }
                                            $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                        } catch {
                                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Scavenging Item)"
                                        }
                                    } else {
                                        Write-PScriboMessage -IsWarning "DNS Scavenging Section: Unable to connect to DC server $DC"
                                    }
                                }

                                if ($HealthCheck.DNS.Zones) {
                                    $OutObj | Where-Object { $_.'Scavenging State' -eq 'Disabled' } | Set-Style -Style Warning -Property 'Scavenging State'
                                }

                                $TableParams = @{
                                    Name = "Scavenging - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 25, 15, 15, 15, 15, 15
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                                if ($HealthCheck.DNS.Zones -and ($OutObj | Where-Object { $_.'Scavenging State' -eq 'Disabled' })) {
                                    Paragraph "Health Check:" -Bold -Underline
                                    BlankLine
                                    Paragraph {
                                        Text "Best Practices:" -Bold
                                        Text "Microsoft recommends to enable aging/scavenging on all DNS servers. However, with AD-integrated zones ensure to enable DNS scavenging on one DC at main site. The results will be replicated to other DCs."
                                    }
                                }
                            }
                        } catch {
                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Scavenging Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Forwarder Section                                       #
                    #---------------------------------------------------------------------------------------------#
                    try {
                        Section -Style Heading4 "Forwarder Options" {
                            $OutObj = @()
                            foreach ($DC in $DCs) {
                                if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                                    try {
                                        $DNSSetting = Get-DnsServerForwarder -CimSession $TempCIMSession -ComputerName $DC
                                        $Recursion = Get-DnsServerRecursion -CimSession $TempCIMSession -ComputerName $DC | Select-Object -ExpandProperty Enable
                                        $inObj = [ordered] @{
                                            'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                            'IP Address' = $DNSSetting.IPAddress.IPAddressToString
                                            'Timeout' = ("$($DNSSetting.Timeout)/s")
                                            'Use Root Hint' = ($DNSSetting.UseRootHint)
                                            'Use Recursion' = ($Recursion)
                                        }
                                        $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                    } catch {
                                        Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Forwarder Item)"
                                    }
                                } else {
                                    Write-PScriboMessage -IsWarning "DNS Forwarder Section: Unable to connect to DC server $DC"
                                }
                            }

                            if ($HealthCheck.DNS.BestPractice) {
                                $OutObj | Where-Object { $_.'IP Address'.Count -gt 2 } | Set-Style -Style Warning -Property 'IP Address'
                                $OutObj | Where-Object { $_.'IP Address'.Count -lt 2 } | Set-Style -Style Warning -Property 'IP Address'
                            }

                            $TableParams = @{
                                Name = "Forwarders - $($Domain.ToString().ToUpper())"
                                List = $false
                                ColumnWidths = 35, 15, 15, 15, 20
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            if ($HealthCheck.DNS.BestPractice -and (($OutObj | Where-Object { $_.'IP Address' -gt 2 }) -or ($OutObj | Where-Object { $_.'IP Address'.Count -lt 2 }))) {
                                Paragraph "Health Check:" -Bold -Underline
                                BlankLine
                                if ($OutObj | Where-Object { $_.'IP Address' -gt 2 }) {

                                    Paragraph {
                                        Text "Best Practices:" -Bold
                                        Text "Configure the servers to use no more than two external DNS servers as Forwarders."
                                    }
                                    BlankLine
                                    Paragraph {
                                        Text "Reference:" -Bold
                                        Text "https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/forwarders-resolution-timeouts" -Color blue
                                    }
                                    BlankLine
                                }
                                if ($OutObj | Where-Object { $_.'IP Address'.Count -lt 2 }) {
                                    Paragraph {
                                        Text "Best Practices:" -Bold
                                        Text "For redundancy reason, more than one forwarding server should be configured"
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Forwarder Table)"
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Root Hints Section                                      #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading4 "Root Hints" {
                                Paragraph "The following section provides Root Hints information from domain $($Domain)."
                                BlankLine
                                foreach ($DC in $DCs) {
                                    if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                                        try {
                                            Section -ExcludeFromTOC -Style NOTOCHeading5 $($DC.ToString().ToUpper().Split(".")[0]) {
                                                $OutObj = @()
                                                $DNSSetting = Get-DnsServerRootHint -CimSession $TempCIMSession -ComputerName $DC -ErrorAction SilentlyContinue | Select-Object @{Name = "Name"; E = { $_.NameServer.RecordData.Nameserver } }, @{ Name = "IPv4Address"; E = { $_.IPAddress.RecordData.IPv4Address.IPAddressToString } }, @{ Name = "IPv6Address"; E = { $_.IPAddress.RecordData.IPv6Address.IPAddressToString } }
                                                if ($DNSSetting) {
                                                    foreach ($Hints in $DNSSetting) {
                                                        try {
                                                            $inObj = [ordered] @{
                                                                'Name' = $Hints.Name
                                                                'IPv4 Address' = Switch ([string]::IsNullOrEmpty($Hints.IPv4Address)) {
                                                                    $true { '--' }
                                                                    $false { $Hints.IPv4Address -split " " }
                                                                    default { 'Unknown' }
                                                                }
                                                                'IPv6 Address' = Switch ([string]::IsNullOrEmpty($Hints.IPv6Address)) {
                                                                    $true { '--' }
                                                                    $false { $Hints.IPv6Address -split " " }
                                                                    default { 'Unknown' }
                                                                }
                                                            }
                                                            $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                        } catch {
                                                            Write-PScriboMessage -IsWarning $_.Exception.Message
                                                        }
                                                    }
                                                } else {
                                                    $RootServers = @(
                                                        "a.root-servers.net",
                                                        "b.root-servers.net",
                                                        "c.root-servers.net",
                                                        "d.root-servers.net",
                                                        "e.root-servers.net",
                                                        "f.root-servers.net",
                                                        "g.root-servers.net",
                                                        "h.root-servers.net",
                                                        "i.root-servers.net",
                                                        "j.root-servers.net",
                                                        "k.root-servers.net",
                                                        "l.root-servers.net",
                                                        "m.root-servers.net"
                                                    )
                                                    foreach ($server in $RootServers) {
                                                        $inObj = [ordered] @{
                                                            'Name' = $server
                                                            'IPv4 Address' = "--"
                                                            'IPV6 Address' = "--"
                                                        }
                                                        $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                    }

                                                }

                                                if ($HealthCheck.DNS.BestPractice) {
                                                    $OutObj | Where-Object { $_.'IPv4 Address' -eq '--' -and $_.'IPv6 Address' -eq '--' } | Set-Style -Style Warning -Property 'IPv4 Address', 'IPv6 Address'
                                                    $OutObj | Where-Object { $_.'IPv4 Address'.Count -gt 1 } | Set-Style -Style Warning -Property 'IPv4 Address'
                                                    $OutObj | Where-Object { $_.'IPv6 Address'.Count -gt 1 } | Set-Style -Style Warning -Property 'IPv6 Address'
                                                }

                                                $TableParams = @{
                                                    Name = "Root Hints - $($DC.ToString().ToUpper().Split(".")[0])"
                                                    List = $false
                                                    ColumnWidths = 40, 30, 30
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $OutObj | Sort-Object -Property 'Name' | Table @TableParams
                                                if ($HealthCheck.DNS.BestPractice -and (($OutObj | Where-Object { $_.'IPv4 Address' -eq '--' -and $_.'IPv6 Address' -eq '--' }) -or (($OutObj | Where-Object { $_.'IPv4 Address'.Count -gt 1 }) -or ($OutObj | Where-Object { $_.'IPv6 Address'.Count -gt 1 })))) {
                                                    Paragraph "Health Check:" -Bold -Underline
                                                    BlankLine
                                                    if ($OutObj | Where-Object { $_.'IPv4 Address' -eq '--' -and $_.'IPv6 Address' -eq '--' }) {
                                                        Paragraph {
                                                            Text "Corrective Actions:" -Bold
                                                            Text "A default installation of the DNS server role should have root hints unless the server has a root zone - .(root). If the server has a root zone then delete it. If the server doesn't have a root zone and there are no root servers listed on the Root Hints tab of the DNS server properties then the server may be missing the cache.dns file in the %systemroot%\system32\dns directory, which is where the list of root servers is loaded from."
                                                        }
                                                    }
                                                    if (($OutObj | Where-Object { $_.'IPv4 Address'.Count -gt 1 }) -or ($OutObj | Where-Object { $_.'IPv6 Address'.Count -gt 1 })) {
                                                        Paragraph {
                                                            Text "Corrective Actions:" -Bold
                                                            Text "Duplicate IP Address found in the table of the DNS root hints servers. The DNS console does not show the duplicate Root Hint servers; you can only see them using the DNS PowerShell cmdlets. While there is a dnscmd utility to replace the Root Hints file, Using PowerShell is the best way to remediate this issue."
                                                        }
                                                    }
                                                }
                                            }
                                        } catch {
                                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Root Hints Table)"
                                        }
                                    } else {
                                        Write-PScriboMessage -IsWarning "DNS Root Hints Section: Unable to connect to DC server $DC"
                                    }
                                }
                            }
                        } catch {
                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Root Hints Section)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Zone Scope Section                                      #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading4 "Zone Scope Recursion" {
                                $OutObj = @()
                                foreach ($DC in $DCs) {
                                    if (Test-WSMan -Credential $Credential -Authentication $Options.PSDefaultAuthentication -ComputerName $DC -ErrorAction SilentlyContinue) {
                                        try {
                                            $DNSSetting = Get-DnsServerRecursionScope -CimSession $TempCIMSession -ComputerName $DC
                                            $inObj = [ordered] @{
                                                'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                                'Zone Name' = Switch ($DNSSetting.Name) {
                                                    "." { "Root" }
                                                    default { $DNSSetting.Name }
                                                }
                                                'Forwarder' = $DNSSetting.Forwarder
                                                'Use Recursion' = ($DNSSetting.EnableRecursion)
                                            }
                                            $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                        } catch {
                                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Zone Scope Recursion Item)"
                                        }
                                    } else {
                                        Write-PScriboMessage -IsWarning "DNS Zone Scope Recursion Section: Unable to connect to DC server $DC"
                                    }
                                }

                                $TableParams = @{
                                    Name = "Zone Scope Recursion - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 35, 25, 20, 20
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            }
                        } catch {
                            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (Zone Scope Recursion Table)"
                        }
                    }
                }
            }
        } catch {
            Write-PScriboMessage -IsWarning "$($_.Exception.Message) (DNS Infrastructure Section)"
        }
    }

    end {}

}
