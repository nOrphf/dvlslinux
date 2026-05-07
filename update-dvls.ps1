$DVLSPath = "/opt/devolutions/dvls"
$DVLSProductURL = "https://devolutions.net/productinfo.htm"

function Set-DVLSPerms {
    Param(
        $DVLSPath
    )
    & pwsh -Command {
        Param(
            $DVLSPath
        )
        chown -R dvls:dvls /opt/devolutions/dvls
        chmod 550 /opt/devolutions/dvls
        chown -R dvls:dvls $DVLSPath
        chmod -R o-rwx $DVLSPath
        chmod 660 (Join-Path -Path $DVLSPath -ChildPath "appsettings.json")
        chmod 770 (Join-Path -Path $DVLSPath -ChildPath "App_Data")
        chown -R dvls:dvls $DVLSPath
        setcap CAP_NET_BIND_SERVICE=+eip (Join-Path -Path $DVLSPath -ChildPath "Devolutions.Server")
    } -Args $DVLSPath
}

if (-not (Test-Path $DVLSPath)) {
    New-Item -Type Directory -Path /opt/devolutions/dvls
}

$Result = (Invoke-RestMethod -Method "GET" -Uri $DVLSProductURL) -Split "`r"

$DVLSLinux = [PSCustomObject]@{
    "Version" = (($Result | Select-String DPSLinuxX64bin.Version) -Split "=")[-1].Trim()
    "URL"     = (($Result | Select-String DPSLinuxX64bin.Url) -Split "=")[-1].Trim()
    "Hash"    = (($Result | Select-String DPSLinuxX64bin.hash) -Split "=")[-1].Trim()
}

$DVLSDownloadPath = Join-Path -Path "/tmp" -ChildPath (([URI]$DVLSLinux.URL).Segments)[-1]

Invoke-RestMethod -Method "GET" -Uri $DVLSLinux.URL -OutFile $DVLSDownloadPath
systemctl stop dvls
if (Test-Path (Join-Path -Path $DVLSPath -ChildPath "appsettings.json")) {
    Copy-Item -Path (Join-Path -Path $DVLSPath -ChildPath "appsettings.json") -Destination (Join-Path -Path $DVLSPath -ChildPath "appsettings.json.bak") -Force
    tar -xzf $DVLSDownloadPath -C $DVLSPath --strip-components=1
    Copy-Item -Path (Join-Path -Path $DVLSPath -ChildPath "appsettings.json.bak") -Destination (Join-Path -Path $DVLSPath -ChildPath "appsettings.json") -Force
}else {
    tar -xzf $DVLSDownloadPath -C $DVLSPath --strip-components=1
}
Remove-Item -Path $DVLSDownloadPath

if (-not (id -u dvls)) {
    useradd -N dvls
}
[bool]$GroupExsists = $false
foreach ($currentItem in (Get-Content /etc/group)) {
    if ($currentItem -like "*dvls*") {
        $GroupExsists = $true
        break
    }
}
if (-not $GroupExsists) {
    groupadd dvls
}
Set-DVLSPerms -DVLSPath $DVLSPath

Push-Location -Path $DVLSPath

$JSON = Get-Content -Path (Join-Path -Path $DVLSPath -ChildPath "appsettings.json") | ConvertFrom-JSON -Depth 100

if (-not $JSON.Kestrel) {

    usermod -a -G dvls dvls
    # optional, add current user to dvls group
    usermod -a -G dvls $(id -un)

    
    $DVLSAdminUsername = 'dvls-admin'
    $DVLSAdminPassword = '%VYPeJz&dX2gy5uFqyndzHx0Ceeh0w9&DNMdfH2ZPX'
    $DVLSAdminEmail    = 'lmor@4tw.dk'  

    $Params = @{
        "DatabaseHost"           = "sql01.auth.4tw.dk"
        "DatabaseName"           = "DVLSDB"
        "DatabaseUserName"       = "dvlsuser"
        "DatabasePassword"       = "qT6q.SF,Ir!,LQwpJe7d#TLVoL.157"
        "ServerName"             = "4tw Enterprise"
        "AccessUri"              = "http://dvls.4tw.dk"
        "HttpListenerUri"        = "http://dvls.4tw.dk"
        "DPSPath"                = $DVLSPath
        "UseEncryptedconnection" = $false # Modify as needed
        "TrustServerCertificate" = $true # Modify as needed
        "EnableTelemetry"        = $true # Modify as needed
        "DisableEncryptConfig"   = $true
    }
    $Configuration = New-DPSInstallConfiguration @Params
    New-DPSAppsettings -Configuration $Configuration

    $Settings = Get-DPSAppSettings -ApplicationPath $DVLSPath

    New-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer
    Update-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -InstallationPath $DVLSPath
    New-DPSDataSourceSettings -ConnectionString $Settings.ConnectionStrings.LocalSqlServer

    New-DPSEncryptConfiguration -ApplicationPath $DVLSPath
    New-DPSDatabaseAppSettings -Configuration $Configuration

    New-DPSAdministrator -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -Name $DVLSAdminUsername -Password $DVLSAdminPassword -Email $DVLSAdminEmail
}else {

    $Settings = Get-DPSAppSettings -ApplicationPath $DVLSPath
    Update-DPSDatabase -ConnectionString $Settings.ConnectionStrings.LocalSqlServer -InstallationPath $DVLSPath
    #New-DPSDataSourceSettings -ConnectionString $Settings.ConnectionStrings.LocalSqlServer

    #New-DPSEncryptConfiguration -ApplicationPath $DVLSPath
    #New-DPSDatabaseAppSettings -Configuration $Configuration
}
Set-DVLSPerms -DVLSPath $DVLSPath
systemctl start dvls




$CleanDVLS = $false
if ($CleanDVLS) {
    journalctl --flush --rotate --vacuum-time=1s
    rm -rf /opt/devolutions/dvls
}