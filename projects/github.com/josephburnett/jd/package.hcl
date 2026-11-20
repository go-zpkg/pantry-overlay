# github.com/josephburnett/jd — diffs and patches JSON and YAML values in a
# human-readable format. A whole recipe, written from the project's own files
# at v2.5.0 (go-zpkg/packages#440 step 1). Built as github.com/fatih/gomodifytags
# is (go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the repository holds TWO modules. The root module
# github.com/josephburnett/jd (main.go, go.mod:3 `go 1.24.0`) is the DEPRECATED
# v1 command (main.go:20 "this is the v1 main.go. It is no longer being
# developed"; main.go:23 version = "deprecated"). The command the project ships is
# v2/jd, in module github.com/josephburnett/jd/v2 (v2/go.mod): Makefile:37 builds
# `cd v2/jd ; CGO_ENABLED=0 go build -tags include_web ... main.go`, and
# CLAUDE.md names /v2/jd/main.go "V2 commandline". This recipe builds that one.
#
# `-tags include_web` is NOT passed: it embeds the web UI, whose assets
# (internal/web/assets/jd.wasm) come from a GOOS=js build (Makefile:103) and are
# not in the tag (v2/internal/web/assets holds only index.html). Without the tag v2/internal/web/serve/serve.go:1 (`//go:build
# include_web`) is left out and the command is the plain CLI. The version is a
# constant (v2/jd/main.go:21 `const version = "2.5.0"`), so nothing is stamped.

summary = "Diff and patch JSON and YAML values"

# LICENSE:1-3 "MIT License / Copyright (c) 2016 Joseph Burnett". The binary
# COMPILES IN one module besides the standard library (`go list -deps ./jd` in
# v2/): go.yaml.in/yaml/v3 v3.0.4, whose LICENSE:2 says "covered by two different
# licenses: MIT and Apache" (the libyaml-derived files are MIT, the rest Apache-2.0).
license = "Apache-2.0 AND MIT"

versions {
  github = "josephburnett/jd"
}

distributable {
  # GitHub's archive of the tag. The release does list assets, but they are the
  # project's prebuilt binaries (jd-amd64-linux …), not source.
  url              = "https://github.com/josephburnett/jd/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 2277190 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.5.0" = "f4d141122ad91d1e7628e9cfee95ca183113e144872cce61f6d3d56449efa19b"
  }
}

provides = [
  "bin/jd",
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
cd v2
go build -ldflags "-s -w" -o "{{prefix}}/bin/jd" ./jd
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
echo '{"a":1}' > a.json
echo '{"a":2}' > b.json
# Exit status 1 means "the inputs differ"; 0 would mean they are equal.
rc=0
jd a.json b.json > diff.txt || rc=$?
test "$rc" -eq 1
grep -q '^- 1$' diff.txt
grep -q '^+ 2$' diff.txt
# -f merge writes the diff as an RFC 7386 merge patch.
jd -f merge a.json b.json > merge.json || true
grep -q '{"a":2}' merge.json
jd -version | grep -q '2\.5\.0'
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                 # :1 module github.com/josephburnett/jd, :3 go 1.24.0, :20 replace => ./v2
    "main.go",                # :20 "this is the v1 main.go. It is no longer being developed", :23 version = "deprecated"
    "v2/go.mod",              # :1 module .../jd/v2, :3 go 1.24.0, :9 the only non-test requirement
    "v2/go.sum",              # the pin under -mod=readonly
    "v2/jd/main.go",          # :21 const version = "2.5.0", :37 the -version flag
    "v2/internal/web/serve/serve.go", # :1 //go:build include_web
    "Makefile",               # :37 the release build, :103 the wasm build behind include_web
    "LICENSE",                # :1-3 MIT, Copyright (c) 2016 Joseph Burnett
    "CLAUDE.md",              # File Structure: /v2/jd/main.go is the V2 commandline
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v2.5.0 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands: `-version`
printed "jd version 2.5.0", the diff exited 1 and printed "- 1" / "+ 2". The
linux arms were not run.
EOT
}
