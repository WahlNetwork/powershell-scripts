function Set-NTPServer {

<#  
.SYNOPSIS  Sets the NTP server values for ESXi hosts
.DESCRIPTION Goes through your ESXi hosts to remove old NTP settings and update with new ones.
.NOTES  Author:  Chris Wahl
.PARAMETER vCenter
	The vCenter Server to connect to
.PARAMETER NTPServer1
	The IP or FQDN or your primary NTP Server
.PARAMETER NTPServer2
	The IP or FQDN or your secondary NTP Server
.PARAMETER Credentials
	Credentials to authenticate with. If none are supplied, the script will prompt for credentials.
.PARAMETER Cluster
	Optional ability to specify a cluster for this script to run against
.EXAMPLE
	PS> Set-NTPServer -vCenter vcenter.fqdn -NTPServer1 1.2.3.4 -NTPServer2 2.3.4.5 -Cluster Production
#>

[CmdletBinding()] 
	param(
		[Parameter(Mandatory=$true,Position=1)]
		[String]$vCenter,
		[Parameter(Mandatory=$true)]
		[String]$NTPServer1,
		[Parameter(Mandatory=$false)]
		[String]$NTPServer2,
		[System.Management.Automation.PSCredential]$Credentials,
		[String]$Cluster
  	)

	Process {
	
	### Connect to vCenter
	if (-not $Credentials) {Connect-VIServer -Server $vCenter -Credential (Get-Credential)}
	else {Connect-VIServer -Server $vCenter -Credential $Credentials}
	
	### Gather ESXi host data for future processing
	if (-not $Cluster) {$Cluster = "*"}
	$VMHosts = Get-VMHost -Location (Get-Cluster $Cluster)

	### Update NTP server info on the ESXi hosts in $vmhosts
	$i = 1
	foreach ($Server in $VMHosts)
		{
		# Everyone loves progress bars, so here is a progress bar
		Write-Progress -Activity "Configuring NTP Settings" -Status $Server -PercentComplete (($i / $VMHosts.Count) * 100)
		
		# Determine existing ntp config
		$NTPold = $Server | Get-VMHostNtpServer
		
		# Check to see if an NTP entry exists; if so, delete the value(s)
		If ($NTPold) {$Server | Remove-VMHostNtpServer -NtpServer $NTPold -Confirm:$false}
		
		# Add desired NTP value to the host
		Add-VmHostNtpServer -VMHost $Server -NtpServer $NTPServer1 | Out-Null
		if ($NTPServer2) {Add-VmHostNtpServer -VMHost $Server -NtpServer $NTPServer2 | Out-Null}
		
		# Enable the NTP Client and restart the service
		$ntpclient = Get-VMHostService -VMHost $Server | where{$_.Key -match "ntpd"}
		Write-Host -BackgroundColor:Black -ForegroundColor:Yellow "Status: Configuring NTPd on $Server ..."
		$ntpclient | Set-VMHostService -Policy:On -Confirm:$false -ErrorAction:Stop | Out-Null
		Write-Host -BackgroundColor:Black -ForegroundColor:Yellow "Status: Restarting NTPd on $Server ..."
		$ntpclient | Restart-VMHostService -Confirm:$false -ErrorAction:Stop | Out-Null

		# Output to console (optional)
		Write-Host -BackgroundColor:Black -ForegroundColor:Green "Success: $Server is now using NTP server(s)" (Get-VMHostNtpServer -VMHost $server)

		$i++
		}

	} # End of process
} # End of function