# go.dev — the Go toolchain (the `go` command, gofmt, the compiler, linker,
# assembler and the standard library, source and all), built from the project's
# own source tarball. A whole recipe: the upstream pantry's cannot be merged
# underneath any more (zpkb v0.92.0, go-zpkg/packages#431), so this one states
# where the source comes from, what it is bootstrapped with, and how it is built
# (go-zpkg/packages#440 step 1).
#
# ⛔ WRITTEN FROM GO'S OWN FILES (go-zpkg/packages#431), at 1.27.4.
#
# ⭐⭐ THE CARRYING FACT: GO CANNOT BUILD ITSELF FROM NOTHING. src/make.bash:67
# "GOROOT_BOOTSTRAP: A working Go tree >= Go 1.24.6" and :74 `bootgo=1.24.6`
# (cmd/dist/buildtool.go:127 `minBootstrap`). This recipe cannot name `go.dev`
# as its own build dependency (the resolver would need the artifact it is
# making), so, as rust-lang.org/cargo does with its bootstrap cargo, it FETCHES
# one published Go toolchain, 1.26.11, checks each archive against the sha256
# go.dev publishes for it, and builds 1.27.4 with that. The bootstrap is thrown
# away: it is never installed and nothing of it is copied.
#
# Everything else the build could reach for is named below:
#   - modules: the standard library and cmd/ build from their own vendor/
#     directories (src/vendor, src/cmd/vendor); GOPROXY=off and
#     GOTOOLCHAIN=local are set for the whole build, so a build that tried to
#     fetch a module or a newer toolchain fails instead of fetching.
#   - cgo: left to the go command, as the project does (see build.env).

summary = "Go: the toolchain, gofmt and the standard library"

# LICENSE:1-27 "Copyright 2009 The Go Authors", the 3-clause BSD text, and
# PATENTS (an additional patent grant, no SPDX identifier of its own). The
# artifact installs the whole source tree (src/, as the project's own binary
# release does) and `go tool pprof` COMPILES IN third-party code, each read from
# its own LICENSE:
#
#   Apache-2.0    src/cmd/vendor/github.com/google/pprof/LICENSE (pprof itself)
#   BSD-3-Clause  pprof's third_party/svgpan (Andrea Leofreddi, 3 clauses),
#                 golang.org/x/*, ianlancetaylor/demangle, rsc.io/markdown's
#                 siblings under cmd/vendor — all "The Go Authors" or BSD-3
#   MIT           src/cmd/vendor/rsc.io/markdown/LICENSE ("The MIT License")
#
# NOT added: the BoringSSL object files under src/crypto/internal/boring/syso
# (LICENSE there: "When building with GOEXPERIMENT=boringcrypto, the following
# applies") — they ship in src/ but are linked only under that experiment, which
# this build does not turn on.
license = "BSD-3-Clause AND Apache-2.0 AND MIT"

versions {
  # golang/go tags more than releases: `go1.27rc1`, `go1.27beta1`, `weekly.*`,
  # `release.r60`. A release is `go` followed by digits and dots only, so after
  # the strip anything with a letter in it is not one.
  github = "golang/go/tags"
  strip  = "/^go/"
  ignore = [
    "/[a-z]/",
  ]
}

# What the upstream pantry's recipe declared here was `openssl.org ^3`, "for
# ca-certificates". Go links no OpenSSL; what it needs is a CA bundle, and it
# finds one itself: src/crypto/x509/root.go:127 and :132 read SSL_CERT_FILE and
# SSL_CERT_DIR, and cert_pool.go:108-113 documents them. curl.se/ca-certs sets
# SSL_CERT_FILE to the bundle it installs (its env block), which is the thing
# that was meant.
dependencies = {
  "curl.se/ca-certs" = "*"
}

distributable {
  # The project's own source tarball: https://go.dev/dl/ lists it (kind
  # "source") and redirects to dl.google.com/go.
  url              = "https://go.dev/dl/go{{version.raw}}.src.tar.gz"
  strip-components = 1

  # 35153471 bytes. ⚠ NOT SIGNED BY ANYTHING THIS TREE CAN ANCHOR. go.dev serves
  # go1.27.4.src.tar.gz.asc, a detached signature (made 2026-11-05) by key
  # 0E225917414670F4442C250DFD533C07C264648F, but no page the project controls
  # that was read prints that fingerprint (go.dev/dl/, go.dev/security and
  # go.dev/doc/security/release carry none), so the signature is no anchor and
  # is not claimed as one. The pin is a TWO-PATH CONFIRMATION instead: the
  # sha256 go.dev's own download index (https://go.dev/dl/?mode=json, kind
  # "source") publishes for the file, and what shasum computed over a fetch from
  # go.dev/dl and a second, independent fetch from dl.google.com/go.
  sha256 = {
    "1.27.4" = "73cfb8571aec0c01177687db87163d46aa20e9779672772891aa17654d9a6099"
  }
}

