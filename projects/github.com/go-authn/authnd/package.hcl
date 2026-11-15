# authnd, a static pure-Go program (CGO_ENABLED=0), like the release binaries.
#
# Built in MODULE mode, `go install github.com/go-authn/authnd@v{{version}}`, and not with
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
  url = "https://github.com/go-authn/authnd/archive/refs/tags/v{{version}}.tar.gz"
}

provides = [
  "bin/authnd",
]

build {
  dependencies = {
    "go.dev" = "^1.27.1"
  }
  script = <<EOT
go install $ARGS -ldflags="$GO_LDFLAGS" github.com/go-authn/authnd@v{{version}}
cd "$(go env GOMODCACHE)/github.com/go-authn/authnd@v{{version}}"
find . -type f | while IFS= read -r f; do
  cmp -s "$f" "$SRCROOT/$f" || { echo "the module Go compiled differs from the source tarball at $f" >&2; exit 1; }
done
EOT

  env {
    CGO_ENABLED = "0"
    GOBIN       = "{{prefix}}/bin"
    # go.mod states `go 1.27.3` at v0.18.6, the tag this recipe builds (checked
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
  script = [
    "test \"$(authnd --version)\" = \"authnd version v{{version}}\"",
  ]
}

versions {
  github = "go-authn/authnd"
}

provenance {
  read = [
    "go.mod",                        # :3 `go 1.27.3` at v0.18.6 — the toolchain floor this build needs
    "go.sum",                        # the hashes module mode verifies against sum.golang.org
    ".github/workflows/release.yml", # :4 "pure Go (CGO_ENABLED=0)"; :75 the build line; :91-93 mod == TAG
  ]

  note = <<EOT
Read at v0.18.6, THE TAG THIS RECIPE BUILDS, not at the default branch: a
directive raised after a release would read as the released module's
requirement, and a provenance citing it would be false about the very thing it
pins.

What each file settled:

  - `release.yml:4` states "pure Go (CGO_ENABLED=0)", and three lines carry
    CGO_ENABLED — so `CGO_ENABLED = "0"` here matches how the project ships,
    rather than being our preference.
  - `release.yml:75` is `go build -trimpath -ldflags="-w" -o "$dist/$${out}" .`
    and NO line carries `buildmode`, which is what the comment above means by
    "no -buildmode=pie": the project does not ask for one either.
  - `release.yml:91-93` is the check this recipe's build mode exists for:
        mod=$(go version -m "$f" | awk '$1=="mod"{print $3}')
        vm=$(go version -m "$f" | awk -F= '/vcs.modified/{print $2}')
        if [ "$mod" != "$TAG" ] || [ "$vm" != false ]; then
    It requires the binary to name its release and to be built from a clean
    tree. The project gets that from a git checkout; a tag TARBALL has no .git,
    so `go build` would stamp "(devel)" and this check could not hold. ⭐ So
    `go install …@v{{version}}` is a DELIBERATE divergence from the project's
    own build line, and reading the workflow is what proves it is the right one
    rather than a habit.

Two honest differences from `release.yml:75`, stated because "like the release
binaries" is a claim:

  - this adds `-s` to the workflow's `-w` (symbol table stripped as well);
  - the workflow builds `.` from a checkout, this installs the module path.

⛔ AND ONE THING THE READING FOUND WRONG ABOVE. The comment in `env` said
"go.mod says go 1.27.1". It says `go 1.27.3`, and did so at the tag already. The
`"go.dev" = "^1.27.1"` constraint is therefore a FLOOR THIS REQUIREMENT
OUTGREW: with `GOTOOLCHAIN = "local"`, a go.dev resolved at that floor would
refuse to build a module requiring 1.27.3 rather than silently fetch a
toolchain. It is left as it is in this change because raising it needs the
registry's published go.dev versions checked first, and that is a separate
measurement; the comment is corrected so the file no longer states something
its own project contradicts.
EOT
}
