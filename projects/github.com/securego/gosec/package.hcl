# github.com/securego/gosec — inspects Go source for security problems by
# scanning the AST and the SSA form. A whole recipe, written from the project's
# own files at v2.30.0 (go-zpkg/packages#440 step 1). Built as
# github.com/fatih/gomodifytags is (go.sum as the pin under -mod=readonly,
# GOPROXY without `,direct`, GOTOOLCHAIN=local, -trimpath, -buildvcs=false,
# CGO_ENABLED=0).
#
# Per project: the module is github.com/securego/gosec/v2 (go.mod:1, :68
# `go 1.26.0`) and the command is ./cmd/gosec (.goreleaser.yml:13
# `main: ./cmd/gosec/`, CLAUDE.md "go build ./cmd/gosec/"). .goreleaser.yml:24
# stamps main.Version, main.GitTag and main.BuildDate (cmd/gosec/version.go:4-10);
# this recipe stamps Version and GitTag and leaves BuildDate empty, since a
# date would make the binary differ run to run. Unstamped, Version falls back
# to "dev" (version.go:17-22).
#
# gosec LOADS and type-checks the code it scans through the Go toolchain, so at
# run time it needs `go` on PATH: the go.dev dependency is declared for the
# run, not only the build.

summary = "Security checker for Go source code"

# LICENSE.txt, the Apache License, Version 2.0. The binary COMPILES IN
# forty-eight modules (`go list -deps ./cmd/gosec`; the optional AI-autofix code links the
# Anthropic, OpenAI and Google GenAI SDKs and their Google/OpenTelemetry/gRPC
# trees), each licence read from the module's own file in the module cache:
#
#   Apache-2.0    cloud.google.com/go{,/auth,/compute/metadata}, go-logr/{logr,stdr},
#                 google/s2a-go, googleapis/enterprise-certificate-proxy,
#                 openai/openai-go/v3, pb33f/{go-yaml,ordered-map/v2},
#                 go.opentelemetry.io/*, go.yaml.in/yaml/v3 (MIT AND Apache-2.0),
#                 google.golang.org/{genai,genproto/googleapis/rpc,grpc}
#   BSD-3-Clause  bahlo/generic-list-go, google/{go-cmp,uuid},
#                 googleapis/gax-go/v2, golang.org/x/*, google.golang.org/{api,protobuf}
#   BSD-2-Clause  gorilla/websocket
#   ISC           coder/websocket
#   MIT           anthropics/anthropic-sdk-go, buger/jsonparser, ccojocar/zxcvbn-go,
#                 cespare/xxhash/v2, felixge/httpsnoop, gookit/color, invopop/jsonschema,
#                 standard-webhooks/libraries, tidwall/{gjson,match,pretty,sjson},
#                 xo/terminfo
license = "Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND ISC AND MIT"

versions {
  github = "securego/gosec"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries,
  # each with a sigstore bundle over THAT binary, not over the source.
  url              = "https://github.com/securego/gosec/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 419234 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.30.0" = "58ad3a584453ad31f0b646818bcd1cc005afd20ef507d71cd41821fbba506332"
  }
}

provides = [
  "bin/gosec",
]

# Run time: gosec shells out to `go` to load packages.
dependencies = {
  "go.dev" = "^1.27"
}

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
go build -ldflags "-s -w -X main.Version={{version.raw}} -X main.GitTag=v{{version.raw}}" -o "{{prefix}}/bin/gosec" ./cmd/gosec
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
printf 'package m\n\nimport "crypto/md5"\n\nfunc Foo() []byte {\n\th := md5.New()\n\treturn h.Sum(nil)\n}\n' > p.go
# Exit status 1 means "issues found".
rc=0
gosec -fmt text -quiet ./... > out.txt || rc=$?
test "$rc" -eq 1
grep -q 'G401 (CWE-328): Use of weak cryptographic primitive' out.txt
grep -q 'G501 (CWE-327): Blocklisted import crypto/md5' out.txt
gosec -version > ver.txt
grep -q '^Version: {{version.raw}}$' ver.txt
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",                  # :1 module github.com/securego/gosec/v2, :68 go 1.26.0
    "go.sum",                  # the pin under -mod=readonly
    "LICENSE.txt",             # the Apache License, Version 2.0
    ".goreleaser.yml",         # :13 main: ./cmd/gosec/, :24 the ldflags, :26 CGO_ENABLED=0
    "Makefile",                # :11 BUILDFLAGS, :66 `go build $(LDFLAGS) -o $(BIN) ./cmd/gosec/`
    "cmd/gosec/version.go",    # :4-10 Version, GitTag, BuildDate; :17-22 the "dev" fallback
    "cmd/gosec/main.go",       # :159 the -version flag, :433-434 what it prints
    "CLAUDE.md",               # Build & Test: `go build ./cmd/gosec/`
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com. The release's sigstore
bundles cover the prebuilt binaries, not this archive.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v2.30.0 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands: gosec
exited 1 on a file importing crypto/md5, reporting G401 and G501, and
`-version` printed "Version: 2.30.0". The linux arms were not run.
EOT
}
