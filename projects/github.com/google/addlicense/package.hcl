# github.com/google/addlicense — scans source files and adds a licence header
# where one is missing. A whole recipe, written from the project's own files at
# v1.2.0 (go-zpkg/packages#431, #440 step 1). Built as github.com/BurntSushi/toml
# is (its header says how and why: go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: the module root IS the command (main.go, `package main`, sits
# beside go.mod), so the package is `.`. The project documents `go install`
# only, no Makefile and no release tooling, and the program has no version
# flag, so nothing is stamped. go.mod:3 says `go 1.13`; go.sum pins the two
# modules it requires.

summary = "Add licence headers to source files"

# LICENSE:2-3 "Apache License Version 2.0". The binary COMPILES IN two modules
# (`go list -deps .`), each licence read from the module's own file in the
# module cache:
#
#   MIT           github.com/bmatcuk/doublestar/v4 v4.0.2
#   BSD-3-Clause  golang.org/x/sync (the Go Authors' text)
license = "Apache-2.0 AND MIT AND BSD-3-Clause"

versions {
  github = "google/addlicense"
}

distributable {
  # GitHub's archive of the tag: the release lists only the tag, no assets.
  url              = "https://github.com/google/addlicense/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 26469 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "1.2.0" = "d2e05668e6f3da9b119931c2fdadfa6dd19a8fc441218eb3f2aec4aa24ae3f90"
  }
}

provides = [
  "bin/addlicense",
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
mkdir -p "{{prefix}}/bin"
go build -ldflags "-s -w" -o "{{prefix}}/bin/addlicense" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf 'package p\n' > a.go
# -l mit writes the MIT text, -c and -y fill the holder and the year.
addlicense -c Acme -y 2024 -l mit a.go
grep -q 'Copyright (c) 2024 Acme' a.go
grep -q 'Permission is hereby granted' a.go
# -check passes on a headed file and fails on a bare one.
addlicense -check a.go
printf 'package q\n' > b.go
if addlicense -check b.go; then echo "-check accepted a file with no header"; exit 1; fi
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",         # :3 go 1.13, the two requirements
    "go.sum",         # the pin under -mod=readonly
    "LICENSE",        # :2-3 Apache License Version 2.0
    "main.go",        # :17 package main; the flags -c -y -l -check -ignore
    "README.md",      # the `go install` line and the usage
  ]

  note = <<EOT
pkgxdev/pantry was not consulted for facts beyond the binary name; the fragment
this replaces said only `provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v1.2.0 tarball (modules fetched from
proxy.golang.org under -mod=readonly), and every step of the test script: it
passed. The linux arms were not run.
EOT
}
