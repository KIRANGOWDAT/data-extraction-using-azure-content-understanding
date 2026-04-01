Param (
    [string]$AdminUsername = "azureadmin",
    [string]$AdminPassword = "",
    [string]$DVMIP = ""
)

# ============================================================================
# Lab VM Setup Script - Data Extraction Using Azure Content Understanding
# This script is executed by Azure Custom Script Extension during VM provisioning.
# It installs all prerequisites so the lab is ready to use immediately.
# ============================================================================

Start-Transcript -Path "C:\WindowsAzure\Logs\LabSetup.log" -Append -Force

$ErrorActionPreference = "SilentlyContinue"

# ---------- Helper Functions ----------

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

function Disable-InternetExplorerESC {
    Write-Log "Disabling IE Enhanced Security Configuration..."
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $UserKey  -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
    Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
    Write-Log "IE ESC disabled."
}

function Disable-UserAccessControl {
    Write-Log "Disabling UAC..."
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0
    Write-Log "UAC disabled."
}

function Enable-LongPaths {
    Write-Log "Enabling long paths..."
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1
    Write-Log "Long paths enabled."
}

function Set-WindowsFirewallRules {
    Write-Log "Configuring Windows Firewall for lab..."
    New-NetFirewallRule -DisplayName "Allow Azure Functions Port 7071" -Direction Inbound -LocalPort 7071 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Allow HTTPS 443" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    Write-Log "Firewall rules configured."
}

# ---------- Install Chocolatey ----------

function Install-Chocolatey {
    Write-Log "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    choco feature enable -n allowGlobalConfirmation
    Write-Log "Chocolatey installed."
}

# ---------- Install Prerequisites ----------

function Install-Python {
    Write-Log "Installing Python 3.12..."
    choco install python312 --params "/InstallDir:C:\Python312" -y
    # Refresh path
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    # Upgrade pip
    & "C:\Python312\python.exe" -m pip install --upgrade pip
    Write-Log "Python 3.12 installed."
}

function Install-AzureCLI {
    Write-Log "Installing Azure CLI..."
    choco install azure-cli -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Azure CLI installed."
}

function Install-Terraform {
    Write-Log "Installing Terraform..."
    choco install terraform -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Terraform installed."
}

function Install-Git {
    Write-Log "Installing Git..."
    choco install git.install --params "/GitAndUnixToolsOnPath /NoShellIntegration" -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Git installed."
}

function Install-NodeJS {
    Write-Log "Installing Node.js 18 LTS..."
    choco install nodejs-lts --version=18.20.4 -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Node.js 18 installed."
}

function Install-AzureFunctionsCoreTools {
    Write-Log "Installing Azure Functions Core Tools v4..."
    choco install azure-functions-core-tools -y --params "'/x64'"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Azure Functions Core Tools v4 installed."
}

function Install-VSCode {
    Write-Log "Installing Visual Studio Code..."
    choco install vscode -y --params "/NoDesktopIcon"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Wait for VS Code installation to complete
    Start-Sleep -Seconds 10

    # Install VS Code Extensions
    Write-Log "Installing VS Code extensions..."
    $codePath = "C:\Program Files\Microsoft VS Code\bin\code.cmd"
    
    if (Test-Path $codePath) {
        & $codePath --install-extension ms-python.python --force
        & $codePath --install-extension ms-azuretools.vscode-azurefunctions --force
        & $codePath --install-extension humao.rest-client --force
        & $codePath --install-extension ms-python.vscode-pylance --force
        & $codePath --install-extension hashicorp.terraform --force
        & $codePath --install-extension ms-vscode.azure-account --force
        & $codePath --install-extension tomoki1207.pdf --force
        Write-Log "VS Code extensions installed."
    }
    else {
        Write-Log "WARNING: VS Code path not found at $codePath"
    }
}

function Install-DotNet {
    Write-Log "Installing .NET 8.0 SDK..."
    choco install dotnet-8.0-sdk -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log ".NET 8.0 SDK installed."
}

# ---------- Clone Repository ----------

