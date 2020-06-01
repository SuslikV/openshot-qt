REM Install script before build; for appveyor.com
REM mute output
@ECHO off

CD %APPVEYOR_BUILD_FOLDER%

REM Override used Qt installation by using folder C:\Qt\5.12.2\mingw73_64\bin
REM SET OPENSHOT_QT_SOURCE=IN_PYQT

REM Do not restore Python files, and emulate that PyQt5 installed
REM DEL /f /q /a:s /a:s /a:r /a:a "%OPENSHOT_INST_DIR%\python-%PLATFORM%.7z"
REM SET OPENSHOT_PYQT5=OK

REM leave some space
ECHO:
ECHO Platform: %PLATFORM%
ECHO Default build folder: %APPVEYOR_BUILD_FOLDER%
ECHO Dependencies folder: %OPENSHOT_DEPS_DIR%
ECHO Install folder: %OPENSHOT_INST_DIR%
ECHO Python folder: %PYTHONHOME%
ECHO Qt is %OPENSHOT_QT_SOURCE%
ECHO:

REM Python module path of the libopenshot installation
SET P_MODULE_PATH=python

REM Make copy of the variable with slashes instead of backslashes to use it in the bash
SET MYAPP_BUILD_FOLDER_SLASH=%APPVEYOR_BUILD_FOLDER:\=/%

REM We need to update PATH with MSYS2 dirs, also it resolves ZLIB dependency and finds static one at C:/msys64/mingw64/lib/libz.dll.a,
REM while dynamic zlib is in C:\msys64\mingw64\bin\zlib1.dll
SET PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%
REM Cmake will unable to compile without "MinGW\bin" path to PATH
REM SET PATH=C:\MinGW\bin;%PATH% - is 32bit
REM Force cmake to find fixed version of mingw-w64 7.3.0 by adding it in the PATH as first item, do not use MSYS2 compillers
SET OPENSHOT_COMPILER_BINDIR=C:\mingw-w64\x86_64-7.3.0-posix-seh-rt_v5-rev0\mingw64\bin
SET PATH=%OPENSHOT_COMPILER_BINDIR%;%PATH%

REM Create downloads folder for external dependencies
IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\downloads" MKDIR %APPVEYOR_BUILD_FOLDER%\downloads

REM List current Python PyQt5 modules, if any
IF EXIST %PYTHONHOME%\lib\site-packages\PyQt5 (
  CD %PYTHONHOME%\lib\site-packages\PyQt5
  DIR
)
REM Restore cached Python folder, with some PyQt5 modules installed.
REM When rebuilding PyQt modules the OPENSHOT_QT_SOURCE should be set to IN_MSYS
REM this ensures that right files of the installation environment will be grabbed.
REM Process of rebuilding PyQt exceeds 1 hour limit, so it was splitted into 3 parts.
REM Two increase speed and reduce size of the cx_Freeze final package
REM set OPENSHOT_QT_SOURCE to DEPS_FOLDER - it will use custom dependencies folder
REM that has its own version of Python with all needed packages pre-installed.
REM If restore cache and download fails, while OPENSHOT_QT_SOURCE is set to DEPS_FOLDER,
REM then exit with error.
REM If cache restore fails, while OPENSHOT_QT_SOURCE is set to IN_MSYS,
REM then script will attempt to use default installation of the Python under the same
REM directory (the folder's contents doesn't wipes).
CD %PYTHONHOME%
DIR
IF "%OPENSHOT_QT_SOURCE%" == "IN_MSYS2" GOTO pyqtRestoreCached 
CD "%APPVEYOR_BUILD_FOLDER%\downloads"
IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\downloads\python-%PLATFORM%.7z" curl -kL https://github.com/SuslikV/libopenshot/raw/build-deps/win-x64/Python3-x64-withPyQt5-5122-win-N456.7z -f --retry 4 --output python-%PLATFORM%.7z
IF NOT EXIST "%OPENSHOT_INST_DIR%" MKDIR "%OPENSHOT_INST_DIR%"
MOVE /y "%APPVEYOR_BUILD_FOLDER%\downloads\python-%PLATFORM%.7z" "%OPENSHOT_INST_DIR%\python-%PLATFORM%.7z"
IF errorlevel 1 (
  ECHO Unable to download/install Python dependencies
  EXIT 1
)
:pyqtRestoreCached
CD C:\
IF EXIST "%OPENSHOT_INST_DIR%\python-%PLATFORM%.7z" (
  REM Wipe destination dir silently, suppress the message that process is using current folder
  REM Note. If unpack fails to restore the files, then cache needs to be updated or just skip restoring at the start
  CD %PYTHONHOME% & RMDIR /s /q %PYTHONHOME% 2> NUL
  DIR
  ECHO Restoring Python with PyQt5 package to %PYTHONHOME%
  CD "%OPENSHOT_INST_DIR%"
  7z x python-%PLATFORM%.7z -aoa -o%PYTHONHOME%
  CD %PYTHONHOME%
  DIR
)
REM List restored Python PyQt5 modules, if any
IF EXIST %PYTHONHOME%\lib\site-packages\PyQt5 (
  CD %PYTHONHOME%\lib\site-packages\PyQt5
  DIR
)
REM Update PYTHONPATH environment variable for packages
SET PYTHONPATH=%PYTHONHOME%\lib\site-packages
REM Add Python3 scripts to path
SET PATH=%PYTHONHOME%;%PYTHONHOME%\Scripts;%PATH%
%PYTHONHOME%\python --version

REM Resolve libopenshot-audio dependency
REM We build it first because it requires less dependencies in comparison to libopenshot library
CD %APPVEYOR_BUILD_FOLDER%\downloads
REM Get current hash
git ls-remote https://github.com/SuslikV/libopenshot-audio.git what-you-have-missed-so-far > current-head.txt
IF EXIST current-head.txt (
  ECHO libopenshot-audio current:
  TYPE current-head.txt
)
IF EXIST last-libopenshot-audio.txt (
  ECHO libopenshot-audio cached:
  TYPE last-libopenshot-audio.txt
)
REM Compare current to cached hash, recompile if hash fails
FC current-head.txt last-libopenshot-audio.txt > NUL
IF errorlevel 1 GOTO InstLibAudio
IF EXIST "%OPENSHOT_DEPS_DIR%\libopenshot-audio" GOTO LibAudioInstalled
:InstLibAudio
REM Remove libopenshot-audio destination folder for clear install
IF EXIST "%OPENSHOT_DEPS_DIR%\libopenshot-audio" RMDIR "%OPENSHOT_DEPS_DIR%\libopenshot-audio" /s /q
REM Store last compiled hash value to cache it later
git ls-remote https://github.com/SuslikV/libopenshot-audio.git what-you-have-missed-so-far > last-libopenshot-audio.txt
REM clone and checkout what-you-have-missed-so-far branch
git clone --branch what-you-have-missed-so-far https://github.com/SuslikV/libopenshot-audio.git
DIR
CD libopenshot-audio
DIR
REM Make new building dir
MKDIR build
CD build
cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=6.1 -DCMAKE_INSTALL_PREFIX:PATH="%OPENSHOT_DEPS_DIR%\libopenshot-audio" ..
mingw32-make --version
mingw32-make
mingw32-make install
REM Here libopenshot-audio already installed
:LibAudioInstalled
SET LIBOPENSHOT_AUDIO_DIR=%OPENSHOT_DEPS_DIR%\libopenshot-audio

REM Update MSYS2 itself
bash -lc "pacman -Syu --noconfirm"

REM Remove python2, just to not mess up the things later
bash -lc "pacman -Rsc --noconfirm python2"
REM Remove python2 from PATH
SET PATH=%PATH:C:\Python27;=%
SET PATH=%PATH:C:\Python27\Scripts;=%

REM Specify Qt source, resolving Qt dependency
IF "%OPENSHOT_QT_SOURCE%" == "DEPS_FOLDER" GOTO qtFromDeps

