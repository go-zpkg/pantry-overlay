# github.com/usbarmory/tamago-go — the TamaGo Go toolchain: the Go distribution
# with one more GOOS, `tamago`, for bare-metal Go on ARM, ARM64, RISC-V and
# AMD64 boards (the project's USB armory and Firecracker targets). A whole
# recipe (go-zpkg/packages#431, #440 step 1); the build is go.dev's, and
# projects/go.dev/package.hcl explains everything shared with it.
#
# ⛔ WRITTEN FROM THE PROJECT'S OWN FILES, at tamago-go1.27.4. The tree is the Go
# 1.27.4 tree plus the tamago port: src/internal/goos/zgoos_tamago.go:3
# `//go:build tamago` and :7 `const GOOS = "tamago"`, src/internal/syslist/
# syslist.go:33 `"tamago": true`, src/runtime/os_tamago.go and
# src/runtime/rt0_tamago_arm.s. VERSION is shipped IN the tarball
# (`go1.27.4` and a `time` line), so unlike a git checkout nothing has to be
# synthesised.
#
# ⭐ THE DIFFERENCE FROM go.dev: the bootstrap. go.dev fetches one published Go
# archive in its build script because it cannot depend on itself. This recipe is
# a DIFFERENT project, so it names `go.dev` as an ordinary build dependency and
# points GOROOT_BOOTSTRAP at it (src/make.bash:67-74 wants a Go >= 1.24.6, and
# go.dev here is ^1.27): no curl, no second pinned archive.

summary = "TamaGo: the Go toolchain with a bare-metal `tamago` GOOS (ARM, ARM64, RISC-V, AMD64)"

# LICENSE:1 "Copyright 2009 The Go Authors" (BSD-3-Clause), and PATENTS. The tree
# carries the same vendored code as go.dev, each read from its own LICENSE:
# src/cmd/vendor/github.com/google/pprof/LICENSE (Apache-2.0), its
# third_party/svgpan/LICENSE (BSD-3-Clause), src/cmd/vendor/rsc.io/markdown/LICENSE
# (MIT).
license = "BSD-3-Clause AND Apache-2.0 AND MIT"

versions {
  # The project tags every release `tamago-go<go version>`.
  github = "usbarmory/tamago-go/tags"
  strip  = "/^tamago-go/"
}

dependencies = {
  # Go reads SSL_CERT_FILE itself (src/crypto/x509/root.go); ca-certs sets it.
  "curl.se/ca-certs" = "*"
}

# ⛔ DELIBERATELY NO `provides`: the toolchain installs bin/go and bin/gofmt, the
# names go.dev owns, and claiming them would make `go` ambiguous. It is used by
# naming it, as go.dev/dev-simd is.

distributable {
  # The tag's GitHub archive: the project's releases carry only prebuilt
  # linux-amd64 and linux-armv7l binaries, and this builds from source for any
  # host.
  url              = "https://github.com/usbarmory/tamago-go/archive/refs/tags/tamago-go{{version.raw}}.tar.gz"
  strip-components = 1

  # 35583577 bytes. ⚠ NOT SIGNED: a generated archive has no signature and the
  # project publishes no checksum for it. The digest was computed over a fetch
  # from github.com and confirmed by a second, independent fetch from
  # codeload.github.com (identical).
  sha256 = {
    "1.27.4" = "3f40fe87451a49b0bc0d8f73afe9a21de7ca9dc0237efc2b2ea13b636bc2ae9d"
  }
}

build {
  dependencies = {
    # The bootstrap toolchain: src/make.bash:74 `bootgo=1.24.6`.
    "go.dev" = "^1.27"
  }

  env = {
    # ⛔ Refused for the whole build: no module fetch, no toolchain download.
    GOPROXY     = "off"
    GOTOOLCHAIN = "local"
    # CGO_ENABLED is left unset on purpose, for the reason go.dev gives.
  }

  script = [
    {
      run = <<EOT
set -eu
test "$(head -n 1 VERSION)" = "go{{version.raw}}"
# Kept in the build tree so nothing is written to the builder's home.
export GOCACHE="$PWD/.gocache"
# The directory, not a bin/go (make.bash:161).
export GOROOT_BOOTSTRAP="{{deps.go.dev.prefix}}"
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
test "$("$G" env GOROOT)" = "{{prefix}}"
test -f "{{prefix}}/src/runtime/os_tamago.go"

# THE POINT OF THE PACKAGE: the tamago GOOS exists, for each architecture the
# port names. A tamago program cannot BUILD here: cmd/go/internal/goos/goos.go:82
# refuses the GOOS without an external GOOSPKG (the github.com/usbarmory/tamago
# module, which is the board support and which this recipe does not fetch). So
# the test asserts what is observable offline: the port is listed, `go env`
# accepts it, and the refusal is the documented one, not a crash.
"$G" tool dist list > dist.txt
grep -q '^tamago/arm$' dist.txt
grep -q '^tamago/arm64$' dist.txt
grep -q '^tamago/riscv64$' dist.txt
grep -q '^tamago/amd64$' dist.txt

export GOCACHE="$PWD/.gocache" GOPROXY=off GOTOOLCHAIN=local CGO_ENABLED=0
test "$(GOOS=tamago GOARCH=arm "$G" env GOOS)" = "tamago"
if GOOS=tamago GOARCH=arm "$G" build runtime > refusal.txt 2>&1; then
  echo "tamago built without GOOSPKG" >&2
  exit 1
fi
grep -q 'unsupported without external GOOSPKG' refusal.txt

# It is still an ordinary Go for the host.
mkdir t
cat > t/main.go <<'GOEOF'
package main

import "fmt"

func main() { fmt.Println("Hello World") }
GOEOF
cd t
printf 'module example.com/hello\n\ngo 1.24\n' > go.mod
test "$("$G" run .)" = "Hello World"
EOT
    },
  ]
}

provenance {
  read = [
    "VERSION",                              # go1.27.4: shipped in the tarball
    "src/make.bash",                        # :67-74 GOROOT_BOOTSTRAP >= 1.24.6, bootgo; :78 run from src/; :161 the bootstrap is a directory
    "src/internal/goos/zgoos_tamago.go",    # :3 //go:build tamago, :7 GOOS = tamago
    "src/internal/syslist/syslist.go",      # :33 "tamago": true
    "src/runtime/os_tamago.go",             # the port's runtime hooks
    "src/cmd/go/internal/goos/goos.go",     # :82 the refusal without an external GOOSPKG, asserted by the test
    "LICENSE",                              # BSD-3-Clause, "The Go Authors"
    "src/cmd/vendor/github.com/google/pprof/LICENSE",                    # Apache-2.0
    "src/cmd/vendor/github.com/google/pprof/third_party/svgpan/LICENSE", # BSD-3-Clause
    "src/cmd/vendor/rsc.io/markdown/LICENSE",                            # MIT
  ]

  consulted = [
    # Read for facts only: the project's name in the pantry and that a
    # bootstrap Go is needed.
    "pkgxdev/pantry projects/github.com/usbarmory/tamago-go",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG, STATED: no signature, no project checksum; two fetches from
two GitHub hosts agree.

⛔ NOT BUILT BY THE FACTORY. The make.bash step, the install and the test were
run on darwin/arm64 with go.dev's Go 1.27.4 as GOROOT_BOOTSTRAP, in a scratch
copy of the tree; see the pull request for what ran. The `{{deps.go.dev.prefix}}`
bootstrap and the factory sandbox were not exercised.
EOT
}
