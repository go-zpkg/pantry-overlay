# github.com/mmarkdown/mmark — a powerful Markdown processor in Go for writing
# IETF documents (RFC 7749 XML) and man pages. A whole recipe, written from the
# project's own files at v2.2.48 (go-zpkg/packages#440 step 1). Built as
# github.com/fatih/gomodifytags is (go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: the module root IS the command (mmark.go sits beside go.mod), so
# the package is `.`. Makefile:10 builds with plain `CGO_ENABLED=0 go build`.
# The version is a variable assigned the release number in the source
# (version.go:4 `var Version = "2.2.48"`, printed by -version at mmark.go:50),
# so nothing is stamped; go.mod:3 says `go 1.21`.

summary = "Markdown processor for IETF documents and man pages"

# LICENSE:1 "Mmark is distributed under the Simplified BSD License", the
# 2-clause text (it has "Redistributions in binary form" and no "Neither the
# name" clause). The binary COMPILES IN two modules (`go list -deps .`), each
# licence read from the module's own file in the module cache:
#
#   BSD-2-Clause  gomarkdown/markdown (LICENSE.txt)
#   MIT           BurntSushi/toml v1.6.0 (COPYING)
license = "BSD-2-Clause AND MIT"

versions {
  github = "mmarkdown/mmark"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries and
  # a checksums file over THOSE, not over the source.
  url              = "https://github.com/mmarkdown/mmark/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 256336 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.2.48" = "8ab1295db3a9c1cdd353d4fc0f29daf1e6085b6e1989e30cd0348d0e17760bc1"
  }
}

provides = [
  "bin/mmark",
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
go build -ldflags "-s -w" -o "{{prefix}}/bin/mmark" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf '# Title\n\nHello.\n' > m.md
mmark -html m.md > out.html
grep -q '<h1 id="title">Title</h1>' out.html
grep -q '<p>Hello.</p>' out.html
mmark -version | grep -q '^2\.2\.48$'
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",         # :1 module github.com/mmarkdown/mmark/v2, :3 go 1.21, :6-7 the two requirements
    "go.sum",         # the pin under -mod=readonly
    "LICENSE",        # :1 "distributed under the Simplified BSD License", 2-clause text
    "mmark.go",       # :33 the -version flag, :50 it prints Version
    "version.go",     # :4 var Version = "2.2.48"
    "Makefile",       # :10 CGO_ENABLED=0 go build
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v2.2.48 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands:
`# Title` rendered as <h1 id="title">Title</h1> and `-version` printed 2.2.48.
The linux arms were not run.
EOT
}
