# mvdan.cc/xurls — extracts urls from text. Upstream repo is mvdan/xurls;
# mvdan's projects take the vanity host (the pantry already carries
# mvdan.cc/sh and mvdan.cc/gofumpt). A whole recipe, written from the project's
# own files at v2.6.0 (go-zpkg/packages#440 step 1). Built as
# github.com/fatih/gomodifytags is (go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: the module is mvdan.cc/xurls/v2 (go.mod:1, :3 `go 1.22.0`) and
# the command is ./cmd/xurls. cmd/xurls/main.go:34 declares `var version string`
# and :261-296 read it, then the module's build info, then a pseudo-version from
# VCS data; a tarball build has none of the latter, so this recipe stamps
# main.version. The tag is v2.6.0 and readVersion returns the string as given, so
# it is stamped WITH its `v`, as the stored release binaries are named.

summary = "Extract URLs from text"

# LICENSE:1 "Copyright (c) 2015, Daniel Martí. All rights reserved.", the
# 3-clause BSD text (it carries the "Neither the name" clause). The binary
# COMPILES IN two modules (`go list -deps ./cmd/xurls`), both BSD-3-Clause from
# the module's own LICENSE: golang.org/x/mod v0.22.0, golang.org/x/sync v0.10.0.
license = "BSD-3-Clause"

versions {
  github = "mvdan/xurls"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries and
  # a sha256sums.txt over THOSE, not over the source.
  url              = "https://github.com/mvdan/xurls/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 28122 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.6.0" = "476d92a0416fee965f928180a950691b85dbb8d11efc3dc7f795ecc106c76075"
  }
}

provides = [
  "bin/xurls",
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
go build -ldflags "-s -w -X main.version=v{{version.raw}}" -o "{{prefix}}/bin/xurls" ./cmd/xurls
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
echo 'see https://example.com/x and http://go.dev' > in.txt
xurls in.txt > out.txt
grep -qx 'https://example.com/x' out.txt
grep -qx 'http://go.dev' out.txt
test "$(xurls -version)" = "v{{version.raw}}"
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",            # :1 module mvdan.cc/xurls/v2, :3 go 1.22.0
    "go.sum",            # the pin under -mod=readonly
    "LICENSE",           # :1 Copyright (c) 2015, Daniel Martí, 3-clause BSD text
    "cmd/xurls/main.go", # :31 the -version flag, :34 var version, :216-217, :261-296 readVersion
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v2.6.0 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands: both
URLs of a sentence were extracted and `-version` printed v2.6.0. The linux
arms were not run.
EOT
}
