# Package

version       = "0.1.0"
author        = "zacharycarter"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["nes.js"]
binDir        = "bin"
installExt    = @["nim"]
backend       = "js"

# Dependencies

requires "nim >= 0.18.1"
requires "ast_pattern_matching >= 1.0.0"
requires "ssh://git@coderepo.carfax.net:7999/smc/litz.git"

task test, "run nes tests":
  withDir "tests":
    exec "nim js test_es2015_class.nim"
    exec "nim js test_custom_elements.nim"
    exec "node runner.js"

task dtest, "run nes tests w/ nes debug flag on":
  withDir "tests":
    exec "nim js -d:debugNES test_es2015_class.nim"
    exec "nim js -d:debugNES test_custom_elements.nim"
    exec "node runner.js"
  
task mtools, "run macro tools":
  withDir "tools":
    exec "nim c -r mtools.nim"