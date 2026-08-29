@echo off
setlocal enabledelayedexpansion


SET "FORGE_VERSION=40.3.11"

:: The major java version which will be searched for on your system files for an installation of.
SET "JAVAVERSION=17"

:: If you want to set a custom java path to use enter it after the = character.
:: EXAMPLE: SET "JAVA_OVERRIDE=C:\Program Files\Eclipse Adoptium\jre-17.0.14.7-hotspot\bin\java.exe"
SET "JAVA_OVERRIDE="

:: Add any custom JVM args after the = to change Java's default settings.
SET "JVM_ARGS="

:: If set to true, server will attempt to restart on unplanned shutdown up to 10 times.
SET "VH3_RESTART=false"

:: If you want to only install forge, and not launch server files, change this to true.
SET "VH3_INSTALL_ONLY=false"







REM MAIN SECTION BEGINS - DO NOT EDIT BELOW!
REM MAIN SECTION BEGINS - DO NOT EDIT BELOW!
REM MAIN SECTION BEGINS - DO NOT EDIT BELOW!

:: Sets the current directory as the working directory - this should fix attempts to run the script as admin.
PUSHD "%~dp0" >nul 2>&1

CALL :javacheck
CALL :forgecheck
CALL :setup

IF "%VH3_INSTALL_ONLY%"=="true" (
    ECHO: & ECHO   INSTALL_ONLY^: complete^^!
    EXIT /B
)

CALL :start

EXIT /B
REM MAIN SECTION ENDS
REM MAIN SECTION ENDS
REM MAIN SECTION ENDS



REM FUNCTIONS DEFINED BELOW

REM BEGIN START SECTION
:start

:: Deletes unwanted client side mods entered in the list
FOR %%X IN (legendarytooltips torohealth rubidium embeddium oculus vaultlootbeams xaero fancymenu drippyloadingscreen konkrete justzoom reauth controlling mousetweaks inventoryhud appleskin iceberg prism highlighter equipmentcompare) DO (
    FOR /F "delims=" %%A IN ('DIR /B mods') DO (
        ECHO "%%A" | FINDSTR /I "%%X" >nul && DEL "mods\%%A"
    )
)

SET /a RESTARTCOUNT=0
:restartserver
"!JAVAFILE!" !JVM_ARGS! @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.18.2-%FORGE_VERSION%/win_args.txt nogui

:: If auto restart is enabled, check if server was purposely shut down or if should restart
IF DEFINED VH3_RESTART IF !VH3_RESTART!==true IF EXIST "logs\latest.log" FINDSTR /I "Stopping the server" "logs\latest.log" || (
  SET /a RESARTCOUNT+=1
  IF !RESTARTCOUNT! LEQ 10 (
    ECHO Restarting automatically in 10 seconds ^(press Ctrl + C to cancel^)
    TIMEOUT /t 10 /nobreak > NUL
    GOTO :restartserver
  )
)
EXIT /B



REM BEGIN SETUP SECTION
:setup
IF NOT EXIST "server.properties" (
    CHOICE /C YN /M " Would you like to use Sky Vaults? [Y] or [N]"
	IF !ERRORLEVEL!==1 SET skyvaults=y
	IF !ERRORLEVEL!==2 SET skyvaults=n
)
IF NOT EXIST "server.properties" (
    (
        ECHO allow-flight=true
        ECHO motd=Vault Hunters 3 - 1.18.2
        IF "!skyvaults!" == "y" (
            ECHO level-type=the_vault:sky_vaults
        ) ELSE (
            ECHO level-type=default
        )
    )> "server.properties"
)

IF NOT EXIST "eula.txt" (
    ECHO: & ECHO "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula)."> "eula.txt"
    ECHO eula=true>> "eula.txt"
) ELSE (
    ECHO: & ECHO "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula)."> "eula.txt"
    ECHO eula=true>> "eula.txt"
)


:: Checks the status of the Terralith mod and sets it, depending on the world type being set to default or sky vaults.

:: If a Terralith mod file is found: gets the name of the Terralith mod file in the mods folder.
DIR /B mods | FINDSTR /I "terralith" >nul && ( FOR /F "delims=" %%A IN ('DIR /B mods ^| FINDSTR /I "terralith"') DO SET "TERRALITH_FILE=%%A" )

:: If the Terralith file isn't found then the rest of setup can be skipped
IF NOT DEFINED TERRALITH_FILE ( EXIT /B )

:: If the level-type IS sky vaults check and set the Terralith mod file to disabled.
:: If the level-type IS NOT sky vaults make sure that the Terralith file does not include .disabled at the end
FINDSTR "level-type=the_vault" "server.properties" >nul && (
    IF "!TERRALITH_FILE:~-4!"==".jar" RENAME "mods\!TERRALITH_FILE!" "!TERRALITH_FILE!.disabled"
) || (
    IF "!TERRALITH_FILE:~-9!"==".disabled" (
        SET "TERRALITH_FILE_RENAME=!TERRALITH_FILE:~0,-9!"
        RENAME "mods\!TERRALITH_FILE!" "!TERRALITH_FILE_RENAME!"
    )
)
EXIT /B