REM Resolve ZMQ dependency
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-zeromq"
REM Resolve SWIG dependency
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-swig"
REM Resolve Qt depenndency
REM Insall QtWebKit and all required stuff
bash -lc "pacman -S --needed --noconfirm --disable-download-timeout mingw64/mingw-w64-x86_64-qtwebkit"
REM Workaround a MSYS2 packaging issue for Qt5, if instaled in MSYS2
REM see https://github.com/msys2/MINGW-packages/issues/5253
REM Replacing all occurrences of "C:/building/msys32" with the "C:/msys64" in C:/msys64/mingw64/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
bash -lc "sed -i -e 's;C:\/building\/msys32;C:\/msys64;g' C:/msys64/mingw64/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake"

REM Let us see what is environment set to
SET
REM Let us see what is installed within MSYS2
bash -lc "pacman -Q"

REM This is mingw based files, x64.
REM Collect required libraries of Qt and put them to cache later, just to not install full Qt with unneeded debug libs.
REM
REM Build the folders tree
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\Qt\bin" MKDIR "%OPENSHOT_DEPS_DIR%\Qt\bin"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\Qt\include" MKDIR "%OPENSHOT_DEPS_DIR%\Qt\include"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\Qt\lib" MKDIR "%OPENSHOT_DEPS_DIR%\Qt\lib"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats" MKDIR "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\Qt\plugins\platforms" MKDIR "%OPENSHOT_DEPS_DIR%\Qt\plugins\platforms"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\zmq\bin" MKDIR "%OPENSHOT_DEPS_DIR%\zmq\bin"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\zmq\lib" MKDIR "%OPENSHOT_DEPS_DIR%\zmq\lib"
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\zmq\lib" MKDIR "%OPENSHOT_DEPS_DIR%\zmq\include"
REM Exclude list, files shouldn't be copied
ECHO Qt5Gui_QMinimalIntegrationPlugin.cmake> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Gui_QOffscreenIntegrationPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Gui_QTuioTouchPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Gui_QVirtualKeyboardPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Gui_QWebGLIntegrationPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Gui_QWindowsDirect2DIntegrationPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Multimedia_AudioCaptureServicePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Multimedia_DSServicePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Multimedia_QM3uPlaylistPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Multimedia_QWindowsAudioPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Network_QGenericEnginePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Positioning_QGeoPositionInfoSourceFactoryPoll.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Positioning_QGeoPositionInfoSourceFactorySerialNmea.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5PrintSupport_QWindowsPrinterSupportPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QDebugMessageServiceFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QLocalClientConnectionFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlDebuggerServiceFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlDebugServerFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlInspectorServiceFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlNativeDebugConnectorFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlNativeDebugServiceFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlPreviewServiceFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQmlProfilerServiceFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QQuickProfilerAdapterFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Qml_QTcpServerConnectionFactory.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Sensors_genericSensorPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Sensors_QCounterGesturePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Sensors_QShakeSensorGesturePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Sensors_QtSensorGesturePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Svg_QSvgIconPlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
ECHO Qt5Widgets_QWindowsVistaStylePlugin.cmake>> "%OPENSHOT_DEPS_DIR%\exclude_list.txt"
REM
REM All Qt dlls that currently in use, some of them just dependencies of QtWebKit.
COPY /y /b "C:\msys64\mingw64\bin\Qt5Core.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Core.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Gui.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Gui.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Widgets.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Widgets.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Multimedia.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Multimedia.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5MultimediaWidgets.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5MultimediaWidgets.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Network.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Network.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5OpenGL.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5OpenGL.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Positioning.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Positioning.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5PrintSupport.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5PrintSupport.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Qml.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Qml.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Quick.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Quick.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5QuickWidgets.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5QuickWidgets.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Sensors.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Sensors.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5Svg.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5Svg.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5WebChannel.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5WebChannel.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5WebSockets.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5WebSockets.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5WebKit.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5WebKit.dll"
COPY /y /b "C:\msys64\mingw64\bin\Qt5WebKitWidgets.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\Qt5WebKitWidgets.dll"
REM
REM All dlls that Qt uses, but compiler dependencies
REM
COPY /y /b "C:\msys64\mingw64\bin\libicuin64.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libicuin64.dll"
COPY /y /b "C:\msys64\mingw64\bin\libicuuc64.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libicuuc64.dll"
COPY /y /b "C:\msys64\mingw64\bin\libicudt64.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libicudt64.dll"
COPY /y /b "C:\msys64\mingw64\bin\libpcre2-16-0.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libpcre2-16-0.dll"
COPY /y /b "C:\msys64\mingw64\bin\zlib1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\zlib1.dll"
COPY /y /b "C:\msys64\mingw64\bin\libharfbuzz-0.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libharfbuzz-0.dll"
COPY /y /b "C:\msys64\mingw64\bin\libfreetype-6.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libfreetype-6.dll"
COPY /y /b "C:\msys64\mingw64\bin\libbz2-1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libbz2-1.dll"
COPY /y /b "C:\msys64\mingw64\bin\libpng16-16.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libpng16-16.dll"
COPY /y /b "C:\msys64\mingw64\bin\libglib-2.0-0.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libglib-2.0-0.dll"
COPY /y /b "C:\msys64\mingw64\bin\libintl-8.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libintl-8.dll"
COPY /y /b "C:\msys64\mingw64\bin\libiconv-2.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libiconv-2.dll"
COPY /y /b "C:\msys64\mingw64\bin\libpcre-1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libpcre-1.dll"
COPY /y /b "C:\msys64\mingw64\bin\libgraphite2.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libgraphite2.dll"
REM
REM Few unique dependencies for QtWebKit, about the Qt own, as Qt5Multimedia etc., see above
REM
COPY /y /b "C:\msys64\mingw64\bin\libjpeg-8.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libjpeg-8.dll"
COPY /y /b "C:\msys64\mingw64\bin\libsqlite3-0.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libsqlite3-0.dll"
COPY /y /b "C:\msys64\mingw64\bin\libwebp-7.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libwebp-7.dll"
COPY /y /b "C:\msys64\mingw64\bin\libxml2-2.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libxml2-2.dll"
COPY /y /b "C:\msys64\mingw64\bin\liblzma-5.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\liblzma-5.dll"
COPY /y /b "C:\msys64\mingw64\bin\libxslt-1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libxslt-1.dll"
REM
REM The few unique dependencies of Qt5WebKitWidgets, like Qt5MultimediaWidgets etc. see above
REM
REM All dlls that Qt uses from mingw-w64 compiler
REM
COPY /y /b "%OPENSHOT_COMPILER_BINDIR%\libgcc_s_seh-1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libgcc_s_seh-1.dll"
COPY /y /b "%OPENSHOT_COMPILER_BINDIR%\libwinpthread-1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libwinpthread-1.dll"
COPY /y /b "%OPENSHOT_COMPILER_BINDIR%\libgomp-1.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libgomp-1.dll"
COPY /y /b "%OPENSHOT_COMPILER_BINDIR%\libstdc++-6.dll" "%OPENSHOT_DEPS_DIR%\Qt\bin\libstdc++-6.dll"
REM
REM Copy exe files, that cmake looks for when building Qt
COPY /y /b "C:\msys64\mingw64\bin\qmake.exe" "%OPENSHOT_DEPS_DIR%\Qt\bin\qmake.exe"
COPY /y /b "C:\msys64\mingw64\bin\moc.exe" "%OPENSHOT_DEPS_DIR%\Qt\bin\moc.exe"
COPY /y /b "C:\msys64\mingw64\bin\rcc.exe" "%OPENSHOT_DEPS_DIR%\Qt\bin\rcc.exe"
COPY /y /b "C:\msys64\mingw64\bin\uic.exe" "%OPENSHOT_DEPS_DIR%\Qt\bin\uic.exe"
REM
XCOPY "C:\msys64\mingw64\include\QtCore" "%OPENSHOT_DEPS_DIR%\Qt\include\QtCore" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtGui" "%OPENSHOT_DEPS_DIR%\Qt\include\QtGui" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtWidgets" "%OPENSHOT_DEPS_DIR%\Qt\include\QtWidgets" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtMultimedia" "%OPENSHOT_DEPS_DIR%\Qt\include\QtMultimedia" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtMultimediaWidgets" "%OPENSHOT_DEPS_DIR%\Qt\include\QtMultimediaWidgets" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtNetwork" "%OPENSHOT_DEPS_DIR%\Qt\include\QtNetwork" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtOpenGL" "%OPENSHOT_DEPS_DIR%\Qt\include\QtOpenGL" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtPositioning" "%OPENSHOT_DEPS_DIR%\Qt\include\QtPositioning" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtPrintSupport" "%OPENSHOT_DEPS_DIR%\Qt\include\QtPrintSupport" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtQml" "%OPENSHOT_DEPS_DIR%\Qt\include\QtQml" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtQuick" "%OPENSHOT_DEPS_DIR%\Qt\include\QtQuick" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtQuickWidgets" "%OPENSHOT_DEPS_DIR%\Qt\include\QtQuickWidgets" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtSensors" "%OPENSHOT_DEPS_DIR%\Qt\include\QtSensors" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtSvg" "%OPENSHOT_DEPS_DIR%\Qt\include\QtSvg" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtWebChannel" "%OPENSHOT_DEPS_DIR%\Qt\include\QtWebChannel" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtWebSockets" "%OPENSHOT_DEPS_DIR%\Qt\include\QtWebSockets" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtWebKit" "%OPENSHOT_DEPS_DIR%\Qt\include\QtWebKit" /s /i /q /y
XCOPY "C:\msys64\mingw64\include\QtWebKitWidgets" "%OPENSHOT_DEPS_DIR%\Qt\include\QtWebKitWidgets" /s /i /q /y
REM
REM Probably it is instalation dependent files, maybe will be modified later
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Core" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Core" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Gui" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Gui" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Widgets" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Widgets" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Multimedia" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Multimedia" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5MultimediaWidgets" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5MultimediaWidgets" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Network" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Network" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5OpenGL" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5OpenGL" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Positioning" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Positioning" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5PrintSupport" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5PrintSupport" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Qml" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Qml" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Quick" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Quick" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5QuickWidgets" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5QuickWidgets" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Sensors" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Sensors" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5Svg" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Svg" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5WebChannel" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5WebChannel" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5WebSockets" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5WebSockets" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5WebKit" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5WebKit" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
XCOPY "C:\msys64\mingw64\lib\cmake\Qt5WebKitWidgets" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5WebKitWidgets" /s /i /q /y /EXCLUDE:"%OPENSHOT_DEPS_DIR%\exclude_list.txt"
REM
COPY /y /b "C:\msys64\mingw64\lib\libQt5Core.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Core.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Gui.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Gui.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Widgets.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Widgets.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Multimedia.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Multimedia.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5MultimediaWidgets.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5MultimediaWidgets.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Network.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Network.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5OpenGL.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5OpenGL.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Positioning.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Positioning.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5PrintSupport.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5PrintSupport.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Qml.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Qml.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Quick.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Quick.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5QuickWidgets.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5QuickWidgets.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Sensors.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Sensors.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5Svg.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5Svg.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5WebChannel.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5WebChannel.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5WebSockets.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5WebSockets.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5WebKit.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5WebKit.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libQt5WebKitWidgets.dll.a" "%OPENSHOT_DEPS_DIR%\Qt\lib\libQt5WebKitWidgets.dll.a"
REM
XCOPY "C:\msys64\mingw64\share\qt5\mkspecs" "%OPENSHOT_DEPS_DIR%\Qt\mkspecs" /s /i /q /y
REM
REM All dlls from Qt plugins, qsvg.dll draws images on tool buttons if any, other from imageformats can be skipped
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qgif.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qgif.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qicns.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qicns.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qico.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qico.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qjp2.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qjp2.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qjpeg.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qjpeg.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qmng.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qmng.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qsvg.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qsvg.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qtga.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qtga.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qtiff.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qtiff.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qwbmp.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qwbmp.dll"
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\imageformats\qwebp.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\imageformats\qwebp.dll"
REM
COPY /y /b "C:\msys64\mingw64\share\qt5\plugins\platforms\qwindows.dll" "%OPENSHOT_DEPS_DIR%\Qt\plugins\platforms\qwindows.dll"
REM
REM Zmq dependency dlls, the compiler dependencies are in Qt\bin folder
COPY /y /b "C:\msys64\mingw64\bin\libzmq.dll" "%OPENSHOT_DEPS_DIR%\zmq\bin\libzmq.dll"
COPY /y /b "C:\msys64\mingw64\bin\libsodium-23.dll" "%OPENSHOT_DEPS_DIR%\zmq\bin\libsodium-23.dll"
REM
COPY /y /b "C:\msys64\mingw64\lib\libzmq.dll.a" "%OPENSHOT_DEPS_DIR%\zmq\lib\libzmq.dll.a"
COPY /y /b "C:\msys64\mingw64\lib\libsodium.dll.a" "%OPENSHOT_DEPS_DIR%\zmq\lib\libsodium.dll.a"
REM
COPY /y /b "C:\msys64\mingw64\include\zmq.h" "%OPENSHOT_DEPS_DIR%\zmq\include\zmq.h"
COPY /y /b "C:\msys64\mingw64\include\zmq.hpp" "%OPENSHOT_DEPS_DIR%\zmq\include\zmq.hpp"
COPY /y /b "C:\msys64\mingw64\include\zmq_utils.h" "%OPENSHOT_DEPS_DIR%\zmq\include\zmq_utils.h"
COPY /y /b "C:\msys64\mingw64\include\sodium.h" "%OPENSHOT_DEPS_DIR%\zmq\include\sodium.h"
REM
XCOPY "C:\msys64\mingw64\include\sodium" "%OPENSHOT_DEPS_DIR%\zmq\include\sodium" /s /i /q /y
REM
REM Removing links to debug files from .cmake
REM This allows to skip the error that Qt debug files not exist for cmake when building.
REM
REM Start it from Qt\lib\cmake folder
CD "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake"
SETLOCAL ENABLEDELAYEDEXPANSION
REM Removing strings from files by regular expression
FOR /r %%I in (*) DO (
 FINDSTR /r /v "_populate.*DEBUG.*d.dll" "%%I">cmake.tmp
 MOVE /y "cmake.tmp" "%%I"
)
ENDLOCAL
REM Here all links to the debug files _populate inside the .cmake of the Qt already removed.
REM
REM Correct path to mkspecs/win32-g++, removing double slash in Qt5CoreConfigExtrasMkspecDir.cmake
REM the "qt5//mkspecs/win32-g++" to "qt5/mkspecs/win32-g++"
REM
CD "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake"
ECHO.>cmake.tmp
ECHO set(_qt5_corelib_extra_includes "${_qt5Core_install_prefix}/share/qt5/mkspecs/win32-g++")>>cmake.tmp
MOVE /y "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\cmake.tmp" "%OPENSHOT_DEPS_DIR%\Qt\lib\cmake\Qt5Core\Qt5CoreConfigExtrasMkspecDir.cmake"
REM Here path is OK

