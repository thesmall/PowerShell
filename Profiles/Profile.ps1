#region End Transcript

#if a transcript was running, stop it, import/re-import the profile and then start it (further down)
$oldEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
Stop-Transcript -ErrorAction SilentlyContinue
$ErrorActionPreference = $oldEAP

#endregion

#region Determine if the User is running the process with their Admin Account

switch ($true) {
	($env:USERNAME -match 'a-') {
		$normalUser = $env:USERNAME.Replace('a-','')
		$adminAccountInUse = $true
        Write-Host "Admin Account in Use." -ForegroundColor Red
        Write-Host ""
        break
	}
    default {
        $normalUser = $env:USERNAME
        $adminAccountInUse = $false
        Write-Host "Normal Account in Use." -ForegroundColor Green
        Write-Host ""
        break
    }
}

#endregion

#region Set script paths

#Get path from which this script was run
$psProfilepath = $MyInvocation.MyCommand.Path
Write-Host 'PS Profile Path: ' -NoNewline
Write-Host $psProfilePath -ForegroundColor Cyan

#$Global:WorkingPath is a global variable (should be set in $PROFILE) pointing
#to the directory containing working directories for GIT projects.
#Here, we test that the variable has indeed been set and that it points to a valid path.
if ( ($Global:WorkingPath) -and (Test-Path $Global:WorkingPath) ) {
	Write-Host 'Using ' -NoNewline
    Write-Host '$Global:WorkingPath' -ForegroundColor Cyan
	$working = $Global:WorkingPath
}
#Failing either test, let's take a crack at guessing
else {
	Write-Host 'Using guess for $working based on relative location of profile script.' -NoNewline -ForegroundColor Yellow
	$working = Split-Path (Split-Path ((Split-Path $psProfilePath)))
}

#Inform the user whether or not the working folder was found
if (Test-Path $working) {
	Write-Host 'Working Directory ($working): ' -NoNewline
	Write-Host $working -ForegroundColor Cyan
}
else {
	Write-Host 'Working Directory ($working) not found:' $working -ForegroundColor Red
}

#endregion

#region Determine Process Architecture & Administrator Status

#Check to see if the current PowerShell Process is 64-bit
$is64Bit = [System.Environment]::Is64BitProcess

#Determine if the current user is running an administrative session.
#Note of clarity. This is not a check to see if you are using an Admin Account.
#Your Admin Account might be an administrator for a given system, however,
#this is not the same as running the current process in an administrative session.
$wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
$adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$isAdmin = $prp.IsInRole($adm)

#endregion

########################## Set Preferences ##########################

#Banner
Write-Host
Write-Host "**************************************" -ForegroundColor Red
Write-Host "****ALL YOUR BASE ARE BELONG TO US****" -ForegroundColor Red
Write-Host "**************************************" -ForegroundColor Red
Write-Host

#Git Name & Email
$gitName = "Ben Small"
$gitEmail = "ben.small88@gmail.com"

#Other Git Settings
$gitColorStatusChanged   = "red normal bold"
$gitColorStatusUntracked = "red normal bold"
$gitColorDiffNew         = "green bold"
$gitColorDiffOld         = "red bold"

#Specify fingerprint (aka SHA1 Hash) of personal Code Signing Certificates
$adminAccountCSCFingerprint  = ""
$normalAccountCSCFingerprint = ""

#Define default values for certain functions/parameters.
$PSDefaultParameterValues = @{}

#PowerShell.exe Window Title
$baseWindowTitle = "$($env:USERDOMAIN.ToLower())\$env:USERNAME@$env:COMPUTERNAME | PID:$pid"

#Root Path for PSTranscripts
$transcriptRoot = "$working\PSTranscripts"

$modulesToImport = @(
    "posh-git"
)

$scriptsToImport = @()

#Specify any additional module Paths to add to $env:PSModulePath or $env:PATH
#Warning: Modifying $modulePathAdditions and $execPathAdditions may break your PowerShell Profile.
#Please take care when making modifications to $env:Path and $env:PSModulePath.

$modulePathAdditions = @()


$execPathAdditions = @(
	'C:\Program Files\Notepad++'
	'C:\Program Files (x86)\SysInternals'
)

