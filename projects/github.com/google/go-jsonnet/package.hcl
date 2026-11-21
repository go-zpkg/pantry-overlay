# github.com/google/go-jsonnet — the Go implementation of Jsonnet, a data
# templating language; this recipe installs its `jsonnet` interpreter. A whole
# recipe, written from the project's own files at v0.22.0 (go-zpkg/packages#431,
# #440 step 1). Built as github.com/BurntSushi/toml is (its header says how and
# why: go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# The project's release recipe is .goreleaser.yml: build id `jsonnet`, main
# ./cmd/jsonnet, CGO_ENABLED=0, no ldflags (:21-23). The version string the
# program prints is a constant in the source, so nothing is stamped. go.mod:3
# says `go 1.24.5`.
#
# Not installed: jsonnetfmt, jsonnet-lint and jsonnet-deps (the other builds of
# the same .goreleaser.yml) and cmd/wasm. They are not in `provides`.

summary = "Go implementation of the Jsonnet data templating language"

# LICENSE:2-3 "Apache License Version 2.0". The jsonnet binary COMPILES IN, per
# `go list -deps ./cmd/jsonnet`, modules whose licences were read from the
# module cache:
#
#   MIT           fatih/color v1.18.0, mattn/go-colorable v0.1.13,
#                 mattn/go-isatty v0.0.20
#   BSD-3-Clause  golang.org/x/sys v0.38.0, golang.org/x/crypto v0.45.0
#   Apache-2.0 / MIT / BSD-3-Clause  sigs.k8s.io/yaml v1.4.0 (its LICENSE
#                 carries all three; the forked goyaml.v2/v3 directories keep
#                 theirs)
license = "Apache-2.0 AND BSD-3-Clause AND MIT"

versions {
  github = "google/go-jsonnet"
}

distributable {
  # GitHub's archive of the tag: the release's assets are the project's own
  # binaries, not a source tarball.
  url              = "https://github.com/google/go-jsonnet/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 761437 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.22.0" = "9c463043a05c1e833c57136521e808ee8df192131f00c636235a2b54823d8c4c"
  }
}

provides = [
  "bin/jsonnet",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/jsonnet" ./cmd/jsonnet
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
jsonnet --version > v.txt
grep -q 'v{{version.raw}}' v.txt
jsonnet -e '{a: 1 + 2}' > out.json
grep -q '"a": 3' out.json
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",              # :3 go 1.24.5
    "go.sum",              # the pin under -mod=readonly
    "LICENSE",             # :2-3 Apache License Version 2.0
    ".goreleaser.yml",     # :21-23 the jsonnet build: main ./cmd/jsonnet, CGO_ENABLED=0
    "cmd/jsonnet/cmd.go",  # :17 package main; :34 version(), :177 -v/--version
    "README.md",           # :30 the `go install` line
  ]

  note = <<EOT
pkgxdev/pantry was not consulted; the fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v0.22.0 tarball (modules fetched from
proxy.golang.org under -mod=readonly), and the evaluation steps of the test
script with the version placeholder replaced by 0.22.0 by hand: it passed. The
linux arms were not run.
EOT
}