REM Download FFmpeg dependencies, libopenshot
CD %APPVEYOR_BUILD_FOLDER%\downloads
IF NOT EXIST "ffmpeg-4.2-win64-dev.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/dev/ffmpeg-4.2-win64-dev.zip -f --retry 4
IF NOT EXIST "ffmpeg-4.2-win64-shared.zip" curl -kLO https://ffmpeg.zeranoe.com/builds/win64/shared/ffmpeg-4.2-win64-shared.zip -f --retry 4
DIR
7z x ffmpeg-4.2-win64-dev.zip -offmpeg
7z x ffmpeg-4.2-win64-shared.zip -offmpeg -aoa
REM
REM Keep all in one folder
REM
REM First archive
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-4.2-win64-dev
REM Move folders
FOR /d %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Move files
FOR %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM
REM Second archive
CD %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg\ffmpeg-4.2-win64-shared
REM Move folders
FOR /d %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Move files
FOR %%I IN (*) DO (MOVE "%%I" "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg")
REM Change current folder to move it later
CD %APPVEYOR_BUILD_FOLDER%\downloads
REM Move all stuff to one place
MOVE /y %APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg %OPENSHOT_DEPS_DIR%
REM Add ffmpeg folders to PATH
SET FFMPEGDIR=%OPENSHOT_DEPS_DIR%\ffmpeg