function Clone-LabRepository {
    Write-Log "Cloning lab repository..."
    
    $labFilesPath = "C:\LabFiles"
    if (-not (Test-Path $labFilesPath)) {
        New-Item -ItemType Directory -Path $labFilesPath -Force | Out-Null
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    $gitPath = "C:\Program Files\Git\bin\git.exe"
    if (Test-Path $gitPath) {
        & $gitPath clone "https://github.com/KIRANGOWDAT/data-extraction-using-azure-content-understanding.git" "$labFilesPath\data-extraction-using-azure-content-understanding"
        Write-Log "Repository cloned to $labFilesPath."
    }
    else {
        Write-Log "WARNING: Git not found at $gitPath. Retrying with PATH..."
        git clone "https://github.com/KIRANGOWDAT/data-extraction-using-azure-content-understanding.git" "$labFilesPath\data-extraction-using-azure-content-understanding"
    }

    # Remove lab-provider internal folders that users should not see
    $repoPath = "$labFilesPath\data-extraction-using-azure-content-understanding"
    Remove-Item -Path "$repoPath\cloudlabs-setup" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$repoPath\labguide" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$repoPath\media" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Removed internal lab-provider folders from cloned repo."
}

# ---------- Create Desktop Shortcuts ----------

function Create-DesktopShortcuts {
    Write-Log "Creating desktop shortcuts..."
    
    $desktopPath = "C:\Users\$AdminUsername\Desktop"
    if (-not (Test-Path $desktopPath)) {
        $desktopPath = "C:\Users\Public\Desktop"
    }

    # VS Code shortcut pointing to lab folder
    $WshShell = New-Object -ComObject WScript.Shell
    
    $shortcut = $WshShell.CreateShortcut("$desktopPath\Visual Studio Code.lnk")
    $shortcut.TargetPath = "C:\Program Files\Microsoft VS Code\Code.exe"
    $shortcut.Arguments = "C:\LabFiles\data-extraction-using-azure-content-understanding"
    $shortcut.WorkingDirectory = "C:\LabFiles\data-extraction-using-azure-content-understanding"
    $shortcut.IconLocation = "C:\Program Files\Microsoft VS Code\Code.exe,0"
    $shortcut.Save()

    # Lab Files folder shortcut
    $shortcut2 = $WshShell.CreateShortcut("$desktopPath\Lab Files.lnk")
    $shortcut2.TargetPath = "C:\LabFiles\data-extraction-using-azure-content-understanding"
    $shortcut2.Save()

    # Azure Portal shortcut
    $shortcut3 = $WshShell.CreateShortcut("$desktopPath\Azure Portal.url")
    $shortcut3.TargetPath = "https://portal.azure.com"
    $shortcut3.Save()

    # Windows Terminal shortcut
    $shortcut4 = $WshShell.CreateShortcut("$desktopPath\Windows Terminal.lnk")
    $shortcut4.TargetPath = "wt.exe"
    $shortcut4.Save()

    Write-Log "Desktop shortcuts created."
}

# ---------- Configure Edge Browser ----------

function Configure-EdgeBrowser {
    Write-Log "Configuring Microsoft Edge..."
    
    # Set Edge as default browser and disable first-run experience
    $edgeRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $edgeRegPath)) {
        New-Item -Path $edgeRegPath -Force | Out-Null
    }
    Set-ItemProperty -Path $edgeRegPath -Name "HideFirstRunExperience" -Value 1 -Type DWord
    Set-ItemProperty -Path $edgeRegPath -Name "DefaultBrowserSettingEnabled" -Value 0 -Type DWord
    
    Write-Log "Edge configured."
}

# ---------- Set Auto-Logon ----------

function Set-AutoLogon {
    param([string]$Username, [string]$Password)
    
    Write-Log "Configuring auto-logon for $Username..."
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path $regPath -Name "DefaultUsername" -Value $Username
    Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $Password
    Write-Log "Auto-logon configured."
}

# ---------- Create Validation Script ----------

function Create-ValidationScript {
    Write-Log "Creating validation script on desktop..."
    
    $desktopPath = "C:\Users\$AdminUsername\Desktop"
    if (-not (Test-Path $desktopPath)) {
        $desktopPath = "C:\Users\Public\Desktop"
    }

    $validationScript = @'
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Lab Environment Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$checks = @(
    @{ Name = "Python 3.12"; Command = { python --version 2>&1 } },
    @{ Name = "Azure CLI"; Command = { az version 2>&1 | ConvertFrom-Json | Select-Object -ExpandProperty 'azure-cli' } },
    @{ Name = "Terraform"; Command = { terraform version 2>&1 | Select-Object -First 1 } },
    @{ Name = "Git"; Command = { git --version 2>&1 } },
    @{ Name = "Node.js"; Command = { node --version 2>&1 } },
    @{ Name = "Azure Functions Core Tools"; Command = { func --version 2>&1 } },
    @{ Name = "VS Code"; Command = { code --version 2>&1 | Select-Object -First 1 } },
    @{ Name = "Lab Repository"; Command = { if (Test-Path "C:\LabFiles\data-extraction-using-azure-content-understanding") { "Present" } else { "NOT FOUND" } } }
)

foreach ($check in $checks) {
    try {
        $result = & $check.Command
        Write-Host "[PASS] $($check.Name): $result" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] $($check.Name): Not found or error" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Validation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Read-Host "Press Enter to close"
'@

    Set-Content -Path "$desktopPath\Validate-LabSetup.ps1" -Value $validationScript -Force
    Write-Log "Validation script created."
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "========================================"
Write-Log "Starting Lab VM Setup..."
Write-Log "========================================"

# System Configuration
Disable-InternetExplorerESC
Disable-UserAccessControl
Enable-LongPaths
Set-WindowsFirewallRules
Configure-EdgeBrowser

# Install Package Manager
Install-Chocolatey

# Install All Prerequisites
Install-Git
Install-Python
Install-AzureCLI
Install-Terraform
Install-NodeJS
Install-AzureFunctionsCoreTools
Install-VSCode
Install-DotNet

# Clone Repository
Clone-LabRepository

# User Experience Setup
Create-DesktopShortcuts
Create-ValidationScript

# Auto-logon for CloudLabs
if ($AdminPassword -ne "") {
    Set-AutoLogon -Username $AdminUsername -Password $AdminPassword
}

Write-Log "========================================"
Write-Log "Lab VM Setup COMPLETE!"
Write-Log "========================================"

Stop-Transcript

# Signal completion
New-Item -ItemType File -Path "C:\WindowsAzure\Logs\LabSetupComplete.txt" -Value "Setup completed at $(Get-Date)" -Force
