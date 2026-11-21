# github.com/tmccombs/hcl2json — converts HCL2 (Terraform-style) files to JSON.
# A whole recipe, written from the project's own files at v0.6.9
# (go-zpkg/packages#440 step 1). Built as github.com/fatih/gomodifytags is
# (go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the module root IS the command (main.go sits beside go.mod, with
# the conversion in convert/), so the package is `.`; README.md:77 documents
# `go build`. main.go:16 declares `var version string = ""` and :32-40 fall back
# to the module's build info and then to "devel" when it is empty, so this
# recipe stamps main.version (a `go build` of a tarball has no module version
# to fall back on). go.mod:3 says `go 1.25`.

summary = "Convert HCL2 files to JSON"

# LICENSE:1-3 the Apache License, Version 2.0. The binary COMPILES IN six
# modules (`go list -deps .`), each licence read from the module's own file in
# the module cache:
#
#   Apache-2.0    agext/levenshtein v1.2.3, apparentlymart/go-textseg/v15 v15.0.0
#   MPL-2.0       hashicorp/hcl/v2 v2.24.0
#   MIT           mitchellh/go-wordwrap v1.0.1, zclconf/go-cty v1.18.0
#   BSD-3-Clause  golang.org/x/text v0.25.0
license = "Apache-2.0 AND BSD-3-Clause AND MIT AND MPL-2.0"

versions {
  github = "tmccombs/hcl2json"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries and
  # a checksums file over THOSE, not over the source.
  url              = "https://github.com/tmccombs/hcl2json/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 14976 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "0.6.9" = "df7361e4ea5f34de02a81afa06f515bc6379efeb5ab86c154c6a31def6bcb3dc"
  }
}

provides = [
  "bin/hcl2json",
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
go build -ldflags "-s -w -X main.version={{version.raw}}" -o "{{prefix}}/bin/hcl2json" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf 'resource "a" "b" {\n  x = 1\n}\n' > in.tf
hcl2json in.tf > out.json
grep -q '"x": 1' out.json
grep -q '"resource"' out.json
test "$(hcl2json -version)" = "{{version.raw}}"
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",       # :1 module github.com/tmccombs/hcl2json, :3 go 1.25
    "go.sum",       # the pin under -mod=readonly
    "LICENSE",      # :1-3 the Apache License, Version 2.0
    "main.go",      # :16 var version, :27-28 the -version / -v flags, :32-43 the fallbacks
    "README.md",    # :77 `go build`
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v0.6.9 tag (modules fetched from
proxy.golang.org under -mod=readonly), and the test script's commands: a
resource block came out as {"resource": {"a": {"b": [{"x": 1}]}}} and
`-version` printed 0.6.9. The linux arms were not run.
EOT
}
