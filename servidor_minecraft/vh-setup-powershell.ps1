# Vault Hunters 3 Server Setup Script - PowerShell Version
param(
    [string]$ForgeVersion = "40.3.11",
    [string]$JavaVersion = "17",
    [string]$JavaOverride = "",
    [string]$JvmArgs = "",
    [bool]$VH3Restart = $false,
    [bool]$VH3InstallOnly = $false
)

# Global variables
$script:JavaFile = ""
$script:JavaNum = ""

function Find-Java {
    # If JAVA_OVERRIDE is specified, use it
    if ($JavaOverride -ne "") {
        $script:JavaFile = $JavaOverride
        return
    }

    # Search paths for Java installations
    $searchPaths = @(
        "C:\Program Files",
        "C:\Program Files\Java", 
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\Eclipse Foundation",
        "C:\Program Files\Amazon Corretto",
        "C:\Program Files\Zulu"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $javaFolders = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -match "^(jdk-?$JavaVersion|temurin-?$JavaVersion|jre-?$JavaVersion([\.0-9]+[-]?)*|zulu-?$JavaVersion|jdk1\.$JavaVersion|java-?$JavaVersion|openjdk-?$JavaVersion)([-_].*)*$" }
            
            foreach ($folder in $javaFolders) {
                $javaExe = Join-Path $folder.FullName "bin\java.exe"
                if (Test-Path $javaExe) {
                    $script:JavaFile = $javaExe
                    
                    # Try to get version info
                    $releaseFile = Join-Path $folder.FullName "release"
                    if (Test-Path $releaseFile) {
                        $releaseContent = Get-Content $releaseFile
                        $impl = ($releaseContent | Where-Object { $_ -match "IMPLEMENTOR=" }) -replace 'IMPLEMENTOR=|"', ''
                        $jver = ($releaseContent | Where-Object { $_ -match "JAVA_VERSION=" }) -replace 'JAVA_VERSION=|"', ''
                        
                        if ($impl -and $jver) {
                            $script:JavaNum = "$impl / $jver" -replace "C:\\Program Files\\", ""
                        }
                    }
                    return
                }
            }
        }
    }

    if ($script:JavaFile -eq "") {
        Write-Host ""
        Write-Host "     - Did not find a system installed Java for version $JavaVersion." -ForegroundColor Red
        Write-Host ""
        Write-Host "     - Install some distribution of Java $JavaVersion to your operating system!" -ForegroundColor Red
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
}

function Test-Forge {
    $forgePath = "libraries\net\minecraftforge\forge\1.18.2-$ForgeVersion"
    if (Test-Path $forgePath) {
        Write-Host ""
        Write-Host "  Found Forge $ForgeVersion installation!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  $(Get-Location)" -ForegroundColor Cyan
        Write-Host ""
        return $true
    }
    return $false
}

