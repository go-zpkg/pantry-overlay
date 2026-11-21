# github.com/itchyny/json2yaml — converts JSON to YAML. A whole recipe, written from the project's own files
# at v0.1.5 (go-zpkg/packages#431, #440 step 1). Built as
# github.com/BurntSushi/toml is (its header says how and why: GOPROXY without
# `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
# This module has NO dependencies (go.mod requires nothing and go.sum is
# empty), so the build fetches nothing and -mod=readonly has nothing to check.
#
# The project's own build is the Makefile: BUILD_LDFLAGS (:5) is
# `-s -w -X main.revision=$(CURRENT_REVISION)` and the build line (:13) is
# `go build -ldflags=$(BUILD_LDFLAGS) -o json2yaml ./cmd/json2yaml`. This recipe
# passes `-s -w` and leaves `revision` at its default "HEAD": the revision is a
# git commit hash and the tag tarball has no .git. The version itself is a
# constant (cmd/json2yaml/main.go:15). go.mod:3 says `go 1.24`.

summary = "Convert JSON to YAML"

# LICENSE:1-3 "The MIT License (MIT) Copyright (c) 2022-2026 itchyny". No
# module is compiled in besides this one.
license = "MIT"

versions {
  github = "itchyny/json2yaml"
}

distributable {
  # GitHub's archive of the tag: the release's assets are the project's own
  # binaries, not a source tarball.
  url              = "https://github.com/itchyny/json2yaml/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 10089 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.1.5" = "eafee825469155ff60156b23c0ab77a452be93359d975128ce164e515bf344f6"
  }
}

provides = [
  "bin/json2yaml",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/json2yaml" ./cmd/json2yaml
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
json2yaml --version > v.txt
grep -q 'json2yaml {{version.raw}} ' v.txt
echo '{"a":[1,2]}' > in.json
json2yaml in.json > out.yaml
grep -q '^a:$' out.yaml
grep -q '^  - 1$' out.yaml
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                  # :3 go 1.24, no requirements
    "go.sum",                  # empty
    "LICENSE",                 # :1-3 The MIT License (MIT)
    "Makefile",                # :5 BUILD_LDFLAGS, :13 the build line
    "cmd/json2yaml/main.go",   # :15 const version, :17 var revision, :45 -version
    "README.md",               # :56 the `go install` line
  ]

  note = <<EOT
pkgxdev/pantry was not consulted; the fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v0.1.5 tarball, and every step of the test script
with the version placeholder replaced by 0.1.5 by hand: it passed. The linux
arms were not run.
EOT
}
