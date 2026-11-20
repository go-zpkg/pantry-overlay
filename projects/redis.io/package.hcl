# redis.io — the Redis in-memory data store: server, CLI, benchmark and the
# check-aof / check-rdb / sentinel names. A whole recipe (go-zpkg/packages#440
# step 1): it was a fragment of one dependency.
#
# ⛔ WRITTEN FROM REDIS'S OWN FILES (go-zpkg/packages#431), at 8.10.3.
#
# WHAT IS INSTALLED: six names under bin/ (src/Makefile:573-580). No
# redis.conf, no data directory, no service registration (USE_SYSTEMD=no).
#
# ⭐⭐ WHAT WRITING IT FOUND: the same three probes valkey.io found, all in
# src/Makefile and none pinned by the fragment:
#   1. libsystemd (:282-306): USE_SYSTEMD unset means "link libsystemd if
#      pkg-config knows it".
#   2. the allocator (:82-107): jemalloc on Linux, libc elsewhere.
#   3. TLS: BUILD_TLS defaults to no (TLS.md), so the fragment's openssl.org
#      bought a server with NO TLS.
# And a fourth that only 8.x has: the top-level Makefile's default goal is
# scripts/build.sh, which builds Redis PLUS every module cloned under
# modules/*/src (scripts/build.sh:7-9, 31-34). The tarball clones none, so a
# plain `make` is a core build today and becomes a core-plus-network-and-Rust
# build the day a module is vendored. `make -C src` is the core alone, named.

summary = "Redis: an in-memory data structure store, used as a database, cache and message broker"

# LICENSE.txt:1-9: since Redis 8, "your choice of: (a) the Redis Source
# Available License v2 (RSALv2); or (b) the Server Side Public License v1
# (SSPLv1); or (c) the GNU Affero General Public License v3 (AGPLv3)".
# RSALv2 has no SPDX identifier. REDISCONTRIBUTIONS.txt:1-9: "portions of Redis
# Open Source remain available subject to the BSD-3-Clause License", so that is
# AND-ed. Code compiled in with its own notice, each read from its header:
#   BSD-2-Clause  deps/jemalloc/COPYING (Linux builds), deps/linenoise,
#                 deps/xxhash/LICENSE, deps/tre/LICENSE, src/lzf_c.c:1-12
#   BSD-3-Clause  deps/hiredis/COPYING
#   MIT           deps/lua/COPYRIGHT
#   BSL-1.0       deps/fpconv/LICENSE.txt
#   CC0-1.0       deps/hdr_histogram/COPYING.txt
license = "(LicenseRef-RSALv2 OR SSPL-1.0 OR AGPL-3.0-only) AND BSD-3-Clause AND BSD-2-Clause AND MIT AND BSL-1.0 AND CC0-1.0"

versions {
  github = "redis/redis"
}

dependencies = {
  # BUILD_TLS=yes below links libssl and libcrypto.
  "openssl.org" = "^3"
}

distributable {
  # GitHub's archive of the tag.
  url              = "https://github.com/redis/redis/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 4780701 bytes. ⚠ A SINGLE-HOST CHAIN, stated: GitHub's generated archive of
  # the 8.10.3 tag, no signature, fetched twice independently with the same digest.
  sha256 = {
    "8.10.3" = "85ae62e175cc76f638015fa18cb384b549b6808a765425d9e9d47466f69532ea"
  }
}