provides = [
  "bin/go",
  "bin/gofmt",
]

build {
  dependencies = {
    # Fetches the bootstrap toolchain.
    "curl.se" = "*"
  }

  env = {
    # ⛔ Refused for the whole build: a module fetch and a toolchain download.
    # src and cmd build from their vendor/ directories, so neither is needed,
    # and a download here would be a dependency this recipe does not pin.
    GOPROXY     = "off"
    GOTOOLCHAIN = "local"

    # ⛔ NOT SET: CGO_ENABLED. cmd/dist/buildruntime.go:70 writes the
    # environment's CGO_ENABLED into the toolchain as DefaultCGO_ENABLED. Unset,
    # that is "" and the go command decides on the USER'S machine
    # (cmd/go/internal/cfg/cfg.go:136-183: cgo is on when a C compiler is on
    # PATH, off otherwise), which is what a Go release does. Setting it here
    # would bake this builder's choice into every user's `go build`. GOROOT_FINAL
    # is not set either: make.bash and cmd/dist no longer read it, the tree is
    # relocatable (the test below moves nothing, but `go env GOROOT` is read
    # off the binary's own location).
  }

  script = [
    {
      run = <<EOT
set -eu
# ⛔ BOOTSTRAP. One published Go toolchain, 1.26.11 (>= the 1.24.6 floor named
# in the header), fetched from go.dev/dl and checked against the sha256 that
# https://go.dev/dl/?mode=json lists for each archive; the five platforms this
# tree builds for. Each digest was also confirmed by shasum over a fetch from
# dl.google.com/go.
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)               B=linux-amd64;  SUM=9849f4e04ee35303714e34fbc3ac8ab44ea3e448a95aa182f91e3b9b79c710ec ;;
  Linux-aarch64|Linux-arm64)  B=linux-arm64;  SUM=6c2f29b458b5add0835f18b776f69c8881a6d88428f1484a6da55755e620757e ;;
  Linux-s390x)                B=linux-s390x;  SUM=7d991c350ab49393c4c66e2ddb33c60e5c32bb1446d270afc810efcd275563ac ;;
  Darwin-x86_64)              B=darwin-amd64; SUM=394baae971332f2bc783d6e2004ae57101479bd3b06ed8209a3fe3570d4ce498 ;;
  Darwin-arm64)               B=darwin-arm64; SUM=e3a42e67a7a8acf450ebada2b074c7ca863000ca514907b7185b45e8f5cdff57 ;;
  *) echo "no pinned bootstrap Go for $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac
T="go1.26.11.$B.tar.gz"
curl -fsSLo "$T" "https://go.dev/dl/$T"
if command -v sha256sum >/dev/null 2>&1; then echo "$SUM  $T" | sha256sum -c -
else echo "$SUM  $T" | shasum -a 256 -c -; fi
mkdir .bootstrap
tar xzf "$T" -C .bootstrap --strip-components=1
.bootstrap/bin/go version

# make.bash complains about an unset GOCACHE and HOME otherwise; kept in the
# build tree so nothing is written to the builder's home.
export GOCACHE="$PWD/.gocache"
# make.bash must run from src/ (make.bash:78). GOROOT_BOOTSTRAP is the
# directory, not a bin/go (make.bash:161).
export GOROOT_BOOTSTRAP="$PWD/.bootstrap"
( cd src && ./make.bash )
EOT
    },
    {
      run = <<EOT
set -eu
# What the project's own binary release ships at its top level (read from
# go1.26.11.linux-amd64.tar.gz): api bin doc lib misc pkg src test go.env
# VERSION and the licence and README files. VERSION matters: it is what the
# toolchain reports, and a tarball has no .git to derive one from.
for d in api bin doc lib misc pkg src test; do
  cp -a "$d" "{{prefix}}/"
done
for f in go.env VERSION LICENSE PATENTS README.md SECURITY.md CONTRIBUTING.md codereview.cfg; do
  cp "$f" "{{prefix}}/"
done
EOT
    },
  ]
}

test {
  fixture = <<EOT
package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Println("Hello World", runtime.Version())
}
EOT

  script = [
    {
      run = <<EOT
set -eu
G="{{prefix}}/bin/go"
V="$("$G" version)"
echo "$V"
case "$V" in
  "go version go{{version.raw}} "*) ;;
  *) echo "not go{{version.raw}}: $V" >&2; exit 1 ;;
