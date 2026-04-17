# EpiTool Installation Script
# One-line installer: iwr -useb "https://your-domain.com/install-plugin.ps1" | iex

# Configuration
$MILLENNIUM_INSTALL_URL = "https://steambrew.app/install.ps1"
$EPITOOL_GITHUB_OWNER = "Kendo4"
$EPITOOL_GITHUB_REPO = "EpiTool"
$EPITOOL_ASSET_NAME = "epitoolplugin.zip"

# ANSI color codes for terminal output
function Write-ColorOutput {
    param(
        [string]$ForegroundColor,
        [string]$Message
    )
    $colorMap = @{
        'Red' = [ConsoleColor]::Red
        'Green' = [ConsoleColor]::Green
        'Yellow' = [ConsoleColor]::Yellow
        'Blue' = [ConsoleColor]::Blue
        'Cyan' = [ConsoleColor]::Cyan
        'White' = [ConsoleColor]::White
    }
    $color = $colorMap[$ForegroundColor]
    if ($color) {
        Write-Host $Message -ForegroundColor $color
    } else {
        Write-Host $Message
    }
}

# EpiTool ASCII Logo
function Show-Logo {
    Write-ColorOutput "Red" @"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ██╗  ██╗███████╗███╗   ██╗████████╗ ██████╗  ██████╗ ║
║     ██║ ██╔╝██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔═══██╗║
║     █████╔╝ █████╗  ██╔██╗ ██║   ██║   ██║   ██║██║   ██║║
║     ██╔═██╗ ██╔══╝  ██║╚██╗██║   ██║   ██║   ██║██║   ██║║
║     ██║  ██╗███████╗██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝║
║     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  ╚═════╝ ║
║                                                           ║
║              Steam Plugin Installation                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "Green" "✓ $Message"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "Red" "✗ $Message"
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "Cyan" "ℹ $Message"
}

function Get-SteamPath {
    # Try to get from registry (Windows)
    try {
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    } catch {
        # Registry access failed, try common paths
    }
    
    # Common Steam paths
    $commonPaths = @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam",
        "$env:USERPROFILE\.steam\steam",
        "$env:USERPROFILE\.local\share\Steam"
    )
    
    foreach ($path in $commonPaths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }
    
    return $null
}

function Install-Millennium {
    param([string]$SteamPath)
    
    Write-Info "Installing Millennium..."
    
    # Check if Millennium is already installed
    $millenniumPath = Join-Path $SteamPath "ext"
    if (Test-Path $millenniumPath) {
        Write-Info "Millennium appears to be already installed, skipping..."
        return $true
    }
    
    # Install via PowerShell script
    Write-Info "Running Millennium installation script..."
    try {
        Invoke-Expression "& { $(Invoke-WebRequest -Uri $MILLENNIUM_INSTALL_URL -UseBasicParsing).Content }"
        Write-Success "Millennium installed successfully!"
        return $true
    } catch {
        Write-Error "Millennium installation failed: $_"
        return $false
    }
}

function Get-LatestGitHubRelease {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$AssetName
    )
    
    try {
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        Write-Info "Fetching latest release from GitHub..."
        
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 15
        $assets = $response.assets
        
        foreach ($asset in $assets) {
            if ($asset.name -eq $AssetName) {
                $tagName = $response.tag_name
                Write-Success "Found release: $tagName"
                return $asset.browser_download_url
            }
        }
        
        Write-Error "Asset '$AssetName' not found in latest release"
        return $null
    } catch {
        Write-Error "Failed to fetch GitHub release: $_"
        return $null
    }
}

