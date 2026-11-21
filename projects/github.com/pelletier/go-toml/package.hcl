# github.com/pelletier/go-toml — a TOML library for Go; the repository's
# commands are tomll (linter), tomljson (TOML to JSON) and jsontoml. A whole
# recipe, written from the project's own files at v2.4.3 (go-zpkg/packages#440
# step 1). Built as github.com/fatih/gomodifytags is (go.sum as the pin under
# -mod=readonly, GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath,
# -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the module is github.com/pelletier/go-toml/v2 (go.mod:1) and its
# commands sit under cmd/. THE FRAGMENT THIS REPLACES NAMED ONE BINARY,
# bin/tomljson, and this recipe keeps that scope: package ./cmd/tomljson. The
# other two (./cmd/tomll, ./cmd/jsontoml) are built the same way by
# .goreleaser.yaml:8-10 and :46-48, and are left to a later change.
# .goreleaser.yaml:15-16 passes `-X main.version=... main.commit=... main.date=...`
# to each; tomljson declares no such variable (no `version` in cmd/tomljson),
# so nothing is stamped. go.mod:3 says `go 1.21.0`.

summary = "Convert TOML to JSON"

# LICENSE:1-4 "The MIT License (MIT) / go-toml v2 / Copyright (c) 2021 - 2023
# Thomas Pelletier". The binary compiles in no other module: `go list -deps
# ./cmd/tomljson` names only this module's own packages and the standard
# library, so the licence is the project's alone.
license = "MIT"

versions {
  github = "pelletier/go-toml"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries (and
  # a sha256sums.txt over THOSE), not source.
  url              = "https://github.com/pelletier/go-toml/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 985933 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.4.3" = "0778701c7c7d3261510da7f622c20bfc17c204c80134c1e032aacc99e14c8b35"
  }
}

provides = [
  "bin/tomljson",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/tomljson" ./cmd/tomljson
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf '[t]\nx = 1\n' > in.toml
tomljson in.toml > out.json
grep -q '"t": {' out.json
grep -q '"x": 1' out.json
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",              # :1 module github.com/pelletier/go-toml/v2, :3 go 1.21.0
    "go.sum",              # the pin under -mod=readonly
    "LICENSE",             # :1-4 The MIT License (MIT), go-toml v2, Thomas Pelletier
    ".goreleaser.yaml",    # :8-10 :27-29 :46-48 the three commands, :15-16 the ldflags
    "AGENTS.md",           # the project's contribution rules; no build recipe
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v2.4.3 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands: a
two-line TOML file came out as {"t": {"x": 1}}. The linux arms were not run.
EOT
}
