# github.com/hashicorp/hcl — the HashiCorp Configuration Language toolkit; this
# recipe installs `hclfmt`, the canonical formatter. A whole recipe, written
# from the project's own files at v2.25.0 (go-zpkg/packages#431, #440 step 1).
# Built as github.com/BurntSushi/toml is (its header says how and why: go.sum as
# the pin under -mod=readonly, GOPROXY without `,direct`, GOTOOLCHAIN=local,
# -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the module is github.com/hashicorp/hcl/v2 (go.mod:1), and the
# command is ./cmd/hclfmt in that same module (cmd/hclfmt/main.go:4
# `package main`). The project documents no build flags; hclfmt has a -version
# flag whose value is the constant "0.0.1-dev" (main.go:21), so nothing is
# stamped. go.mod:3
# says `go 1.25.0`. Not installed: hcldec and hclspecsuite (cmd/), not in
# `provides`.

summary = "HCL configuration language formatter (hclfmt)"

# LICENSE:1-3 "Copyright IBM Corp. 2014, 2026 / Mozilla Public License, version
# 2.0". The hclfmt binary COMPILES IN, per `go list -deps ./cmd/hclfmt`, modules
# whose licences were read from the module cache:
#
#   MIT           zclconf/go-cty v1.19.0, apparentlymart/go-textseg v15 and
#                 v17, mitchellh/go-wordwrap v1.0.1
#   Apache-2.0    agext/levenshtein v1.2.1
#   BSD-3-Clause  golang.org/x/text v0.31.0, golang.org/x/sys v0.38.0,
#                 golang.org/x/term v0.37.0, google/go-cmp v0.6.0
license = "MPL-2.0 AND Apache-2.0 AND BSD-3-Clause AND MIT"

versions {
  github = "hashicorp/hcl"
}

distributable {
  # GitHub's archive of the tag: the release lists no source asset.
  url              = "https://github.com/hashicorp/hcl/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 465059 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.25.0" = "a2cc385ada570cea4e623c4e7eae862e1a920482e91fb08d24590fc1c546e8d1"
  }
}

provides = [
  "bin/hclfmt",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/hclfmt" ./cmd/hclfmt
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf 'a   =   1\n' > t.hcl
# Without -w it prints the formatted file.
hclfmt t.hcl > out.hcl
grep -q '^a = 1$' out.hcl
# -require-no-change fails on the unformatted file ...
if hclfmt -require-no-change t.hcl; then echo "unformatted file accepted"; exit 1; fi
# ... and -w makes the file formatted, so it then passes.
hclfmt -w t.hcl
hclfmt -require-no-change t.hcl
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                # :1 module .../hcl/v2, :3 go 1.25.0
    "go.sum",                # the pin under -mod=readonly
    "LICENSE",               # :1-3 IBM copyright, Mozilla Public License 2.0
    "cmd/hclfmt/main.go",    # :4 package main; the flags -check -require-no-change -version -w
    "Makefile",              # the project's own targets
  ]

  note = <<EOT
pkgxdev/pantry was not consulted; the fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v2.25.0 tarball (modules fetched from
proxy.golang.org under -mod=readonly), and every step of the test script: it
passed. The linux arms were not run.
EOT
}
