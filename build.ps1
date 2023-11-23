$WORK = (Get-Location).Path

Copy-Item -Path $WORK\xmake.lua.in -Destination $WORK\tomlc99\xmake.lua
Copy-Item -Path toml.export.txt -Destination $WORK\tomlc99\toml.export.txt

Set-Location -Path $WORK\tomlc99
xmake build
Set-Location -Path $WORK

Copy-Item -Path $WORK\tomlc99\build\windows\x64\release\toml.dll $WORK\toml.dll
