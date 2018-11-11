$script:moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
"$script:moduleRoot\..\..\..\functions\Connect-Az.ps1" | Resolve-Path | ForEach-Object{. $_.ProviderPath}

  Describe 'Connect-Az' {
    BeforeEach {
      Mock Get-AzureRmContext { }
      Mock Connect-AzureRmAccount { }
    }

    it "Uses a service principal account to log into Azure" {
      Connect-Az -clientId 'mock-clientid' -clientSecret 'mock-clientsecret' -DirectoryID 'mock-DirectoryID'
      Assert-MockCalled Connect-AzureRmAccount -ParameterFilter {$ServicePrincipal -eq $true} -Exactly 1 -Scope It
    }

    it "If you are already logged in, either with a service principal or your own creds, you are not prompted to login" {
      Mock Get-AzureRmContext {
        return @{
          Subscription = '1234-guid-5678-moreguid'
        }
      }
      
      Connect-Az -clientId 'mock-clientid' -clientSecret 'mock-clientsecret' -DirectoryID 'mock-DirectoryID'
      Connect-Az

      Assert-MockCalled Connect-AzureRmAccount -Exactly 0 -Scope It
    }

    it "Logs in using your own credentials" {
      Connect-Az -clientID $null -clientSecret $null -DirectoryID $null
      Assert-MockCalled Connect-AzureRmAccount -ParameterFilter {$cred -eq $null} -Exactly 1 -Scope It
    }
  }