@echo off

REM Copyright (C) 2007-2019 Crafter Software Corporation. All Rights Reserved.
REM
REM This program is free software: you can redistribute it and/or modify
REM it under the terms of the GNU General Public License as published by
REM the Free Software Foundation, either version 3 of the License, or
REM (at your option) any later version.
REM
REM This program is distributed in the hope that it will be useful,
REM but WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
REM GNU General Public License for more details.
REM
REM You should have received a copy of the GNU General Public License
REM along with this program.  If not, see <http://www.gnu.org/licenses/>.

SETLOCAL EnableDelayedExpansion

Rem Dont bother do anything if OS is not 64
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OSARCH=32BIT || set OSARCH=64BIT
if %OSARCH%==32BIT (
  echo CrafterCMS is not support 32bit OS
  pause
  exit 4
)

rem Make sure this variable is clean.
SET CRAFTER_BIN_DIR=
SET CRAFTER_HOME=
SET CATALINA_OPTS=
rem Reinit variables
SET CRAFTER_BIN_DIR=%~dp0.
for %%i in ("%CRAFTER_BIN_DIR%\..") do set CRAFTER_HOME=%%~fi

call "%CRAFTER_BIN_DIR%\crafter-setenv.bat" %2

IF /i "%1%"=="start" goto init
IF /i "%1%"=="-s" goto init

IF /i "%1%"=="stop" goto skill
IF /i "%1%"=="-k" goto skill

IF /i "%1%"=="debug" goto debug
IF /i "%1%"=="-d" goto debug

IF /i "%1%"=="backup" goto backup
IF /i "%1%"=="restore" goto restore

goto shelp
exit 0;

:shelp
echo Crafter Bat script
echo -s start, Start crafter deployer
echo -k stop, Stop crafter deployer
echo -d debug, Impli  eds start, Start crafter deployer in debug mode
exit /b 0

:installMongo
mkdir "%CRAFTER_BIN_DIR%\mongodb"
cd "%CRAFTER_BIN_DIR%\mongodb"
java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" download mongodbmsi
msiexec.exe /i mongodb.msi /passive INSTALLLOCATION="%CRAFTER_BIN_DIR%\mongodb\" /l*v "%CRAFTER_BIN_DIR%\mongodb\mongodb.log" /norestart
SET MONGODB_BIN_DIR= "%CRAFTER_BIN_DIR%\mongodb\bin\mongod.exe"
IF NOT EXIST "%MONGODB_BIN_DIR%" (
  echo Mongodb bin path not found trying download the zip %MONGODB_BIN_DIR%
  rmdir /Q /S "%CRAFTER_BIN_DIR%\mongodb"
  mkdir "%CRAFTER_BIN_DIR%\mongodb"
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" download mongodb
  java -jar  "%CRAFTER_BIN_DIR%\craftercms-utils.jar" unzip mongodb.zip "%CRAFTER_BIN_DIR%\mongodb" true
)
cd "%CRAFTER_BIN_DIR%"
goto :init

:initWithOutExit
@rem Windows does not support Or in the If soo...
netstat -o -n -a | findstr  "0.0.0.0:%MARIADB_PORT%"
IF %ERRORLEVEL% equ 0 (
 echo Crafter CMS Database Port: %MARIADB_PORT% is in use.
 echo This might be because of a prior unsuccessful or incomplete shut down.
 echo Please terminate that process before attempting to start Crafter CMS.
 pause
 exit /b 2
)

IF EXIST "%PROFILE_WAR_PATH%" set start_mongo=true
IF /i "%FORCE_MONGO%"=="forceMongo" set start_mongo=true