function Install-EpiTool {
    param([string]$SteamPath)
    
    Write-Info "Installing EpiTool..."
    
    $pluginsDir = Join-Path $SteamPath "plugins"
    $epitoolDir = Join-Path $pluginsDir "epitool"
    
    # Create plugins directory if it doesn't exist
    if (-not (Test-Path $pluginsDir)) {
        New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
    }
    
    # Download from GitHub
    Write-Info "Fetching latest EpiTool release from GitHub..."
    $downloadUrl = Get-LatestGitHubRelease -Owner $EPITOOL_GITHUB_OWNER -Repo $EPITOOL_GITHUB_REPO -AssetName $EPITOOL_ASSET_NAME
    
    if (-not $downloadUrl) {
        Write-Error "Failed to get download URL"
        return $false
    }
    
    # Download ZIP
    $tempZip = Join-Path $env:TEMP "epitool_temp.zip"
    Write-Info "Downloading EpiTool..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 60
        Write-Success "Download complete!"
    } catch {
        Write-Error "Failed to download: $_"
        return $false
    }
    
    # Remove old installation if exists
    if (Test-Path $epitoolDir) {
        Write-Info "Removing existing installation..."
        Remove-Item -Path $epitoolDir -Recurse -Force
    }
    
    # Extract ZIP
    Write-Info "Extracting EpiTool..."
    try {
        # Create temporary extraction directory
        $tempExtract = Join-Path $env:TEMP "epitool_extract_temp"
        if (Test-Path $tempExtract) {
            Remove-Item -Path $tempExtract -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
        
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        
        # Find the actual plugin files (could be at root or in a subfolder)
        $extractedItems = Get-ChildItem -Path $tempExtract
        $sourceDir = $tempExtract
        
        # Check if there's a single subdirectory (common in GitHub releases)
        if ($extractedItems.Count -eq 1) {
            $singleItem = $extractedItems[0].FullName
            if (Test-Path $singleItem -PathType Container) {
                # Check if it contains plugin.json (indicates it's the plugin root)
                if (Test-Path (Join-Path $singleItem "plugin.json")) {
                    $sourceDir = $singleItem
                }
            }
        }
        
        # Copy to final location
        $itemsToCopy = Get-ChildItem -Path $sourceDir -Exclude '__pycache__', '*.pyc', '*.pyo', '.git'
        foreach ($item in $itemsToCopy) {
            $destPath = Join-Path $epitoolDir $item.Name
            Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force
        }
        
        # Clean up
        Remove-Item -Path $tempExtract -Recurse -Force
        Remove-Item -Path $tempZip -Force
        Write-Success "EpiTool installed successfully!"
        return $true
    } catch {
        Write-Error "Failed to extract EpiTool: $_"
        if (Test-Path $tempZip) {
            Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

# Main function
function Main {
    # Clear screen and show logo
    Clear-Host
    Show-Logo
    
    Write-Info "EpiTool Installer"
    Write-Host ""
    
    # Detect Steam path
    Write-Info "Detecting Steam installation..."
    $steamPath = Get-SteamPath
    
    if (-not $steamPath) {
        Write-Error "Could not detect Steam installation path"
        Write-ColorOutput "Yellow" "`nPlease provide your Steam installation path:"
        $steamPath = Read-Host "Steam path"
        $steamPath = $steamPath.Trim('"')
        
        if (-not $steamPath -or -not (Test-Path $steamPath)) {
            Write-Error "Invalid Steam path"
            exit 1
        }
    }
    
    Write-Success "Found Steam at: $steamPath"
    Write-Host ""
    
    # Install Millennium first
    Write-Info "Step 1/2: Installing Millennium framework..."
    $millenniumResult = Install-Millennium -SteamPath $steamPath
    Write-Host ""
    
    # Install EpiTool
    Write-Info "Step 2/2: Installing EpiTool plugin..."
    $epitoolResult = Install-EpiTool -SteamPath $steamPath
    
    if ($millenniumResult -and $epitoolResult) {
        Write-Host ""
        Write-ColorOutput "Green" "✓ Installation Complete!"
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor White
        Write-ColorOutput "Cyan" "1. Restart Steam to load the plugins"
        Write-ColorOutput "Cyan" "2. EpiTool should appear in your Steam interface"
        Write-Host ""
        Write-ColorOutput "Red" "Thank you for using EpiTool!"
        Write-Host ""
        exit 0
    } else {
        Write-Host ""
        Write-Error "Installation completed with errors. Please check the messages above."
        if (-not $millenniumResult) {
            Write-Error "Millennium installation failed"
        }
        if (-not $epitoolResult) {
            Write-Error "EpiTool installation failed"
        }
        exit 1
    }
}

# Run main function
try {
    Main
} catch {
    Write-Host "`n`nUnexpected error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}

