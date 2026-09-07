param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe

$fourPartVersion = if ($Version.Split('.').Count -eq 3) { "$Version.0" } else { $Version }
Invoke-ps2exe `
    -inputFile (Join-Path $projectRoot 'ShirtDesignFolderBuilder.ps1') `
    -outputFile (Join-Path $dist 'ShirtDesignFolderBuilder.exe') `
    -iconFile (Join-Path $projectRoot 'JM-Folder-Creator.ico') `
    -title 'J&M Apparel Shirt Design Folder Builder' `
    -description 'Creates organized and numbered shirt-design folder sets.' `
    -company 'J&M Apparel' `
    -product 'Shirt Design Folder Builder' `
    -copyright 'J&M Apparel' `
    -version $fourPartVersion `
    -noConsole `
    -STA

$innoCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$iscc = $innoCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 was not found.' }

& $iscc "/DAppVersion=$Version" (Join-Path $projectRoot 'ShirtFolderSetup.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }

Write-Host "Installer created: $(Join-Path $dist 'ShirtFolderSetup.exe')"