REM BEGIN JAVACHECK SECTION
:javacheck

:: If JAVA_OVERRIDE is being used set JAVAFILE equal to it and then skip the rest.
IF DEFINED JAVA_OVERRIDE (
    SET "JAVAFILE=!JAVA_OVERRIDE!"
    EXIT /B
)

:: Tries to find a Java installation in system files.
FOR /F "delims=" %%A IN ('powershell -Command "$ver='!JAVAVERSION!'; $paths = @('C:\Program Files', 'C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Eclipse Foundation', 'C:\Program Files\Amazon Corretto', 'C:\Program Files\Zulu'); foreach ($p in $paths) { if (Test-Path $p) { Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(jdk-?'+$ver+'|temurin-?'+$ver+'|jre-?'+$ver+'([\.0-9]+[-]?)*|zulu-?'+$ver+'|jdk1\.'+$ver+'|java-?'+$ver+'|openjdk-?'+$ver+')([-_].*)*$' } | ForEach-Object { 'new#' + $_.FullName } } }"') DO (
  FOR /F "tokens=1-2 delims=#" %%B IN ("%%A") DO (
    IF /I "%%B"=="new" IF EXIST "%%C\bin\java.exe" (
      SET "JAVAFOLDER=%%C"
      SET "JAVAFILE=%%C\bin\java.exe"
      SET "IMPL=" & SET "JVER="

      IF EXIST "%%C\release" FOR /F "tokens=1-2 delims==" %%L IN ('type "%%C\release"') DO (
        SET "TEMP=%%L"
        REM Character replacement of double quotes " like below will fail if it's on the same line as an '&' character - leave that kind of char replacement on its own line.
        IF /I %%L==IMPLEMENTOR ( 
          SET "IMPL=%%M"
          SET "IMPL=!IMPL:"=!"
        )
        IF /I %%L==JAVA_VERSION ( 
          SET "JVER=%%M"
          SET "JVER=!JVER:"=!"
          )
      )
      IF DEFINED IMPL (
        REM If the IMPL value was found then assume it got version also, set JAVANUM to the values and then strip out the Program files part from the string.
        REM JAVANUM is only used for display purposes on the ready to launch screen.
        SET "JAVANUM=!IMPL! / !JVER!"
        SET "JAVANUM=!JAVANUM:C:\Program Files\=!"
      )
      GOTO :javafileisset
    )
  )
)
:javafileisset

IF NOT DEFINED JAVAFILE (
    ECHO: & ECHO      - Did not find a system installed Java for version !JAVAVERSION!. & ECHO:
    ECHO      - Install some distribution of Java !JAVAVERSION! to your operating system ^^! & ECHO: & ECHO: & ECHO:
    PAUSE & EXIT
)

ECHO: & ECHO      - Found existing system installed Java for version - !JAVAVERSION!
ECHO: & ECHO        !JAVANUM! & ECHO:
EXIT /B



REM BEGIN FORGECHECK SECTION
:forgecheck
IF EXIST "libraries\net\minecraftforge\forge\1.18.2-%FORGE_VERSION%\." (
    ECHO: & ECHO   Found Forge !FORGE_VERSION! installation^^!
    ECHO: & ECHO   %CD% & ECHO:
    EXIT /B
)

SET "INSTALLER=forge-1.18.2-%FORGE_VERSION%-installer.jar"
SET "FORGE_URL=http://files.minecraftforge.net/maven/net/minecraftforge/forge/1.18.2-%FORGE_VERSION%/forge-1.18.2-%FORGE_VERSION%-installer.jar"

:: Clears out possibly bad installations
IF EXIST "libraries" RD /s /q "libraries\"

IF NOT EXIST %INSTALLER% (
    ECHO: & ECHO   No Forge installer found, downloading from^:
    ECHO   %FORGE_URL% & ECHO:

    powershell -Command "(New-Object Net.WebClient).DownloadFile('%FORGE_URL%', '%INSTALLER%')" >nul 2>&1
    IF NOT EXIST %INSTALLER% (
        ECHO   For some reason the installer failed to download. & ECHO   Please try again or download the installer manually and place it in this folder. & ECHO:
        PAUSE & EXIT
    )
)
    
ECHO   Running Forge installer. & ECHO:
"%JAVAFILE%" -jar %INSTALLER% -installServer

IF EXIST "libraries\net\minecraftforge\forge\1.18.2-%FORGE_VERSION%\." (
    ECHO: & ECHO   Found Forge !FORGE_VERSION! installation^^!
    ECHO: & ECHO   %CD% & ECHO:
    EXIT /B
) ELSE (
    ECHO: & ECHO   The Forge installer was run but failed to install all required files for some reason^^! & ECHO:
    PAUSE & EXIT
)
EXIT /B