IF /i "%start_mongo%"=="true" (
  set mongoDir=%CRAFTER_BIN_DIR%\mongodb
  IF NOT EXIST "%mongoDir%" goto installMongo
  IF NOT EXIST "%MONGODB_DATA_DIR%" mkdir "%MONGODB_DATA_DIR%"
  IF NOT EXIST "%MONGODB_DATA_DIR%" mkdir "%MONGODB_DATA_DIR%"
  IF NOT EXIST "%MONGODB_LOGS_DIR%" mkdir "%MONGODB_LOGS_DIR%"
  start "" "%mongoDir%\bin\mongod" --dbpath="%MONGODB_DATA_DIR%" --directoryperdb --journal --logpath="%MONGODB_LOGS_DIR%\mongod.log" --port %MONGODB_PORT%
)

IF NOT EXIST "%DEPLOYER_LOGS_DIR%" mkdir "%DEPLOYER_LOGS_DIR%"
start "" "%DEPLOYER_HOME%\%DEPLOYER_STARTUP%"

IF NOT EXIST "%SOLR_INDEXES_DIR%" mkdir "%SOLR_INDEXES_DIR%"
IF NOT EXIST "%SOLR_LOGS_DIR%" mkdir "%SOLR_LOGS_DIR%"
call "%CRAFTER_BIN_DIR%\solr\bin\solr" start -p %SOLR_PORT% -s "%SOLR_HOME%" -Dcrafter.solr.index="%CRAFTER_DATA_DIR%\indexes"

IF NOT EXIST "%CATALINA_LOGS_DIR%" mkdir "%CATALINA_LOGS_DIR%"
IF NOT EXIST "%CATALINA_TMPDIR%" mkdir "%CATALINA_TMPDIR%"
call "%CATALINA_HOME%\bin\catalina.bat" start

@rem Windows keep variables live until terminal dies.
set start_mongo=false
goto :eof

:init
call :initWithOutExit
goto cleanOnExitKeepTermAlive

:debug
@rem Windows does not support Or in the If soo...

IF EXIST "%PROFILE_WAR_PATH%" set start_mongo=true
IF /i "%FORCE_MONGO%"=="forceMongo" set start_mongo=true

IF /i "%start_mongo%"=="true" (
  set mongoDir=%CRAFTER_BIN_DIR%\mongodb
  IF NOT EXIST "%mongoDir%" goto installMongo
  IF NOT EXIST "%MONGODB_DATA_DIR%" mkdir "%MONGODB_DATA_DIR%"
  IF NOT EXIST "%MONGODB_DATA_DIR%" mkdir "%MONGODB_DATA_DIR%"
  IF NOT EXIST "%MONGODB_LOGS_DIR%" mkdir "%MONGODB_LOGS_DIR%"
  start "" "%mongoDir%\bin\mongod" --dbpath="%MONGODB_DATA_DIR%" --directoryperdb --journal --logpath="%MONGODB_LOGS_DIR%\mongod.log" --port %MONGODB_PORT%
)

IF NOT EXIST "%DEPLOYER_LOGS_DIR%" mkdir "%DEPLOYER_LOGS_DIR%"
start "" "%DEPLOYER_HOME%\%DEPLOYER_DEBUG%"

IF NOT EXIST "%SOLR_INDEXES_DIR%" mkdir "%SOLR_INDEXES_DIR%"
IF NOT EXIST "%SOLR_LOGS_DIR%" mkdir "%SOLR_LOGS_DIR%"
call "%CRAFTER_BIN_DIR%\solr\bin\solr" start -p %SOLR_PORT% -s "%SOLR_HOME%" -Dcrafter.solr.index="%CRAFTER_DATA_DIR%\indexes" -a "-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=%SOLR_DEBUG_PORT%

IF NOT EXIST "%CATALINA_LOGS_DIR%" mkdir "%CATALINA_LOGS_DIR%"
IF NOT EXIST "%CATALINA_TMPDIR%" mkdir "%CATALINA_TMPDIR%"
call "%CATALINA_HOME%\bin\catalina.bat" jpda start

@rem Windows keep variables live until terminal dies.
set start_mongo=false
goto cleanOnExit

