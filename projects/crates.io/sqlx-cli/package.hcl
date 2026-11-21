# crates.io/sqlx-cli — SQLx's command-line tool: database creation, migrations,
# offline query data (launchbadge/sqlx). Written whole from the crate's own files
# at 0.9.1 (go-zpkg/packages#440 step 1), replacing a dependencies-only fragment.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE DEFAULT FEATURES ARE NOT WHAT THE FRAGMENT ASSUMED. `default` is
#      postgres, sqlite, mysql, native-tls, completions, sqlx-toml
#      (Cargo.toml:47-54): native-tls means OpenSSL on linux, which the
#      fragment declared. This recipe turns native-tls OFF and `rustls` ON, and
#      names the rest: postgres, mysql, sqlite, completions, sqlx-toml. With
#      those, `cargo tree --locked -e normal,build` for x86_64-unknown-linux-gnu
#      and aarch64-apple-darwin finds NO openssl-sys, NO native-tls, NO
#      aws-lc-sys, NO cmake and NO rsa: TLS is rustls 0.23.46 over `ring` 0.17.14
#      (sqlx features tls-rustls-ring-webpki) with the webpki-roots CA list
#      compiled in, so no CA bundle is needed at run time and no library is
#      linked from the host.
#   2. SQLITE IS BUNDLED, NOT SYSTEM. `sqlite` -> sqlx/sqlite-bundled ->
#      libsqlite3-sys 0.37.0 [bundled] (Cargo.lock :1050): sqlite3.c is compiled
#      with cc. The `sqlite-unbundled` feature (Cargo.toml) is off.
#   3. `mysql-rsa` (Cargo.toml:56) is OFF: it pulls the `rsa` crate for MySQL's
#      RSA password exchange over a non-TLS connection. Use TLS (rustls) to a
#      MySQL server, or rebuild with it.
#   4. THE CRATE SHIPS Cargo.lock; the GitHub tag does NOT (the sqlx workspace
#      commits none), so this recipe builds the .crate from static.crates.io.
#
# ⛔ NOT BUILT. Lint-only: no factory build and no hand build was run.

summary = "sqlx-cli: SQLx's database, migration and offline-query command-line tool"

# Cargo.toml:41 license = "MIT OR Apache-2.0"; LICENSE-MIT and LICENSE-APACHE
# are shipped in the crate. Dependencies carry their own licences.
license = "MIT OR Apache-2.0"

versions {
  # The crate is published at every tag of the repository (v0.9.1 <-> 0.9.1).
  github = "launchbadge/sqlx/tags"
  strip  = "/^v/"
}

distributable {
  url              = "https://static.crates.io/crates/sqlx-cli/sqlx-cli-{{version.raw}}.crate"
  strip-components = 1

  # 107935 bytes. Recorded with `zpkb sourcepin` (v0.96.0), and the second
  # witness is crates.io's own sparse index: https://index.crates.io/sq/lx/sqlx-cli
  # lists "vers":"0.9.1" with this same "cksum" (read 2026-11-21).
  sha256 = {
    "0.9.1" = "7e99f14841a9fe8e5650ccda3dd7607f1f22c33af86b17b4872488a2146bcdfe"
  }
}

# Cargo.toml:75-81: [[bin]] cargo-sqlx and [[bin]] sqlx.
provides = [
  "bin/cargo-sqlx",
  "bin/sqlx",
]

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:14 rust-version = "1.94.0"; edition 2021.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
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
# ⛔ Features, named (Cargo.toml:44-60): default (postgres, sqlite, mysql,
# native-tls, completions, sqlx-toml) is replaced by the same list with
# native-tls -> rustls. Off: native-tls, mysql-rsa, sqlite-unbundled,
# openssl-vendored.
# ⛔ --locked: the crate's Cargo.lock is the dependency pin, and cargo verifies
# its checksums.
cargo build --locked --release --no-default-features \
  --features postgres,mysql,sqlite,rustls,completions,sqlx-toml
mkdir -p "{{prefix}}/bin"
cp target/release/sqlx target/release/cargo-sqlx "{{prefix}}/bin/"
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
S="{{prefix}}/bin/sqlx"
test -x "$S"
test -x "{{prefix}}/bin/cargo-sqlx"
OUT="$("$S" --version)"
case "$OUT" in
  *"0.9.1"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# A real SQLite round trip, which proves the bundled SQLite is linked: create a
# database file, then run an empty migration directory against it.
D="$PWD/db"
mkdir -p "$D/migrations"
export DATABASE_URL="sqlite://$D/test.db"
"$S" database create
test -f "$D/test.db"
"$S" migrate add --source "$D/migrations" first
"$S" migrate run --source "$D/migrations"
"$S" database drop -y
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :13-16 edition 2021, rust-version 1.94.0, name sqlx-cli, version 0.9.1; :41 licence; :44-60 [features], default :47-54, mysql-rsa :56; :75-81 [[bin]] cargo-sqlx, sqlx; :149 sqlx = =0.9.1
    "Cargo.lock",   # :1050 libsqlite3-sys, :1471 ring; resolved with `cargo tree --locked --no-default-features --features postgres,sqlite,mysql,rustls,completions,sqlx-toml -e normal,build` for x86_64-unknown-linux-gnu and aarch64-apple-darwin: ring 0.17.14, rustls 0.23.46, libsqlite3-sys 0.37.0 [bundled]; no openssl-sys, native-tls, aws-lc-sys, cmake, rsa
    "LICENSE-MIT",  # MIT
    "LICENSE-APACHE",  # Apache-2.0
    "README.md",    # :21 `cargo install sqlx-cli --no-default-features --features rustls`; :15 native-tls,postgres; :24 sqlite-unbundled; :27 mysql-rsa
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. This recipe is lint-only: neither the factory nor a hand build ran
it. `cargo tree --locked` was run on the 0.9.1 crate to name what the features
compile, and nothing else. The test block (a SQLite create / migrate / drop round
trip) is written from the CLI's own help and is unverified.

⚠ THE SOURCE RUNG IS TWO WITNESSES, STATED. The digest is of the .crate file
from static.crates.io, and crates.io's sparse index lists the same checksum for
sqlx-cli 0.9.1. Both are crates.io; neither is a signature by the authors. The
crates it compiles are pinned by Cargo.lock's checksums.

C CODE, NAMED: SQLite (bundled libsqlite3-sys 0.37.0, cc) and ring 0.17.14 (C and
pregenerated assembly, cc). No OpenSSL, libpq, libmysqlclient or system SQLite.
EOT
}
