#Requires -Version 2
function Reset-CBT
{
    <#  
            .SYNOPSIS
            Resets the Change Block Tracking (CBT) file for affected Virtual Machines
            .DESCRIPTION
            The Reset-CBT cmdlet will reset the Change Block Tracking (CBT) file for a Virtual Machine affected by issues or corruption with the CBT file.
            .NOTES
            Written by Chris Wahl for community usage
            Twitter: @ChrisWahl
            GitHub: chriswahl
            .LINK
            https://github.com/WahlNetwork/powershell-scripts
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,Position = 0,HelpMessage = 'Virtual Machine',ValueFromPipeline = $true)]
        [Alias('Name')]
        [ValidateNotNullorEmpty()]
        $VM,
        [Parameter(Mandatory = $true,Position = 1,HelpMessage = 'vCenter FQDN or IP address')]
        [ValidateNotNullorEmpty()]
        [String]$vCenter,
        [Parameter(Mandatory = $false,Position = 2,HelpMessage = 'Enables CBT for any VMs found with it disabled')]
        [ValidateNotNullorEmpty()]
        [Switch]$EnableCBT
    )

    Process {

        Write-Verbose -Message 'Importing required modules and snapins'
        $powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
        try 
        {
            switch ($powercli.Version.Major) {
                {
                    $_ -ge 6
                }
                {
                    Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
                    Write-Verbose -Message 'PowerCLI 6+ module imported'
                }
                5
                {
                    Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop
                    Write-Warning -Message 'PowerCLI 5 snapin added; recommend upgrading your PowerCLI version'
                }
                default 
                {
                    throw 'This script requires PowerCLI version 5 or later'
                }
            }
        }
        catch 
        {
            throw $_
        }


        Write-Verbose -Message 'Ignoring self-signed SSL certificates for vCenter Server (optional)'
        $null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

        Write-Verbose -Message 'Connecting to vCenter'
        try 
        {
            $null = Connect-VIServer -Server $vCenter -ErrorAction Stop -Session ($global:DefaultVIServers | Where-Object -FilterScript {
                    $_.name -eq $vCenter
            }).sessionId
        }
        catch 
        {
            throw 'Could not connect to vCenter'
        }

        Write-Verbose -Message 'Gathering data on VM inventory'
        $fixvm = Get-VM $VM
        [array]$notfixedvm = $null

        Write-Verbose -Message 'Creating configuration specification'
        $vmconfigspec = New-Object -TypeName VMware.Vim.VirtualMachineConfigSpec
        
        Write-Verbose -Message 'Walking through VM inventory'
        foreach($_ in $fixvm)
        {
            if ($EnableCBT -ne $true -and $_.ExtensionData.Config.ChangeTrackingEnabled -eq $true -and $_.PowerState -eq 'PoweredOn' -and $_.ExtensionData.Snapshot -eq $null)
            {
                try 
                {
                    Write-Verbose -Message "Reconfiguring $($_.name) to disable CBT"
                    $vmconfigspec.ChangeTrackingEnabled = $false
                    $_.ExtensionData.ReconfigVM($vmconfigspec)


                    Write-Verbose -Message "Creating a snapshot on $($_.name) to clear CBT file"
                    New-Snapshot -VM $_ -Name 'CBT Cleanup'

                    Write-Verbose -Message "Removing snapshot on $($_.name)"
                    $_ |
                    Get-Snapshot |
                    Remove-Snapshot -RemoveChildren -Confirm:$false
                }
                catch 
                {
                    throw $_
                }
            }
            elseif ($EnableCBT -and $_.ExtensionData.Config.ChangeTrackingEnabled -eq $false)
            {
                Write-Verbose -Message "Reconfiguring $($_.name) to enable CBT"
                $vmconfigspec.ChangeTrackingEnabled = $true
                $_.ExtensionData.ReconfigVM($vmconfigspec)
            }
            else 
            {
                if ($_.PowerState -ne 'PoweredOn') 
                {
                    Write-Warning -Message "Skipping $_ - Not powered on"
                    $notfixedvm += $_
                }
                if ($_.ExtensionData.Snapshot -ne $null) 
                {
                    Write-Warning -Message "Skipping $_ - Snapshots found"
                    $notfixedvm += $_
                }
            }
        }

        if ($notfixedvm -ne $null)
        {
            Write-Warning -Message 'The following VMs were not altered'
            $notfixedvm | Format-Table -AutoSize
        }

    } # End of process
} # End of function