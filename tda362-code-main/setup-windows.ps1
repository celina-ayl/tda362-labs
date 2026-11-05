#Requires -Version 5.1
<#
.SYNOPSIS
Installs the Windows course tools, builds the labs, and opens VS Code.
.DESCRIPTION
Run as your normal Windows user. Only the installers request administrator access.
Existing tools are reused. Run again after a restart if an installer requires one.
Use -CheckOnly to report prerequisites without installing or changing anything.
#>
[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot

function Refresh-ToolPath {
    # Preserve developer-shell entries while picking up newly installed programs.
    $paths = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:PATH
        "$env:ProgramFiles\CMake\bin"
        "$env:ProgramFiles\Git\cmd"
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
        "$env:ProgramFiles\Microsoft VS Code\bin"
    )
    $env:PATH = ((($paths -join ';') -split ';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Find-CppTools {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $instances = & $vswhere -latest -products '*' -version '[17.0,)' `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json
        if ($LASTEXITCODE -ne 0) { throw 'Could not query installed C++ Build Tools.' }
        $instance = @($instances -join "`n" | ConvertFrom-Json) | Select-Object -First 1
        if ($instance) { return $instance }
    }
}

function Save-ToolPaths {
    # Build tasks run these commands directly, including after the next login.
    $userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
    $savedPaths = @(([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + $userPath) -split ';' |
        ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') })
    foreach ($command in @('cmake.exe', 'git.exe', 'code.cmd')) {
        $directory = Split-Path (Get-Command $command).Source
        if ($savedPaths -notcontains $directory.TrimEnd('\')) {
            $userPath = ($userPath.TrimEnd(';') + ';' + $directory).TrimStart(';')
            $savedPaths += $directory.TrimEnd('\')
            Write-Host "Adding to your user PATH: $directory"
        }
    }
    [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
}

function Test-WindowsSdk {
    $kits = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' -ErrorAction SilentlyContinue
    if ($kits -and $kits.KitsRoot10) {
        $versions = Get-ChildItem (Join-Path $kits.KitsRoot10 'Include') -Directory -ErrorAction SilentlyContinue
        foreach ($version in $versions) {
            if ((Test-Path (Join-Path $version.FullName 'um\Windows.h')) -and
                (Test-Path (Join-Path $kits.KitsRoot10 "Lib\$($version.Name)\um\x64\kernel32.lib")) -and
                (Test-Path (Join-Path $version.FullName 'ucrt\stdio.h'))) { return $true }
        }
    }
    return $false
}

function Invoke-Checked {
    param([string]$Program, [string[]]$ToolArguments)
    & $Program @ToolArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed (exit code $LASTEXITCODE). See the output above."
    }
}

function Install-Tool {
    param([string]$Command, [string]$PackageId)
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "Already installed: $Command"
        return
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'Windows App Installer (winget) is missing. Install/update App Installer from Microsoft Store, then run setup again: https://aka.ms/getwinget'
    }
    Write-Host "Installing $PackageId..."
    Invoke-Checked 'winget.exe' @('install', '--id', $PackageId, '--exact', '--source', 'winget',
        '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    Refresh-ToolPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$PackageId was installed but $Command is not available. Restart Windows and run setup again."
    }
}

function Install-CppTools {
    if ((Find-CppTools) -and (Test-WindowsSdk)) {
        Write-Host 'Already installed: MSVC and Windows SDK'
        return
    }
    Write-Host 'Installing Microsoft C++ Build Tools and Windows SDK. This can take several minutes.'
    $installer = Join-Path $env:TEMP 'tda362-vs-buildtools.exe'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile $installer -UseBasicParsing
    $installerArguments = '--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $existingBuildTools = & $vswhere -latest -products Microsoft.VisualStudio.Product.BuildTools `
            -version '[17.0,18.0)' -property installationPath
        if ($LASTEXITCODE -ne 0) { throw 'Could not query the Build Tools installation.' }
        if ($existingBuildTools) {
            $installerArguments = 'modify --installPath "' + $existingBuildTools + '" ' + $installerArguments
        }
    }
    $installation = Start-Process -FilePath $installer -ArgumentList $installerArguments `
        -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    if ($installation.ExitCode -eq 3010) {
        throw 'The C++ tools were installed and need a restart. Restart Windows, then run setup again.'
    }
    if ($installation.ExitCode -ne 0) { throw "C++ Build Tools installer failed (exit code $($installation.ExitCode))." }
    if (-not ((Find-CppTools) -and (Test-WindowsSdk))) { throw 'MSVC or the Windows SDK is still missing. Check the installer output and run setup again.' }
}

function Prepare-BuildDirectory {
    param([string]$ProjectPath, [string]$Generator, [string]$Instance)
    $projectRoot = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\', '/')
    $buildPath = Join-Path $projectRoot 'build'
    $cachePath = Join-Path $buildPath 'CMakeCache.txt'
    if (Test-Path -LiteralPath $cachePath) {
        $cache = @{}
        foreach ($line in Get-Content -LiteralPath $cachePath) {
            if ($line -match '^([^#/:=]+):[^=]*=(.*)$') { $cache[$matches[1]] = $matches[2] }
        }
        $cachedSource = ([string]$cache['CMAKE_HOME_DIRECTORY']).Replace('/', '\').TrimEnd('\')
        $cachedInstance = ([string]$cache['CMAKE_GENERATOR_INSTANCE']).Replace('/', '\').TrimEnd('\')
        if ($cache['CMAKE_GENERATOR'] -ne $Generator -or
            $cache['CMAKE_GENERATOR_PLATFORM'] -ne 'x64' -or
            $cachedSource -ne $projectRoot.Replace('/', '\') -or
            $cachedInstance -ne $Instance.Replace('/', '\').TrimEnd('\')) {
            $backupName = 'build.previous.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
            $backupPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $backupName))
            # Both absolute paths must be immediate children of this project.
            if ((Split-Path $buildPath -Parent) -ne $projectRoot -or
                (Split-Path $backupPath -Parent) -ne $projectRoot) { throw 'Unexpected build backup path.' }
            Rename-Item -LiteralPath $buildPath -NewName $backupName
            New-Item -ItemType Directory -Path $buildPath | Out-Null
            return $backupPath
        }
    }
    New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
}

$transcribing = $false
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        -not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'This setup requires x64 Windows and 64-bit Windows PowerShell. For Linux, follow README_LINUX.md.'
    }
    Refresh-ToolPath
    if ($CheckOnly) {
        $missing = @()
        foreach ($command in @('cmake.exe', 'git.exe', 'code.cmd')) {
            $tool = Get-Command $command -ErrorAction SilentlyContinue
            if ($tool) { Write-Host "$command : $($tool.Source)" }
            else { Write-Host "$command : missing"; $missing += $command }
        }
        if (-not (Find-CppTools)) { $missing += 'MSVC'; Write-Host 'MSVC: missing' }
        else { Write-Host 'MSVC: installed' }
        if (-not (Test-WindowsSdk)) { $missing += 'Windows SDK'; Write-Host 'Windows SDK: missing' }
        else { Write-Host 'Windows SDK: installed' }
        if ($missing.Count) { throw "Missing prerequisites: $($missing -join ', ')" }
        Write-Host 'All prerequisite tools are installed. No changes made.'
        exit 0
    }

    New-Item -ItemType Directory -Path (Join-Path $projectDirectory 'build') -Force | Out-Null
    Start-Transcript -Path (Join-Path $projectDirectory 'build\setup-windows.log') -Append | Out-Null
    $transcribing = $true
    Write-Host 'Setting up the graphics labs: VS Code, CMake, Git, Microsoft C++ tools, and extensions.'
    Write-Host 'Existing tools are reused. Installers may request administrator permission.'
    Install-Tool 'cmake.exe' 'Kitware.CMake'
    Install-Tool 'git.exe' 'Git.Git'
    Install-Tool 'code.cmd' 'Microsoft.VisualStudioCode'
    Install-CppTools
    Refresh-ToolPath
    Save-ToolPaths

    $cppTools = Find-CppTools
    $majorVersion = ([version]$cppTools.installationVersion).Major
    $capabilities = (& cmake.exe -E capabilities) -join "`n" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Could not query CMake capabilities.' }
    $generator = $capabilities.generators.name | Where-Object { $_ -like "Visual Studio $majorVersion *" } | Select-Object -First 1
    if (-not $generator) { throw 'CMake is too old for the installed C++ tools. Update CMake, then run setup again.' }

    Write-Host 'Installing the VS Code extensions...'
    foreach ($extension in @('ms-vscode.cpptools', 'ms-vscode.cmake-tools')) {
        Invoke-Checked 'code.cmd' @('--install-extension', $extension)
    }
    Write-Host 'Configuring and building the labs...'
    # Close the log before moving an incompatible build directory on Windows.
    Stop-Transcript | Out-Null
    $transcribing = $false
    $previousBuild = Prepare-BuildDirectory $projectDirectory $generator $cppTools.installationPath
    Start-Transcript -Path (Join-Path $projectDirectory 'build\setup-windows.log') -Append | Out-Null
    $transcribing = $true
    if ($previousBuild) { Write-Host "Previous build configuration saved in $previousBuild. Configuring a fresh x64 build." }
    Invoke-Checked 'cmake.exe' @('-S', $projectDirectory, '-B', (Join-Path $projectDirectory 'build'),
        '-G', $generator, '-A', 'x64', "-DCMAKE_GENERATOR_INSTANCE=$($cppTools.installationPath)")
    Invoke-Checked 'cmake.exe' @('--build', (Join-Path $projectDirectory 'build'), '--config', 'Debug', '--parallel', '2')
    Write-Host 'Setup complete. In VS Code, open Run and Debug, select lab1-rasterization, and press F5.'
    Write-Host 'If VS Code was already open during setup, close all its windows and reopen the project to refresh its tools.'
    if (-not $NoLaunch) { Invoke-Checked 'code.cmd' @('--new-window', $projectDirectory) }
}
catch {
    Write-Host "`nSETUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'You can run setup again after fixing the problem. Existing source files are kept.'
    exit 1
}
finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
}
