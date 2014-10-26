cls
<#
vSphere Replication Limits
Scriptable way to toggle your VR bandwidth cap for day, night, weekend, or whatever
Args usage = PSfile "vcenter name" "VDS name to configure" "Mbps limit value"
#>

# Variables
$vcenter = $args[0]
$dvsName = $args[1]
$rpName = "vSphere Replication"
# Set to -1 to go back to unlimited
$newLimit = $args[2]

# Connect to vCenter
If (-not $global:DefaultVIServer) {Connect-VIServer -Server $vcenter}

# Check args
	if (-not $args[2])
		{
		throw "Incorrect format. Provide the vCenter name, VDS name, and limit in Mbps. Example: `"script.ps1 `"vCenter.FQDN`" `"VDS1`" 500`" would set VR bandwidth on VDS1 to 500 Mbps"
		exit		
		}

# Get the VDS details
$dvs = Get-VDSwitch -Name $dvsName
 
# Set the VR network pool to the value provided in args
# The section below was written by Luc Dekens (@LucD22), all credit to him
$rp = $dvs.ExtensionData.NetworkResourcePool | Where {$_.Name -match $rpName}
if($rp){
    $spec = New-Object VMware.Vim.DVSNetworkResourcePoolConfigSpec
    $spec.AllocationInfo = $rp.AllocationInfo
    $spec.AllocationInfo.Limit = [long]$newLimit
    $spec.ConfigVersion = $rp.ConfigVersion
    $spec.Key = $rp.Key
    $dvs.ExtensionData.UpdateNetworkResourcePool(@($spec))
}

# Verify
$rp = $dvs.ExtensionData.NetworkResourcePool | Where {$_.Name -match $rpName}
Write-Host "A limit of" $rp.AllocationInfo.Limit "Mbps has been set on $dvs"
