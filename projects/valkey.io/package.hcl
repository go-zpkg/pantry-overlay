# valkey.io — the Valkey in-memory data store: server, CLI, benchmark, and the
# check-aof / check-rdb / sentinel names. A whole recipe (go-zpkg/packages#440
# step 1): it was a fragment of one dependency.
#
# ⛔ WRITTEN FROM VALKEY'S OWN FILES (go-zpkg/packages#431), at 9.2.0.
#
# WHAT IS INSTALLED: six names under bin/ (src/Makefile:911-924), a default
# configuration file is NOT installed, no service registration (no systemd
# unit, no launchd plist; USE_SYSTEMD=no below), no data directory.
#
# ⭐⭐ WHAT WRITING IT FOUND: src/Makefile probes THREE things on the build
# machine, and the fragment pinned none of them:
#   1. libsystemd (:342-350): USE_SYSTEMD unset means "if pkg-config knows
#      libsystemd, link it" — so a Linux builder with libsystemd-dev produces a
#      server that links libsystemd.so and one without does not.
#   2. the allocator (:76-79): jemalloc on Linux, libc elsewhere, and the
#      bundled jemalloc is configured by deps/Makefile:124 with its own probes.
#   3. USE_REDIS_SYMLINKS (:466) defaults to yes: bin/redis-server, redis-cli…
#      are installed as symlinks to valkey's, which would collide with
#      redis.io's in one prefix. Refused.
# And the OpenSSL fragment only declared the library: BUILD_TLS defaults to no
# (README.md:340), so the server had NO TLS.

summary = "Valkey: an open-source in-memory data store, a Redis fork under BSD-3-Clause"

# COPYING and REUSE.toml: BSD-3-Clause for the project (REUSE.toml:3-7). Files
# compiled in with their own licence, each from REUSE.toml's annotations:
#   MIT           src/setproctitle.c (:10-13), deps/lua (:105-109, the Lua
#                 scripting engine, built static by default), deps/fast_float
#   CC0-1.0       src/sha1.c, sha256.c, siphash.c (:27-37), deps/hdr_histogram
#                 (CC0-1.0 AND BSD-2-Clause, :100-103)
#   Zlib          src/crcspeed.c, crccombine.c (:45-55)
#   ISC           src/strl.c (:57-61)
#   BSD-2-Clause  src/lzf*.c (:69-73), deps/linenoise, deps/lz4, and
#                 deps/jemalloc (compiled on Linux only)
#   BSL-1.0       deps/fpconv (:117-121)
# NOT added: deps/gtest-parallel (Apache-2.0), which REUSE.toml:128 says is
# "Development/testing dependency only. Not present in compiled binaries."
license = "BSD-3-Clause AND MIT AND CC0-1.0 AND Zlib AND ISC AND BSD-2-Clause AND BSL-1.0"

versions {
  github = "valkey-io/valkey"
}

dependencies = {
  # BUILD_TLS=yes below links libssl and libcrypto (src/Makefile:403-407).
  "openssl.org" = "^3"
}

distributable {
  # GitHub's archive of the tag: the release attaches no signed tarball this
  # recipe reads, and the tag is the source of record.
  url              = "https://github.com/valkey-io/valkey/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 5219426 bytes. ⚠ A SINGLE-HOST CHAIN, stated: GitHub's generated archive of
  # the 9.2.0 tag, no signature, fetched twice independently with the same digest.
  sha256 = {
    "9.2.0" = "a02cb44db1269b699629e419d4949e6e51e984b1f0e9a984e8ee1e1b3b7cc36f"
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

      # ⛔⛔ 1. TLS, NAMED. Default no (README.md:340); `yes` links libssl and
      # libcrypto (src/Makefile:403-407), `module` builds valkey-tls.so instead.
      # On macOS the Makefile hard-codes a Homebrew OPENSSL_PREFIX (:182-185);
      # this one overrides it.
      "BUILD_TLS=yes",
      "OPENSSL_PREFIX={{deps.openssl.org.prefix}}",

      # ⛔⛔ 2. systemd, REFUSED. Unset, :342-350 links libsystemd if
      # pkg-config finds it.
      "USE_SYSTEMD=no",

      # ⛔⛔ 3. no redis-* symlinks (:466-468, :919-924).
      "USE_REDIS_SYMLINKS=no",

      # The rest are defaults of "no", named so a change of default shows here:
      "BUILD_ZSTD=no",        # :263, would need a STATIC libzstd
      "BUILD_RDMA=no",        # :427-440, librdmacm and libibverbs
      "USE_LTTNG=no",         # :379-382
      "USE_LIBBACKTRACE=no",  # :700
      # tcmalloc is refused by not setting USE_TCMALLOC (:87-93). The
      # allocator is the Makefile's own choice, jemalloc (bundled, static) on
      # Linux and libc elsewhere (:76-79), and the test reads it back.
      #
      # BUILD_LUA is left at its default, a static Lua module (:322-333); the
      # bundled Lua is compiled in, not a system one.
    ]
  }

  script = [
    "make --jobs {{ hw.concurrency }} $ARGS",
    "make install $ARGS",
  ]
}