REM Resolve UnitTest++ Dependency, libopenshot
IF EXIST "%OPENSHOT_DEPS_DIR%\UTpp" GOTO UnitTestppInstalled
REM Remove UTpp destination folder for clear install
IF EXIST "%OPENSHOT_DEPS_DIR%\UTpp" RMDIR "%OPENSHOT_DEPS_DIR%\UTpp" /s /q
CD %APPVEYOR_BUILD_FOLDER%\downloads
SETLOCAL
SET UnitTestppSHA1=bc5d87f484cac2959b0a0eafbde228e69e828d74
ECHO %UnitTestppSHA1%
IF NOT EXIST "UnitTestpp.zip" curl -kL "https://github.com/unittest-cpp/unittest-cpp/archive/%UnitTestppSHA1%.zip" -f --retry 4 --output UnitTestpp.zip
DIR
7z x UnitTestpp.zip
RENAME "unittest-cpp-%UnitTestppSHA1%" unittest-cpp
DIR
ENDLOCAL
REM
CD unittest-cpp
DIR
MKDIR build
CD build
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=6.1 -DCMAKE_INSTALL_PREFIX:PATH="%OPENSHOT_DEPS_DIR%\UTpp" ..
mingw32-make
mingw32-make install
REM
REM Here UnitTest++ already installed
:UnitTestppInstalled
REM
REM Set environment variable
SET UNITTEST_DIR=%OPENSHOT_DEPS_DIR%\UTpp
REM Because in recent builds of libopenshot tests are not required, can be skipped s not found
REM SET UnitTest++_INCLUDE_DIRS=%OPENSHOT_DEPS_DIR%\UTpp\include

