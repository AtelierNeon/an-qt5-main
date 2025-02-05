##
## Built-in config
##
$InformationPreference = 'Continue'
#$VerbosePreference = 'Continue'

##
## Global config
##
$CmdCli = 'cmd'
$GitCli = 'git'
$NmakeCli = 'nmake'
$PerlCli = 'perl'
$PythonCli = 'python'
$ProjectFolder = Join-Path -Path $PSScriptRoot -ChildPath '..'
$SourceFolder = $ProjectFolder
$TempRootFolder = Join-Path -Path $ProjectFolder -ChildPath 'build'
$TempBuildFolder = Join-Path -Path $TempRootFolder -ChildPath 't'
$TempInstallFolder = Join-Path -Path $TempRootFolder -ChildPath 'i'

##
## Project config
##
####
#### Project level config
####
$ProjectRevision = if ($Env:BUILD_NUMBER) {$Env:BUILD_NUMBER} else {'9999'}
$ProjectShouldDisableCleanBuild = if ($Env:MY_PROJECT_SHOULD_DISABLE_CLEAN_BUILD) {$Env:MY_PROJECT_SHOULD_DISABLE_CLEAN_BUILD} else {'OFF'}
$ProjectShouldDisable32BitBuild = if ($Env:MY_PROJECT_SHOULD_DISABLE_32BIT_BUILD) {$Env:MY_PROJECT_SHOULD_DISABLE_32BIT_BUILD} else {'OFF'}
$ProjectShouldDisable64BitBuild = if ($Env:MY_PROJECT_SHOULD_DISABLE_64BIT_BUILD) {$Env:MY_PROJECT_SHOULD_DISABLE_64BIT_BUILD} else {'OFF'}
$ProjectShouldDisableMsvc2019Build = if ($Env:MY_PROJECT_SHOULD_DISABLE_MSVC2019_BUILD) {$Env:MY_PROJECT_SHOULD_DISABLE_MSVC2019_BUILD} else {'OFF'}
$ProjectShouldDisableMsvc2022Build = if ($Env:MY_PROJECT_SHOULD_DISABLE_MSVC2022_BUILD) {$Env:MY_PROJECT_SHOULD_DISABLE_MSVC2022_BUILD} else {'OFF'}
####
#### Project component level config
####

##
## My variables
##
$MyProjectVersionMajor = '0'
$MyProjectVersionMinor = '0'
$MyProjectVersionPatch = '0'
foreach ($line in Get-Content $ProjectFolder\version.dat) {
    if ($line -like 'MAJOR=*') {
        $MyProjectVersionMajor = $line.Substring(6)
    }
    if ($line -like 'MINOR=*') {
        $MyProjectVersionMinor = $line.Substring(6)
    }
    if ($line -like 'PATCH=*') {
        $MyProjectVersionPatch = $line.Substring(6)
    }
}
$MyProjectVersion = "$MyProjectVersionMajor.$MyProjectVersionMinor.$MyProjectVersionPatch"
$MyOpenSslDebugReleaseModeList = @(
        'debug',
        'release'
)
$MyOpenSslDebugReleaseModeToRuntimeFlagMap = @{
        'debug' = 'MDd'
        'release' = 'MD'
}
$MyQtPlatformList = @(
        'msvc2019',
        'msvc2019_64',
        'msvc2022',
        'msvc2022_64'
)
$MyQtPlatformToBuildToggleMap = @{
        'msvc2019' = 'ON'
        'msvc2019_64' = 'ON'
        'msvc2022' = 'ON'
        'msvc2022_64' = 'ON'
}
$MyQtPlatformToMsvcPlatformMap = @{
        'msvc2019' = 'x86'
        'msvc2019_64' = 'x64'
        'msvc2022' = 'x86'
        'msvc2022_64' = 'x64'
}
$MyQtPlatformToMsvcVersionMap = @{
        'msvc2019' = '2019'
        'msvc2019_64' = '2019'
        'msvc2022' = '2022'
        'msvc2022_64' = '2022'
}
$MyQtPlatformToOpenSslBuildFlagMap = @{
        'msvc2019' = 'VC-WIN32'
        'msvc2019_64' = 'VC-WIN64A'
        'msvc2022' = 'VC-WIN32'
        'msvc2022_64' = 'VC-WIN64A'
}
if ('ON'.Equals($ProjectShouldDisable32BitBuild)) {
    $MyQtPlatformToBuildToggleMap['msvc2019'] = 'OFF'
    $MyQtPlatformToBuildToggleMap['msvc2022'] = 'OFF'
}
if ('ON'.Equals($ProjectShouldDisable64BitBuild)) {
    $MyQtPlatformToBuildToggleMap['msvc2019_64'] = 'OFF'
    $MyQtPlatformToBuildToggleMap['msvc2022_64'] = 'OFF'
}
if ('ON'.Equals($ProjectShouldDisableMsvc2019Build)) {
    $MyQtPlatformToBuildToggleMap['msvc2019'] = 'OFF'
    $MyQtPlatformToBuildToggleMap['msvc2019_64'] = 'OFF'
}
if ('ON'.Equals($ProjectShouldDisableMsvc2022Build)) {
    $MyQtPlatformToBuildToggleMap['msvc2022'] = 'OFF'
    $MyQtPlatformToBuildToggleMap['msvc2022_64'] = 'OFF'
}
$MySystemGitCliFound = $true
$MySystemPerlCliFound = $true
$MySystemPythonCliFound = $true