:backup
SET TARGET_NAME=%2
IF NOT DEFINED TARGET_NAME (
  IF EXIST "%CRAFTER_BIN_DIR%\apache-tomcat\webapps\studio.war" (
    SET TARGET_NAME=crafter-authoring-backup
  ) ELSE (
    SET TARGET_NAME=crafter-delivery-backup
  )
)
FOR /F "tokens=2-4 delims=/ " %%a IN ("%DATE%") DO (SET CDATE=%%c-%%a-%%b)
FOR /F "tokens=1-3 delims=:. " %%a IN ("%TIME%") DO (SET CTIME=%%a-%%b-%%c)
SET TARGET_FILE="%CRAFTER_HOME%\backups\%TARGET_NAME%-%CDATE%-%CTIME%.zip"
IF EXIST "%TARGET_FILE%" (
  DEL /Q "%TARGET_FILE%"
)
SET TEMP_FOLDER="%CRAFTER_HOME%\temp\backup"

echo ------------------------------------------------------------------------
echo Starting backup into %TARGET_FILE%
echo ------------------------------------------------------------------------
IF NOT EXIST "%TEMP_FOLDER%" md "%TEMP_FOLDER%"
IF NOT EXIST "%CRAFTER_HOME%\backups" md "%CRAFTER_HOME%\backups"

REM MySQL Dump
IF EXIST "%MYSQL_DATA%" (
  netstat -o -n -a | findstr  "0.0.0.0:%MARIADB_PORT%"
  IF !ERRORLEVEL! neq 0 (
    IF NOT EXIST "%CRAFTER_BIN_DIR%\dbms" md "%CRAFTER_BIN_DIR%\dbms

    echo ------------------------------------------------------------------------
    echo Starting DB
    echo ------------------------------------------------------------------------
    start java -jar -DmariaDB4j.port=%MARIADB_PORT% -DmariaDB4j.baseDir="%CRAFTER_BIN_DIR%\dbms" -DmariaDB4j.dataDir="%MYSQL_DATA%" "%CRAFTER_BIN_DIR%\mariaDB4j-app.jar"
    timeout /nobreak /t 60
    set start_db=true
  )

  echo ------------------------------------------------------------------------
  echo Backing up MySQL
  echo ------------------------------------------------------------------------
  start /w "MySQL Dump" "%CRAFTER_BIN_DIR%\dbms\bin\mysqldump.exe" --databases crafter --port=%MARIADB_PORT% --protocol=tcp --user=root --result-file="%TEMP_FOLDER%\crafter.sql"
  echo SET GLOBAL innodb_large_prefix = TRUE ; SET GLOBAL innodb_file_format = 'BARRACUDA' ; SET GLOBAL innodb_file_format_max = 'BARRACUDA' ; SET GLOBAL innodb_file_per_table = TRUE ; > "%TEMP_FOLDER%\temp.txt"
  type "%TEMP_FOLDER%\crafter.sql" >> "%TEMP_FOLDER%\temp.txt"
  move /y "%TEMP_FOLDER%\temp.txt" "%TEMP_FOLDER%\crafter.sql"

  IF /i "!start_db!"=="true" (
    echo ------------------------------------------------------------------------
    echo Stopping DB
    echo ------------------------------------------------------------------------
    set /p pid=<mariadb4j.pid
    taskkill /pid !pid! /t /f
    timeout /nobreak /t 10
  )
)

REM MongoDB Dump
IF EXIST %MONGODB_DATA_DIR% (
  IF EXIST "%CRAFTER_BIN_DIR%\mongodb\bin\mongodump" (
    echo ------------------------------------------------------------------------
    echo Backing up mongodb
    echo ------------------------------------------------------------------------
    "%CRAFTER_BIN_DIR%\mongodb\bin\mongodump" --port %MONGODB_PORT% --out "%TEMP_FOLDER%\mongodb" --quiet
    cd "%TEMP_FOLDER%\mongodb"
    java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar zip" . "%TEMP_FOLDER%\mongodb.zip"
    cd "%CRAFTER_BIN_DIR%"
    rd /Q /S "%TEMP_FOLDER%\mongodb"
  )
)

