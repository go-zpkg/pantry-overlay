# go.dev/dev-simd — the Go toolchain built from the `dev.simd` branch of
# golang/go, the project's own branch for the SIMD work (`simd/archsimd`
# intrinsics for amd64 and arm64, behind GOEXPERIMENT=simd). A whole recipe, the
# sibling of go.dev (go-zpkg/packages#431, #440 step 1); everything the two
# share — the bootstrap, the vendor-only build, the cgo default — is explained
# in projects/go.dev/package.hcl and only restated here where it differs.
#
# ⭐ IT IS A REAL PROJECT, NOT A DUPLICATE. Read at the pinned commit:
# src/internal/goversion/goversion.go:12 says `const Version = 28`, so this is
# the Go 1.28 development tree, and src/internal/goexperiment/flags.go:122-124
# defines SIMD ("enables the simd package and the compiler's handling of SIMD
# intrinsics"); every file of src/simd/archsimd starts with
# `//go:build goexperiment.simd` (types_amd64.go:3). go.dev's released 1.27.4
# ships the package too; this one tracks the branch's newer work (the commit
# pinned here added the arm64 NEON 8-bit ConcatAddPairs).
#
# ⚠ A MOVING BRANCH, SO A PINNED COMMIT. dev.simd carries no tags, and the
# commit tarball has no VERSION file. Each version is the COMMIT'S committer
# date as CalVer (YYYY.M.D.HH.MM.SS, what the upstream pantry's recipe used),
# and the recipe states the one commit it builds.

summary = "Go toolchain from the dev.simd branch: simd/archsimd intrinsics (GOEXPERIMENT=simd)"

# The same LICENSE and vendored third-party code as go.dev, read from this
# commit's tree (find -iname LICENSE*): LICENSE (BSD-3-Clause, "The Go
# Authors"), cmd/vendor/github.com/google/pprof (Apache-2.0), its
# third_party/svgpan (BSD-3-Clause), cmd/vendor/rsc.io/markdown (MIT),
# golang.org/x/* and demangle (BSD-3-Clause). NOT added: the BoringSSL objects
# under src/crypto/internal/boring, linked only under GOEXPERIMENT=boringcrypto.
license = "BSD-3-Clause AND Apache-2.0 AND MIT"

versions = ["2026.9.1.18.14.31"]

dependencies = {
  # What upstream's recipe meant by `openssl.org` ("for ca-certificates"): Go
  # reads SSL_CERT_FILE itself (src/crypto/x509/root.go), and ca-certs sets it.
  "curl.se/ca-certs" = "*"
}

# ⛔ DELIBERATELY NO `provides`: this toolchain installs bin/go and bin/gofmt
# exactly as go.dev does, so claiming them would make `go` ambiguous between the
# two. go.dev owns those names; this one is used by naming it
# (`+go.dev/dev-simd`), as the upstream recipe said.

distributable {
  # The commit's archive from GitHub's mirror of go.googlesource.com/go: the
  # branch head on 2026-11-20 (commit 22fde194033d4d969811153efbc06d71f95ee819,
  # tree 277ffaa02f26c35d98411b64300712a97da50fa4, committed 2026-09-01T18:14:31Z
  # by Junyang Shao, "[dev.simd] simd: add missing ARM64 NEON 8-bit
  # ConcatAddPairs intrinsics"). The same commit and tree answer on the
  # project's own host, https://go.googlesource.com/go/+/22fde194…?format=JSON.
  url              = "https://github.com/golang/go/archive/22fde194033d4d969811153efbc06d71f95ee819.tar.gz"
  strip-components = 1

  # 35454882 bytes. ⚠ NOT SIGNED: GitHub reports the commit unverified, and a
  # generated archive has no signature or project-published checksum. The digest
  # was computed over a fetch from github.com/golang/go/archive and confirmed by
  # a second, independent fetch from codeload.github.com.
  sha256 = {
    "2026.9.1.18.14.31" = "9240f670a6711756972661897d382ddf492b2bf872c3c97ca58ba31dccb0be86"
  }
}

