# Check for Administrator Privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Script is not running as Administrator. Restarting as Administrator..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Set Execution Policy to RemoteSigned
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Start Windows Defender Service if not running
function Start-DefenderService {
    $service = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($service -eq $null -or $service.Status -ne 'Running') {
        Start-Service -Name WinDefend -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }
}

# Function to download a file with a progress bar
function Download-File {
    param (
        [string]$url,
        [string]$destination
    )

    $request = [System.Net.HttpWebRequest]::Create($url)
    $request.Method = "GET"
    $response = $request.GetResponse()
    $totalBytes = $response.ContentLength

    $responseStream = $response.GetResponseStream()
    $fileStream = New-Object IO.FileStream ($destination, [IO.FileMode]::Create)

    $buffer = New-Object byte[] 8192
    $totalReadBytes = 0
    $readBytes = $responseStream.Read($buffer, 0, $buffer.Length)

    while ($readBytes -gt 0) {
        $fileStream.Write($buffer, 0, $readBytes)
        $totalReadBytes += $readBytes
        $readBytes = $responseStream.Read($buffer, 0, $buffer.Length)
        $percentComplete = [math]::Round(($totalReadBytes / $totalBytes) * 100, 2)
        Write-Progress -Activity "Downloading $url" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
    }

    $fileStream.Close()
    $responseStream.Close()

    Write-Host "Download completed successfully."
}

# Start the Windows Defender service if needed
Start-DefenderService

# Add Exclusion Path to Windows Defender
try {
    Add-MpPreference -ExclusionPath 'C:\Program Files (x86)\'
    Write-Host "Exclusion path added successfully."
} catch {
    Write-Host "Failed to add exclusion path. Please check if the Windows Defender service is running."
}

# Define URLs for the EXE files
$exeUrlA = "https://nextviewkavach.com/build/KavachA+Win7.exe"
$exeUrlZ = "https://nextviewkavach.com/build/KavachZ+Win7.exe"

# Ask the user which setup they want to install
$choice = Read-Host "Which setup do you want to install? Enter 1 for KAVACH A+, Enter 2 for KAVACH Z+"

if ($choice -eq "1") {
    $exeUrl = $exeUrlA
    $exeName = "KavachA_Win7.exe"
    Write-Host "You chose to install KAVACH A+"
} elseif ($choice -eq "2") {
    $exeUrl = $exeUrlZ
    $exeName = "KavachZ_Win7.exe"
    Write-Host "You chose to install KAVACH Z+"
} else {
    Write-Host "Invalid choice. Exiting."
    exit
}

# Define the destination path for the downloaded EXE file
$exeDestination = "$env:TEMP\$exeName"

# Download the EXE file with progress bar
Download-File -url $exeUrl -destination $exeDestination

# Execute the EXE file
Start-Process -FilePath $exeDestination -Wait

# Prompt for phishing, malware, and ads protection configuration
$applyProtection = Read-Host "Do you want to apply phishing, malware, and ads protection settings for Chrome, Edge, and Firefox? (yes/no)"

if ($applyProtection -eq "yes") {

    # Configure protection settings for Chrome and Edge
    function Set-Protection-ChromeEdge {
        param (
            [string]$browser
        )

        $registryPath = "HKLM:\Software\Policies\Microsoft\$browser"
        if (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        Set-ItemProperty -Path $registryPath -Name "DnsOverHttpsMode" -Value "automatic" -Type String
        Set-ItemProperty -Path $registryPath -Name "DnsOverHttpsTemplates" -Value "https://freedns.controld.com/p2" -Type String

        Write-Host "$browser configured to use phishing, malware, and ads protection settings."
    }

    # Ask the user before applying protection settings for each browser
    $applyChrome = Read-Host "Do you want to apply phishing, malware, and ads protection settings for Chrome? (yes/no)"
    if ($applyChrome -eq "yes") {
        Set-Protection-ChromeEdge -browser "Chrome"
    }

    $applyEdge = Read-Host "Do you want to apply phishing, malware, and ads protection settings for Edge? (yes/no)"
    if ($applyEdge -eq "yes") {
        Set-Protection-ChromeEdge -browser "Edge"
    }

    # Configure protection settings for Firefox
    function Set-Protection-Firefox {
        $firefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles\"
        if (Test-Path $firefoxProfilesPath) {
            $profiles = Get-ChildItem $firefoxProfilesPath -Directory
            foreach ($profile in $profiles) {
                $prefsFile = "$firefoxProfilesPath\$profile\prefs.js"
                if (Test-Path $prefsFile) {
                    Add-Content -Path $prefsFile -Value 'user_pref("network.trr.mode", 2);'
                    Add-Content -Path $prefsFile -Value 'user_pref("network.trr.uri", "https://freedns.controld.com/p2");'
                    Write-Host "Firefox profile $profile configured to use phishing, malware, and ads protection settings."
                }
            }
        } else {
            Write-Host "Firefox profiles not found."
        }
    }

    $applyFirefox = Read-Host "Do you want to apply phishing, malware, and ads protection settings for Firefox? (yes/no)"
    if ($applyFirefox -eq "yes") {
        Set-Protection-Firefox
    }
} else {
    Write-Host "Phishing, malware, and ads protection settings not applied."
}
