#requires -Version 2

# Variables

$vcenter = 'vc1.glacier.local' 				# Connects to this vCenter Server.
$Cluster = 'Lab'							# Adds templates to this cluster.
$Datastores = 'NAS2-Lab'					# Searches these datastores for templates.
$VMFolder = 'Staging'						# Imports templates into this folder.

# Import modules or snapins
$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered

try 
{
    switch ($powercli.Version.Major) {
        {
            $_ -ge 6
        }
        {
            Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
            Write-Host -Object 'PowerCLI 6+ module imported'
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
    throw 'Could not load the required VMware.VimAutomation.Vds cmdlets'
}

# Ignore self-signed SSL certificates for vCenter Server (optional)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

# Connect to vCenter
try 
{
    $null = Connect-VIServer $vcenter -ErrorAction Stop
}
catch 
{
    throw 'Could not connect to vCenter'
}

# Select an ESXi host to own the templates for the import process
$ESXHost = Get-Cluster $Cluster | Get-VMHost | Select-Object -First 1
 
foreach($Datastore in Get-Datastore $Datastores) 
{
    # Collect .vmtx paths of registered VMs on the datastore
    $registered = @{}
    Get-Template -Datastore $Datastore | ForEach-Object -Process {
        $registered.Add($_.Name+'.vmtx',$true)
    }
 
    # Set up Search for .VMTX Files in Datastore
    $null = New-PSDrive -Name TgtDS -Location $Datastore -PSProvider VimDatastore -Root '\'
    $unregistered = @(Get-ChildItem -Path TgtDS: -Recurse | `
        Where-Object -FilterScript {
            $_.FolderPath -notmatch '.snapshot' -and $_.Name -like '*.vmtx' -and !$registered.ContainsKey($_.Name)
        }
    )
    Remove-PSDrive -Name TgtDS
 
    #Register all .vmtx Files as VMs on the datastore
    foreach($vmtxFile in $unregistered) 
    {
        New-Template -Name $vmtxFile.Name -TemplateFilePath $vmtxFile.DatastoreFullPath -VMHost $ESXHost -Location $VMFolder -RunAsync
    }
}
