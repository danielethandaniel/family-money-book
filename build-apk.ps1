$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$App = Join-Path $Root "app"
$Build = Join-Path $Root "build"
$Generated = Join-Path $Build "generated"
$Classes = Join-Path $Build "classes"
$Dex = Join-Path $Build "dex"
$CompiledRes = Join-Path $Build "compiled-res.zip"
$UnsignedApk = Join-Path $Build "unsigned.apk"
$AlignedApk = Join-Path $Build "aligned.apk"
$FinalApk = Join-Path $Root "family-money-book.apk"
$SigningKeystore = $env:SIGNING_KEYSTORE
$SigningStorePass = $env:SIGNING_STOREPASS
$SigningKeyPass = $env:SIGNING_KEYPASS
$SigningAlias = $env:SIGNING_ALIAS

function Find-FirstFile($RootPath, $Pattern) {
    if (-not (Test-Path $RootPath)) { return $null }
    return Get-ChildItem -Path $RootPath -Recurse -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

function Find-JavaHome {
    $candidates = @(
        (Join-Path $Root ".conda-jdk\Library"),
        (Join-Path $Root "jdk")
    )
    foreach ($candidate in $candidates) {
        $javac = Find-FirstFile $candidate "javac.exe"
        if ($javac) {
            return (Split-Path -Parent (Split-Path -Parent $javac))
        }
    }
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\javac.exe"))) {
        return $env:JAVA_HOME
    }
    throw "JDK not found. Expected .conda-jdk\Library, jdk, or JAVA_HOME."
}

function Find-AndroidSdk {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA "Android\sdk"),
        (Join-Path $env:PROGRAMDATA "Android\sdk")
    ) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($candidate in $candidates) {
        if ((Test-Path (Join-Path $candidate "platforms")) -and (Test-Path (Join-Path $candidate "build-tools"))) {
            return $candidate
        }
    }
    throw "Android SDK not found. Install command line tools and packages first."
}

function Latest-Directory($Path) {
    $dir = Get-ChildItem -Path $Path -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $dir) { throw "No directory found in $Path" }
    return $dir.FullName
}

function Assert-Exit($Name) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

if (Test-Path $Build) {
    Remove-Item -LiteralPath $Build -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Build, $Generated, $Classes, $Dex | Out-Null

$JavaHome = Find-JavaHome
$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome "bin") + ";" + $env:PATH

$AndroidSdk = Find-AndroidSdk
$BuildTools = Latest-Directory (Join-Path $AndroidSdk "build-tools")
$Platform = Latest-Directory (Join-Path $AndroidSdk "platforms")
$AndroidJar = Join-Path $Platform "android.jar"

$Aapt2 = Join-Path $BuildTools "aapt2.exe"
$D8 = Join-Path $BuildTools "d8.bat"
$Zipalign = Join-Path $BuildTools "zipalign.exe"
$ApkSigner = Join-Path $BuildTools "apksigner.bat"
$Javac = Join-Path $JavaHome "bin\javac.exe"
$Jar = Join-Path $JavaHome "bin\jar.exe"

foreach ($tool in @($AndroidJar, $Aapt2, $D8, $Zipalign, $ApkSigner, $Javac, $Jar)) {
    if (-not (Test-Path $tool)) { throw "Missing build tool: $tool" }
}

& $Aapt2 compile --dir (Join-Path $App "src\main\res") -o $CompiledRes
Assert-Exit "aapt2 compile"
$Aapt2LinkArgs = @(
    "link",
    "-o", $UnsignedApk,
    "-I", $AndroidJar,
    "--manifest", (Join-Path $App "src\main\AndroidManifest.xml"),
    "-R", $CompiledRes,
    "--auto-add-overlay",
    "--java", $Generated,
    "--min-sdk-version", "23",
    "--target-sdk-version", "35",
    "--version-code", "1",
    "--version-name", "1.0"
)
$Assets = Join-Path $App "src\main\assets"
if (Test-Path $Assets) {
    $Aapt2LinkArgs += @("-A", $Assets)
}
& $Aapt2 @Aapt2LinkArgs
Assert-Exit "aapt2 link"

$SourcesFile = Join-Path $Build "sources.txt"
Get-ChildItem -Path (Join-Path $App "src\main\java"), $Generated -Recurse -Filter "*.java" |
    ForEach-Object { $_.FullName } |
    Set-Content -Path $SourcesFile -Encoding ASCII

& $Javac -encoding UTF-8 -source 8 -target 8 -bootclasspath $AndroidJar -d $Classes "@$SourcesFile"
Assert-Exit "javac"

$ClassFiles = Get-ChildItem -Path $Classes -Recurse -Filter "*.class" | ForEach-Object { $_.FullName }
& $D8 --min-api 23 --lib $AndroidJar --output $Dex $ClassFiles
Assert-Exit "d8"
& $Jar uf $UnsignedApk -C $Dex classes.dex
Assert-Exit "jar"

& $Zipalign -p -f 4 $UnsignedApk $AlignedApk
Assert-Exit "zipalign"

$CanSign = $SigningKeystore -and $SigningStorePass -and $SigningKeyPass -and $SigningAlias -and (Test-Path $SigningKeystore)
if ($CanSign) {
    & $ApkSigner sign `
        --ks $SigningKeystore `
        --ks-pass ("pass:" + $SigningStorePass) `
        --key-pass ("pass:" + $SigningKeyPass) `
        --ks-key-alias $SigningAlias `
        --out $FinalApk `
        $AlignedApk
    Assert-Exit "apksigner sign"
    & $ApkSigner verify --verbose $FinalApk
    Assert-Exit "apksigner verify"
    Write-Host "Signed APK built: $FinalApk"
} else {
    Copy-Item -LiteralPath $AlignedApk -Destination $FinalApk -Force
    Write-Host "Unsigned APK built: $FinalApk"
    Write-Host "Set SIGNING_KEYSTORE, SIGNING_STOREPASS, SIGNING_KEYPASS, and SIGNING_ALIAS to sign the APK."
}
