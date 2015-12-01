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
            .EXAMPLE
            Reset-CBT -VM 'WAHLNETWORK' -vCenter VCENTER.DOMAIN.LOCAL
            Disables CBT for a VM named WAHLNETWORK, then creates and consolidates (remove) a snapshot to flush the CBT file. The assumption here is that your backup software will then re-enable CBT during the next backup job.
            .EXAMPLE
            Reset-CBT -VM 'WAHLNETWORK' -vCenter VCENTER.DOMAIN.LOCAL -NoSnapshots
            Disables CBT for a VM named WAHLNETWORK but will not use a snapshot to flush the CBT file. This is useful for environments where you simply want to disable CBT and do not have backup software that will go back and re-enable CBT.
            .EXAMPLE
            Reset-CBT -VM $VMlist -vCenter VCENTER.DOMAIN.LOCAL
            Disables CBT for all VMs in the list $VMlist, which can be useful for more targeted lists of virtual machines that don't easily match a regular expression.
            Here are some methods to build $VMlist

            $VMlist = Get-VM -Location (Get-Folder 'Test Servers')
            $VMlist = Get-VM -Location (Get-DataCenter 'Austin')
            .EXAMPLE
            Get-VM -Location (Get-Folder 'Test Servers') | Reset-CBT -vCenter VCENTER.DOMAIN.LOCAL
            Similar to the previous example, except that it uses a pipeline for the list of virtual machines.
            .EXAMPLE
            Reset-CBT -VM 'WAHLNETWORK' -vCenter VCENTER.DOMAIN.LOCAL -EnableCBT
            Enables CBT for a VM named WAHLNETWORK. No other activities are performed. This is useful for when you want to enable CBT for one or more virtual machines.
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
        [Switch]$EnableCBT,
        [Parameter(Mandatory = $false,Position = 3,HelpMessage = 'Prevents usings snapshots from flushing the CBT file')]
        [ValidateNotNullorEmpty()]
        [Switch]$NoSnapshots
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
                    Write-Verbose -Message "Reconfiguring $($_.name) to disable CBT" -Verbose
                    $vmconfigspec.ChangeTrackingEnabled = $false
                    $_.ExtensionData.ReconfigVM($vmconfigspec)

                    if ($NoSnapshots -ne $true)
                    {
                        Write-Verbose -Message "Creating a snapshot on $($_.name) to clear CBT file" -Verbose
                        $null = New-Snapshot -VM $_ -Name 'CBT Cleanup'

                        Write-Verbose -Message "Removing snapshot on $($_.name)" -Verbose
                        $null = $_ |
                        Get-Snapshot |
                        Remove-Snapshot -RemoveChildren -Confirm:$false
                    }
                }
                catch 
                {
                    throw $_
                }
            }
            elseif ($EnableCBT -and $_.ExtensionData.Config.ChangeTrackingEnabled -eq $false)
            {
                Write-Verbose -Message "Reconfiguring $($_.name) to enable CBT" -Verbose
                $vmconfigspec.ChangeTrackingEnabled = $true
                $_.ExtensionData.ReconfigVM($vmconfigspec)
            }
            else 
            {
                if ($_.PowerState -ne 'PoweredOn' -and $EnableCBT -ne $true) 
                {
                    Write-Warning -Message "Skipping $_ - Not powered on"
                    $notfixedvm += $_
                }
                if ($_.ExtensionData.Snapshot -ne $null -and $EnableCBT -ne $true) 
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