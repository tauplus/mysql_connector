# Package

version = "0.1.0"
author = "tauplus"
description = "Pure MySQL Connector in Nim"
license = "MIT"
srcDir = "src"


# Dependencies

requires "nim >= 1.4.2"

task ci, "Run CI":
  exec "docker-compose up -d"
  let output = gorgeEx("nimble test")
  exec "docker-compose down"
  if output.exitCode != 0:
    echo output.output
    quit(1)