REM ZIP git repos
IF EXIST "%CRAFTER_DATA_DIR%\repos" (
  echo ------------------------------------------------------------------------
  echo Backing up git repos
  echo ------------------------------------------------------------------------
  cd "%CRAFTER_DATA_DIR%\repos"
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" zip . "%TEMP_FOLDER%\repos.zip"
)

REM ZIP solr indexes
IF EXIST "%SOLR_INDEXES_DIR%" (
  echo ------------------------------------------------------------------------
  echo Backing up solr indexes
  echo ------------------------------------------------------------------------
  cd "%SOLR_INDEXES_DIR%"
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" zip . "%TEMP_FOLDER%\indexes.zip"
)

REM ZIP deployer data
IF EXIST "%DEPLOYER_DATA_DIR%" (
  echo ------------------------------------------------------------------------
  echo Backing up deployer data
  echo ------------------------------------------------------------------------
  cd "%DEPLOYER_DATA_DIR%"
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" zip . "%TEMP_FOLDER%\deployer.zip"
)

REM ZIP everything (without compression)
echo ------------------------------------------------------------------------
echo Packaging everything
echo ------------------------------------------------------------------------
cd "%TEMP_FOLDER%"
java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" zip . "%TARGET_FILE%" true

cd "%CRAFTER_HOME%"
rd /Q /S "%TEMP_FOLDER%"
echo Backup completed
goto cleanOnExitKeepTermAlive

:restore
netstat -o -n -a | findstr "0.0.0.0:%TOMCAT_HTTP_PORT%"
IF %ERRORLEVEL% equ 0 (
  echo Please stop the system before starting the restore process.
  goto cleanOnExitKeepTermAlive
)
SET SOURCE_FILE=%2
IF NOT EXIST "%SOURCE_FILE%" (
  echo The backup file does not exist
  exit /b 1
)

SET /P DO_IT= Warning, you're about to restore CrafterCMS from a backup, which will wipe the ^

existing sites and associated database and replace everything with the restored data. If you ^

care about the existing state of the system then stop this process, backup the system, and then ^

attempt the restore. Are you sure you want to proceed? (yes/no)

IF /i NOT "%DO_IT%"=="yes" (
  IF /i NOT "%DO_IT%"=="y" (
    exit /b 0
  )
)

echo ------------------------------------------------------------------------
echo Clearing all existing data
echo ------------------------------------------------------------------------
rd /q /s "%CRAFTER_DATA_DIR%"

SET TEMP_FOLDER="%CRAFTER_HOME%\temp\backup"
echo ------------------------------------------------------------------------
echo Starting restore from %SOURCE_FILE%
echo ------------------------------------------------------------------------
md "%TEMP_FOLDER%"

REM UNZIP everything
java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" unzip "%SOURCE_FILE%" "%TEMP_FOLDER%"

REM MongoDB Dump
IF EXIST "%TEMP_FOLDER%\mongodb.zip" (
  echo ------------------------------------------------------------------------
  echo Restoring MongoDB
  echo ------------------------------------------------------------------------
  IF NOT EXIST "%MONGODB_DATA_DIR%" mkdir "%MONGODB_DATA_DIR%"
  IF NOT EXIST "%MONGODB_LOGS_DIR%" mkdir "%MONGODB_LOGS_DIR%"
  start "MongoDB" "%CRAFTER_BIN_DIR%\mongodb\bin\mongod" --dbpath="%MONGODB_DATA_DIR%" --directoryperdb --journal --logpath="%MONGODB_LOGS_DIR%\mongod.log" --port %MONGODB_PORT%
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" unzip "%TEMP_FOLDER%\mongodb.zip" "%TEMP_FOLDER%\mongodb"
  start "MongoDB Restore" /W "%CRAFTER_BIN_DIR%\mongodb\bin\mongorestore" --port %MONGODB_PORT% "%TEMP_FOLDER%\mongodb"
  taskkill /IM mongod.exe
)

