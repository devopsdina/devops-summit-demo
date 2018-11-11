
<#
.SYNOPSIS
Check to see if Azure context exists, if not, look for the pop-up behind all the windows, else use this context!

.PARAMETER ClientID
Optional. The Service Principal/App ClientID to use to authenticate

.PARAMETER ClientSecret
Optional. The ervice Principal/App client secret to use to authenticate

.PARAMETER DirectoryID
Optional. The tenant id to connect to
#>
function Connect-Az {
    param (
      [Parameter(Mandatory=$false)]
      [string]$ClientID = $env:ClientID,
      
      [Parameter(Mandatory=$false)]
      [string]$ClientSecret = $env:ClientSecret,
      
      [Parameter(Mandatory=$false)]
      [string]$DirectoryID = $env:DirectoryID
    )


  try {
    $Azcontext = Get-AzureRmcontext

    if (($null -ne $Azcontext.Tenant.Id) -and ($Azcontext.Tenant.Id -ne $DirectoryID)) {
      $Azcontext = $null
    }

    if (-not $Azcontext.Subscription) {
      if ((-not $ClientID) -or (-not $ClientSecret) -or (-not $DirectoryID)) {
        Connect-AzureRmAccount
      }
      else {
        $cred = (New-Object System.Management.Automation.PSCredential $ClientID, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force))
        Connect-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId $DirectoryID
      }
    }
  }
  catch {
      Throw $_
  }
}