@echo off
where gradle >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  gradle %*
  exit /b %ERRORLEVEL%
)
echo Gradle executable not found.
echo Install Android Studio/Gradle or regenerate the wrapper with: cd android ^& gradle wrapper
exit /b 1
