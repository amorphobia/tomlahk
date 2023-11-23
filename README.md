# tomlahk

AutoHotkey wrapper of [tomlc99](https://github.com/cktan/tomlc99)

## Building

### Dependencies

- git
- C toolchain
- [xmake](https://github.com/xmake-io/xmake) for easily export symbols from dll without modifying source code

### Steps

1. Clone tomlc99 submodule
2. Execute [build.ps1](build.ps1)
3. Copy [`toml.ahk`](toml.ahk) and generated `toml.dll` to your project

## License

[GPL-3.0 license](LICENSE)

## Used Open Source Projects

- [tomlc99](https://github.com/cktan/tomlc99)
- [xmake](https://github.com/xmake-io/xmake)