:qtFromDeps
REM Do not restore from custom Qt archive if script configured to use native MSYS2 Qt installation
IF "%OPENSHOT_QT_SOURCE%" == "IN_MSYS2" GOTO depsInstalled
CD "%APPVEYOR_BUILD_FOLDER%\downloads"
REM Remove restored from the cache dependencies that are already in this custom archive
IF EXIST "%OPENSHOT_DEPS_DIR%\ffmpeg" RMDIR /s /q "%OPENSHOT_DEPS_DIR%\ffmpeg"
IF EXIST "%OPENSHOT_DEPS_DIR%\zmq" RMDIR /s /q "%OPENSHOT_DEPS_DIR%\zmq"
IF EXIST "%OPENSHOT_DEPS_DIR%\UTpp" RMDIR /s /q "%OPENSHOT_DEPS_DIR%\UTpp"
IF EXIST "%OPENSHOT_DEPS_DIR%\Qt" RMDIR /s /q "%OPENSHOT_DEPS_DIR%\Qt"
REM Unpacking Qt files and move them at default locations
CD "%APPVEYOR_BUILD_FOLDER%\downloads"
IF NOT EXIST "OpenShot-Ext-Deps-win-x64-N491m01.7z" curl -kLO https://github.com/SuslikV/libopenshot/raw/build-deps/win-x64/OpenShot-Ext-Deps-win-x64-N491m01.7z -f --retry 4
7z x OpenShot-Ext-Deps-win-x64-N491m01.7z
DIR
REM Make copy of Qt dir to deps folder before moving files - this ensures that actual dependencies will be deployed later
XCOPY "%APPVEYOR_BUILD_FOLDER%\downloads\Qt" "%OPENSHOT_DEPS_DIR%\Qt" /s /i /q /y
REM Move Qt files in place
IF NOT EXIST "C:\msys64\mingw64\bin" MKDIR "C:\msys64\mingw64\bin"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Core.dll" "C:\msys64\mingw64\bin\Qt5Core.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Gui.dll" "C:\msys64\mingw64\bin\Qt5Gui.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Widgets.dll" "C:\msys64\mingw64\bin\Qt5Widgets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Multimedia.dll" "C:\msys64\mingw64\bin\Qt5Multimedia.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5MultimediaWidgets.dll" "C:\msys64\mingw64\bin\Qt5MultimediaWidgets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Network.dll" "C:\msys64\mingw64\bin\Qt5Network.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5OpenGL.dll" "C:\msys64\mingw64\bin\Qt5OpenGL.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Positioning.dll" "C:\msys64\mingw64\bin\Qt5Positioning.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5PrintSupport.dll" "C:\msys64\mingw64\bin\Qt5PrintSupport.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Qml.dll" "C:\msys64\mingw64\bin\Qt5Qml.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Quick.dll" "C:\msys64\mingw64\bin\Qt5Quick.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5QuickWidgets.dll" "C:\msys64\mingw64\bin\Qt5QuickWidgets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Sensors.dll" "C:\msys64\mingw64\bin\Qt5Sensors.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5Svg.dll" "C:\msys64\mingw64\bin\Qt5Svg.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebChannel.dll" "C:\msys64\mingw64\bin\Qt5WebChannel.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebSockets.dll" "C:\msys64\mingw64\bin\Qt5WebSockets.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebKit.dll" "C:\msys64\mingw64\bin\Qt5WebKit.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\Qt5WebKitWidgets.dll" "C:\msys64\mingw64\bin\Qt5WebKitWidgets.dll"
REM
REM All dlls that Qt uses, but compiler dependencies
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libicuin64.dll" "C:\msys64\mingw64\bin\libicuin64.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libicuuc64.dll" "C:\msys64\mingw64\bin\libicuuc64.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libicudt64.dll" "C:\msys64\mingw64\bin\libicudt64.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libpcre2-16-0.dll" "C:\msys64\mingw64\bin\libpcre2-16-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\zlib1.dll" "C:\msys64\mingw64\bin\zlib1.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libharfbuzz-0.dll" "C:\msys64\mingw64\bin\libharfbuzz-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libfreetype-6.dll" "C:\msys64\mingw64\bin\libfreetype-6.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libbz2-1.dll" "C:\msys64\mingw64\bin\libbz2-1.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libpng16-16.dll" "C:\msys64\mingw64\bin\libpng16-16.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libglib-2.0-0.dll" "C:\msys64\mingw64\bin\libglib-2.0-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libintl-8.dll" "C:\msys64\mingw64\bin\libintl-8.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libiconv-2.dll" "C:\msys64\mingw64\bin\libiconv-2.dll"
REM MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libpcre-1.dll" "C:\msys64\mingw64\bin\libpcre-1.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libgraphite2.dll" "C:\msys64\mingw64\bin\libgraphite2.dll"
REM
REM Few unique dependencies for QtWebKit, about the Qt own, as Qt5Multimedia etc., see above
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libjpeg-8.dll" "C:\msys64\mingw64\bin\libjpeg-8.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libsqlite3-0.dll" "C:\msys64\mingw64\bin\libsqlite3-0.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libwebp-7.dll" "C:\msys64\mingw64\bin\libwebp-7.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libxml2-2.dll" "C:\msys64\mingw64\bin\libxml2-2.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\liblzma-5.dll" "C:\msys64\mingw64\bin\liblzma-5.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\libxslt-1.dll" "C:\msys64\mingw64\bin\libxslt-1.dll"
REM
REM Copy exe files, that cmake looks for when building Qt
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\qmake.exe" "C:\msys64\mingw64\bin\qmake.exe"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\moc.exe" "C:\msys64\mingw64\bin\moc.exe"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\rcc.exe" "C:\msys64\mingw64\bin\rcc.exe"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\bin\uic.exe" "C:\msys64\mingw64\bin\uic.exe"
REM
IF NOT EXIST "C:\msys64\mingw64\include" MKDIR "C:\msys64\mingw64\include"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtCore" "C:\msys64\mingw64\include\QtCore"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtGui" "C:\msys64\mingw64\include\QtGui"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWidgets" "C:\msys64\mingw64\include\QtWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtMultimedia" "C:\msys64\mingw64\include\QtMultimedia"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtMultimediaWidgets" "C:\msys64\mingw64\include\QtMultimediaWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtNetwork" "C:\msys64\mingw64\include\QtNetwork"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtOpenGL" "C:\msys64\mingw64\include\QtOpenGL"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtPositioning" "C:\msys64\mingw64\include\QtPositioning"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtPrintSupport" "C:\msys64\mingw64\include\QtPrintSupport"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtQml" "C:\msys64\mingw64\include\QtQml"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtQuick" "C:\msys64\mingw64\include\QtQuick"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtQuickWidgets" "C:\msys64\mingw64\include\QtQuickWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtSensors" "C:\msys64\mingw64\include\QtSensors"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtSvg" "C:\msys64\mingw64\include\QtSvg"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebChannel" "C:\msys64\mingw64\include\QtWebChannel"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebSockets" "C:\msys64\mingw64\include\QtWebSockets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebKit" "C:\msys64\mingw64\include\QtWebKit"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\include\QtWebKitWidgets" "C:\msys64\mingw64\include\QtWebKitWidgets"
REM
REM Probably it is instalation dependent files, maybe will be modified later
IF NOT EXIST "C:\msys64\mingw64\lib\cmake" MKDIR "C:\msys64\mingw64\lib\cmake"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5" "C:\msys64\mingw64\lib\cmake\Qt5"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Core" "C:\msys64\mingw64\lib\cmake\Qt5Core"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Gui" "C:\msys64\mingw64\lib\cmake\Qt5Gui"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Widgets" "C:\msys64\mingw64\lib\cmake\Qt5Widgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Multimedia" "C:\msys64\mingw64\lib\cmake\Qt5Multimedia"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5MultimediaWidgets" "C:\msys64\mingw64\lib\cmake\Qt5MultimediaWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Network" "C:\msys64\mingw64\lib\cmake\Qt5Network"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5OpenGL" "C:\msys64\mingw64\lib\cmake\Qt5OpenGL"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Positioning" "C:\msys64\mingw64\lib\cmake\Qt5Positioning"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5PrintSupport" "C:\msys64\mingw64\lib\cmake\Qt5PrintSupport"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Qml" "C:\msys64\mingw64\lib\cmake\Qt5Qml"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Quick" "C:\msys64\mingw64\lib\cmake\Qt5Quick"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5QuickWidgets" "C:\msys64\mingw64\lib\cmake\Qt5QuickWidgets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Sensors" "C:\msys64\mingw64\lib\cmake\Qt5Sensors"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5Svg" "C:\msys64\mingw64\lib\cmake\Qt5Svg"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebChannel" "C:\msys64\mingw64\lib\cmake\Qt5WebChannel"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebSockets" "C:\msys64\mingw64\lib\cmake\Qt5WebSockets"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebKit" "C:\msys64\mingw64\lib\cmake\Qt5WebKit"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\cmake\Qt5WebKitWidgets" "C:\msys64\mingw64\lib\cmake\Qt5WebKitWidgets"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Core.dll.a" "C:\msys64\mingw64\lib\libQt5Core.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Gui.dll.a" "C:\msys64\mingw64\lib\libQt5Gui.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Widgets.dll.a" "C:\msys64\mingw64\lib\libQt5Widgets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Multimedia.dll.a" "C:\msys64\mingw64\lib\libQt5Multimedia.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5MultimediaWidgets.dll.a" "C:\msys64\mingw64\lib\libQt5MultimediaWidgets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Network.dll.a" "C:\msys64\mingw64\lib\libQt5Network.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5OpenGL.dll.a" "C:\msys64\mingw64\lib\libQt5OpenGL.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Positioning.dll.a" "C:\msys64\mingw64\lib\libQt5Positioning.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5PrintSupport.dll.a" "C:\msys64\mingw64\lib\libQt5PrintSupport.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Qml.dll.a" "C:\msys64\mingw64\lib\libQt5Qml.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Quick.dll.a" "C:\msys64\mingw64\lib\libQt5Quick.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5QuickWidgets.dll.a" "C:\msys64\mingw64\lib\libQt5QuickWidgets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Sensors.dll.a" "C:\msys64\mingw64\lib\libQt5Sensors.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5Svg.dll.a" "C:\msys64\mingw64\lib\libQt5Svg.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebChannel.dll.a" "C:\msys64\mingw64\lib\libQt5WebChannel.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebSockets.dll.a" "C:\msys64\mingw64\lib\libQt5WebSockets.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebKit.dll.a" "C:\msys64\mingw64\lib\libQt5WebKit.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\lib\libQt5WebKitWidgets.dll.a" "C:\msys64\mingw64\lib\libQt5WebKitWidgets.dll.a"
REM
IF NOT EXIST "C:\msys64\mingw64\share\qt5" MKDIR "C:\msys64\mingw64\share\qt5"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\mkspecs" "C:\msys64\mingw64\share\qt5\mkspecs"
REM
REM All dlls from Qt plugins, qsvg.dll draws images on tool buttons if any, other can be skipped
IF NOT EXIST "C:\msys64\mingw64\share\qt5\plugins\imageformats" MKDIR "C:\msys64\mingw64\share\qt5\plugins\imageformats"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qgif.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qgif.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qicns.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qicns.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qico.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qico.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qjp2.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qjp2.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qjpeg.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qjpeg.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qmng.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qmng.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qsvg.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qsvg.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qtga.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qtga.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qtiff.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qtiff.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qwbmp.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qwbmp.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\imageformats\qwebp.dll" "C:\msys64\mingw64\share\qt5\plugins\imageformats\qwebp.dll"
REM
IF NOT EXIST "C:\msys64\mingw64\share\qt5\plugins\platforms" MKDIR "C:\msys64\mingw64\share\qt5\plugins\platforms"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\Qt\plugins\platforms\qwindows.dll" "C:\msys64\mingw64\share\qt5\plugins\platforms\qwindows.dll"
REM
IF NOT EXIST "%OPENSHOT_DEPS_DIR%" MKDIR "%OPENSHOT_DEPS_DIR%"
REM Remove existing FFmpeg deps folder (Force FFmpeg update)
IF EXIST "%OPENSHOT_DEPS_DIR%\ffmpeg" RMDIR "%OPENSHOT_DEPS_DIR%\ffmpeg" /s /q
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\ffmpeg" MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\ffmpeg" "%OPENSHOT_DEPS_DIR%"
REM Add ffmpeg folders to PATH
SET FFMPEGDIR=%OPENSHOT_DEPS_DIR%\ffmpeg
REM
REM Make copy of zmq dir to deps folder before moving files - this ensures that actual dependencies will be deployed later
XCOPY "%APPVEYOR_BUILD_FOLDER%\downloads\zmq" "%OPENSHOT_DEPS_DIR%\zmq" /s /i /q /y
REM
REM Zmq dependency dlls, the compiler dependencies are in Qt\bin folder
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\bin\libzmq.dll" "C:\msys64\mingw64\bin\libzmq.dll"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\bin\libsodium-23.dll" "C:\msys64\mingw64\bin\libsodium-23.dll"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\lib\libzmq.dll.a" "C:\msys64\mingw64\lib\libzmq.dll.a"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\lib\libsodium.dll.a" "C:\msys64\mingw64\lib\libsodium.dll.a"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\zmq.h" "C:\msys64\mingw64\include\zmq.h"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\zmq.hpp" "C:\msys64\mingw64\include\zmq.hpp"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\zmq_utils.h" "C:\msys64\mingw64\include\zmq_utils.h"
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\sodium.h" "C:\msys64\mingw64\include\sodium.h"
REM
MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\zmq\include\sodium" "C:\msys64\mingw64\include\sodium"
REM
REM Resolve UnitTest++ dependency of libopenshot
IF NOT EXIST "%OPENSHOT_DEPS_DIR%\UTpp" MOVE "%APPVEYOR_BUILD_FOLDER%\downloads\UTpp" "%OPENSHOT_DEPS_DIR%"
REM Set environment variable
SET UNITTEST_DIR=%OPENSHOT_DEPS_DIR%\UTpp
REM
REM Resolve SWIG dependency, used to create import file of libopenshot into Python, these libs would be freezed
REM so use any allowed here.
bash -lc "pacman -S --needed --noconfirm mingw64/mingw-w64-x86_64-swig"
REM Here all dependencies are ready
:depsInstalled

