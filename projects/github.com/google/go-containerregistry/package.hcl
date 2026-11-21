# github.com/google/go-containerregistry — `crane`, the command-line client for
# container registries. A whole recipe, written from the project's own files at
# v0.22.1 (go-zpkg/packages#431, #440 step 1). Built as github.com/BurntSushi/toml
# is (its header says how and why: go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# The project's own release recipe is .goreleaser.yml: build id `crane`, main
# ./cmd/crane/main.go, CGO_ENABLED=0, -trimpath, and the ldflags `-s -w` plus
# `-X github.com/google/go-containerregistry/cmd/crane/cmd.Version={{.Version}}`
# and the same for pkg/v1/remote/transport.Version. This recipe passes the same
# four flags with the version in place, so `crane version` prints the release.
# (Without them cmd/crane/cmd/version.go falls back to the module version,
# which a tarball build reports as `(devel)`.)
#
# The tree also carries a vendor/ directory; the build ignores it and reads the
# modules from go.sum like the others of this family. go.mod:8 says `go 1.25.0`
# and :10 `toolchain go1.26.6`: GOTOOLCHAIN=local accepts any local go.dev at or
# above the `go` line, and go.dev ^1.27 is.
#
# Only crane is installed. gcrane and krane (cmd/) pull in cloud-provider
# modules and are not in `provides`.

summary = "Command-line client for container registries (crane)"

# LICENSE:2-3 "Apache License Version 2.0". The crane binary COMPILES IN, per
# `go list -deps ./cmd/crane`, modules whose licences were read from the module
# cache:
#
#   Apache-2.0    docker/cli v29.7.2, spf13/cobra v1.10.2,
#                 opencontainers/go-digest v1.0.0 and image-spec v1.1.1
#   MIT           docker/docker-credential-helpers v0.9.3, sirupsen/logrus
#                 v1.9.4
#   BSD-3-Clause  golang.org/x/sync, golang.org/x/sys, spf13/pflag,
#                 google/go-cmp
#   BSD-3-Clause AND MIT AND Apache-2.0  klauspost/compress v1.19.2 (its LICENSE
#                 is the Go Authors' text; subdirectories carry MIT and Apache)
license = "Apache-2.0 AND BSD-3-Clause AND MIT"

versions {
  github = "google/go-containerregistry"
}

distributable {
  # GitHub's archive of the tag: the release lists only the tag, no assets this
  # recipe uses.
  url              = "https://github.com/google/go-containerregistry/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 4749677 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.22.1" = "a52cc7d61f8b2f043b7f0be1febecead5fceb791543c4790d699440f12d6b370"
  }
}

provides = [
  "bin/crane",
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
go build -ldflags "-s -w -X github.com/google/go-containerregistry/cmd/crane/cmd.Version={{version.raw}} -X github.com/google/go-containerregistry/pkg/v1/remote/transport.Version={{version.raw}}" -o "{{prefix}}/bin/crane" ./cmd/crane
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
test "$(crane version)" = "{{version.raw}}"
# Offline: append a layer to the empty base into a tarball, then validate it.
printf 'hello\n' > hello.txt
tar -cf layer.tar hello.txt
crane append -f layer.tar -t example.com/x:1 -o img.tar
crane validate --tarball img.tar
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",              # :8 go 1.25.0, :10 toolchain go1.26.6
    "go.sum",              # the pin under -mod=readonly
    "LICENSE",             # :2-3 Apache License Version 2.0
    ".goreleaser.yml",     # :3-15 the crane build: main, flags, ldflags
    "cmd/crane/main.go",   # :15 package main
    "cmd/crane/cmd/version.go", # :24-26 Version "can be set via" -ldflags -X
    "cmd/crane/README.md", # :57 the `go install` line
  ]

  note = <<EOT
pkgxdev/pantry was not consulted; the fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second host.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against the unpacked v0.22.1 tarball (modules fetched from
proxy.golang.org under -mod=readonly; the version placeholder in the build and
test lines replaced by 0.22.1 by hand), and every step of the test script: it passed. The linux arms
were not run.
EOT
}
