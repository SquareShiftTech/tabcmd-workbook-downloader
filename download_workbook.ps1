z# -----------------------------
# Parameters (Input from user)
# -----------------------------
$server   = Read-Host "Enter Tableau Server URL (e.g., http://localhost)"
$username = Read-Host "Enter Tableau Username"
$password = Read-Host "Enter Tableau Password"
$site     = Read-Host "Enter Site Name (use '' for default site)"


# -----------------------------
# Setup folder for the site
# -----------------------------
$baseFolder = Join-Path $PWD $site
if (-not (Test-Path $baseFolder)) {
    New-Item -ItemType Directory -Path $baseFolder | Out-Null
}

# -----------------------------
# Map site to default when empty
# -----------------------------
if ([string]::IsNullOrWhiteSpace($site)) {
    # map empty input to "default"
    $site = "default"
}

# -----------------------------
# Store password in temp file
# -----------------------------
$pwFile = Join-Path $baseFolder "tabcmd_pw.txt"
# Save plain password with no trailing new line
$password | Out-File -FilePath $pwFile -Encoding ascii -NoNewline
# -----------------------------
# Login to Tableau Server
# -----------------------------
Write-Host "Logging into Tableau Server..."
.\tabcmd login -s $server -t $site -u $username --password-file $pwFile --no-prompt

# -----------------------------
# List workbooks and extract names + contentUrl
# -----------------------------
$rawFile = Join-Path $baseFolder "workbooks_raw.txt"
# Run tabcmd and redirect logs
.\tabcmd list workbooks --details 2>&1 | Out-File $rawFile -Encoding utf8

$csvFile = Join-Path $baseFolder "workbooks_map.csv"
Get-Content $rawFile |
    Where-Object { $_ -match "<WorkbookItem" } |
    ForEach-Object {
        if ($_ -match "<WorkbookItem [^ ]+ '([^']+)' contentUrl='([^']+)'") {
            "$($matches[1]),$($matches[2])"
        }
    } | Set-Content $csvFile -Encoding UTF8

# -----------------------------
# Download each workbook
# -----------------------------
Import-Csv -Path $csvFile -Header DisplayName,ContentUrl |
ForEach-Object {
    $display = $_.DisplayName
    $url = $_.ContentUrl

    # Make filename safe
    $safe_name = $display -replace '[ /:&()#?*\[\]{}$]', '_'

    # Full path for download
    $twbxPath = Join-Path $baseFolder "$safe_name.twbx"
    $twbPath  = Join-Path $baseFolder "$safe_name.twb"

    Write-Host "Downloading: $display  (contentUrl=$url)"

    try {
        .\tabcmd get "/workbooks/$url.twbx" -f $twbxPath
    } catch {
        .\tabcmd get "/workbooks/$url.twb" -f $twbPath
    }
}
# -----------------------------
# Logout and cleanup
# -----------------------------
.\tabcmd logout
Remove-Item $pwFile

Write-Host "All workbooks for site '$site' downloaded to $baseFolder"