## Print build information
Write-Information "[PowerShell] Project information: version: `"$MyProjectVersion`""
Write-Information "[PowerShell] Project information: revision: `"$ProjectRevision`""



##
## My Functions
##
function Invoke-CmdScript {
    param(
        [String] $scriptName
    )
    $cmdLine = """$scriptName"" $args & set"
    & $Env:SystemRoot\system32\cmd.exe /c $cmdLine |
    select-string '^([^=]*)=(.*)$' | foreach-object {
        $varName = $_.Matches[0].Groups[1].Value
        $varValue = $_.Matches[0].Groups[2].Value
        set-item Env:$varName $varValue
    }
}
function Use-MSVC {
    param(
        [Parameter(Mandatory = $false)][string]$MsvcVersion,
        [Parameter(Mandatory = $false)][string]$MsvcPlatform
    )
    if (!($MsvcVersion)) {
        $MsvcVersion = '2019'
    }
    if (!($MsvcPlatform)) {
        $MsvcPlatform = 'x64'
    }
    $MsvcVariantList = @(
            "BuildTools",
            "Community",
            "Professional",
            "Enterprise"
    )
    if ('2019'.Equals($MsvcVersion)) {
        $MsvcVariantFound = $false
        foreach ($MsvcVariant in $MsvcVariantList) {
            if (-not $MsvcVariantFound -and (Test-Path -Path "C:\Program Files (x86)\Microsoft Visual Studio\2019\$MsvcVariant\VC\Auxiliary\Build\vcvarsall.bat")) {
                Write-Information "[PowerShell] Using MSVC $MsvcVersion/$MsvcVariant/$MsvcPlatform ..."
                Invoke-CmdScript "C:\Program Files (x86)\Microsoft Visual Studio\2019\$MsvcVariant\VC\Auxiliary\Build\vcvarsall.bat" $MsvcPlatform
                $MsvcVariantFound = $true
            }
        }
        if (-not $MsvcVariantFound) {
            Write-Error "[PowerShell] Can not find MSVC $MsvcVersion/$MsvcPlatform to use ..."
        }
    } elseif ('2022'.Equals($MsvcVersion)) {
        $MsvcVariantFound = $false
        foreach ($MsvcVariant in $MsvcVariantList) {
            if (-not $MsvcVariantFound -and (Test-Path -Path "C:\Program Files\Microsoft Visual Studio\2022\$MsvcVariant\VC\Auxiliary\Build\vcvarsall.bat")) {
                Write-Information "[PowerShell] Using MSVC $MsvcVersion/$MsvcVariant/$MsvcPlatform ..."
                Invoke-CmdScript "C:\Program Files\Microsoft Visual Studio\2022\$MsvcVariant\VC\Auxiliary\Build\vcvarsall.bat" $MsvcPlatform
                $MsvcVariantFound = $true
            }
        }
        if (-not $MsvcVariantFound) {
            Write-Error "[PowerShell] Can not find MSVC $MsvcVersion/$MsvcPlatform to use ..."
        }
    } else {
        Write-Error "[PowerShell] Can not find MSVC $MsvcVersion/$MsvcPlatform to use ..."
    }
}



## Detect source folder
Write-Information "[PowerShell] Detecting $SourceFolder folder ..."
if (-not (Test-Path -Path $SourceFolder)) {
    Write-Error "[PowerShell] Detecting $SourceFolder folder ... NOT FOUND"
    Exit 1
}
Write-Information "[PowerShell] Detecting $SourceFolder folder ... FOUND"



## Create or clean temp folder
if (-not ('ON'.Equals($ProjectShouldDisableCleanBuild))) {
    $MyIoError = $null
    Write-Information "[PowerShell] Cleaning $TempRootFolder folder ..."
    if (Test-Path -Path $TempRootFolder) {
        Write-Verbose "[PowerShell] Removing $TempRootFolder folder ..."
        Remove-Item -Recurse -Force $TempRootFolder -ErrorVariable MyIoError
        if ($MyIoError) {
            Write-Error "[PowerShell] Remove $TempRootFolder folder ... FAILED"
            Exit 1
        }
    }
    Write-Information "[PowerShell] Cleaning $TempRootFolder folder ... DONE"
}
if (-not (Test-Path -Path $TempBuildFolder)) {
    $MyIoError = $null
    Write-Verbose "[PowerShell] Creating $TempBuildFolder folder ..."
    New-Item -ItemType Directory -Path $TempBuildFolder -ErrorVariable MyIoError | Out-Null
    if ($MyIoError) {
        Write-Error "[PowerShell] Creating $TempBuildFolder folder ... FAILED"
        Exit 1
    }
    Write-Verbose "[PowerShell] Creating $TempBuildFolder folder ... DONE"
}
if (-not (Test-Path -Path $TempInstallFolder)) {
    $MyIoError = $null
    Write-Verbose "[PowerShell] Creating $TempInstallFolder folder ..."
    New-Item -ItemType Directory -Path $TempInstallFolder -ErrorVariable MyIoError | Out-Null
    if ($MyIoError) {
        Write-Error "[PowerShell] Creating $TempInstallFolder folder ... FAILED"
        Exit 1
    }
    Write-Verbose "[PowerShell] Creating $TempInstallFolder folder ... DONE"
}



## Append Perl-portable / Python-embedded folder into PATH
$MyPerlTargetPath = "${Env:USERPROFILE}\.perl-portable"
$MyPythonTargetPath = "${Env:USERPROFILE}\.python-embedded"
$Env:PATH = "${MyPythonTargetPath}" + ';' + $Env:PATH + ';' + "${MyPerlTargetPath}\perl\bin"



## Detect Git
$MyGitProcess = $null
$MyGitProcessHandle = $null
Write-Information "[PowerShell] Detecting Git ..."
try {
    $MyGitProcess = Start-Process -FilePath "$GitCli" -WindowStyle Hidden -PassThru `
            -ArgumentList "--version"
    $MyGitProcessHandle = $MyGitProcess.Handle
    $MyGitProcess.WaitForExit()
    $MyGitProcessExitCode = $MyGitProcess.ExitCode
    if ($MyGitProcessExitCode -ne 0) {
        Write-Information "[PowerShell] Detecting Git ... INCORRECT (ExitCode: $MyGitProcessExitCode)"
        $MySystemGitCliFound = $false
    } else {
        Write-Information "[PowerShell] Detecting Git ... FOUND"
    }
} catch {
    Write-Information "[PowerShell] Detecting Git ... NOT FOUND"
    $MySystemGitCliFound = $false
} finally {
    if ($null -ne $MyGitProcessHandle) {
        $MyGitProcessHandle = $null
    }
    if ($null -ne $MyGitProcess) {
        $MyGitProcess.Dispose()
        $MyGitProcess = $null
    }
}



## Detect Perl
$MyPerlProcess = $null
$MyPerlProcessHandle = $null
Write-Information "[PowerShell] Detecting Perl ..."
try {
    $MyPerlProcess = Start-Process -FilePath "$PerlCli" -WindowStyle Hidden -PassThru `
            -ArgumentList "--version"
    $MyPerlProcessHandle = $MyPerlProcess.Handle
    $MyPerlProcess.WaitForExit()
    $MyPerlProcessExitCode = $MyPerlProcess.ExitCode
    if ($MyPerlProcessExitCode -ne 0) {
        Write-Information "[PowerShell] Detecting Perl ... INCORRECT (ExitCode: $MyPerlProcessExitCode)"
        $MySystemPerlCliFound = $false
    } else {
        Write-Information "[PowerShell] Detecting Perl ... FOUND"
    }
} catch {
    Write-Information "[PowerShell] Detecting Perl ... NOT FOUND"
    $MySystemPerlCliFound = $false
} finally {
    if ($null -ne $MyPerlProcessHandle) {
        $MyPerlProcessHandle = $null
    }
    if ($null -ne $MyPerlProcess) {
        $MyPerlProcess.Dispose()
        $MyPerlProcess = $null
    }
}



## Install Perl
if (-not $MySystemPerlCliFound) {
    Write-Information "[PowerShell] Installing Perl ..."

    ## Install Perl - Download archive file
    $MyPerlArchiveName = "strawberry-perl-5.40.0.1-64bit-portable.zip"
    $MyPerlArchiveUrl = "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/${MyPerlArchiveName}"
    $MyPerlTempPath = [System.guid]::NewGuid().toString()
    $MyPerlTempPath = "${Env:Temp}\${MyPerlTempPath}_${MyPerlArchiveName}"
    Write-Information "[PowerShell] Installing Perl ... Downloading archive file from ${MyPerlArchiveUrl} ..."
    try {
        Invoke-WebRequest $MyPerlArchiveUrl -OutFile $MyPerlTempPath
    } catch {
        Write-Error "[PowerShell] Installing Perl ... Downloading archive file from ${MyPerlArchiveUrl} ... FAILED"
        Exit 1
    }
    Write-Information "[PowerShell] Installing Perl ... Downloading archive file from ${MyPerlArchiveUrl} ... DONE"

    ## Install Perl - Extract archive file
    Write-Information "[PowerShell] Installing Perl ... Extracting archive file to ${MyPerlTargetPath} ..."
    try {
        Expand-Archive -Path $MyPerlTempPath -DestinationPath $MyPerlTargetPath
    } catch {
        Write-Error "[PowerShell] Installing Perl ... Extracting archive file to ${MyPerlTargetPath} ... FAILED"
        Exit 1
    }
    Write-Information "[PowerShell] Installing Perl ... Extracting archive file to ${MyPerlTargetPath} ... DONE"

    ## Install Perl - Check binary file
    Write-Information "[PowerShell] Installing Perl ... Checking binary file ..."
    if (-not (Test-Path "${MyPerlTargetPath}\perl\bin")) {
        Write-Error "[PowerShell] Installing Perl ... Checking binary file ... FAILED (Folder does not exist)"
        Exit 1
    }
    if (Test-Path "${MyPerlTargetPath}\perl\bin\${PerlCli}.exe") {
        Write-Information "[PowerShell] Installing Perl ... Checking binary file ... FOUND"
    } else {
        Write-Error "[PowerShell] Installing Perl ... Checking binary file ... NOT FOUND (Perl is missing)"
        Exit 1
    }
}



## Detect Python
$MyPythonProcess = $null
$MyPythonProcessHandle = $null
Write-Information "[PowerShell] Detecting Python ..."
try {
    $MyPythonProcess = Start-Process -FilePath "$PythonCli" -WindowStyle Hidden -PassThru `
            -ArgumentList "--version"
    $MyPythonProcessHandle = $MyPythonProcess.Handle
    $MyPythonProcess.WaitForExit()
    $MyPythonProcessExitCode = $MyPythonProcess.ExitCode
    if ($MyPythonProcessExitCode -ne 0) {
        Write-Information "[PowerShell] Detecting Python ... INCORRECT (ExitCode: $MyPythonProcessExitCode)"
        $MySystemPythonCliFound = $false
    } else {
        Write-Information "[PowerShell] Detecting Python ... FOUND"
    }
} catch {
    Write-Information "[PowerShell] Detecting Python ... NOT FOUND"
    $MySystemPythonCliFound = $false
} finally {
    if ($null -ne $MyPythonProcessHandle) {
        $MyPythonProcessHandle = $null
    }
    if ($null -ne $MyPythonProcess) {
        $MyPythonProcess.Dispose()
        $MyPythonProcess = $null
    }
}



## Install Python
if (-not $MySystemPythonCliFound) {
    Write-Information "[PowerShell] Installing Python ..."

    ## Install Python - Download archive file
    $MyPythonArchiveName = "python-3.11.9-embed-amd64.zip"
    $MyPythonArchiveUrl = "https://www.python.org/ftp/python/3.11.9/${MyPythonArchiveName}"
    $MyPythonTempPath = [System.guid]::NewGuid().toString()
    $MyPythonTempPath = "${Env:Temp}\${MyPythonTempPath}_${MyPythonArchiveName}"
    Write-Information "[PowerShell] Installing Python ... Downloading archive file from ${MyPythonArchiveUrl} ..."
    try {
        Invoke-WebRequest $MyPythonArchiveUrl -OutFile $MyPythonTempPath
    } catch {
        Write-Error "[PowerShell] Installing Python ... Downloading archive file from ${MyPythonArchiveUrl} ... FAILED"
        Exit 1
    }
    Write-Information "[PowerShell] Installing Python ... Downloading archive file from ${MyPythonArchiveUrl} ... DONE"

    ## Install Python - Extract archive file
    Write-Information "[PowerShell] Installing Python ... Extracting archive file to ${MyPythonTargetPath} ..."
    try {
        Expand-Archive -Path $MyPythonTempPath -DestinationPath $MyPythonTargetPath
    } catch {
        Write-Error "[PowerShell] Installing Python ... Extracting archive file to ${MyPythonTargetPath} ... FAILED"
        Exit 1
    }
    Write-Information "[PowerShell] Installing Python ... Extracting archive file to ${MyPythonTargetPath} ... DONE"

    ## Install Python - Check binary file
    Write-Information "[PowerShell] Installing Python ... Checking binary file ..."
    if (-not (Test-Path "${MyPythonTargetPath}")) {
        Write-Error "[PowerShell] Installing Python ... Checking binary file ... FAILED (Folder does not exist)"
        Exit 1
    }
    if (Test-Path "${MyPythonTargetPath}\${PythonCli}.exe") {
        Write-Information "[PowerShell] Installing Python ... Checking binary file ... FOUND"
    } else {
        Write-Error "[PowerShell] Installing Python ... Checking binary file ... NOT FOUND (Python is missing)"
        Exit 1
    }
}



## Build project
Write-Information "[PowerShell] Building project ..."
foreach ($MyQtPlatform in $MyQtPlatformList) {
    ## Build project for arch $MyQtPlatform
    Write-Information "[PowerShell] Building project for arch $MyQtPlatform ..."
    if (-not ('ON'.Equals($MyQtPlatformToBuildToggleMap[$MyQtPlatform]))) {
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... SKIPPED"
    } else {
        $MyTempOpenSslFolderAbs = Resolve-Path $TempBuildFolder
        $MyTempOpenSslFolderAbs = Join-Path -Path $MyTempOpenSslFolderAbs -ChildPath openssl
        $MyTempOpenSslFolderAbs = Join-Path -Path $MyTempOpenSslFolderAbs -ChildPath $MyQtPlatform
        $MyTempOpenSslIncFolderAbs = Join-Path -Path $MyTempOpenSslFolderAbs -ChildPath include
        $MyTempOpenSslLibFolderAbs = Join-Path -Path $MyTempOpenSslFolderAbs -ChildPath lib

        $MyTempQtFolderAbs = Resolve-Path $TempBuildFolder
        $MyTempQtFolderAbs = Join-Path -Path $MyTempQtFolderAbs -ChildPath Qt
        $MyTempQtFolderAbs = Join-Path -Path $MyTempQtFolderAbs -ChildPath $MyProjectVersion
        $MyTempQtFolderAbs = Join-Path -Path $MyTempQtFolderAbs -ChildPath $MyQtPlatform

        $MyOpenSslBuildFlag = $MyQtPlatformToOpenSslBuildFlagMap[$MyQtPlatform]
        $MyMsvcPlatform = $MyQtPlatformToMsvcPlatformMap[$MyQtPlatform]
        $MyMSvcVersion = $MyQtPlatformToMsvcVersionMap[$MyQtPlatform]

        ## Build project for arch $MyQtPlatform - Clean workspace
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning workspace ..."
        if (-not $MySystemGitCliFound) {
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning workspace ... SKIPPED"
        } else {
            try {
                $MyGitProcess = Start-Process -FilePath "$GitCli" -NoNewWindow -PassThru `
                        -ArgumentList "submodule foreach --recursive `"git clean -dfx`""
                $MyGitProcessHandle = $MyGitProcess.Handle
                $MyGitProcess.WaitForExit()
                $MyGitProcessExitCode = $MyGitProcess.ExitCode
                if ($MyGitProcessExitCode -ne 0) {
                    Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning workspace - $MyOpenSslDebugReleaseMode ... FAILED (ExitCode: $MyGitProcessExitCode)"
                    Set-Location $ProjectFolder
                    Exit 1
                }
            } catch {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning workspace - $MyOpenSslDebugReleaseMode ... FAILED (Git is missing)"
                Set-Location $ProjectFolder
                Exit 1
            } finally {
                if ($null -ne $MyGitProcessHandle) {
                    $MyGitProcessHandle = $null
                }
                if ($null -ne $MyGitProcess) {
                    $MyGitProcess.Dispose()
                    $MyGitProcess = $null
                }
            }
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning workspace ... DONE"    
        }

        ## Build project for arch $MyQtPlatform - Apply MSVC environment
        Use-MSVC -MsvcVersion $MyMSvcVersion -MsvcPlatform $MyMsvcPlatform

        ## Build project for arch $MyQtPlatform - Generate OpenSSL project
        foreach ($MyOpenSslDebugReleaseMode in $MyOpenSslDebugReleaseModeList) {
            $MyPerlProcess = $null
            $MyPerlProcessHandle = $null
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Generating OpenSSL project - $MyOpenSslDebugReleaseMode ..."
            try {
                $MyOpenSslArgumentList = @(
                        "Configure $MyOpenSslBuildFlag",
                        "no-asm",
                        "no-shared",
                        "--prefix=`"$MyTempOpenSslFolderAbs`"",
                        "--openssldir=C:\ProgramData\ssl",
                        "--$MyOpenSslDebugReleaseMode"
                )
                $MyOpenSslArgumentListString = $MyOpenSslArgumentList -join " "
                Write-Verbose "[PowerShell] Building project for arch $MyQtPlatform ... Generating OpenSSL project - $MyOpenSslDebugReleaseMode ... argument list: $MyOpenSslArgumentListString"
                Set-Location .\openssl
                $MyPerlProcess = Start-Process -FilePath "$PerlCli" -NoNewWindow -PassThru `
                        -ArgumentList $MyOpenSslArgumentListString
                $MyPerlProcessHandle = $MyPerlProcess.Handle
                $MyPerlProcess.WaitForExit()
                $MyPerlProcessExitCode = $MyPerlProcess.ExitCode
                if ($MyPerlProcessExitCode -ne 0) {
                    Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Generating OpenSSL project - $MyOpenSslDebugReleaseMode ... FAILED (ExitCode: $MyPerlProcessExitCode)"
                    Set-Location $ProjectFolder
                    Exit 1
                }
            } catch {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Generating OpenSSL project - $MyOpenSslDebugReleaseMode ... FAILED (Perl is missing)"
                Set-Location $ProjectFolder
                Exit 1
            } finally {
                if ($null -ne $MyPerlProcessHandle) {
                    $MyPerlProcessHandle = $null
                }
                if ($null -ne $MyPerlProcess) {
                    $MyPerlProcess.Dispose()
                    $MyPerlProcess = $null
                }
            }
            Set-Location $ProjectFolder
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Generating OpenSSL project - $MyOpenSslDebugReleaseMode ... DONE"
    
            ## Build project for arch $MyQtPlatform - Update OpenSSL project - $MyOpenSslDebugReleaseMode
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Updating OpenSSL project - $MyOpenSslDebugReleaseMode ..."
            $MyRuntimeFlag = $MyOpenSslDebugReleaseModeToRuntimeFlagMap[$MyOpenSslDebugReleaseMode]
            $MyTempContent = [System.IO.File]::ReadAllText("$ProjectFolder\openssl\makefile").Replace(" /MT "," /$MyRuntimeFlag ").Replace(" /MD "," /$MyRuntimeFlag ")
            [System.IO.File]::WriteAllText("$ProjectFolder\openssl\makefile", $MyTempContent)
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Updating OpenSSL project - $MyOpenSslDebugReleaseMode ... DONE"
    
            ## Build project for arch $MyQtPlatform - Clean OpenSSL project - $MyOpenSslDebugReleaseMode
            Set-Location $ProjectFolder\openssl
            $MyNmakeProcess = $null
            $MyNmakeProcessHandle = $null
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning OpenSSL project - $MyOpenSslDebugReleaseMode ..."
            try {
                $MyNmakeProcess = Start-Process -FilePath "$NmakeCli" -NoNewWindow -PassThru `
                        -ArgumentList "clean"
                $MyNmakeProcessHandle = $MyNmakeProcess.Handle
                $MyNmakeProcess.WaitForExit()
                $MyNmakeProcessExitCode = $MyNmakeProcess.ExitCode
                if ($MyNmakeProcessExitCode -ne 0) {
                    Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning OpenSSL project - $MyOpenSslDebugReleaseMode ... FAILED (ExitCode: $MyNmakeProcessExitCode)"
                    Set-Location $ProjectFolder
                    Exit 1
                }
            } catch {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning OpenSSL project - $MyOpenSslDebugReleaseMode ... FAILED (NMake is missing)"
                Set-Location $ProjectFolder
                Exit 1
            } finally {
                if ($null -ne $MyNmakeProcessHandle) {
                    $MyNmakeProcessHandle = $null
                }
                if ($null -ne $MyNmakeProcess) {
                    $MyNmakeProcess.Dispose()
                    $MyNmakeProcess = $null
                }
            }
            Set-Location $ProjectFolder
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Cleaning OpenSSL project - $MyOpenSslDebugReleaseMode ... DONE"
    
            ## Build project for arch $MyQtPlatform - Compile OpenSSL - $MyOpenSslDebugReleaseMode
            Set-Location $ProjectFolder\openssl
            $MyNmakeProcess = $null
            $MyNmakeProcessHandle = $null
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Compiling OpenSSL - $MyOpenSslDebugReleaseMode ..."
            try {
                $MyNmakeProcess = Start-Process -FilePath "$NmakeCli" -NoNewWindow -PassThru `
                        -ArgumentList "all"
                $MyNmakeProcessHandle = $MyNmakeProcess.Handle
                $MyNmakeProcess.WaitForExit()
                $MyNmakeProcessExitCode = $MyNmakeProcess.ExitCode
                if ($MyNmakeProcessExitCode -ne 0) {
                    Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Compiling OpenSSL - $MyOpenSslDebugReleaseMode ... FAILED (ExitCode: $MyNmakeProcessExitCode)"
                    Set-Location $ProjectFolder
                    Exit 1
                }
            } catch {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Compiling OpenSSL - $MyOpenSslDebugReleaseMode ... FAILED (NMake is missing)"
                Set-Location $ProjectFolder
                Exit 1
            } finally {
                if ($null -ne $MyNmakeProcessHandle) {
                    $MyNmakeProcessHandle = $null
                }
                if ($null -ne $MyNmakeProcess) {
                    $MyNmakeProcess.Dispose()
                    $MyNmakeProcess = $null
                }
            }
            Set-Location $ProjectFolder
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Compiling OpenSSL - $MyOpenSslDebugReleaseMode ... DONE"
    
            ## Build project for arch $MyQtPlatform - Install OpenSSL - $MyOpenSslDebugReleaseMode
            Set-Location $ProjectFolder\openssl
            $MyNmakeProcess = $null
            $MyNmakeProcessHandle = $null
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Installing OpenSSL - $MyOpenSslDebugReleaseMode ..."
            try {
                $MyNmakeProcess = Start-Process -FilePath "$NmakeCli" -NoNewWindow -PassThru `
                        -ArgumentList "install_sw"
                $MyNmakeProcessHandle = $MyNmakeProcess.Handle
                $MyNmakeProcess.WaitForExit()
                $MyNmakeProcessExitCode = $MyNmakeProcess.ExitCode
                if ($MyNmakeProcessExitCode -ne 0) {
                    Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Installing OpenSSL - $MyOpenSslDebugReleaseMode ... FAILED (ExitCode: $MyNmakeProcessExitCode)"
                    Set-Location $ProjectFolder
                    Exit 1
                }
            } catch {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Installing OpenSSL - $MyOpenSslDebugReleaseMode ... FAILED (NMake is missing)"
                Set-Location $ProjectFolder
                Exit 1
            } finally {
                if ($null -ne $MyNmakeProcessHandle) {
                    $MyNmakeProcessHandle = $null
                }
                if ($null -ne $MyNmakeProcess) {
                    $MyNmakeProcess.Dispose()
                    $MyNmakeProcess = $null
                }
            }
            Set-Location $ProjectFolder
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Installing OpenSSL - $MyOpenSslDebugReleaseMode ... DONE"
    
            ## Build project for arch $MyQtPlatform - Update OpenSSL binary - $MyOpenSslDebugReleaseMode
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Updating OpenSSL binary - $MyOpenSslDebugReleaseMode ..."
            if (Test-Path -Path "$TempBuildFolder\openssl\$MyQtPlatform\lib\libcrypto.lib") {
                Move-Item "$TempBuildFolder\openssl\$MyQtPlatform\lib\libcrypto.lib" -Destination "$TempBuildFolder\openssl\$MyQtPlatform\lib\libcrypto${MyRuntimeFlag}.lib"
            }
            if (Test-Path -Path "$TempBuildFolder\openssl\$MyQtPlatform\lib\libssl.lib") {
                Move-Item "$TempBuildFolder\openssl\$MyQtPlatform\lib\libssl.lib" -Destination "$TempBuildFolder\openssl\$MyQtPlatform\lib\libssl${MyRuntimeFlag}.lib"
            }
            Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Updating OpenSSL binary - $MyOpenSslDebugReleaseMode ... DONE"
        }

        ## Build project for arch $MyQtPlatform - Generate Qt project
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Generating Qt project ..."
        $MyCmdProcess = $null
        $MyCmdProcessHandle = $null
        try {
            $MyQtArgumentList = @(
                    "/c configure.bat",
                    "-prefix `"$MyTempQtFolderAbs`""
                    "-recheck-all",
                    "-opensource -confirm-license",
                    "-debug-and-release -optimize-size -optimized-tools -mp",
                    "-platform win32-msvc -opengl desktop",
                    "-nomake examples -nomake tests -skip qtwebengine",
                    "-openssl-linked",
                    "OPENSSL_INCDIR=`"$MyTempOpenSslIncFolderAbs`"",
                    "OPENSSL_LIBDIR=`"$MyTempOpenSslLibFolderAbs`"",
                    "OPENSSL_LIBS=`"-lws2_32 -lgdi32 -ladvapi32 -lcrypt32 -luser32`"",
                    "OPENSSL_LIBS_DEBUG=`"-llibsslMDd -llibcryptoMDd`"",
                    "OPENSSL_LIBS_RELEASE=`"-llibsslMD -llibcryptoMD`""
            )
            $MyQtArgumentListString = $MyQtArgumentList -join " "
            $MyCmdProcess = Start-Process -FilePath "$CmdCli" -NoNewWindow -PassThru `
                    -ArgumentList $MyQtArgumentListString
            $MyCmdProcessHandle = $MyCmdProcess.Handle
            $MyCmdProcess.WaitForExit()
            $MyCmdProcessExitCode = $MyCmdProcess.ExitCode
            if ($MyCmdProcessExitCode -ne 0) {
                Write-Error "[PowerShell] Building project for platform $MyGoPlatform ... Generating Qt project ... FAILED (ExitCode: $MyCmdProcessExitCode)"
                Exit 1
            }
        } catch {
            Write-Error "[PowerShell] Building project for platform $MyGoPlatform ... Generating Qt project ... FAILED (Cmd is missing)"
            Exit 1
        } finally {
            if ($null -ne $MyCmdProcessHandle) {
                $MyCmdProcessHandle = $null
            }
            if ($null -ne $MyBinaryBuildProcess) {
                $MyCmdProcess.Dispose()
                $MyCmdProcess = $null
            }
        }
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Generating Qt project ... DONE"

        ## Build project for arch $MyQtPlatform - Compile Qt
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Compiling Qt ..."
        $MyNmakeProcess = $null
        $MyNmakeProcessHandle = $null
        try {
            $MyNmakeProcess = Start-Process -FilePath "$NmakeCli" -NoNewWindow -PassThru
            $MyNmakeProcessHandle = $MyNmakeProcess.Handle
            $MyNmakeProcess.WaitForExit()
            $MyNmakeProcessExitCode = $MyNmakeProcess.ExitCode
            if ($MyNmakeProcessExitCode -ne 0) {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Compiling Qt ... FAILED (ExitCode: $MyNmakeProcessExitCode)"
                Exit 1
            }
        } catch {
            Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Compiling Qt ... FAILED (NMake is missing)"
            Exit 1
        } finally {
            if ($null -ne $MyNmakeProcessHandle) {
                $MyNmakeProcessHandle = $null
            }
            if ($null -ne $MyNmakeProcess) {
                $MyNmakeProcess.Dispose()
                $MyNmakeProcess = $null
            }
        }
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Compiling Qt ... DONE"

        ## Build project for arch $MyQtPlatform - Install Qt
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Installing Qt ..."
        $MyNmakeProcess = $null
        $MyNmakeProcessHandle = $null
        try {
            $MyNmakeProcess = Start-Process -FilePath "$NmakeCli" -NoNewWindow -PassThru `
                    -ArgumentList "install"
            $MyNmakeProcessHandle = $MyNmakeProcess.Handle
            $MyNmakeProcess.WaitForExit()
            $MyNmakeProcessExitCode = $MyNmakeProcess.ExitCode
            if ($MyNmakeProcessExitCode -ne 0) {
                Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Installing Qt ... FAILED (ExitCode: $MyNmakeProcessExitCode)"
                Exit 1
            }
        } catch {
            Write-Error "[PowerShell] Building project for arch $MyQtPlatform ... Installing Qt ... FAILED (NMake is missing)"
            Exit 1
        } finally {
            if ($null -ne $MyNmakeProcessHandle) {
                $MyNmakeProcessHandle = $null
            }
            if ($null -ne $MyNmakeProcess) {
                $MyNmakeProcess.Dispose()
                $MyNmakeProcess = $null
            }
        }
        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... Installing Qt ... DONE"

        Write-Information "[PowerShell] Building project for arch $MyQtPlatform ... DONE"
    }
}
Write-Information "[PowerShell] Building project ... DONE"
