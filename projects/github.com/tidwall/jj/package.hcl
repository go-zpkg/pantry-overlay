# github.com/tidwall/jj — JSON Stream Editor: reads, writes and edits JSON by
# key path from the command line. A whole recipe, written from the project's own
# files at v1.9.2 (go-zpkg/packages#440 step 1). Built as
# github.com/fatih/gomodifytags is (go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: the command is ./cmd/jj (scripts/build.sh:46
# `go build -ldflags "-X main.version=$VERSION" -o jj cmd/jj/*.go`), not the
# module root. cmd/jj/main.go:17 declares `version = "0.0.1"` as a variable, and
# scripts/build.sh:9 sets VERSION="1.9.2" for the release, so this recipe stamps
# main.version with the recipe's version, as the project's own script does.
# go.mod:3 says `go 1.15`.

summary = "JSON stream editor: read and edit JSON by key path"

# LICENSE:1-3 "The MIT License (MIT) / Copyright (c) 2016 Josh Baker". The binary
# COMPILES IN six modules (`go list -deps ./cmd/jj`), each licence read from the
# module's own file in the module cache:
#
#   MIT           mattn/go-isatty v0.0.14, tidwall/{gjson v1.14.0, match v1.1.1,
#                 pretty v1.2.0, sjson v1.2.4}
#   BSD-3-Clause  golang.org/x/sys v0.0.0-20210630005230-0f9fa26af87c
license = "BSD-3-Clause AND MIT"

versions {
  github = "tidwall/jj"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries.
  url              = "https://github.com/tidwall/jj/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 11289 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "1.9.2" = "a3dafa9f2182bf79f26cdca790ff7106ebc02a50bd72bcc2db58bdbc39ee052f"
  }
}

provides = [
  "bin/jj",
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
go build -ldflags "-s -w -X main.version={{version.raw}}" -o "{{prefix}}/bin/jj" ./cmd/jj
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
echo '{"a":{"b":[1,2]}}' > in.json
# Read a value by key path.
test "$(jj -i in.json a.b.1)" = "2"
# Edit one: -v sets the value and the document comes back whole.
test "$(jj -i in.json -v 3 a.b.1)" = '{"a":{"b":[1,3]}}'
jj --version > ver.txt
grep -q 'JSON Stream Editor {{version.raw}}$' ver.txt
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",            # :1 module github.com/tidwall/jj, :3 go 1.15
    "go.sum",            # the pin under -mod=readonly
    "LICENSE",           # :1-3 MIT, Copyright (c) 2016 Josh Baker
    "scripts/build.sh",  # :9 VERSION="1.9.2", :46 the build line with -X main.version
    "cmd/jj/main.go",    # :17-18 version / tag, :126 the --version flag
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v1.9.2 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands:
`jj -i in.json a.b.1` printed 2, the edit printed {"a":{"b":[1,3]}} and
`--version` printed "jj - JSON Stream Editor 1.9.2". The linux arms were not run.
EOT
}
