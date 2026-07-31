@echo off
chcp 65001 >nul
rem Пересборка standalone-exe из текущих исходников.
rem Нужна, только если хочешь отдать сборку кому-то без Godot.
rem Для себя запускай ярлык "Играть (текущая версия)" — он всегда свежий.

set GODOT=C:\Users\1\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe
set PROJ=%~dp0

echo Сборка занимает несколько минут, окно не закрывай.
"%GODOT%" --headless --path "%PROJ%" --export-release "Windows" "%PROJ%build\graveyard-shift.exe"

if exist "%PROJ%build\graveyard-shift.exe" (
    echo.
    echo Готово: %PROJ%build\graveyard-shift.exe
) else (
    echo.
    echo НЕ СОБРАЛОСЬ. Смотри ошибки выше.
)
pause
