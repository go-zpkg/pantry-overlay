# authn-bridge, a static pure-Go program (CGO_ENABLED=0), like the release binaries.
#
# Built in MODULE mode, `go install github.com/go-authn/bridge/cmd/authn-bridge@v{{version}}`, and not with
# `go build` inside the tag tarball. A tarball has no .git, so Go stamps the
# main module as "(devel)": `go version -m` would not name the release, and
# govulncheck and the release workflow's own check (mod == tag) could not
# match the binary to an advisory. In module mode Go records the version and
# the go.sum hash of the exact module it compiled, verified against
# sum.golang.org.
#
# The tag tarball stays the distributable, so the factory attests the source.
# The last build step proves the two are the same tree: every file Go
# compiled is compared byte for byte with the tarball.
#
# No -buildmode=pie (vale.sh adds it on linux for a cgo crash): with cgo off
# it would add a PT_INTERP, and this binary must run with no loader at all.

distributable {
  strip-components = 1
  url = "https://github.com/go-authn/bridge/archive/refs/tags/v{{version}}.tar.gz"
}

provides = [
  "bin/authn-bridge",
]

build {
  dependencies = {
    "go.dev" = "^1.27.1"
  }
  script = <<EOT
go install $ARGS -ldflags="$GO_LDFLAGS" github.com/go-authn/bridge/cmd/authn-bridge@v{{version}}
cd "$(go env GOMODCACHE)/github.com/go-authn/bridge@v{{version}}"
find . -type f | while IFS= read -r f; do
  cmp -s "$f" "$SRCROOT/$f" || { echo "the module Go compiled differs from the source tarball at $f" >&2; exit 1; }
done
EOT

  env {
    CGO_ENABLED = "0"
    GOBIN       = "{{prefix}}/bin"
    # go.mod says go 1.27.1: build with the go.dev artifact, never a toolchain
    # downloaded behind the factory's back.
    GOTOOLCHAIN = "local"
    ARGS = [
      "-v",
      "-trimpath",
      "-modcacherw",
    ]
    GO_LDFLAGS = [
      "-s",
      "-w",
    ]
  }
}

test {
  script = [
    "test \"$(authn-bridge --version)\" = \"authn-bridge version v{{version}}\"",
  ]
}

versions {
  github = "go-authn/bridge"
  # before v0.20.0 the command was not cmd/authn-bridge
  ignore = [
    "/^v?0\\.([0-9]|1[0-9])\\./",
  ]
}