#region Define Custom Aliases

Set-Alias -Name 'imo'     -Value Import-Module
Set-Alias -Name 'pssh'    -Value Connect-WinRMHost
Set-Alias -Name 'gpss'    -Value Get-PSSession
Set-Alias -Name 'rpss'    -Value Remove-PSSession
Set-Alias -Name 'gas'     -Value Get-AdapterSummary
Set-Alias -Name 'gpsd'    -Value Get-PSDrive
Set-Alias -Name 'asnapin' -Value Add-PSSnapin
Set-Alias -Name 'rsnapin' -Value Remove-PSSnapin
Set-Alias -Name 'tp'      -Value Test-Path
Set-Alias -Name 'ql'      -Value Quote-List
Set-Alias -Name 'ivh'     -Value Invoke-History
Set-Alias -Name 'push'    -Value Push-Location
Set-Alias -Name 'pop'     -Value Pop-Location
Set-Alias -Name 'grid'    -Value Out-GridView
Set-Alias -Name 'tnc'     -Value Test-NetConnection
Set-Alias -Name 'tc'      -Value Test-Connection

#endregion

#region Import-Modules

foreach ($mod in $modulesToImport) {
    $moduleLeaf = Split-Path $mod -Leaf

    Write-Host "Importing Module: " -NoNewline
    Write-Host "$($moduleLeaf.Replace('.psm1','').Replace('.psd1',''))" -ForegroundColor Cyan
    Import-Module $mod -DisableNameChecking
}
Write-Host

#region Dot-Source Scripts

foreach ($dotscript in $scriptsToImport) {
    $scriptLeaf = Split-Path $dotscript -Leaf

    Write-Host "Importing Script: " -NoNewline
    Write-Host "$($scriptLeaf.Replace('.ps1',''))" -ForegroundColor Cyan
    . $dotscript
}
Write-Host

#endregion

#region Add PSDrives for the remaining Registry Hives.

$null = New-PSDrive -Name HKU  -PSProvider Registry -Root Registry::HKEY_USERS          -ErrorAction SilentlyContinue
$null = New-PSDrive -Name HKCR -PSProvider Registry -Root Registry::HKEY_CLASSES_ROOT   -ErrorAction SilentlyContinue
$null = New-PSDrive -Name HKCC -PSProvider Registry -Root Registry::HKEY_CURRENT_CONFIG -ErrorAction SilentlyContinue

#endregion

#region Define Custom Functions
#Define any custom functions that aren't substantial enough to warrant their own script file.

function Quote-List { $args }

Function Format-DiskSize {
    [cmdletbinding()]
    Param (
        [Long] $Type
    )
    If ($Type -ge 1TB)     {[string]::Format("{0:0.00} TB", $Type / 1TB)}
    ElseIf ($Type -ge 1GB) {[string]::Format("{0:0.00} GB", $Type / 1GB)}
    ElseIf ($Type -ge 1MB) {[string]::Format("{0:0.00} MB", $Type / 1MB)}
    ElseIf ($Type -ge 1KB) {[string]::Format("{0:0.00} KB", $Type / 1KB)}
    ElseIf ($Type -gt 0)   {[string]::Format("{0:0.00} Bytes", $Type)}
    Else {""}
}

function Tail-LogFile {
    param(
        [String] $Path
    )
    if (Test-Path $Path) {
        Get-Content -Path $Path -Tail 1 -Wait
    }
    else {
        Write-Error "Unable to Get-Content from $Path. Does it exist?" -Category InvalidArgument
    }
}
function Search-PSTranscript {
    [CmdletBinding()]
    param(
        [String] $Path,

        [String] $Pattern
    )

    Begin {

    }

    Process {
        $transcriptFiles = Get-ChildItem $Path

        foreach ($t in $transcriptFiles) {
            $matchingContent = Get-Content $t.FullName | Select-String -SimpleMatch $Pattern | Sort-Object

            if ($matchingContent) {
                [pscustomobject] @{
                    File = $t
                    Matches = @($matchingContent)
                }
            }
        }
    }

    End {

    }
}

