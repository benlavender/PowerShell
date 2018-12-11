
<#PSScriptInfo

.VERSION 1.0

.GUID 041dbc44-2d46-45a0-845e-ac476091deee

.AUTHOR ben@airnet.org.uk

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
Generates bearer tokens for HTTP requests to access OAuth 2.0 protected resources on Microsoft Azure.

.Synopsis
Generates bearer tokens for HTTP requests to access OAuth 2.0 protected resources on Microsoft Azure. This can then be used in other calls and functions.

For further reading on Oauth 2.0 Bearer Token Usage:

https://tools.ietf.org/html/rfc6750
https://oauth.net/2/bearer-tokens/

.Parameter tenantID
Requires ID of the tenant where the resources and subscription identifies reside.

.Parameter subscriptionID
Requires ID of the subscription for the resources to be requested that are billed.

.Parameter homepage
Requires home page string of the registered application. Requires URI format only.

.Parameter Environment
If resources reside in an alternate Azure environment such as Azure US Gov then specify this parameter. Defaults to AzureCloud.

.Parameter Credential
Requires application credentials in the form of username:password. For service principles this is the AppId and the key value.

.Example 
#Requests a bearer token using default and standard parameters

PS C:\>Get-AzBearerKey -tenantID "tenant-string" -subscriptionID "subsription-string" -homepage "https://testapp" -Credential "app-id"

#> 

#Requires -Version 5.0
#Requires -Modules @{ModuleName = "Az.Profile"; ModuleVersion = "0.5.0"}
#Requires -Modules @{ModuleName = "Microsoft.PowerShell.Utility"; ModuleVersion = "3.1.0.0"}

function Get-AzBearerKey {
    [CmdletBinding()]
    
    param (

        [Parameter(Mandatory)]
        [string[]]$tenantID,

        [Parameter(Mandatory)]
        [string[]]$subscriptionID,

        [Parameter(Mandatory)]
        [string[]]$homepage,

        [string[]]$Environment = "AzureCloud",

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]$Credential
        
        )

    begin {

        #Build REST POST request
        $WebForms=@{
            grant_type = "client_credentials"
            client_id = "$($Credential.UserName)"
            client_secret = "$($Credential.GetNetworkCredential().Password)"
            resource = "https://management.azure.com"
        }
        $Headers=@{
            "Accept" = "application/json"
            "cache-control" = "no-cache"
        }
        $params=@{
            Body = $WebForms
            Method = "POST"
            Headers = $Headers
            URI = "https://login.microsoftonline.com/$tenantID/oauth2/token"
        }
    }
    
    process {

        try {

            #Connect to Azure AD
            Connect-AzAccount -Subscription $subscriptionID -Tenant $tenantID -Credential $Credential -ServicePrincipal -Environment $Environment -Verbose
        }

        catch {

            Write-Host $Error[0]
            Break
        }

        #Get OAuth bearer token
        $token = Invoke-RestMethod @params    
    }
    
    end {

        Disconnect-AzAccount -Verbose
    }
}