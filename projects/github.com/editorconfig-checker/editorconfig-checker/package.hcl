# github.com/editorconfig-checker/editorconfig-checker — checks that files
# follow their .editorconfig. A whole recipe, written from the project's own
# files at v4.0.2 (go-zpkg/packages#431, #440 step 1). Built the way
# github.com/BurntSushi/toml is built (that recipe's header says how, and why:
# go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: go.mod:4 and :7 say `go 1.26.0` and `toolchain go1.27.0`, both
# met by go.dev 1.27.4, and go.sum pins the six direct and thirteen indirect
# modules. .goreleaser.yaml:20 and :32 build with CGO_ENABLED=0 and -trimpath, which this
# recipe matches. The version is NOT stamped: cmd/editorconfig-checker/main.go:27
# holds `var version = "v4.0.2" // x-release-please-version`, a constant the
# project's release tooling rewrites in the source, and the .goreleaser.yaml
# -X flags (main.commit, main.date, main.builtBy) name variables that file does
# not declare.

summary = "Check that files respect their .editorconfig"

# LICENSE:1-3 "The MIT License (MIT) Copyright (c) 2018 Max Strübing". The
# binary COMPILES IN seven modules (`go list -deps` over ./cmd/editorconfig-checker),
# each licence read from the module's own file in the module cache:
#
#   MIT           editorconfig-core-go/v2 v2.6.4, gabriel-vasile/mimetype v1.4.15,
#                 gkampitakis/ciinfo v0.3.4, wlynxg/chardet v1.0.5
#   BSD-3-Clause  golang.org/x/text v0.42.0, golang.org/x/mod v0.41.0
#   Apache-2.0    gopkg.in/ini.v1 v1.67.0
license = "MIT AND BSD-3-Clause AND Apache-2.0"

versions {
  github = "editorconfig-checker/editorconfig-checker"
}

distributable {
  # GitHub's archive of the tag. The release does publish assets (61: the
  # project's goreleaser binaries, packages and SBOMs), but none is a source
  # archive, so the tag archive is the source rung.
  url              = "https://github.com/editorconfig-checker/editorconfig-checker/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 4153108 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "4.0.2" = "0b84c5090d3f48db1bdfab454b7cde79adb26015d1a2731bba59bc1a636276bb"
  }
}

provides = [
  "bin/editorconfig-checker",
]

build {
  dependencies = {
    "go.dev" = "^1.27"
  }

  env = {
    CGO_ENABLED = "0"
    GOTOOLCHAIN = "local"
    GOFLAGS     = "-mod=readonly -modcacherw -trimpath -buildvcs=false"
    GOPROXY     = "https://proxy.golang.org"
  }

  script = [
    {
      run = <<EOT
set -eu
export GOCACHE="$PWD/.gocache" GOMODCACHE="$PWD/.gomodcache"
mkdir -p "{{prefix}}/bin" "{{prefix}}/share/man/man1"
# Makefile:26 builds ./cmd/editorconfig-checker/main.go; .goreleaser.yaml:17's
# `main: ./cmd/editorconfig-checker` is the package.
go build -ldflags "-s -w" -o "{{prefix}}/bin/editorconfig-checker" ./cmd/editorconfig-checker
# Makefile:56 `install` also installs the manual page.
cp docs/editorconfig-checker.1 "{{prefix}}/share/man/man1/editorconfig-checker.1"
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
# main.go:27 is the version, main.go:287-288 prints it.
test "$(editorconfig-checker -version)" = "v{{version.raw}}"
printf 'root = true\n\n[*]\nindent_style = space\ntrim_trailing_whitespace = true\ninsert_final_newline = true\n' > .editorconfig
printf 'a\nb\n' > clean.txt
editorconfig-checker clean.txt
# A file that breaks its rules is refused, and named.
printf 'a  \nb' > dirty.txt
if editorconfig-checker dirty.txt > out.txt 2>&1; then
  echo "accepted a file that breaks .editorconfig" >&2
  exit 1
fi
grep -q "dirty.txt" out.txt
test -f "{{prefix}}/share/man/man1/editorconfig-checker.1"
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                        # :4 go 1.26.0, :7 toolchain go1.27.0, :9-30 the requirements
    "go.sum",                        # the dependency pin under -mod=readonly
    "LICENSE",                       # :1-3 MIT
    "Makefile",                      # :26 the build line, :56 the manual page install
    ".goreleaser.yaml",              # :17 main, :20 CGO_ENABLED=0, :32 -trimpath, :33-36 the -X flags with no variable behind them
    "cmd/editorconfig-checker/main.go", # :27 the version, :84 -version, :287-288 the output
    "docs/editorconfig-checker.1",   # the installed manual page
  ]

  note = <<EOT
pkgxdev/pantry carries no recipe for this project (projects/github.com/
editorconfig-checker/editorconfig-checker/package.yml answers 404), so nothing
was consulted there; the fragment this replaces said only `provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host. The 61 release assets are binaries the project built, not what
this recipe builds from.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line and the test script on
darwin/arm64 with go1.27.4 against the unpacked v4.0.2 tarball (modules fetched
from proxy.golang.org under -mod=readonly): it built, `-version` printed v4.0.2
and the test passed. The man page copy and the linux arms were not run.
EOT
}
