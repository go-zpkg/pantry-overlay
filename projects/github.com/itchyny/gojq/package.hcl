# github.com/itchyny/gojq — a pure Go implementation of jq. A whole recipe,
# written from the project's own files at v0.12.20 (go-zpkg/packages#431, #440
# step 1). Built as github.com/BurntSushi/toml is (its header says how and why:
# go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# The project's own build is the Makefile: BUILD_LDFLAGS (:5) is
# `-s -w -X github.com/itchyny/gojq/cli.revision=$(CURRENT_REVISION)` and the
# build line (:14) is `go build -ldflags=$(BUILD_LDFLAGS) -o gojq ./cmd/gojq`.
# This recipe passes `-s -w` and leaves `revision` at its default: the revision
# is a git commit hash and the tag tarball has no .git, so `gojq --version`
# prints `gojq 0.12.20 (rev: HEAD/go…)`. The version itself is a constant
# (cli/cli.go:20). The build is the default one: the Makefile's `gojq_debug`
# tag (:22) is for debugging and is not used. go.mod:3 says `go 1.24.0`.

summary = "Pure Go implementation of jq"

# LICENSE:1-3 "The MIT License (MIT) Copyright (c) 2019-2026 itchyny". The
# binary COMPILES IN, per `go list -deps ./cmd/gojq`, modules whose licences
# were read from the module cache:
#
#   Apache-2.0    itchyny/go-yaml (a fork; its LICENSE is the Apache text)
#   MIT           itchyny/timefmt-go v0.1.9, mattn/go-isatty v0.0.24,
#                 mattn/go-runewidth v0.0.31, clipperhouse/uax29 v2.7.0
#   BSD-3-Clause  golang.org/x/sys v0.41.0
license = "MIT AND Apache-2.0 AND BSD-3-Clause"

versions {
  github = "itchyny/gojq"
}

distributable {
  # GitHub's archive of the tag: the release's assets are the project's own
  # binaries, not a source tarball.
  url              = "https://github.com/itchyny/gojq/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 141471 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.12.20" = "7a52db203c779c88eea3ad70d6e7f10daac804e0def4198a5766a41bf6f00141"
  }
}

provides = [
  "bin/gojq",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/gojq" ./cmd/gojq
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
gojq --version > v.txt
grep -q 'gojq {{version.raw}} ' v.txt
echo '{"a":[1,2,3]}' > in.json
gojq -c '.a | map(. * 2)' in.json > out.txt
grep -q '^\[2,4,6\]$' out.txt
# --yaml-input reads YAML.
printf 'a: 1\n' > in.yaml
gojq --yaml-input -c . in.yaml > y.txt
grep -q '^{"a":1}$' y.txt
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",              # :3 go 1.24.0
    "go.sum",              # the pin under -mod=readonly
    "LICENSE",             # :1-3 The MIT License (MIT)
    "Makefile",            # :5 BUILD_LDFLAGS, :14 the build line, :22 gojq_debug
    "cli/cli.go",          # :20 const version, :22 var revision, :81 --version
    "README.md",           # :78 the `go install` line
  ]

  note = <<EOT
pkgxdev/pantry was not consulted; the fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v0.12.20 tarball (modules fetched from
proxy.golang.org under -mod=readonly), and every step of the test script with
the version placeholder replaced by 0.12.20 by hand: it passed. The linux arms were not run.
EOT
}