#Remaps the cd alias to a new function that improves functionality in Set-Location
#Can cd to the previous directory by typing 'cd -'
Remove-Item Alias:cd -ErrorAction SilentlyContinue
function cd {
    if ($args[0] -eq '-') {
        $pwd = $OLDPWD
    }
    else {
        $pwd = $args[0]
    }

    $tmp = Get-Location

    if ($pwd) {
        Set-Location $pwd
    }

    Set-Variable -Name OLDPWD -Value $tmp -Scope global
}

#endregion

#--------------------------------------------

#region Append Supplementary Module Paths to $ENV:PSModulePath

foreach ($mpa in $modulePathAdditions) {
	if (-not ($Env:PSModulePath.Split(';') -contains $mpa)) {
		Write-Host "Appending to `$Env:PSModulePath: " -NoNewline
		Write-Host "`"$mpa`""-ForegroundColor Cyan
		$Env:PSModulePath += ";$mpa"
	}
}

#endregion

#region Append Supplementary Executables to $ENV:Path

foreach ( $epa in $execPathAdditions ) {
    if ( -not ($Env:Path.Split(';') -contains $epa) ) {
		Write-Host "Appending to `$Env:Path: " -NoNewline
		Write-Host "`"$epa`""-ForegroundColor Cyan
		$Env:Path += ";$epa"
	}
}

#endregion

#endregion

#####################################################################

#region Set code-signing certificate variables

#These vars are used by Set-MySignature in the authenticode module
$tss = "http://timestamp.comodoca.com/authenticode"

if ($adminAccountInUse) {
    if ($adminAccountCSCFingerprint) {
	    $myCSCThumbprint = $adminAccountCSCFingerprint
    }
}
else {
    if ($normalAccountCSCFingerprint) {
	    $myCSCThumbprint = $normalAccountCSCFingerprint
    }
}

if ($myCSCThumbprint) {
    $mycert = Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $myCSCThumbprint }
}

#endregion

#region Run Once on Console Start
#Here we run code that the we don't want re-run if the
#profile config is reloaded in the current session.
#$ProfileLoaded is set to $true at the end of the script.
if (-not $profileLoaded) {
    Write-Host

	#Only change to home path if this is a new shell
	if (Test-Path $Working) { Set-Location $Working }
}
#endregion

#region Detect Elevated Privileges & Set Console/ISE/PowerGUI Colors

#Check if the current session is a PowerShellISE Session
if ($psISE) {
    $iseStatus = $true
}

switch ($true) {
    #Using VSCode
    ($host.Name -eq "Visual Studio Code Host") {
        Write-Host
        Write-Host "VSCode Host detected." -ForegroundColor Green
        Write-Host
        break
    }

    #Not using the ISE e.g. the Console.
    ((-not $psISE) -and (-not $host.PrivateData.ProductTitle)) {
        Write-Host
        Write-Host "PowerShell Console detected." -ForegroundColor Green
        Write-Host
        break
    }

    #Using PowerShellISE
    ($iseStatus) {
        Write-Host
        Write-Host "PowerShellISE detected." -ForegroundColor Green
        Write-Host
        break
    }
}

#endregion

#region Configure Prompt and Window Title

#Attempt to load Posh-Git. If Posh-Git is NOT loaded, and you enter a Git-Enabled Directory, there will be no Git Overlay.
if (-not $poshGitLoaded) {
    if ((Get-Module Posh-Git -ErrorAction SilentlyContinue) -and (($env:USERNAME -eq "ben") -or ($env:USERNAME -eq "a-ben")) ) {

        #region Define Posh Git Settings
        $GitPromptSettings.EnableWindowTitle = $null
        #endregion

        #region User Config
        git config --global user.name $gitName
        git config --global user.email $gitEmail
        git config --global color.status.changed $gitColorStatusChanged
        git config --global color.status.untracked $gitColorStatusUntracked
        git config --global color.diff.new $gitColorDiffNew
        git config --global color.diff.old $gitColorDiffOld
        #endregion

        #region Diff Config
        #git config --global --add diff.guitool kdiff3
        #git config --global --add difftool.kdiff3.path "C:/Program Files/KDiff3/kdiff3.exe"
        #git config --global --add difftool.kdiff3.trustExitCode false
        #endregion

        #region Config
        git config --global color.ui true
        git config --global pull.rebase true
        git config --global push.default current
        git config --global fetch.prune true
        git config --global core.autocrlf true
        git config --global log.decorate short
        git config --global core.preloadindex true
        git config --global core.fscache true
        git config --global core.symlinks false
        git config --global http.sslVerify false
        #endregion

        $poshGitLoaded = $true
    }
}


function prompt {
    $basePrompt = "$($env:USERDOMAIN.ToLower())\$env:USERNAME@$env:COMPUTERNAME"

    #Adding this function into prompt removes the psutils.psm1 dependency, allowing the Prompt to function even when the modules fail to load.
    function Get-PSVersion {
	    <#
	    .SYNOPSIS
		    Provides a simple mechanism for getting the release version of the current PowerShell session
	    #>
	    $psVersion = ($PSVersionTable.PSVersion.Major).ToString() + '.' + ($PSVersionTable.PSVersion.Minor).ToString()
	    Write-Output $psVersion
    }

    [Console]::ResetColor()

    $oldVersionPromptColor = 'Magenta'
    $caretPromptColor      = 'White'

    #determine 64/32-bit for Window Title
    if ($is64Bit) {
        $BitWindowTitle = ' x64'
    }
    else {
        $BitWindowTitle = ' x86'
    }

    #build the temporary Window Title
    $tempWindowTitle = $baseWindowTitle + $BitWindowTitle

    #define admin-specific variables
    if ($isAdmin) {
        $currentVersionPromptColor = 'Red'
        $adminWindowTitle          = "Admin: "
    }
    else {
        $currentVersionPromptColor = 'Green'
        $adminWindowTitle          = $null
    }

    $Host.UI.RawUI.WindowTitle = $adminWindowTitle + $tempWindowTitle

    Write-Host ""
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz") -NoNewline -ForegroundColor Cyan
    Write-Host " $basePrompt" -ForegroundColor DarkCyan
    Write-Host $PWD -NoNewline -ForegroundColor White
    if ($poshGitLoaded) { Write-VcsStatus }
    Write-Host ""

    switch (Get-PSVersion) {
        "3.0" { Write-Host "v3.0 " -NoNewline -ForegroundColor $oldVersionPromptColor }
        "4.0" { Write-Host "v4.0 " -NoNewline -ForegroundColor $oldVersionPromptColor }
        "5.0" { Write-Host "v5.0 " -NoNewline -ForegroundColor $oldVersionPromptColor }
        "5.1" { Write-Host "v5.1 " -NoNewline -ForegroundColor $currentVersionPromptColor }
        "6.1" { Write-Host "v5.1 " -NoNewline -ForegroundColor $currentVersionPromptColor }
        default { Write-Host "v? $(Get-PSVersion)" -NoNewline -ForegroundColor $oldVersionPromptColor }
    }

    Write-Host ">"  -NoNewline -ForegroundColor $caretPromptColor
    return " "
}

#endregion

#region Start a Transcript

if ($iseStatus) {
    $ISETab = $psISE.CurrentPowerShellTab.DisplayName.Replace(" ",'').Replace("PowerShell","PSTab")

    $transcriptPath = Join-Path $transcriptRoot "$env:USERNAME`_$env:COMPUTERNAME`_ISE-$ISETab`_$(Get-Date -Format yyyy.MM.dd).txt"
    #Start-Transcript -Path $transcriptPath -Confirm:$false -Append
}
elseif ($host.Name -eq "Visual Studio Code Host") {
    $transcriptPath = Join-Path $transcriptRoot "$env:USERNAME`_$env:COMPUTERNAME`_VSCode_$(Get-Date -Format yyyy.MM.dd).txt"
    #Start-Transcript -Path $transcriptPath -Confirm:$false -Append
}
else {
    $transcriptPath = Join-Path $transcriptRoot "$env:USERNAME`_$env:COMPUTERNAME`_Console_$(Get-Date -Format yyyy.MM.dd).txt"
    Start-Transcript -Path $transcriptPath -Confirm:$false -Append
}

#endregion

#Set variable to indicated the profile has completed its initial load
$profileLoaded = $true