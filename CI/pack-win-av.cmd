REM Packing build into archive
ECHO on

REM If "freezing" fails do not pack files
IF NOT EXIST "%OPENSHOT_INST_DIR%" GOTO:EOF

REM Went to installation folder
CD "%OPENSHOT_INST_DIR%"

IF EXIST "%APPVEYOR_BUILD_FOLDER%\downloads\openshot_pyqt5.txt" (
    ECHO Packing only Python folder with some PyQt5 modules.
    ECHO Artifact will not be posted, just cached.
    REM RENAME "python-%PLATFORM%.7z" "openshot-win-%PLATFORM%.7z"
) ELSE (
    ECHO Packing OpenShot
    7z a -bsp2 -t7z openshot-win-%PLATFORM%.7z * -xr!"python-%PLATFORM%.7z"
    ECHO Packing OpenShot dependencies
    CD "%OPENSHOT_DEPS_DIR%"
    7z a -bsp2 -t7z "%OPENSHOT_INST_DIR%\openshot-deps-win-%PLATFORM%.7z" *
)

DIR