REM Resolve libopenshot dependency
cd %APPVEYOR_BUILD_FOLDER%\downloads
REM Get current hash
git ls-remote https://github.com/SuslikV/libopenshot.git what-you-have-missed-so-far > current-head.txt
IF EXIST current-head.txt (
  ECHO libopenshot current:
  TYPE current-head.txt
)
IF EXIST last-libopenshot.txt (
  ECHO libopenshot cached:
  TYPE last-libopenshot.txt
)
REM Compare current to cached hash, recompile if hash fails
FC current-head.txt last-libopenshot.txt > nul
REM Skip all checks force libopenshot building
REM GOTO InstLibV
IF errorlevel 1 GOTO InstLibV
IF EXIST "%OPENSHOT_DEPS_DIR%\libopenshot" GOTO LibVInstalled
:InstLibV
REM Remove libopenshot destination folder for clear install
IF EXIST "%OPENSHOT_DEPS_DIR%\libopenshot" RMDIR "%OPENSHOT_DEPS_DIR%\libopenshot" /s /q
REM Store last compiled hash value to cache it later
git ls-remote https://github.com/SuslikV/libopenshot.git what-you-have-missed-so-far > last-libopenshot.txt
REM Clone and checkout what-you-have-missed-so-far branch
git clone --branch what-you-have-missed-so-far https://github.com/SuslikV/libopenshot.git
DIR
CD libopenshot
DIR
REM Make new building dir
MKDIR build
CD build
python3 --version
cmake --version
cmake -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_VERSION=6.1 -DPYTHON_EXECUTABLE:FILEPATH="%PYTHONHOME%\python.exe" -DPYTHON_INCLUDE_DIR:PATH="%PYTHONHOME%\include" -DPYTHON_LIBRARY:FILEPATH="%PYTHONHOME%\libs\libpython37.a" -DCMAKE_INSTALL_PREFIX:PATH="%OPENSHOT_DEPS_DIR%\libopenshot" -DPYTHON_MODULE_PATH="%P_MODULE_PATH%" ..
mingw32-make --version
mingw32-make
mingw32-make install
REM Here libopenshot already installed
:LibVInstalled
SET LIBOPENSHOT_DIR=%OPENSHOT_DEPS_DIR%\libopenshot

REM Resolve python-cx_freeze dependency
CD %APPVEYOR_BUILD_FOLDER%\downloads
REM Upgrade PIP
%PYTHONHOME%\python -m pip install --upgrade pip
REM List installed packages
pip3 list
ECHO:
ECHO PIP3 installations...
ECHO:
REM Build and install SIP manually
REM Check if SIP already installed
IF EXIST "%PYTHONHOME%\sip.exe" GOTO PyQt5Install
CD %APPVEYOR_BUILD_FOLDER%\downloads
IF NOT EXIST "PyQt5sipsrc.zip" curl -kL https://www.riverbankcomputing.com/static/Downloads/sip/4.19.17/sip-4.19.17.zip -f --retry 4 --output PyQt5sipsrc.zip
7z x PyQt5sipsrc.zip
RENAME "%APPVEYOR_BUILD_FOLDER%\downloads\sip-4.19.17" sip41917
CD %APPVEYOR_BUILD_FOLDER%\downloads\sip41917
REM %PYTHONHOME%\python configure.py --platform win32-g++ --sip-module PyQt5.sip
%PYTHONHOME%\python configure.py ^
    --platform win32-g++ ^
    --no-stubs ^
    --sip-module PyQt5.sip
mingw32-make
REM XCOPY /i /s /y "%APPVEYOR_BUILD_FOLDER%\downloads\sip41917" "%PYTHONHOME%\sip41917"
REM mingw32-make install
REM Emulate install because install just fails trying to use MSYS2 /usr/bin/sh with backslashes in path instead of slashes
REM
CD %APPVEYOR_BUILD_FOLDER%\downloads\sip41917\sipgen
COPY /y sip.exe %PYTHONHOME%\sip.exe
COPY /y %APPVEYOR_BUILD_FOLDER%\downloads\sip41917\siplib\sip.h %PYTHONHOME%\include\sip.h
REM
CD %APPVEYOR_BUILD_FOLDER%\downloads\sip41917\siplib
IF NOT EXIST %PYTHONHOME%\Lib\site-packages\PyQt5 MKDIR %PYTHONHOME%\Lib\site-packages\PyQt5
COPY /y sip.pyd %PYTHONHOME%\Lib\site-packages\PyQt5\sip.pyd
STRIP C:\Python37-x64\Lib\site-packages\PyQt5\sip.pyd
COPY /y %APPVEYOR_BUILD_FOLDER%\downloads\sip41917\sip.pyi %PYTHONHOME%\Lib\site-packages\PyQt5\sip.pyi
REM
CD %APPVEYOR_BUILD_FOLDER%\downloads\sip41917
IF NOT EXIST %PYTHONHOME%\Lib\site-packages MKDIR %PYTHONHOME%\Lib\site-packages
COPY /y sipconfig.py %PYTHONHOME%\Lib\site-packages\sipconfig.py
COPY /y C:\projects\openshot-qt\downloads\sip41917\sipdistutils.py %PYTHONHOME%\Lib\site-packages\sipdistutils.py
%PYTHONHOME%\python.exe C:\projects\openshot-qt\downloads\sip41917\mk_distinfo.py "" %PYTHONHOME%\Lib\site-packages\PyQt5_sip-4.19.17.dist-info installed.txt
REM Here PyQt5-sip already installed
:PyQt5Install
CD %PYTHONHOME%
REM Build and install PyQt manually, beacause QtWebKit module is needed to OpenShot to work.
REM Check if PyQt5 already installed.
REM The QtWebKitWidgets.pyd or .pyi build last in the below sequence, so just check if it present.
IF EXIST "%PYTHONHOME%\lib\site-packages\PyQt5\QtWebKitWidgets.pyd" (
  ECHO It seems that the required PyQt5 modules installed
  SET OPENSHOT_PYQT5=OK
  GOTO pythPack
)
CD %APPVEYOR_BUILD_FOLDER%\downloads
IF NOT EXIST "PyQt5src.zip" curl -kL https://www.riverbankcomputing.com/static/Downloads/PyQt5/5.12.2/PyQt5_gpl-5.12.2.zip -f --retry 4 --output PyQt5src.zip
7z x PyQt5src.zip
RENAME "%APPVEYOR_BUILD_FOLDER%\downloads\PyQt5_gpl-5.12.2" PyQt5122
CD %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122
REM
REM Workaround Python library linking, the "__imp_PyDict_SetItemString" error during PyQt5 building,
REM the self.get_pylib_link_arguments(name=False) to self.get_pylib_link_arguments(name=True) call
REM in configure.py on Windows (not static).
REM
REM Replacing first occurrence of "(name=False)" with the "(name=True)" in %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\configure.py
bash -lc "sed -i -e 's;(name=False);(name=True);' %MYAPP_BUILD_FOLDER_SLASH%/downloads/PyQt5122/configure.py"
REM
REM Workaround PyQt versioning during install, the openshot-qt will import PYQT_VERSION_STR later just for logging, so version required.
REM Turn run_mk_distinfo to run_mk_distinfo.replace('\\', '/') because this setup requires slashes instead of backslashes in the path
REM in configure.py when makefile creates.
REM
REM Replacing first occurrence of "sys.executable, " with the "sys.executable.replace('\\', '/'), " in %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\configure.py
REM Replacing first occurrence of "), distinfo_dir)" with the ").replace('\\', '/'), distinfo_dir.replace('\\', '/'))" in %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\configure.py
bash -lc "sed -i -e 's;sys.executable, ;sys.executable.replace('\'openshot528491\'', '\'/\''), ;' %MYAPP_BUILD_FOLDER_SLASH%/downloads/PyQt5122/configure.py"
bash -lc "sed -i -e 's;), distinfo_dir);).replace('\'openshot528491\'', '\'/\''), distinfo_dir.replace('\'openshot528491\'', '\'/\''));' %MYAPP_BUILD_FOLDER_SLASH%/downloads/PyQt5122/configure.py"
bash -lc "sed -i -e 's;openshot528491;\\\\\\\\;g' %MYAPP_BUILD_FOLDER_SLASH%/downloads/PyQt5122/configure.py"
REM Here, the PyQt5 compile time exceeds 1 hour limit,
REM so I will try to split the modules, cache them
REM and build it over the cached again until all requred
REM modules will be build.
REM All used in OpenShot, these are mainly QtWebKit dependencies
REM
REM QtCore QtGui QtMultimedia QtMultimediaWidgets QtNetwork QtOpenGL QtPositioning QtPrintSupport QtQml QtQuick QtQuickWidgets QtSensors QtSvg QtWebChannel QtWebKit QtWebKitWidgets QtWidgets
REM
ECHO # The target Python installation.> mypyqt5.cfg
ECHO py_pylib_dir = %PYTHONHOME%\libs>> mypyqt5.cfg
ECHO py_pylib_lib = python37>> mypyqt5.cfg
ECHO # Qt configuration common to all versions.>> mypyqt5.cfg
ECHO qt_shared = True>> mypyqt5.cfg
ECHO [Qt 5.12]>> mypyqt5.cfg
REM To ensure that the module installed check for .pyd file or .pyi file, if output is static lib
IF NOT EXIST "%PYTHONHOME%\lib\site-packages\PyQt5\QtWidgets.pyd" (
    REM About 38 minutes to compile
    ECHO pyqt_modules = QtCore QtGui QtWidgets>> mypyqt5.cfg
) ELSE IF NOT EXIST "%PYTHONHOME%\lib\site-packages\PyQt5\QtWebKitWidgets.pyd" (
    REM About 34 minutes to compile
    ECHO pyqt_modules = QtMultimedia QtMultimediaWidgets QtNetwork QtOpenGL QtPositioning QtPrintSupport QtQml QtQuick QtQuickWidgets QtSensors QtSvg QtWebChannel QtWebKit QtWebKitWidgets>> mypyqt5.cfg
)
TYPE mypyqt5.cfg
ECHO Start PyQt5 configure at: & time /t & ECHO it is long process just wait...
REM %PYTHONHOME%\python configure.py --spec=win32-g++ --confirm-license --static --verbose --configuration mypyqt5.cfg
%PYTHONHOME%\python configure.py ^
    --confirm-license ^
    --spec=win32-g++ ^
    --sip="%PYTHONHOME%\sip.exe" ^
    --no-designer-plugin ^
    --no-docstrings ^
    --no-python-dbus ^
    --no-qml-plugin ^
    --no-qsci-api ^
    --no-sip-files ^
    --no-stubs ^
    --no-tools ^
    --verbose ^
    --configuration mypyqt5.cfg
