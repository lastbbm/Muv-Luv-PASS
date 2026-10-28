@echo off
cd /d "%~dp0"
set "OPENCV_ACTCTX_MANIFEST=%~dp0Libs\autoit-opencv-com\autoit_opencv_com4120.sxs.manifest"
start "" "%~dp0AutoIt\AutoIt3_x64.exe" "%~dp0Game_MuvLuv.au3"
