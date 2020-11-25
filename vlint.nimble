version = "0.1.0"
author = "Marcus Eriksson"
description = "A linter for Verilog IEEE 1364-2005 written in Nim."
license = "MIT"
src_dir = "src"
bin = @["vlint"]
install_ext = @["nim"]

skip_dirs = @["tests"]

# Dependencies
requires "nim >= 1.4.0"
requires "vparse >= 0.3.0"
requires "vltoml >= 0.2.0"