REM UNZIP git repos
IF EXIST "%TEMP_FOLDER%\repos.zip" (
  echo ------------------------------------------------------------------------
  echo Restoring git repos
  echo ------------------------------------------------------------------------
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" unzip "%TEMP_FOLDER%\repos.zip" "%CRAFTER_DATA_DIR%\repos"
)

REM UNZIP solr indexes
IF EXIST "%TEMP_FOLDER%\indexes.zip" (
  echo ------------------------------------------------------------------------
  echo Restoring solr indexes
  echo ------------------------------------------------------------------------
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" unzip "%TEMP_FOLDER%\indexes.zip" "%SOLR_INDEXES_DIR%"
)

REM UNZIP deployer data
IF EXIST "%TEMP_FOLDER%\deployer.zip" (
  echo ------------------------------------------------------------------------
  echo Restoring deployer data
  echo ------------------------------------------------------------------------
  java -jar "%CRAFTER_BIN_DIR%\craftercms-utils.jar" unzip "%TEMP_FOLDER%\deployer.zip" "%DEPLOYER_DATA_DIR%"
)

REM If it is an authoring env then sync the repos
IF EXIST "%TEMP_FOLDER%\crafter.sql" (
  md "%MYSQL_DATA%"
  REM Start DB
  echo ------------------------------------------------------------------------
  echo Starting DB
  echo ------------------------------------------------------------------------
  start java -jar -DmariaDB4j.port=%MARIADB_PORT% -DmariaDB4j.baseDir="%CRAFTER_BIN_DIR%\dbms" -DmariaDB4j.dataDir="%MYSQL_DATA%" "%CRAFTER_BIN_DIR%\mariaDB4j-app.jar"
  timeout /nobreak /t 60
  REM Import
  echo ------------------------------------------------------------------------
  echo Restoring DB
  echo ------------------------------------------------------------------------
  start /B /W "" "%CRAFTER_BIN_DIR%\dbms\bin\mysql.exe" --user=root --port=%MARIADB_PORT% --protocol=TCP -e "source %TEMP_FOLDER%\crafter.sql"
  timeout /nobreak /t 5
  REM Stop DB
  echo ------------------------------------------------------------------------
  echo Stopping DB
  echo ------------------------------------------------------------------------
  set /p pid=<mariadb4j.pid
  taskkill /pid !pid! /t /f
  timeout /nobreak /t 10
)

rd /S /Q "%TEMP_FOLDER%"
echo Restore complete, you may now start the system
goto cleanOnExitKeepTermAlive


:skill
call "%CRAFTER_BIN_DIR%\solr\bin\solr" stop -p %SOLR_PORT%
@rem Windows does not support Or in the If soo...

netstat -o -n -a | findstr  "0.0.0.0:%MONGODB_PORT%"
IF %ERRORLEVEL% equ 0 set start_mongo=true
IF EXIST "%PROFILE_WAR_PATH%" set start_mongo=true
IF /i "%FORCE_MONGO%"=="forceMongo" set start_mongo=true

IF /i "%start_mongo%"=="true" (
  taskkill /IM mongod.exe
)
@rem Windows keeps vars live until cmd window die.
set start_mongo=false
call "%CATALINA_HOME%\bin\shutdown.bat"
SLEEP %TIME_BEFORE_KILL%
netstat -o -n -a | findstr  "0.0.0.0:%MARIADB_PORT%"
IF %ERRORLEVEL% equ 0 (
  taskkill /IM mysqld.exe
)

call "%DEPLOYER_HOME%\%DEPLOYER_SHUTDOWN%"
taskkill /FI "WINDOWTITLE eq \"Solr-%SOLR_PORT%\"
goto cleanOnExit


:cleanOnExit
cd "%CRAFTER_BIN_DIR%"
exit

:cleanOnExitKeepTermAlive
cd "%CRAFTER_BIN_DIR%"
exit /b