ECHO End PyQt5 configure at: & time /t
REM TYPE %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\PyQt5.pro
REM TYPE %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\QtSvg\QtSvg.pro
REM TYPE %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\Qt\Qt.pro
REM
mingw32-make
REM
REM TYPE %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\makefile
REM TYPE %APPVEYOR_BUILD_FOLDER%\downloads\PyQt5122\Qt\makefile
REM
mingw32-make install
REM
REM List all installed PyQt5 modules
CD %PYTHONHOME%\lib\site-packages\PyQt5
DIR
REM Here PyQt5 already installed

:pythPack
REM Pack whole Python folder with some PyQt5 modules installed.
CD %PYTHONHOME%
7z a -bsp2 -t7z python-%PLATFORM%.7z
DIR
IF NOT EXIST "%OPENSHOT_INST_DIR%" MKDIR "%OPENSHOT_INST_DIR%"
MOVE /y python-%PLATFORM%.7z "%OPENSHOT_INST_DIR%"
REM PyQt5 modules was splitted because of 1 hour building limit.
IF "%OPENSHOT_PYQT5%" NEQ "OK" (
  REM Flag that not all modules of PyQt5 is installed
  CD "%APPVEYOR_BUILD_FOLDER%\downloads"
  ECHO OPENSHOT_PYQT5 isn't fully installed>openshot_pyqt5.txt
  EXIT 0
)

:OtherPkgInstall
pip3 install pyzmq
pip3 install pywin32
pip3 install requests
pip3 install idna

REM Resolve cx_Freeze dependency
REM Check if cx_Freeze already installed. The cxfreeze-quickstart in Scripts installed last from all, so look for it.
IF EXIST "%PYTHONHOME%\Scripts\cxfreeze-quickstart" GOTO Pip3PKGsInstalled
REM Only Python3.7 compatible is needed here
CD %APPVEYOR_BUILD_FOLDER%\downloads
SETLOCAL
SET cxFreezeSHA1=9e06b761740a9e93431ee7ea8d0b10f786446a6a
ECHO %cxFreezeSHA1%
IF NOT EXIST "cxFrsrc.zip" curl -kL "https://github.com/anthony-tuininga/cx_Freeze/archive/%cxFreezeSHA1%.zip" -f --retry 4 --output cxFrsrc.zip
DIR
7z x cxFrsrc.zip
RENAME "cx_Freeze-%cxFreezeSHA1%" cxFr60b1
DIR
ENDLOCAL
CD cxFr60b1
%PYTHONHOME%\python setup.py build
%PYTHONHOME%\python setup.py install
REM Here cx_Freeze already installed

REM Here all required Python packages already installed
:Pip3PKGsInstalled
REM List installed packages
pip3 list

REM All required modules installed in Python, so pack it
REM Pack whole Python folder with some PyQt5 modules installed.
CD %PYTHONHOME%
7z a -bsp2 -t7z python-%PLATFORM%.7z
DIR
IF NOT EXIST "%OPENSHOT_INST_DIR%" MKDIR "%OPENSHOT_INST_DIR%"
MOVE /y python-%PLATFORM%.7z "%OPENSHOT_INST_DIR%"

REM Resolving PyQt5 dependency for freeze.py script, cx_Freeze
REM To resolve ImportError: No module named 'PyQt.Qt' error, that can appear
REM by some reason, just add manually to sys.path the directory of the "qt.pyd" file.
REM This can be done from the system via PYTHONPATH environment variable
SET PYTHONPATH=%PYTHONHOME%\Lib\site-packages\PyQt5;%PYTHONPATH%

REM Resolving libopenshot dependency for freeze.py script, cx_Freeze
SET PYTHONPATH=%LIBOPENSHOT_DIR%\%P_MODULE_PATH%;%PYTHONPATH%
REM Add libopenshot and libopenshot-audio lib's dir to Python path
SET PYTHONPATH=%LIBOPENSHOT_DIR%\lib;%LIBOPENSHOT_AUDIO_DIR%\lib;%PYTHONPATH%

REM Resolving FFmpeg dependency for freeze.py script, cx_Freeze
SET PYTHONPATH=%FFMPEGDIR%\bin;%FFMPEGDIR%\lib;%PYTHONPATH%

REM Resolving Unittest++ dependency to test libopenshot import in Python
SET PYTHONPATH=%UNITTEST_DIR%\lib;%PYTHONPATH%

REM Add msys2 to pythonpath to test libopenshot import in Python
SET PYTHONPATH=C:\msys64\mingw64\bin;%PYTHONPATH%

REM Add mingw-w64 to pythonpath to test libopenshot import in Python
SET PYTHONPATH=C:\mingw-w64\x86_64-7.3.0-posix-seh-rt_v5-rev0\mingw64\bin;%PYTHONPATH%

REM Print build dependency libs directory
REM CD %OPENSHOT_DEPS_DIR%
REM DIR /s

:freezing
REM Quick test of openshot import into Python3.7
ECHO:
ECHO Quick test of openshot import into Python...
CD %LIBOPENSHOT_DIR%\%P_MODULE_PATH%
%PYTHONHOME%\python -c "import sys; print(sys.path); import openshot"

REM Start freezing
ECHO:
ECHO Freezing application...
CD %APPVEYOR_BUILD_FOLDER%
%PYTHONHOME%\python freeze.py build_exe -b "%OPENSHOT_INST_DIR%"
REM Freezing test application instead
REM ECHO:
REM ECHO Freezing test application...
REM CD "%PYTHONHOME%\Lib\site-packages\cx_Freeze-6.0b1-py3.7-win-amd64.egg\cx_Freeze\samples\PyQt5"
REM %PYTHONHOME%\python setup.py build_exe -b "%OPENSHOT_INST_DIR%"

