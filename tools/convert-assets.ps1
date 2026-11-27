param(
    [string]$Dk2Folder = 'C:\Program Files (x86)\Dungeon Keeper 2'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$jdkRoot = Join-Path (Split-Path $root -Parent) '_tools'
$jdk = Get-ChildItem -Directory -Path $jdkRoot -Filter 'jdk-*' |
    Where-Object { Test-Path (Join-Path $_.FullName 'bin\javac.exe') } |
    Select-Object -First 1

if (-not $jdk) { throw "JDK 25 not found under $jdkRoot" }
$env:JAVA_HOME = $jdk.FullName
$env:PATH = "$($jdk.FullName)\bin;$env:PATH"
Write-Host "Using JDK: $($jdk.FullName)"

$openKeeper = Join-Path $root 'OpenKeeper'
Push-Location $openKeeper
try {
    & .\gradlew.bat classes installDist --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with $LASTEXITCODE" }
} finally {
    Pop-Location
}

$lib = Join-Path $openKeeper 'build\install\OpenKeeper\lib\*'
$classes = Join-Path $openKeeper 'build\classes\java\main'
$cp = "$lib;$classes"
$out = Join-Path $PSScriptRoot 'headless\out'
New-Item -ItemType Directory -Force -Path $out | Out-Null

& "$($jdk.FullName)\bin\javac.exe" -encoding UTF-8 -cp $cp -d $out `
    (Join-Path $PSScriptRoot 'headless\HeadlessAssetsConverter.java')
if ($LASTEXITCODE -ne 0) { throw "javac failed with $LASTEXITCODE" }

# AssetsConverter resolves "assets/Converted" against the current directory.
Push-Location $openKeeper
try {
    & "$($jdk.FullName)\bin\java.exe" -cp "$cp;$out" HeadlessAssetsConverter $Dk2Folder
    if ($LASTEXITCODE -ne 0) { throw "Asset conversion failed with $LASTEXITCODE" }
} finally {
    Pop-Location
}

$converted = Join-Path $openKeeper 'assets\Converted'
Write-Host "Converted assets: $converted"
Get-ChildItem -Directory $converted | Select-Object Name
