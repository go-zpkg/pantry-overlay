# github.com/fatih/gomodifytags — adds, removes and rewrites struct field tags
# in Go source. A whole recipe, written from the project's own files at v1.17.0
# (go-zpkg/packages#431, #440 step 1). Built as github.com/BurntSushi/toml is
# (its header says how and why: go.sum as the pin under -mod=readonly, GOPROXY
# without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: the module root IS the command (main.go sits beside go.mod), so
# the package is `.`. The project documents no build flags and no release
# tooling (no Makefile, no goreleaser file), and the program has no version flag
# (`-version` is rejected by its flag set), so nothing is stamped. go.mod:28 says
# `go 1.13`; go.sum pins the three modules it requires.

summary = "Add, remove and rewrite struct tags in Go source"

# LICENSE:1-2 "Copyright (c) 2017, Fatih Arslan All rights reserved", the 3-clause
# BSD text (it carries the "Neither the name" clause). The binary COMPILES IN
# three modules (`go list -deps .`), each licence read from the module's own
# file in the module cache:
#
#   BSD-3-Clause  fatih/structtag v1.2.0 (the same "Fatih Arslan" 3-clause
#                 text), golang.org/x/tools v0.23.0
#   MIT           fatih/camelcase v1.0.0 (LICENSE.md)
license = "BSD-3-Clause AND MIT"

versions {
  github = "fatih/gomodifytags"
}

distributable {
  # GitHub's archive of the tag: the release lists no assets.
  url              = "https://github.com/fatih/gomodifytags/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 23562 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "1.17.0" = "a490786d80c962dc946b8f9804ffec596c1087dbf91b122b9b5903c03b6da6b9"
  }
}

provides = [
  "bin/gomodifytags",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/gomodifytags" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf 'package p\n\ntype S struct {\n\tFooBar string\n}\n' > t.go
# -add-tags json, with the default snake_case transform, rewrites the field.
gomodifytags -file t.go -struct S -add-tags json > out.go
grep -q 'FooBar string `json:"foo_bar"`' out.go
# -w writes the file in place instead of printing it.
gomodifytags -file t.go -struct S -add-tags json -transform camelcase -w -quiet
grep -q 'FooBar string `json:"fooBar"`' t.go
# -remove-tags undoes it (gofmt leaves a trailing space where the tag was).
gomodifytags -file t.go -struct S -remove-tags json -w -quiet
grep -q 'FooBar string *$' t.go
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                        # :28 go 1.13, :3-7 the three requirements
    "go.sum",                        # the pin under -mod=readonly
    "LICENSE",                       # :1-2 the 3-clause BSD text
    "main.go",                       # the command: flags, -file, -struct, -add-tags, -transform, -w
    ".github/workflows/go.yml",      # :17 `go-version: '>=1.22.0'`, the project's own CI
  ]

  note = <<EOT
pkgxdev/pantry carries no recipe for this project (projects/github.com/fatih/
gomodifytags/package.yml answers 404 on its contents API), so nothing was
consulted there; the fragment this replaces said only `provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v1.17.0 tarball (modules fetched from
proxy.golang.org under -mod=readonly), and every step of the test script: it
passed. The linux arms were not run.
EOT
}