esac
# The toolchain finds its own root from where the binary lives.
if [ "$("$G" env GOROOT)" != "{{prefix}}" ]; then
  echo "GOROOT is $("$G" env GOROOT), want {{prefix}}" >&2
  exit 1
fi
# VERSION is installed and says the same.
test "$(head -n 1 "{{prefix}}/VERSION")" = "go{{version.raw}}"
test -x "{{prefix}}/bin/gofmt"
test -d "{{prefix}}/src/simd/archsimd"

# It compiles and runs a program, offline and with no module download or
# toolchain switch allowed.
mkdir t
cp "$FIXTURE" t/main.go
cd t
printf 'module example.com/hello\n\ngo 1.24\n' > go.mod
export GOCACHE="$PWD/.gocache" GOPROXY=off GOTOOLCHAIN=local
OUT="$("$G" run .)"
case "$OUT" in
  "Hello World go{{version.raw}}") ;;
  *) echo "hello printed '$OUT'" >&2; exit 1 ;;
esac

# A statically linked build needs no C compiler, whatever the builder had.
CGO_ENABLED=0 "$G" build -trimpath -o hello .
test "$(./hello)" = "$OUT"

# gofmt is the one this release ships: it accepts what the compiler accepts.
"{{prefix}}/bin/gofmt" -l . > fmt.txt
test ! -s fmt.txt
EOT
    },
  ]
}

provenance {
  read = [
    "src/make.bash",                        # :67-74 GOROOT_BOOTSTRAP >= 1.24.6, bootgo; :78 run from src/; :161 bin/go of the bootstrap; :219 `dist bootstrap -a`
    "src/cmd/dist/buildtool.go",            # :127 minBootstrap = go1.24.6
    "src/cmd/dist/buildruntime.go",         # :70 the build's CGO_ENABLED becomes DefaultCGO_ENABLED
    "src/cmd/dist/build.go",                # :1857-1861 CC is needed only when cgo is forced on
    "src/cmd/go/internal/cfg/cfg.go",       # :136-183 the cgo default is decided on the user's machine
    "src/crypto/x509/root.go",              # :127, :132 SSL_CERT_FILE and SSL_CERT_DIR
    "src/crypto/x509/cert_pool.go",         # :108-113 the documented environment variables
    "go.env",                               # GOPROXY, GOSUMDB and GOTOOLCHAIN=auto as shipped
    "VERSION",                              # go1.27.4
    "LICENSE",                              # BSD-3-Clause, "The Go Authors"
    "src/cmd/vendor/github.com/google/pprof/LICENSE",                   # Apache-2.0
    "src/cmd/vendor/github.com/google/pprof/third_party/svgpan/LICENSE", # BSD-3-Clause
    "src/cmd/vendor/rsc.io/markdown/LICENSE",                           # MIT
    "src/crypto/internal/boring/LICENSE",   # BoringSSL, boringcrypto experiment only
    "https://go.dev/dl/?mode=json",         # the sha256 of the source and of the five bootstrap archives
  ]

  consulted = [
    # Read for facts only: the URL shape, the tag source, the `bin/go` and
    # `bin/gofmt` provides, the directories copied into the prefix, and that a
    # bootstrap Go was needed. NOT taken: the `go.dev: '*'` build dependency on
    # itself, `GOROOT_FINAL` (no longer read), and `openssl.org` as a runtime
    # dependency.
    "pkgxdev/pantry projects/go.dev/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG, STATED. See distributable: go.dev serves a detached .asc but
publishes no fingerprint this session could find, so the digest is anchored on
the project's own download index plus two fetches, not on a signature.

⛔ GOTOOLCHAIN=auto IS SHIPPED, AND LEFT. go.env (read at 1.27.4) says "Automatically
download newer toolchains as directed by go.mod files", and so does every Go
release. It is the project's default for the people who RUN this toolchain, not
something the build uses (the build sets GOTOOLCHAIN=local above). Go programs
built by other recipes in this tree set GOTOOLCHAIN=local themselves.

⚠ THE BOOTSTRAP IS A DOWNLOADED BINARY, its digest from go.dev's own index and
confirmed by a second fetch from dl.google.com. It is 1.26.11, not 1.24.6, the
floor: any older archive go.dev still lists would do, and a current one is the
one go.dev still publishes. A newer 1.27 would also do; 1.26.11 was chosen so
that 1.27.4 is not built by a toolchain of its own series.

⛔ NOT BUILT. No session here can run the factory. A local `./make.bash` with
this tree's own Go as GOROOT_BOOTSTRAP is the way to read the build part; what
the first factory run decides is the bootstrap fetch, the copy step and the
test script.
EOT
}
