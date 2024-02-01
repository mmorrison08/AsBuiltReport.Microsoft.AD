function Get-AbrADCAAIA {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Microsoft Active Directory CA Authority Information Access information.
    .DESCRIPTION

    .NOTES
        Version:        0.8.1
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
        $CA
    )

    begin {
        Write-PScriboMessage "Collecting AD Certification Authority Authority Information Access information."
    }

    process {
        if ($CA) {
            Section -Style Heading3 "Authority Information Access (AIA)" {
                Paragraph "The following section provides the Certification Authority Authority Information Access information."
                BlankLine
                try {
                    $OutObj = @()
                    Write-PScriboMessage "Collecting AD CA Authority Information Access information on $($CA.Name)."
                    $AIA = Get-AuthorityInformationAccess -CertificationAuthority $CA
                    foreach ($URI in $AIA.URI) {
                        try {
                            $inObj = [ordered] @{
                                'Reg URI' = $URI.RegURI
                                'Config URI' = $URI.ConfigURI
                                'Flags' = ConvertTo-EmptyToFiller ($URI.Flags -join ", ")
                                'Server Publish' = ConvertTo-TextYN $URI.ServerPublish
                                'Include To Extension' = ConvertTo-TextYN $URI.IncludeToExtension
                                'OCSP' = ConvertTo-TextYN $URI.OCSP
                            }
                            $OutObj = [pscustomobject]$inobj

                            $TableParams = @{
                                Name = "Authority Information Access - $($CA.Name)"
                                List = $true
                                ColumnWidths = 40, 60
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $OutObj | Table @TableParams
                        } catch {
                            Write-PScriboMessage -IsWarning "Authority Information Access Item $($URI.RegURI) Section: $($_.Exception.Message)"
                        }
                    }
                } catch {
                    Write-PScriboMessage -IsWarning "Authority Information Access Section: $($_.Exception.Message)"
                }
            }
        }
    }

    end {}

}