build {
  dependencies = {
    "curl.se" = "*"
  }

  env = {
    # ⛔ Refused for the whole build, as in go.dev: no module fetch, no toolchain
    # download.
    GOPROXY     = "off"
    GOTOOLCHAIN = "local"
    # CGO_ENABLED is left unset on purpose, for the reason go.dev gives.
  }

  script = [
    {
      run = <<EOT
set -eu
# ⛔ BOOTSTRAP: src/make.bash:74 `bootgo=1.24.6`, cmd/dist/buildtool.go:127. The
# same 1.26.11 archives, digests and checks as go.dev (https://go.dev/dl/?mode=json
# for the digests, a second fetch from dl.google.com/go to confirm each).
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

# ⛔ VERSION. The commit tarball has none and no .git, so cmd/dist could not
# name the toolchain. Written in the format cmd/dist/build.go:440-446 itself
# makes from a checkout (`go1.<goversion>-devel_<short hash> <commit date>`,
# which go/version can parse, per the comment at :424-428), with the optional
# `time` line findgoversion accepts (:392-402).
printf 'go1.28-devel_22fde19 Tue Sep 1 18:14:31 2026 +0000\ntime 2026-09-01T18:14:31Z\n' > VERSION

export GOCACHE="$PWD/.gocache"
export GOROOT_BOOTSTRAP="$PWD/.bootstrap"
( cd src && ./make.bash )
EOT
    },
    {
      run = <<EOT
set -eu
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
  env = {
    # The whole point of this package.
    GOEXPERIMENT = "simd"
  }

  fixture = <<EOT
package main

import (
	"fmt"
	"simd/archsimd"
)

func main() {
	// Compiles only when the simd package exists and the experiment is on.
	// AVX2() is defined on every GOARCH (false off amd64), so this is portable.
	_ = archsimd.X86.AVX2()
	fmt.Println("Hello World")
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
  "go version go1.28-devel_22fde19 "*) ;;
  *) echo "not the pinned dev.simd commit: $V" >&2; exit 1 ;;
esac
test "$("$G" env GOROOT)" = "{{prefix}}"
test -d "{{prefix}}/src/simd/archsimd"

mkdir t
cp "$FIXTURE" t/main.go
cd t
printf 'module example.com/hello\n\ngo 1.28\n' > go.mod
export GOCACHE="$PWD/.gocache" GOPROXY=off GOTOOLCHAIN=local
test "$("$G" run .)" = "Hello World"
"$G" build -o /dev/null .

# Without the experiment the package is not there: the flag is what turns it on.
if GOEXPERIMENT= "$G" build -o /dev/null . >/dev/null 2>&1; then
  echo "simd/archsimd built without GOEXPERIMENT=simd" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "src/make.bash",                          # :74 bootgo=1.24.6, :78 run from src/
    "src/cmd/dist/buildtool.go",              # :127 minBootstrap
    "src/cmd/dist/build.go",                  # :371-446 findgoversion: VERSION first, then git; the devel format
    "src/internal/goversion/goversion.go",    # :12 Version = 28
    "src/internal/goexperiment/flags.go",     # :122-124 SIMD
    "src/simd/archsimd/types_amd64.go",       # :3 //go:build goexperiment.simd
    "go.env",                                 # :12 GOTOOLCHAIN=auto, as shipped
    "LICENSE",                                # BSD-3-Clause
    "https://go.googlesource.com/go/+/22fde194033d4d969811153efbc06d71f95ee819?format=JSON", # the commit and tree on the project's own host
  ]

  consulted = [
    # Read for facts only: that the branch has no tags, the CalVer scheme, the
    # GOEXPERIMENT=simd test, and the decision to claim no `provides`. NOT
    # taken: the dependency on go.dev as its own bootstrap, GOROOT_FINAL, the
    # `GOVER=go1.27` synthetic VERSION (this branch is 1.28's tree) and the
    # 2026-06-01 commit (the branch has moved on).
    "pkgxdev/pantry projects/go.dev/dev-simd/package.yml",
  ]

  note = <<EOT
⚠ ONE COMMIT, A MOVING BRANCH. 22fde194 was the head of dev.simd on 2026-11-20
(GitHub API, branches/dev.simd). Adding a snapshot means a new CalVer in
`versions`, a new digest, and the VERSION line above.

⚠ THE SOURCE RUNG, STATED: no signature, no project checksum; two fetches from
two GitHub hosts agree, and the commit and tree exist on go.googlesource.com.

⛔ NOT BUILT, and the `go1.28-devel_` VERSION and the "package missing without
the experiment" assertion in the test are untested here: a first factory run is
their test. Everything shared with go.dev (GOTOOLCHAIN=auto as shipped, the
bootstrap) is stated in that recipe's note.
EOT
}
