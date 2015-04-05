# Variables
$vc = "vc1.glacier.local"
$newvm = "Example VM"
$template = "Server 2012 R2 Template"
$custspec = "2012R2_DataCenter_PowerCLI"
$portgroup = "VLAN20-Servers"

# Add the required PowerCLI snapin/module
try
    {
    Import-Module VMware.VimAutomation.Vds -ErrorAction Stop
    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Status: PowerCLI version 6.0+ found."
    }
catch
    {
    try {Add-PSSnapin VMware.VimAutomation.Vds -ErrorAction Stop} catch {throw "You are missing the VMware.VimAutomation.Vds snapin"}
    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Status: PowerCLI prior to version 6.0 found."
    }

# Connect to vCenter
Connect-VIServer $vc | Out-Null

# Update the Customization Specification
Get-OSCustomizationSpec $custspec `
| Get-OSCustomizationNicMapping `
| Set-OSCustomizationNicMapping `
-IpMode:UseStaticIP `
-IpAddress (Read-Host "IP Address: ") `
-SubnetMask (Read-Host "Subnet Mask: ") `
-Dns (Read-Host "DNS Server IP: ") `
-DefaultGateway (Read-Host "Default Gateway IP: ")

# Clone the VM
New-VM -VM $template -Name $newvm -LinkedClone -ReferenceSnapshot "LinkedClone" -Location (Get-Folder Staging) -ResourcePool (Get-Cluster Lab) -OSCustomizationSpec $custspec

# Move VM to correct port group
try {Get-VM $newvm | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $portgroup -Confirm:$false -ErrorAction Stop}
catch {break}