REM Build script for appveyor (Windows)

REM Echo status
ECHO
REM Some space
ECHO:
ECHO on

CD %APPVEYOR_BUILD_FOLDER%
ECHO Freezing curent build...
ECHO:
REM %PYTHONHOME%\python freeze.py build_exe -b "C:\OPS\OpenShotVideoEditor"

REM Do nothing here. Freeze in one move during install.
