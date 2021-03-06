function Get-NSXController {

<#  
.SYNOPSIS  Gathers NSX Controller details from NSX Manager
.DESCRIPTION Will inventory all of your controllers from NSX Manager
.NOTES  Author:  Chris Wahl, @ChrisWahl, WahlNetwork.com
.PARAMETER NSXManager
	The FQDN or IP of your NSX Manager
.PARAMETER Username
	The username to connect with. Defaults to admin if nothing is provided.
.PARAMETER Password
	The password to connect with
.EXAMPLE
	PS> Get-NSXController -NSXManager nsxmgr.fqdn -Username admin -Password password
#>

[CmdletBinding()] 
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[String]$NSXManager,
		[Parameter(Mandatory=$false,Position=1)]
		[String]$Username = "admin",
		[Parameter(Mandatory=$true)]
		[String]$Password
  	)

	Process {

	### Ignore TLS/SSL errors	
	add-type @"
	    using System.Net;
	    using System.Security.Cryptography.X509Certificates;
	    public class TrustAllCertsPolicy : ICertificatePolicy {
	        public bool CheckValidationResult(
	            ServicePoint srvPoint, X509Certificate certificate,
	            WebRequest request, int certificateProblem) {
	            return true;
	        }
	    }
"@
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

	### Create authorization string and store in $head
	$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Username + ":" + $Password))
	$head = @{"Authorization"="Basic $auth"}

	### Connect to NSX Manager via API
	$Request = "https://$NSXManager/api/2.0/vdn/controller"
	$r = Invoke-WebRequest -Uri $Request -Headers $head -ContentType "application/xml" -ErrorAction:Stop
	if ($r.StatusCode -eq "200") {Write-Host -BackgroundColor:Black -ForegroundColor:Green Status: Connected to $NSXManager successfully.}
	[xml]$rxml = $r.Content
	
	### Return the NSX Controllers
	$global:nreport = @()
	foreach ($controller in $rxml.controllers.controller)
		{
		$n = @{} | select Name,IP,Status,Version,VMName,Host,Datastore
		$n.Name = $controller.id
		$n.IP = $controller.ipAddress
		$n.Status = $controller.status
		$n.Version = $controller.version
		$n.VMName = $controller.virtualMachineInfo.name
		$n.Host = $controller.hostInfo.name
		$n.Datastore = $controller.datastoreInfo.name
		$global:nreport += $n
		}
	$global:nreport | ft -AutoSize

	} # End of process
} # End of function