REM TREE "%OPENSHOT_INST_DIR%" /f /a

IF "%OPENSHOT_QT_SOURCE%" == "DEPS_FOLDER" GOTO dbgDllRemoved

REM Remove all debug dlls from the release
ECHO off
CD "%OPENSHOT_INST_DIR%"
ECHO:
ECHO Removing *d.dll files from the folder: "%OPENSHOT_INST_DIR%"
ECHO ...
SETLOCAL ENABLEDELAYEDEXPANSION
FOR /r %%I in (*) DO (
  SET debugFile=%%~nI
  REM Any filename that ends with "d"
  IF "!debugFile:~-1!" == "d" (
    SET skipping=0
    REM Exclude files
    IF "!debugFile!" == "libzstd"                    SET skipping=1
    IF "!debugFile!" == "undefined"                  SET skipping=1
    IF "!debugFile!" == "mac_iceland"                SET skipping=1
    IF "!debugFile!" == "qdirect2d"                  SET skipping=1
    IF "!debugFile!" == "preview_thread"             SET skipping=1
    IF "!debugFile!" == "red"                        SET skipping=1
    IF "!debugFile!" == "play_head"                  SET skipping=1
    IF "!debugFile!" == "playhead"                   SET skipping=1
    IF "!debugFile!" == "youtube_HD"                 SET skipping=1
    IF "!debugFile!" == "vimeo_HD"                   SET skipping=1
    IF "!debugFile!" == "nokia_nHD"                  SET skipping=1
    IF "!debugFile!" == "format_mp4_xvid"            SET skipping=1
    IF "!debugFile!" == "flickr_HD"                  SET skipping=1
    IF "!debugFile!" == "avchd"                      SET skipping=1
    IF "!debugFile!" == "qt_gd"                      SET skipping=1
    IF "!debugFile!" == "qtbase_gd"                  SET skipping=1
    IF "!debugFile!" == "OpenShot.id"                SET skipping=1
    IF "!debugFile!" == "test_cffi_backend"          SET skipping=1
    IF "!debugFile!" == "forward"                    SET skipping=1
    IF "!debugFile!" == "_deprecated"                SET skipping=1
    IF "!debugFile!" == "thread"                     SET skipping=1
    IF "!debugFile!" == "weather-showers-scattered"  SET skipping=1
    IF "!debugFile!" == "locked"                     SET skipping=1
    IF "!debugFile!" == "ibus-keyboard"              SET skipping=1
    IF "!debugFile!" == "gpm-battery-charged"        SET skipping=1
    IF "!debugFile!" == "bluetooth-paired"           SET skipping=1
    IF "!debugFile!" == "bluetooth-disabled"         SET skipping=1
    IF "!debugFile!" == "audio-volume-muted"         SET skipping=1
    IF "!debugFile!" == "aptdaemon-add"              SET skipping=1
    IF "!debugFile!" == "folder-download"            SET skipping=1
    IF "!debugFile!" == "application-msword"         SET skipping=1
    IF "!debugFile!" == "phone-motorola-droid"       SET skipping=1
    IF "!debugFile!" == "nm-device-wired"            SET skipping=1
    IF "!debugFile!" == "input-keyboard"             SET skipping=1
    IF "!debugFile!" == "preferences-desktop-sound"  SET skipping=1
    IF "!debugFile!" == "package-installed-updated"  SET skipping=1
    IF "!debugFile!" == "package-installed-outdated" SET skipping=1
    IF "!debugFile!" == "package-installed-locked"   SET skipping=1
    IF "!debugFile!" == "package-available-locked"   SET skipping=1
    IF "!debugFile!" == "media-skip-forward"         SET skipping=1
    IF "!debugFile!" == "media-skip-backward"        SET skipping=1
    IF "!debugFile!" == "media-seek-forward"         SET skipping=1
    IF "!debugFile!" == "media-seek-backward"        SET skipping=1
    IF "!debugFile!" == "media-record"               SET skipping=1
    IF "!debugFile!" == "media-import-audio-cd"      SET skipping=1
    IF "!debugFile!" == "mail-send"                  SET skipping=1
    IF "!debugFile!" == "mail-replied"               SET skipping=1
    IF "!debugFile!" == "mail-read"                  SET skipping=1
    IF "!debugFile!" == "mail-mark-unread"           SET skipping=1
    IF "!debugFile!" == "mail-mark-read"             SET skipping=1
    IF "!debugFile!" == "mail-forward"               SET skipping=1
    IF "!debugFile!" == "locked"                     SET skipping=1
    IF "!debugFile!" == "list-add"                   SET skipping=1
    IF "!debugFile!" == "zoom_clapboard"             SET skipping=1
    IF "!debugFile!" == "threshold"                  SET skipping=1
    IF "!debugFile!" == "sand"                       SET skipping=1
    IF "!debugFile!" == "magic_wand"                 SET skipping=1
    IF "!debugFile!" == "chroma_hold"                SET skipping=1
    IF "!debugFile!" == "board"                      SET skipping=1
    IF "!debugFile!" == "alphagrad"                  SET skipping=1
    IF "!debugFile!" == "openshot-ad"                SET skipping=1
    IF "!debugFile!" == "dyld"                       SET skipping=1
    IF "!debugFile!" == "aptdaemon-add"              SET skipping=1
    IF "!debugFile!" == "folder-download"            SET skipping=1
    IF "!debugFile!" == "chroma_hold"                SET skipping=1
    IF "!debugFile!" == "board"                      SET skipping=1
    IF "!debugFile!" == "alphagrad"                  SET skipping=1
    REM Remove unneded files
    IF !skipping! == 0 (
        DEL /a:s /a:h /a:r /a:a "%%I"
    ) ELSE (
        ECHO "Skip: %%~nxI"
    )
  )
)
ENDLOCAL
ECHO all found files removed.
ECHO off

REM Here all debug dlls from the release already removed
:dbgDllRemoved

REM Remove folders doubles
ECHO:
ECHO Remove folders doubles...
CD "%OPENSHOT_INST_DIR%" & RMDIR /s /q "%OPENSHOT_INST_DIR%\lib\openshot_qt"
ECHO all found folders doubles removed.

REM Move all dlls to the base folder of the application, removing doubles
ECHO off
CD "%OPENSHOT_INST_DIR%"
ECHO:
ECHO Moving .dll files to the base dir: "%OPENSHOT_INST_DIR%"
ECHO ...
SETLOCAL ENABLEDELAYEDEXPANSION
FOR /r %%I in (*) DO (
  SET extFile=%%~xI
  REM Any filename extention that is ".dll"
  IF "!extFile!" == ".dll" (
    SET skipping=0
    REM Exclude files, they all stays at the original position in the folder tree
    IF "%%~nI" == "qwindows" SET skipping=1
    REM Files mentioned below can be moved, but just for beauty - don't touch them
    IF "%%~nI" == "qgif"     SET skipping=1
    IF "%%~nI" == "qicns"    SET skipping=1
    IF "%%~nI" == "qico"     SET skipping=1
    IF "%%~nI" == "qjp2"     SET skipping=1
    IF "%%~nI" == "qjpeg"    SET skipping=1
    IF "%%~nI" == "qmng"     SET skipping=1
    IF "%%~nI" == "qsvg"     SET skipping=1
    IF "%%~nI" == "qtga"     SET skipping=1
    IF "%%~nI" == "qtiff"    SET skipping=1
    IF "%%~nI" == "qwbmp"    SET skipping=1
    IF "%%~nI" == "qwebp"    SET skipping=1
    REM Move files to one folder, same level as the main .exe file
    IF !skipping! == 0 (
        MOVE /y "%%I" "%OPENSHOT_INST_DIR%"
    ) ELSE (
        ECHO "Skip: %%I"
    )
  )
)
ENDLOCAL
ECHO all found files moved.
ECHO off

REM TREE "%OPENSHOT_INST_DIR%" /f /a

REM Unmute output
@ECHO on