function Install-Forge {
    $installer = "forge-1.18.2-$ForgeVersion-installer.jar"
    $forgeUrl = "http://files.minecraftforge.net/maven/net/minecraftforge/forge/1.18.2-$ForgeVersion/forge-1.18.2-$ForgeVersion-installer.jar"

    # Clear out possibly bad installations
    if (Test-Path "libraries") {
        Remove-Item "libraries" -Recurse -Force
    }

    if (!(Test-Path $installer)) {
        Write-Host ""
        Write-Host "  No Forge installer found, downloading from:" -ForegroundColor Yellow
        Write-Host "  $forgeUrl" -ForegroundColor Cyan
        Write-Host ""

        try {
            Invoke-WebRequest -Uri $forgeUrl -OutFile $installer -ErrorAction Stop
        } catch {
            Write-Host "  For some reason the installer failed to download." -ForegroundColor Red
            Write-Host "  Please try again or download the installer manually and place it in this folder." -ForegroundColor Red
            Write-Host ""
            Read-Host "Press Enter to exit"
            exit 1
        }
    }

    Write-Host "  Running Forge installer." -ForegroundColor Yellow
    Write-Host ""
    
    & $script:JavaFile -jar $installer -installServer

    if (Test-Forge) {
        return
    } else {
        Write-Host ""
        Write-Host "  The Forge installer was run but failed to install all required files for some reason!" -ForegroundColor Red
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
}

function Initialize-Server {
    if (!(Test-Path "server.properties")) {
        $useSkyvaults = Read-Host "Would you like to use Sky Vaults? [Y/N]"
        
        $serverProps = @"
allow-flight=true
motd=Vault Hunters 3 - 1.18.2
"@
        
        if ($useSkyvaults -match "^[Yy]") {
            $serverProps += "`nlevel-type=the_vault:sky_vaults"
        } else {
            $serverProps += "`nlevel-type=default"
        }
        
        $serverProps | Out-File -FilePath "server.properties" -Encoding UTF8
    }

    # Always recreate eula.txt to ensure it's set to true
    $eulaContent = @"
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
eula=true
"@
    $eulaContent | Out-File -FilePath "eula.txt" -Encoding UTF8

    # Handle Terralith mod based on world type
    $terraliths = Get-ChildItem "mods" -Filter "*terralith*" -ErrorAction SilentlyContinue
    if ($terraliths) {
        $terralithFile = $terraliths[0].Name
        $serverProps = Get-Content "server.properties" -Raw
        
        if ($serverProps -match "level-type=the_vault") {
            # Sky vaults - disable Terralith
            if ($terralithFile.EndsWith(".jar")) {
                Rename-Item "mods\$terralithFile" "$terralithFile.disabled"
            }
        } else {
            # Default world - enable Terralith
            if ($terralithFile.EndsWith(".disabled")) {
                $newName = $terralithFile -replace "\.disabled$", ""
                Rename-Item "mods\$terralithFile" $newName
            }
        }
    }
}

function Start-Server {
    # Delete unwanted client-side mods
    $unwantedMods = @("legendarytooltips", "torohealth", "rubidium", "embeddium", "oculus", "vaultlootbeams", "xaero", "fancymenu", "drippyloadingscreen", "konkrete", "justzoom", "reauth", "controlling", "mousetweaks", "inventoryhud", "appleskin", "iceberg", "prism", "highlighter", "equipmentcompare")
    foreach ($modPattern in $unwantedMods) {
        Get-ChildItem "mods" -Filter "*$modPattern*" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    $restartCount = 0
    do {
        # Build JVM arguments
        $allArgs = @()
        if ($JvmArgs -ne "") { $allArgs += $JvmArgs.Split(' ') }
        if (Test-Path "user_jvm_args.txt") { 
            $userArgs = Get-Content "user_jvm_args.txt" | Where-Object { $_ -match "^-" }
            $allArgs += $userArgs
        }
        $allArgs += "@libraries/net/minecraftforge/forge/1.18.2-$ForgeVersion/win_args.txt"
        $allArgs += "nogui"

        # Start server
        & $script:JavaFile $allArgs

        # Check for restart conditions
        if ($VH3Restart -and (Test-Path "logs\latest.log")) {
            $logContent = Get-Content "logs\latest.log" -Raw
            if ($logContent -notmatch "Stopping the server") {
                $restartCount++
                if ($restartCount -le 10) {
                    Write-Host "Restarting automatically in 10 seconds (press Ctrl + C to cancel)" -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
                    continue
                }
            }
        }
        break
    } while ($true)
}

# Main execution
try {
    Set-Location $PSScriptRoot
    
    Write-Host "Vault Hunters 3 Server Setup" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor Green
    
    Find-Java
    
    Write-Host ""
    Write-Host "     - Found existing system installed Java for version - $JavaVersion" -ForegroundColor Green
    Write-Host ""
    if ($script:JavaNum -ne "") {
        Write-Host "       $($script:JavaNum)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    if (!(Test-Forge)) {
        Install-Forge
    }
    
    Initialize-Server
    
    if ($VH3InstallOnly) {
        Write-Host ""
        Write-Host "  INSTALL_ONLY: complete!" -ForegroundColor Green
        exit 0
    }
    
    Start-Server
    
} catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}