provides = [
  "bin/valkey-benchmark",
  "bin/valkey-check-aof",
  "bin/valkey-check-rdb",
  "bin/valkey-cli",
  "bin/valkey-sentinel",
  "bin/valkey-server",
]

test {
  script = [
    "valkey-server --version",
    "test ! -e \"{{prefix}}/bin/redis-server\"",
    "test -z \"$(find {{prefix}} -name '*.service' -o -name '*.plist')\"",
    # The settings the recipe pinned, read back from the server it built.
    {
      run = <<EOT
set -eu
D="$(mktemp -d)"
trap 'valkey-cli -s "$D/v.sock" shutdown nosave >/dev/null 2>&1 || true; rm -rf "$D"' EXIT
valkey-server --port 0 --unixsocket "$D/v.sock" --dir "$D" --save "" --daemonize yes --pidfile "$D/v.pid" --logfile "$D/v.log"
i=0
until valkey-cli -s "$D/v.sock" ping >/dev/null 2>&1; do
  i=$((i + 1)); test "$i" -lt 50
  sleep 0.2
done
test "$(valkey-cli -s "$D/v.sock" set k v)" = OK
test "$(valkey-cli -s "$D/v.sock" get k)" = v
# TLS: the tls-* settings exist only when BUILD_TLS=yes compiled them in.
valkey-cli -s "$D/v.sock" config get tls-port | grep -q tls-port
# The allocator is the Makefile's choice: jemalloc on Linux, libc elsewhere.
case "$(uname -s)" in
  Linux) valkey-cli -s "$D/v.sock" info memory | grep -q 'mem_allocator:jemalloc' ;;
  *)     valkey-cli -s "$D/v.sock" info memory | grep -q 'mem_allocator:libc' ;;
esac
# systemd is not linked.
case "$(uname -s)" in
  Linux) ! ldd "$(command -v valkey-server)" | grep -q libsystemd ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "src/Makefile",      # :65 PREFIX, :76-101 the allocator, :182-185 the Homebrew OpenSSL prefix, :263-299 zstd, :302-334 Lua, :336-361 systemd, :379 lttng, :403-417 TLS, :419-440 RDMA, :466-468 redis symlinks, :700 libbacktrace, :911-924 install
    "deps/Makefile",     # :124 the bundled jemalloc's configure line
    "README.md",         # :32-36 BUILD_TLS, :54 USE_SYSTEMD, :69 BUILD_LUA, :340 the TLS default
    "REUSE.toml",        # :3-128 every licence, by path
    "COPYING",           # BSD-3-Clause
    "LICENSES",          # the texts REUSE.toml cites
  ]

  consulted = [
    # Read for facts only: URL shape and that TLS was wanted.
    "pkgxdev/pantry projects/valkey.io/package.yml",
  ]

  note = <<EOT
⚠ THE ARCHIVE'S OWN AGENTS.md is addressed to contributors of the repository
and was not followed; nothing in it concerns a build.

⚠ NO SIGNATURE read: the digest is GitHub's generated archive of the tag,
fetched twice.

⛔ NOT BUILT. No session here can run the factory; the Makefile variables and
the test are read from the sources, not run.
EOT
}
