# authn-revokd, a static pure-Go program (CGO_ENABLED=0), like the release binaries.
#
# Built in MODULE mode, `go install github.com/go-authn/revocation/cmd/authn-revokd@v{{version}}`, and not with
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
  url = "https://github.com/go-authn/revocation/archive/refs/tags/v{{version}}.tar.gz"
}

provides = [
  "bin/authn-revokd",
]

build {
  dependencies = {
    "go.dev" = "^1.27.1"
  }
  script = <<EOT
go install $ARGS -ldflags="$GO_LDFLAGS" github.com/go-authn/revocation/cmd/authn-revokd@v{{version}}
cd "$(go env GOMODCACHE)/github.com/go-authn/revocation@v{{version}}"
find . -type f | while IFS= read -r f; do
  cmp -s "$f" "$SRCROOT/$f" || { echo "the module Go compiled differs from the source tarball at $f" >&2; exit 1; }
done
EOT

  env {
    CGO_ENABLED = "0"
    GOBIN       = "{{prefix}}/bin"
    # go.mod states `go 1.27.3` at v0.7.0, the tag this recipe builds (checked
    # at the tag, not at HEAD): build with the go.dev artifact, never a
    # toolchain downloaded behind the factory's back. ⚠ The `go.dev` constraint
    # above still says ^1.27.1, a floor this requirement outgrew — the
    # provenance note below says why it is left alone here.
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
  # authn-revokd prints its version on stderr (its flag set writes there).
  script = [
    "test \"$(authn-revokd -version 2>&1)\" = \"authn-revokd v{{version}}\"",
  ]
}

versions {
  github = "go-authn/revocation"
  # before v0.6.0 the command was revokd, not cmd/authn-revokd
  ignore = [
    "/^v?0\\.[0-5]\\./",
  ]
}

provenance {
  read = [
    "go.mod",                        # :3 `go 1.27.3` at v0.7.0 — the toolchain floor this build needs
    "go.sum",                        # the hashes module mode verifies against sum.golang.org
    ".github/workflows/release.yml", # :4 "pure Go (CGO_ENABLED=0)"; :75 the build line; :108-110 mod == TAG
  ]

  note = <<EOT
Read at v0.7.0, THE TAG THIS RECIPE BUILDS, not at the default branch: a
directive raised after a release would read as the released module's
requirement, and a provenance citing it would be false about the very thing it
pins.

What each file settled:

  - `release.yml:4` states "pure Go (CGO_ENABLED=0)", and three lines carry
    CGO_ENABLED, so `CGO_ENABLED = "0"` matches how the project ships.
  - `release.yml:75` is
    `go build -trimpath -ldflags="-w" -o "$dist/$${out}" ./cmd/authn-revokd`,
    which is where the installed package path comes from — the command is NOT
    the module root, and `provides = ["bin/authn-revokd"]` follows from it. No
    line carries `buildmode`, so the absence of `-buildmode=pie` matches the
    project.
  - `release.yml:108-110` requires `mod == TAG` and `vcs.modified == false`
    from `go version -m`. A tag TARBALL has no .git, so `go build` would stamp
    "(devel)" and that check could not hold — which is why this recipe installs
    the module path instead, a DELIBERATE divergence from the project's own
    build line.

One honest difference from `release.yml:75`: this adds `-s` to the workflow's
`-w`, stripping the symbol table as well.

⛔ The `env` comment above said "go.mod says go 1.27.1". It says `go 1.27.3`,
at the tag already, so `"go.dev" = "^1.27.1"` is a floor this requirement
outgrew: under `GOTOOLCHAIN = "local"` a go.dev resolved at that floor would
refuse the build rather than fetch a toolchain. Raising it needs the registry's
published go.dev versions checked first, so only the comment is corrected here.
EOT
}
