
<#PSScriptInfo

.VERSION 1.0

.GUID 3910d6cc-315c-4725-b04b-b6222c9dc527

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

.DESCRIPTION 

 Remotely enables Microsoft Remote Desktop Client and configures Windows Firewall.

.SYNOPSIS

Configures the host to allow inbound RDP connections using Network Level Authentication (NLA).

Enables inbound RDP connections on TCP 3389 (MS-RDP) through the Windows Firewall on all Domain-Authenticated, Public and Private network connection profiles.

Powershell attempts to first configure the host using it’s own APIs using WinRM, if that is not enabled it then attempts Remote Registry using the RegistryKey (https://msdn.microsoft.com/en-us/library/microsoft.win32.registrykey(v=vs.110).aspx) .NET class and finally using the StdRegProv CIM class before quiting.

.PARAMETER ComputerName

Specify a target host (default runs against localhost).

.PARAMETER Credential

Username to be used for authentication on the remote host.

.Example

Runs against localhost under current user security context.

C:\PS>Enable-RDC 

Runs against the specified host.

C:\PS>Enable-RDC -Computername Ghost.Hauntedhouse.local

Runs against the specified host with specified remote credentials.

C:\PS>Enable-RDC -Computername Goul.Hauntedhouse.local -Credential hauntedhouse\Me

.LINK 

Project is maintained at https://github.com/benlavender/Powershell

#>

#Requires -RunAsAdministrator
#Requires -Version 4.0

param (
    [string]$ComputerName="localhost",
    [string]$Credential="$Null"
    )
Begin {

    if ($Credential -ne "$Null") {
    $Credentials=Get-Credential -Credential "$Credential"
    }
}

Process {

    if ($ComputerName -eq "localhost") {
        $StatusLocal=Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections | ForEach-Object -Process {$_.fDenyTSConnections}
        $StatusLocalFW=Get-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP | ForEach-Object {$_.Enabled}
        if ($StatusLocal -eq "0") {
            Write-Host "RDC already enabled"
        } 
        elseif ($StatusLocal -eq "1") {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
            Write-Host "RDC enabled"
        }
        if ($StatusLocalFW -eq "True") {
            Write-Host "Already permitted through firewall."
            Break
        } 
        elseif ($StatusLocalFW -ne "True") {
            Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True -Profile Domain,Private
            Write-Host "Permitted through firewall."
            Break
        }   
    }
    if (($ComputerName -ne "localhost") -and ($Credential -eq "$Null")) {
        if (Test-WSMan -ComputerName $ComputerName) {
            $Session=New-PSSession -ComputerName $ComputerName
            $WSMANRESULT="True"
            $ErrorActionPreference="SilentlyContinue"
            $StatusRemote=Invoke-Command -Session $Session -ScriptBlock {Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections | ForEach-Object -Process {$_.fDenyTSConnections}}
            $StatusRemoteFW=Invoke-Command -Session $Session -ScriptBlock {(Get-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP).Enabled} | ForEach-Object -Process {$_.Value}
            $ErrorActionPreference="Continue"
            if ($StatusRemote -eq "0") {
            Write-Host "RDC already enabled"
            }
            elseif ($StatusRemote -eq "1") {
            Invoke-Command -Session $Session -ScriptBlock {Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0}
            Write-Host "RDC enabled"
            }
            if ($StatusRemoteFW -eq "True") {
            Write-Host "Already permitted through firewall."
            Break
            }
            elseif ($StatusRemoteFW -eq "False") {
            Invoke-Command -Session $Session -ScriptBlock {Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True -Profile ANY}
            Write-Host "Permitted through firewall."
            Break
            }
        }
    }
    if ((Test-WSMan -ComputerName $ComputerName) -and ($Credential -ne "$Null")) {
        $WSMANRESULT="True"
        $StatusRemote=Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections | ForEach-Object -Process {$_.fDenyTSConnections}}
        $StatusRemoteFW=Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {(Get-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP).Enabled} | ForEach-Object -Process {$_.Value}
        if ($StatusRemote -eq "0") {
        Write-Host "RDC already enabled"
        }
        elseif ($StatusRemote -eq "1") {
        Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0}
        Write-Host "RDC enabled"
        }
        if ($StatusRemoteFW -eq "True") {
        Write-Host "Already permitted through firewall."
        Break
        }
        elseif ($StatusRemoteFW -eq "False") {
        Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True -Profile ANY}
        Write-Host "Permitted through firewall."
        Break
        }
    }
    #Section runs as current user (if permitted through firewall and remoteregistry service is running).
    $ErrorActionPreference="SilentlyContinue"
    $REMOTEREG=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$ComputerName).OpenSubKey('SYSTEM\CurrentControlSet\Control\Terminal Server').GetValue('fDenyTSConnections')
    if (($?) -and ($Credential -eq "$Null")) {
        $ErrorActionPreference="Continue"
        $REMOTEREGSTATUS="1"          
        if ($REMOTEREG -eq "0") {
        Write-Host "RDC already enabled, check permit via firewall manually"
        Break
        }
        if (($REMOTEREG -eq "1") -and ($REMOTEREGSTATUS -eq "1")) {
        [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$ComputerName).OpenSubKey('SYSTEM\CurrentControlSet\Control\Terminal Server', $True).SetValue('fDenyTSConnections','0',[Microsoft.Win32.RegistryValueKind]::DWord)
        Write-Host "RDC enabled, check permit via firewall manually."
        Break         
        }
    }
    $REMOTEREGSTATUS="0"
    #If permitted through firewall (Windows Management Instrumentation (DCOM-In).
    if (($REMOTEREGSTATUS -eq "0") -and ($Credential -ne "$Null")) {
        if (Get-WmiObject -List -Namespace root\default -ComputerName $ComputerName -Credential $Credentials | Where-Object {$_.Name -eq "StdRegProv"}) {
        $WMIC=Get-WmiObject -List -Namespace root\default -ComputerName $ComputerName -Credential $Credentials | Where-Object {$_.Name -eq "StdRegProv"}
        $WMICHECK=$WMIC.GetDWORDValue(2147483650,"SYSTEM\CurrentControlSet\Control\Terminal Server", "fDenyTSConnections").uValue
        }
        if (($WMICHECK -eq 0) -and ($Credential -ne "$Null")) {
            Write-Host "RDC already enabled, check permit via firewall manually"
            Break
        }
        elseif (($WMICHECK -eq 1) -and ($Credential -ne "$Null")) {
            $WMIC.SetDWORDValue(2147483650,"SYSTEM\CurrentControlSet\Control\Terminal Server", "fDenyTSConnections",1)
            Write-Host "RDC enabled, check permit via firewall manually."
            Break
        }
    }
    if (($REMOTEREGSTATUS -eq "0") -and ($Credential -eq "$Null")) {
        if (Get-WmiObject -List -Namespace root\default -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}) {
            $WMI=Get-WmiObject -List -Namespace root\default -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}
            $WMICHECK=$WMI.GetDWORDValue(2147483650,"SYSTEM\CurrentControlSet\Control\Terminal Server", "fDenyTSConnections").uValue
            }
            if (($WMICHECK -eq 0) -and ($Credential -eq "$Null")) {
                Write-Host "RDC already enabled, check permit via firewall manually"
                Break
            }
            elseif (($WMICHECK -eq 1) -and ($Credential -eq "$Null")) {
                $WMI.SetDWORDValue(2147483650,"SYSTEM\CurrentControlSet\Control\Terminal Server", "fDenyTSConnections",0)
                Write-Host "RDC enabled, check permit via firewall manually."
                Break
            }
    }
}

End {
    $ErrorActionPreference="SilentlyContinue"
    Remove-PSSession -Session $Session -ErrorAction SilentlyContinue
    $ErrorActionPreference="Continue"
}