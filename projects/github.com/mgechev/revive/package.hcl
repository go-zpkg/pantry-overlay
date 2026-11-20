# github.com/mgechev/revive — a fast, configurable Go linter, the replacement
# for golint. A whole recipe, written from the project's own files at v1.17.1
# (go-zpkg/packages#440 step 1). Built as github.com/fatih/gomodifytags is
# (go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the module root IS the command (main.go beside go.mod, deferring
# to cli/), so the package is `.`. .goreleaser.yml:11-17 builds with
# CGO_ENABLED=0 and stamps cli.version, cli.commit, cli.date and cli.builtBy;
# this recipe stamps cli.version (cli/main.go:27 var version = defaultVersion)
# only, the other three describing a commit and a builder this build has not
# got. go.mod:3 says `go 1.26.0`, hence go.dev ^1.27.

summary = "Fast, configurable linter for Go"

# LICENSE:1-3 "MIT License / Copyright (c) 2018 Minko Gechev". The binary
# COMPILES IN fourteen modules (`go list -deps .`), each licence read from the
# module's own file in the module cache:
#
#   MIT           codeberg.org/chavacava/garif v0.2.1, BurntSushi/toml v1.6.0,
#                 fatih/color v1.19.0, mattn/go-colorable v0.1.14,
#                 mattn/go-isatty v0.0.22, revive-lint/dots v1.1.0
#   BSD-3-Clause  fatih/structtag v1.2.0, golang.org/x/{mod,sync,sys,text,tools}
#   Apache-2.0    spf13/afero v1.15.0
#   MPL-2.0       hashicorp/go-version v1.9.0
license = "Apache-2.0 AND BSD-3-Clause AND MIT AND MPL-2.0"

versions {
  github = "mgechev/revive"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries and
  # a checksums.txt over THOSE, not over the source.
  url              = "https://github.com/mgechev/revive/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 906467 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "1.17.1" = "52782382c491aacbf2074df09cbd2e5105c3c0c4fac44b3e273f616068a51d75"
  }
}

provides = [
  "bin/revive",
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
go build -ldflags "-s -w -X github.com/mgechev/revive/cli.version=v{{version.raw}}" -o "{{prefix}}/bin/revive" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf 'module m\n\ngo 1.21\n' > go.mod
printf 'package m\n\nfunc Foo() {}\n' > p.go
# The default config reports an exported function with no comment.
revive ./... > out.txt
grep -q 'exported function Foo should have comment or be unexported' out.txt
revive -version | grep -q 'v1\.17\.1'
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",            # :1 module github.com/mgechev/revive, :3 go 1.26.0, :5-18 the requirements
    "go.sum",            # the pin under -mod=readonly
    "LICENSE",           # :1-3 MIT, Copyright (c) 2018 Minko Gechev
    "main.go",           # the command, deferring to cli/
    "cli/main.go",       # :27-30 version/commit/date/builtBy, :46 the -version flag, :172
    ".goreleaser.yml",   # :11 CGO_ENABLED=0, :12-17 the ldflags with the four -X
    "Makefile",          # :7 VERSION_FLAGS, :18 `go build -ldflags=`
    "AGENTS.md",         # §3 the build is `make build`
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v1.17.1 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands: revive
reported "exported function Foo should have comment or be unexported" and
`-version` printed "Version: v1.17.1". The linux arms were not run.
EOT
}
