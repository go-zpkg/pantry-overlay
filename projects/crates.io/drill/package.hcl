# crates.io/drill — an HTTP load testing application (fcsonline/drill). A
# FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from drill's own files (go-zpkg/packages#431, #440 step 1), at 0.9.1.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment declared a library the binary does not
# use. It said `openssl.org ^3`; drill 0.9.1 depends on reqwest 0.13 (Cargo.toml:
# 22) whose TLS is rustls (Cargo.lock:1751), with AWS-LC compiled in
# (aws-lc-sys 0.41.0, Cargo.lock:110) and the platform's certificate store read
# at run time. No openssl-sys is in Cargo.lock. The dependency is dropped, and
# the CA bundle that rustls-native-certs / openssl-probe read on linux is named.

summary = "drill: an HTTP load testing application"

# Cargo.toml:8 license = "GPL-3.0"; LICENSE is the GNU GPL text. The crates of
# Cargo.lock compiled in (AWS-LC among them) carry their own licences, which
# this expression does not enumerate.
license = "GPL-3.0"

versions {
  github = "fcsonline/drill"
}

distributable {
  # GitHub's archive of the tag 0.9.1 (the repository's tags carry no `v`).
  url              = "https://github.com/fcsonline/drill/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 70682 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.9.1" = "79e90ba78e484e15bf6cc919d0be5fdd99155ff2d5b16581539e4361191a8bc7"
  }
}

# Cargo.toml:2: the package `drill`; src/main.rs is its only target.
provides = [
  "bin/drill",
]

dependencies = {
  # rustls-native-certs 0.8.3 (Cargo.lock:1765) and openssl-probe 0.2.1
  # (:1356) look for the system CA bundle at run time on linux; see runtime.env.
  # On darwin the platform verifier uses Security.framework (:1868).
  linux = {
    "curl.se/ca-certs" = "*"
  }
}

runtime {
  env = {
    linux = {
      # openssl-probe honours SSL_CERT_FILE before probing the usual places.
      SSL_CERT_FILE = "{{deps.curl.se/ca-certs.prefix}}/ssl/cert.pem"
    }
  }
}

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:9 edition 2024 (stable from 1.85); no rust-version is declared
    # by drill. aws-lc-sys 0.41.0 declares rust-version = "1.71.0" (its
    # Cargo.toml:14), lower. The floor the manifest proves is 1.85; the compiler
    # this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ AWS-LC IS COMPILED IN, NOT LINKED: aws-lc-sys vendors the AWS-LC sources
    # (its aws-lc/ directory) and there is no system AWS-LC to use in this tree.
    # Its builder picks between a `cc` build and a CMake build on its own
    # (builder/main.rs:533-577: cmake only when the cc builder's dependency
    # check fails). Named, so a missing cmake is not what decides: 0 forces the
    # cc builder, whose check_dependencies failure is fatal (:556-563).
    AWS_LC_SYS_CMAKE_BUILDER = 0
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # Inherited from rust-lang.org/cargo, which measured it: this tree's gcc keeps
  # libgcc.a outside rustc's link search path, so the link fails without it.
  L=""
  for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
    if [ -e "$c" ]; then L="$(dirname "$c")"; fi
  done
  if [ -z "$L" ]; then echo "no libgcc.a under gnu.org/gcc" >&2; exit 1; fi
  export RUSTFLAGS="$${RUSTFLAGS:-} -L$L"
fi
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path . --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
D="{{prefix}}/bin/drill"
test -x "$D"
# src/main.rs:63-64: Command::new("drill").version(crate_version!()).
OUT="$("$D" --version)"
if [ "$OUT" != "drill 0.9.1" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$D" --help > help.txt
grep -q -- "--benchmark" help.txt

# The plan below asks a port nothing listens on (nothing here touches the
# network), so the report (src/main.rs:174-178, the lines "Total requests",
# "Successful requests", "Failed requests") must count ONE request, FAILED:
# a drill that reported a success, or no report, changes one of these lines.
export NO_COLOR=1
cat > bench.yml <<YML
---
concurrency: 1
base: 'http://127.0.0.1:9'
iterations: 1
plan:
  - name: Fetch root
    request:
      url: /
YML
"$D" --benchmark bench.yml --timeout 2 > out.txt 2>&1 || true
cat out.txt
grep -E "^Total requests +1$" out.txt
grep -E "^Successful requests +0$" out.txt
grep -E "^Failed requests +1$" out.txt

# rustls, not OpenSSL: the binary must NOT link libssl.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$D")"; else LIBS="$(ldd "$D")"; fi
case "$LIBS" in
  *libssl*) echo "drill links libssl, which Cargo.lock does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :8 licence, :9 edition 2024, :11-29 dependencies, :22 reqwest 0.13 with cookies + hickory-dns
    "Cargo.lock",    # :100-120 aws-lc-rs/aws-lc-sys, :226 cmake, :1356 openssl-probe, :1709 ring, :1751 rustls, :1765 rustls-native-certs, :1787 rustls-platform-verifier; no openssl-sys
    "src/main.rs",   # :63-64 the command name and version
    "aws-lc-sys-0.41.0/builder/main.rs",  # :533-577 cc builder vs cmake builder, :241-263 the AWS_LC_SYS_ boolean
    "aws-lc-sys-0.41.0/Cargo.toml",       # :14 rust-version 1.71.0
    "LICENSE",       # GNU General Public License
  ]

  consulted = [
    # Read for facts only: the tag URL (no `v`), the binary name and `--version`.
    # NOT taken: openssl ^1.1, rust >=1.56, the sed that rewrote Cargo.toml's
    # version (0.9.1's own says 0.9.1), the network benchmark in its test.
    "pkgxdev/pantry projects/crates.io/drill/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The report lines the test greps for are read from src/main.rs:174-178
and the `colored` crate's NO_COLOR behaviour is assumed, not run; the failed
request of an unreachable port is expected, not observed. The first factory
run is this file's test.
EOT
}
