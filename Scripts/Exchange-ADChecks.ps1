
<#PSScriptInfo

.VERSION 1.0

.GUID f09f9f80-1d5c-45f1-bc61-638b2e6e52fa

.AUTHOR ben@benlavender.co.uk

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

.SYNOPSIS

 Displays numerous information on ADDS for Exchange upgrade pre-requisites. 

.Description

Provides ADDS attribute values for objects such as ms-Exch-Schema-Version-Pt, Organization container, Organization container and Microsoft Exchange System for pre-requisite checks as per https://blogs.technet.microsoft.com/rmilne/2015/03/17/how-to-check-exchange-schema-and-object-values-in-ad/ 

Also provides ad-hoc information such as domain and forest functional levels and detectable Exchange servers.

.EXAMPLE

Only runs locally:

PS>.\Exchange-ADChecks.ps1

Ran as an expression from the $HOME directory:

PS C:\>Invoke-Expression -Command $Env:USERPROFILE\Exchange-ADChecks.ps1

#> 

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, @{ ModuleName="ActiveDirectory"; ModuleVersion="1.0.0.0"}
#Requires -Version 4

Begin {
    #Script and ADDS root specifics
    $LOCALADDSPARTITION=(Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Domain
    $LOCALADDSFOREST=(Get-ADDomain -Identity $LOCALADDSPARTITION).Forest
    $LOCALADDSFORRESTMODE=(Get-AdForest -Identity $LOCALADDSFOREST).ForestMode
    $LOCALADDSDMODE=(Get-ADDomain -Identity $LOCALADDSPARTITION).DomainMode
    $configurationNamingContext=(Get-ADRootDSE).configurationNamingContext
    $schemaNamingContext=(Get-ADRootDSE).schemaNamingContext
    $defaultNamingContext=(Get-ADRootDSE).defaultNamingContext
    $ExcSchemaVersion=Get-Adobject -SearchBase $schemaNamingContext -Filter 'Name -eq "ms-Exch-Schema-Version-Pt"' -Properties rangeUpper | Foreach-Object -Process {$_.rangeUpper}
    $ExchangeOrgName=(Get-Adobject -SearchBase $configurationNamingContext -Filter 'ObjectClass -eq "msExchOrganizationContainer"').Name
    $ExchangeOrgVersion=(Get-Adobject -SearchBase $configurationNamingContext -Filter 'ObjectClass -eq "msExchOrganizationContainer"' -Properties objectVersion).objectVersion
    $ExchangeProductID=(Get-Adobject -SearchBase $configurationNamingContext -Filter 'ObjectClass -eq "msExchOrganizationContainer"' -Properties msExchProductID).msExchProductID
    $ExchangeMESOPath="CN=Microsoft Exchange System Objects,$defaultNamingContext"
    $ExchangeMESO=(Get-Adobject -SearchBase "$defaultNamingContext" -Filter 'DistinguishedName -eq $ExchangeMESOPath' -Properties objectVersion).objectVersion
    $ExchAdminGroupName=Get-Adobject -SearchBase "CN=Administrative Groups,CN=$ExchangeOrgName,CN=Microsoft Exchange,CN=Services,$configurationNamingContext" -Filter 'ObjectClass -eq "msExchAdminGroup"' -Properties Name | ForEach-Object -Process {$_.Name}
    $ExchangeAdminGroupPath="CN=$ExchAdminGroupName,CN=Administrative Groups,CN=$ExchangeOrgName,CN=Microsoft Exchange,CN=Services,$configurationNamingContext"
    $ExchServers=Get-Adobject -SearchBase "CN=Servers,$ExchangeAdminGroupPath" -Filter 'ObjectClass -eq "msExchExchangeServer"' | Where-Object -Property ObjectClass -eq "msExchExchangeServer" | ForEach-Object -Process {$_.Name}
}

Process {
    Write-Host "`n"
    Write-Host "ADDS DNS Partition = $LOCALADDSFOREST"
    Write-Host "ADDS Forest Functionality Level = $LOCALADDSFORRESTMODE"
    Write-Host "ADDS Domain Functionality Level = $LOCALADDSDMODE"
    Write-Host "Exchange Organization Name = $ExchangeOrgName"
    Write-Host "Exchanges servers in organization: $ExchServers"
    Write-Host "`n"
    Write-Host "Exchange ProductID (msExchProductId) = $ExchangeProductID"
    Write-Host "Exchange Schema Version (rangeUpper) = $ExcSchemaVersion"
    Write-Host "Microsoft Exchange System Objects version (MESO objectVersion) = $ExchangeMESO"
    Write-Host "Exchange Org Version (Organisation objectVersion) = $ExchangeOrgVersion"
    Write-Host "`n"
}