# github.com/BurntSushi/toml — a TOML parser and encoder for Go, with `tomlv`,
# the validator. A whole recipe, written from the project's own files at v1.6.0
# (go-zpkg/packages#431, #440 step 1); the upstream pantry's cannot be merged
# underneath any more.
#
# ⭐ HOW THE GO RECIPES OF THIS FAMILY BUILD (stated once, here; the others in
# this batch say "as BurntSushi/toml"):
#
#   - `go build` inside the tag tarball, with go.mod and go.sum as the
#     dependency pin. go.sum records the hash of every module the build reads;
#     `-mod=readonly` makes a missing or wrong line an ERROR, where the default
#     for a build would be to add it. This module has NO dependencies at all
#     (go.mod: `module github.com/BurntSushi/toml` and `go 1.18`, nothing
#     required, no go.sum, no vendor/), so the build fetches nothing; the
#     recipes below that do require modules fetch them from proxy.golang.org
#     only (GOPROXY has no `,direct`) and check each against go.sum.
#   - GOTOOLCHAIN=local: a go.mod that wanted a newer Go would fail, not
#     download one behind the factory's back.
#   - -trimpath and -buildvcs=false: the tarball has no .git, so there is
#     nothing to stamp, and no builder path ends up in the binary.
#   - CGO_ENABLED=0, because a program that does not link C should not pick up
#     whichever C compiler the builder has (cmd/go turns cgo on by itself when
#     one is on PATH).
#
# This project states no version variable and tomlv has no --version flag, so
# nothing is stamped; `go version -m` reports the main module as (devel).

summary = "TOML parser and encoder for Go, and the tomlv validator"

# COPYING:1-3 "The MIT License (MIT) Copyright (c) 2013 TOML authors". It is the
# only licence file in the tree.
license = "MIT"

versions {
  github = "BurntSushi/toml"
}

distributable {
  # GitHub's archive of the tag: the release has no assets (the API lists none).
  url              = "https://github.com/BurntSushi/toml/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 142004 bytes. ⚠ NOT SIGNED: the tag's commit 52534926 carries no signature
  # this session verified, and GitHub's archive has no project-published
  # checksum. Fetched twice, from github.com/…/archive and from
  # codeload.github.com, and the two digests agree.
  sha256 = {
    "1.6.0" = "eecda85357b0df8b623191a027de3ce43282cceb403f412200a6c5f9776b2098"
  }
}

# cmd/tomlv/main.go is the validator. cmd/toml-test-decoder and
# cmd/toml-test-encoder are the harness binaries for the toml-test suite: not
# installed, and not in the package's provides.
provides = [
  "bin/tomlv",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/tomlv" ./cmd/tomlv
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf 'title = "x"\n\n[owner]\nport = 8080\n' > ok.toml
# -types prints each key and the TOML type it parsed as (cmd/tomlv/main.go:88-95).
tomlv -types ok.toml > types.txt
grep -q 'port.*Integer' types.txt
grep -q 'title.*String' types.txt
# -json re-emits the document (main.go:80-85).
tomlv -json ok.toml > out.json
grep -q '"port": 8080' out.json
# A document that is not TOML is refused with a non-zero status (log.Fatalf).
printf 'title = \n' > bad.toml
if tomlv bad.toml 2> err.txt; then
  echo "tomlv accepted a document with no value" >&2
  exit 1
fi
grep -q "bad.toml" err.txt
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                        # `module github.com/BurntSushi/toml`, `go 1.18`, no requirements
    "COPYING",                       # :1-3 the MIT licence
    "cmd/tomlv/main.go",             # :26-33 the flags, :40-55 files or stdin, :88-95 the -types output
    "cmd/",                          # tomlv, toml-test-decoder, toml-test-encoder: three commands
    ".github/workflows/test.yml",    # the project's own CI invocation
  ]

  note = <<EOT
⚠ The fragment this replaces said only `provides = ["bin/tomlv"]`, "a
wasm32-wasip1 module", and nothing about source or build. Nothing of that is
kept except the provides. pkgxdev/pantry carries no recipe for this project
(projects/github.com/BurntSushi/toml/package.yml answers 404), so nothing was
consulted there.

⚠ THE SOURCE RUNG, STATED. See distributable: a generated archive of an
unsigned tag, confirmed by a second host. The digest is the durable pin.

⛔ NOT BUILT BY THE FACTORY. No session here can run it. What WAS run: the
build line and the test script, on darwin/arm64 with go1.27.4, against the
unpacked v1.6.0 tarball, with this recipe's GOFLAGS, GOPROXY and CGO_ENABLED:
it built and the test passed. The linux arms and the factory's environment
were not.
EOT
}