build {
  dependencies = {
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  env = {
    ARGS = [
      "PREFIX={{prefix}}",

      # ⛔⛔ 1. TLS, NAMED. Default no; `yes` links libssl and libcrypto
      # (src/Makefile:343-351), `module` builds redis-tls.so (:352-356). The
      # Darwin branch defaults OPENSSL_PREFIX to a Homebrew path (:205, :208);
      # this one overrides it (:271-275).
      "BUILD_TLS=yes",
      "OPENSSL_PREFIX={{deps.openssl.org.prefix}}",

      # ⛔⛔ 2. systemd, REFUSED (:282-306).
      "USE_SYSTEMD=no",

      # Defaults of "no", named so a change of default shows here:
      "BUILD_COMPRESSION=no", # :156-171 replication compression, would need libzstd
      "USE_BACKTRACE=no",     # :193-194
      # tcmalloc is refused by not setting USE_TCMALLOC (:93-99); the allocator
      # is the Makefile's, jemalloc (bundled, static) on Linux and libc
      # elsewhere (:82-86), and the test reads it back.
      #
      # SKIP_VEC_SETS is left at its default of "no" (:58): the vector-sets
      # module in modules/vector-sets is compiled INTO the server (:359-362).
      # The tarball carries it, so it needs no network.
    ]
  }

  # src/ only, not the top-level goals: see the header's fourth finding.
  script = [
    "make --jobs {{ hw.concurrency }} -C src all $ARGS",
    "make -C src install $ARGS",
  ]
}

provides = [
  "bin/redis-benchmark",
  "bin/redis-check-aof",
  "bin/redis-check-rdb",
  "bin/redis-cli",
  "bin/redis-sentinel",
  "bin/redis-server",
]

test {
  script = [
    "redis-server --version",
    "test -z \"$(find {{prefix}} -name '*.service' -o -name '*.plist')\"",
    {
      run = <<EOT
set -eu
D="$(mktemp -d)"
trap 'redis-cli -s "$D/r.sock" shutdown nosave >/dev/null 2>&1 || true; rm -rf "$D"' EXIT
redis-server --port 0 --unixsocket "$D/r.sock" --dir "$D" --save "" --daemonize yes --pidfile "$D/r.pid" --logfile "$D/r.log"
i=0
until redis-cli -s "$D/r.sock" ping >/dev/null 2>&1; do
  i=$((i + 1)); test "$i" -lt 50
  sleep 0.2
done
test "$(redis-cli -s "$D/r.sock" set k v)" = OK
test "$(redis-cli -s "$D/r.sock" get k)" = v
# TLS: the tls-* settings exist only when BUILD_TLS=yes compiled them in.
redis-cli -s "$D/r.sock" config get tls-port | grep -q tls-port
# Vector sets are compiled in.
redis-cli -s "$D/r.sock" command info vadd | grep -qi vadd
# The allocator is the Makefile's choice: jemalloc on Linux, libc elsewhere.
case "$(uname -s)" in
  Linux) redis-cli -s "$D/r.sock" info memory | grep -q 'mem_allocator:jemalloc' ;;
  *)     redis-cli -s "$D/r.sock" info memory | grep -q 'mem_allocator:libc' ;;
esac
# systemd is not linked.
case "$(uname -s)" in
  Linux) ! ldd "$(command -v redis-server)" | grep -q libsystemd ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Makefile",                       # :12 the default goal, :17-19 modules are chosen by what is cloned, :88-92 install recurses into src
    "scripts/build.sh",               # :7-9 the tokens, :31-34 cloned modules, :35 `make -C src all`
    "src/Makefile",                   # :58 SKIP_VEC_SETS, :82-107 the allocator, :156-171 compression, :282-306 systemd, :343-356 TLS, :359-362 vector sets, :573-580 install
    "TLS.md",                         # the TLS default and the flags
    "LICENSE.txt",                    # :1-9 the tri-licence
    "REDISCONTRIBUTIONS.txt",         # :1-9 the BSD-3-Clause portions
    "deps/lua/COPYRIGHT",             # MIT
    "deps/fpconv/LICENSE.txt",        # BSL-1.0
    "deps/hdr_histogram/COPYING.txt", # CC0-1.0
  ]

  consulted = [
    # Read for facts only: URL shape. Nothing copied.
    "pkgxdev/pantry projects/redis.io/package.yml",
  ]

  note = <<EOT
⚠ LICENCE MOVED: Redis 7.2 and earlier are BSD-3-Clause; 8.x offers RSALv2,
SSPLv1 or AGPLv3 (LICENSE.txt:1-9). valkey.io is the BSD-3-Clause fork. The
fragment carried no licence at all.

⚠ NO SIGNATURE read: the digest is GitHub's generated archive of the tag,
fetched twice.

⚠ deps/tre/LICENSE and deps/xxhash/LICENSE were identified as BSD-2-Clause
from their headings, not diffed against the SPDX text.

⛔ NOT BUILT. No session here can run the factory; the Makefile variables and
the test are read from the sources, not run.
EOT
}
