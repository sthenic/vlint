[![NIM](https://img.shields.io/badge/Nim-1.2.0-orange.svg?style=flat-square)](https://nim-lang.org)
[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)

# vlint

This tool is linter for Verilog IEEE 1364-2005 written in [Nim](https://nim-lang.org). The parsing is handled by [vparse](https://github.com/sthenic/vparse).

## Configuration

The linter is configured with a [TOML](https://github.com/toml-lang/toml) file that's parsed by the [`vltoml`](https://github.com/sthenic/vltoml) library. Refer to that library's README for more information.

## Version numbers
Releases follow [semantic versioning](https://semver.org/) to determine how the version number is incremented. If the specification is ever broken by a release, this will be documented in the changelog.

## Reporting a bug
If you discover a bug or what you believe is unintended behavior, please submit an issue on the [issue board](https://github.com/sthenic/vls/issues). A minimal working example and a short description of the context is appreciated and goes a long way towards being able to fix the problem quickly.

## License
This tool is free software released under the [MIT license](https://opensource.org/licenses/MIT).

## Third-party dependencies

* [Nim's standard library](https://github.com/nim-lang/Nim)
* [vparse](https://github.com/sthenic/vparse)

## Author
`vls` is maintained by [Marcus Eriksson](mailto:marcus.jr.eriksson@gmail.com).
