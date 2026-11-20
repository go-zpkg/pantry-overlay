# github.com/golangci/misspell — finds and corrects commonly misspelled English
# words in source files. A whole recipe, written from the project's own files at
# v0.8.0 (go-zpkg/packages#431, #440 step 1). Built as github.com/BurntSushi/toml
# is (its header says how and why: go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: goreleaser.yml:4, :6 and :15 are the project's own build: the
# package cmd/misspell/main.go, `-s -w -X main.version={{.Version}}`,
# CGO_ENABLED=0 — matched here, with the version stamped. goreleaser's
# {{.Version}} has no leading `v`, and neither has {{version.raw}}. The word
# lists (words.go, words_us.go, words_uk.go) are COMMITTED output of
# `go run ./internal/gen/` (Makefile:17 `generate`); this recipe does not
# regenerate them.
#
# ⚠ THE ONE MODULE IN go.mod (:5), github.com/gobwas/glob v0.2.3, is imported
# only by the `ignore` package (ignore/glob.go), which cmd/misspell does not
# link (`go list -deps ./cmd/misspell` names no module outside the standard
# library), so the binary is the standard library plus this module's own
# packages.

summary = "Correct commonly misspelled English words in source files"

# LICENSE:1-3 "The MIT License (MIT) Copyright (c) 2015-2017 Nick Galbreath",
# and the only licence file in the tree.
license = "MIT"

versions {
  github = "golangci/misspell"
}

distributable {
  # GitHub's archive of the tag: the release lists 7 assets (the project's own
  # goreleaser binaries), none a source archive.
  url              = "https://github.com/golangci/misspell/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 396930 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.8.0" = "b54e4975a3756465d4bd95a373c6953d3e292edb0581fb066648cc394024f817"
  }
}

provides = [
  "bin/misspell",
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
go build -ldflags "-s -w -X main.version={{version.raw}}" -o "{{prefix}}/bin/misspell" ./cmd/misspell
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
# cmd/misspell/main.go:43 holds the version, :71 and :78-79 print it with -v.
test "$(misspell -v)" = "{{version.raw}}"
printf 'this is teh answer\n' > bad.txt
printf 'this is the answer\n' > ok.txt
misspell -error ok.txt
# -error exits non-zero when it finds a misspelling, and names it.
if misspell -error bad.txt > out.txt 2>&1; then
  echo "misspell -error accepted a misspelling" >&2
  exit 1
fi
grep -q '"teh" is a misspelling of "the"' out.txt
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                        # :3 go 1.23.0, :5 the one requirement (gobwas/glob v0.2.3)
    "go.sum",                        # the pin under -mod=readonly
    "LICENSE",                       # :1-3 MIT
    "goreleaser.yml",                # :4 main, :6 the ldflags with -X main.version, :15 CGO_ENABLED=0
    "Makefile",                      # :17 `generate`: go run ./internal/gen/, the word lists' source
    "cmd/misspell/main.go",          # :43 `var version = "dev"`, :71 -v, :78-79 the output
    "ignore/glob.go",                # the only importer of gobwas/glob
  ]

  note = <<EOT
pkgxdev/pantry carries no recipe for this project (projects/github.com/golangci/
misspell/package.yml answers 404), so nothing was consulted there; the fragment
this replaces said only `provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line and the test script on
darwin/arm64 with go1.27.4 against the unpacked v0.8.0 tarball: `misspell -v`
printed 0.8.0, `misspell -error` exited 2 on a misspelling and 0 on clean text.
The linux arms were not.
EOT
}
