version       = "0.1.0"
author        = "Akito <the@akito.ooo>"
description   = "Handles outgoing Mattermost Webhooks."
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["master"]
skipDirs      = @["tasks"]
skipFiles     = @["README.md"]
skipExt       = @["nim"]

requires "nim             >= 1.6.12"
requires "zero_functional >= 1.3.0" # https://github.com/zero-functional/zero-functional
requires "puppy           >= 2.0.3" # https://github.com/treeform/puppy
requires "mike            >= 1.2.1" # https://github.com/ire4ever1190/mike

import strformat

let name_app = "mattermostwebhookhandler"

task docker_build_prod, "Build Production Docker":
  exec &"""nim c --define:danger --opt:speed --out:app src/{name_app} ; strip --strip-all app"""

task build_prod, "Build Production":
  exec &"""nim c --define:danger --opt:speed --out:{name_app} src/{name_app} ; strip --strip-all {name_app}"""

task build_debug, "Build Debug":
  exec &"""nim c --define:debug:true --debuginfo:on --out:{name_app} src/{name_app}"""

task run_prod, "Run Production":
  exec &"""nim c --run --define:danger --opt:speed --out:{name_app} src/{name_app} ; strip --strip-all {name_app}"""

task run_debug, "Run Debug":
  exec &"""nim c --run --define:debug:true --debuginfo:on --out:{name_app} src/{name_app}"""