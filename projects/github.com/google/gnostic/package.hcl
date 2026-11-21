# github.com/google/gnostic — compiles OpenAPI v2/v3 and Discovery descriptions
# into a protocol-buffer model and runs plugins over it. A whole recipe, written
# from the project's own files at v0.7.1 (go-zpkg/packages#431, #440 step 1).
# Built as github.com/BurntSushi/toml is (its header says how and why: go.sum as
# the pin under -mod=readonly, GOPROXY without `,direct`, GOTOOLCHAIN=local,
# -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the module root IS the `gnostic` command (gnostic.go:32
# `package main`, beside go.mod), so the package is `.`. The top-level Makefile
# runs `go install ./...`, which also builds the plugin and report programs
# under cmd/; only the one in `provides` is built here. Nothing is stamped: the
# program states no version variable. The protobuf code is generated and
# committed, so no `protoc` runs at build time. go.mod:3 says `go 1.24.6`.

summary = "Compile OpenAPI and Discovery descriptions into a protobuf model"

# LICENSE:2-3 "Apache License Version 2.0". The binary COMPILES IN, per
# `go list -deps .`, modules whose licences were read from the module cache:
#
#   Apache-2.0    github.com/google/gnostic-models
#   BSD-3-Clause  google.golang.org/protobuf v1.36.7, github.com/golang/protobuf
#                 v1.5.4
#   MIT / Apache  go.yaml.in/yaml/v3 v3.0.4 (its LICENSE carries both texts: MIT
#                 for the code ported from libyaml, Apache-2.0 for the rest)
license = "Apache-2.0 AND BSD-3-Clause AND MIT"

versions {
  github = "google/gnostic"
}

distributable {
  # GitHub's archive of the tag: v0.7.1 is a tag with no release (the
  # releases list stops at v0.7.0), so there are no assets.
  url              = "https://github.com/google/gnostic/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 423939 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.7.1" = "9d8fd682ef0f92a58705afb76bf9f5baa8f2df36f1863b1ce33de5a24c04ec5c"
  }
}

provides = [
  "bin/gnostic",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/gnostic" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
cat > spec.json <<'SPEC'
{"openapi":"3.0.0","info":{"title":"t","version":"1"},"paths":{}}
SPEC
# Compile the description and write its text-proto form.
gnostic spec.json --text-out=out.txt
grep -q 'title: "t"' out.txt
gnostic --help > help.txt 2>&1
grep -q 'Usage: gnostic SOURCE' help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",         # :3 go 1.24.6, the requirements
    "go.sum",         # the pin under -mod=readonly
    "LICENSE",        # :2-3 Apache License Version 2.0
    "gnostic.go",     # :32 package main; the options listed by --help
    "Makefile",       # :5 `go install ./...`
    "README.md",      # :61 Installation and Getting Started
  ]

  note = <<EOT
pkgxdev/pantry was not consulted; the fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v0.7.1 tarball (modules fetched from
proxy.golang.org under -mod=readonly), and every step of the test script: it
passed. The linux arms were not run. (go.sum is 62 lines.)
EOT
}
