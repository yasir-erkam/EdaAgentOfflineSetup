@echo off
"%~dp0runtime\python.exe" "%~dp0launch.py" %*
exit /b %errorlevel%
