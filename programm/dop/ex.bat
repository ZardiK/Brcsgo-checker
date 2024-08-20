@echo off
chcp 65001
cls
color c
setlocal enabledelayedexpansion

set "folder=C:\Users\%USERNAME%\AppData\Roaming\com.swiftsoft\ExLoader\modifications"
for %%a in ("%folder%\*") do (
    echo %%a
)

rem Если файл не найден, производим поиск на всех доступных дисках
for %%d in (z y x w v u t s r q p o n m l k j i h g f e d c b a) do (
    if exist "%%d:\Program Files\ExLoader\exloader.exe" (
        echo Файл exloader.exe найден по пути %%d:\Program Files\ExLoader\exloader.exe
        goto end
    )
)

rem Поиск файла exloader.exe в папке C:\Program Files\ExLoader\exloader.exe
if exist "C:\Program Files\ExLoader\exloader.exe" (
    echo Файл exloader.exe найден по пути C:\Program Files\ExLoader\exloader.exe
    goto end
)

echo Файл exloader.exe не найден.

:end
pause
