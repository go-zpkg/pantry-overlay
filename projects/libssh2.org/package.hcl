# libssh2.org — the SSH2 client library, and one of the six FRAGMENTS left in
# the base-toolchain closure: `zpkb closure -build -require-standalone
# go-zpkg/base-toolchain` (zpkb v0.87.0) named it as "states no versions, no
# distributable, no build". The fragment declared its two dependencies and
# nothing else, so it resolved only because the upstream pantry was merged
# underneath.
#
# ⛔ WRITTEN FROM LIBSSH2'S OWN FILES (go-zpkg/packages#431), at 1.11.1.
#
# ⭐⭐ THE FINDING IS TWO AUTO-DETECTIONS, AND ONE OF THEM IS SILENT. libssh2
# picks its crypto backend AND decides whether to compress by probing the
# builder, and the default for both is `auto`. Both are pinned below, each with
# the line that makes the pin loud rather than merely present.

summary = "libssh2: a client-side C library implementing the SSH2 protocol"

# BSD-3-Clause: the SPDX line at src/session.c:39 and include/libssh2.h:39.
# COPYING carries the copyright holders (Sara Golemon, Daniel Stenberg and the
# rest) over the same three-clause text.
license = "BSD-3-Clause"

versions {
  # Tags are `libssh2-1.11.1`. Measured 2026-11-19 with `zpkb versions`: seven
  # versions resolve, 1.11.1 FIRST and 1.7.0 last (GitHub releases begin
  # there; older ones exist only on libssh2.org). So the newest resolvable
  # version is the one pinned below, and a consumer asking `*` gets a digest
  # rather than a refusal — the trap kernel.org/linux-headers needed two pins
  # to avoid.
  github = "libssh2/libssh2/releases"
  strip  = ["/^libssh2-/"]
}

dependencies = {
  # Both are LINKED by the installed library, so both are runtime and not
  # build-only: configure.ac:398-410 appends the crypto library and libz to
  # LIBS, and acinclude.m4:862 and configure.ac:170 write `libcrypto` and
  # `zlib` into libssh2.pc's Requires.private — a consumer linking statically
  # needs both.
  "openssl.org" = "^3"
  "zlib.net"    = "^1.2"
}

distributable {
  # The project's own download area rather than a GitHub-generated archive:
  # this is where the signed tarballs are, one `.asc` beside each of .tar.gz,
  # .tar.bz2 and .tar.xz. The .tar.xz is the smallest.
  url              = "https://libssh2.org/download/libssh2-{{version.raw}}.tar.xz"
  strip-components = 1

  # 721700 bytes. Recorded with `zpkb sourcepin --sig auto` and confirmed by a
  # second, independent fetch-and-hash (`curl --fail` + `shasum -a 256`): two
  # paths, one answer. The signature chain is in provenance.note.
  sha256 = {
    "1.11.1" = "9954cb54c4f548198a7cbebad248bdc87dd64bd26185708a294b2b50771e3769"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ THE CRYPTO BACKEND IS CHOSEN BY PROBING, AND THE PROBE TAKES THE
      # FIRST ONE IT FINDS. configure.ac:107-112:
      #
      #   AC_ARG_WITH([crypto], … [Select crypto backend (default: auto)]),
      #     use_crypto=$withval, use_crypto=auto)
      #
      # and :116 runs LIBSSH2_CHECK_CRYPTO over all five of openssl,
      # libgcrypt, mbedtls, wincng and wolfssl. Under `auto` a builder whose
      # OpenSSL is not on the search path but whose libgcrypt is would build a
      # libgcrypt libssh2 and say nothing — a different library behind the
      # same name, varying by builder.
      #
      # ⭐ Naming the backend restricts the probe to it. acinclude.m4:857 is
      #
      #   if test "$use_crypto" = "auto" && test "$found_crypto" = "none" \
      #      || test "$use_crypto" = "$1"; then
      #
      # so with `openssl` only the OpenSSL arm runs, and a miss leaves
      # found_crypto=none, which configure.ac:381-387 turns into a FATAL
      # `AC_MSG_ERROR([Required dependencies are missing.])`.
      "--with-crypto=openssl",
      "--with-libssl-prefix={{deps.openssl.org.prefix}}",

      # ⛔⛔ AND ZLIB IS THE SILENT ONE. configure.ac:149-162:
      #
      #   AC_ARG_WITH([libz], … use_libz=$withval, use_libz=auto)
      #   …
      #     if test "$use_libz" = auto; then
      #       AC_MSG_NOTICE([Cannot find libz, disabling compression])
      #
      # Under `auto`, a missing zlib DISABLES COMPRESSION AND CONTINUES: it
      # never sets libz_errors, so the fatal check at :376-388 never fires
      # and configure exits 0. The dependency above would be declared,
      # staged, and unused, and the artifact would quietly lack a feature the
      # recipe says it has.
      #
      # ⭐ An explicit value takes the other arm, :164-166, which sets
      # libz_errors — and THAT is what reaches the AC_MSG_ERROR. So
      # `--with-libz` is not a restatement of the default; it is the only way
      # to make a missing zlib an error. ⚠ Checked because the error lines
      # themselves use AS_MESSAGE, which only PRINTS: the fatality is a flag
      # they set and a later line reads, and an earlier reading of this file
      # that stopped at the AS_MESSAGE would have trusted a pin that printed
      # "ERROR" and carried on.
      "--with-libz",
      "--with-libz-prefix={{deps.zlib.net.prefix}}",

      # configure.ac:289-299 builds the example programs BY DEFAULT
      # (`[build_examples='yes']`). Nothing installs them, so they are build
      # time and a failure surface for programs this recipe does not ship.
      "--disable-examples-build",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: the install is src/Makefile.am:15 `lib_LTLIBRARIES =
# libssh2.la`, the three headers at Makefile.am:14, and `pkgconfig_DATA =
# libssh2.pc` at Makefile.am:12. There is no bin_PROGRAMS.

test {
  script = [
    "test -f \"{{prefix}}/include/libssh2.h\"",
    "test -f \"{{prefix}}/include/libssh2_sftp.h\"",
    "test -f \"{{prefix}}/include/libssh2_publickey.h\"",
    {
      run = <<EOT
set -eu
ls "{{prefix}}"/lib/libssh2.* >/dev/null 2>&1 \
  || { echo "libssh2 is missing from {{prefix}}/lib" >&2; exit 1; }
test -f "{{prefix}}/lib/pkgconfig/libssh2.pc"
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR BOTH PINS, read off the artifact rather than
    # the build log. libssh2.pc's Requires.private is written by the same
    # lines that make each choice — acinclude.m4:862 appends `libcrypto` only
    # in the OpenSSL arm, configure.ac:170 appends `zlib` only when
    # compression was compiled in. So the file the artifact ships says which
    # backend it was built against and whether zlib is in it:
    #
    #   - dropped --with-crypto and a libgcrypt builder → `libgcrypt`, no
    #     `libcrypto`, and this fails;
    #   - dropped --with-libz and no zlib staged → no `zlib`, and this fails,
    #     where configure itself would have exited 0.
    {
      run = <<EOT
set -eu
pc="{{prefix}}/lib/pkgconfig/libssh2.pc"
req=$(grep '^Requires.private:' "$pc" || true)
case "$req" in
  *libcrypto*) ;;
  *) echo "libssh2 was not built against OpenSSL: $req" >&2; exit 1 ;;
esac
case "$req" in
  *zlib*) ;;
  *) echo "libssh2 was built without zlib compression: $req" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :107-134 the crypto choice and its default; :149-173 zlib and the silent arm; :289-299 examples by default; :374-388 where an error becomes fatal; :398-410 what is linked
    "acinclude.m4",  # :856-865 LIBSSH2_CHECK_CRYPTO, and the one line (:857) that makes naming a backend restrict the probe
    "configure",     # :1567 --with-libssl-prefix, :1578 --with-libz-prefix — the generated option names, checked rather than derived from the macro
    "Makefile.am",   # :12 libssh2.pc, :14 the installed headers
    "src/Makefile.am", # :15 the one installed library
    "COPYING",       # the copyright holders
    "src/session.c", # :39 SPDX-License-Identifier: BSD-3-Clause
    "https://libssh2.org/download/", # the release listing, and the .asc beside every archive
  ]

  note = <<EOT
The source archive is signed, and the signature was checked when this digest
was recorded rather than at every build: the signature's job is to justify
WRITING the hash, and the hash is the durable pin.

  signature  https://libssh2.org/download/libssh2-1.11.1.tar.xz.asc
  key        https://daniel.haxx.se/mykey.asc
  identity   Daniel Stenberg <daniel@haxx.se>
  signed at  2024-10-16T08:03:37Z
  fingerprint 27EDEAF22F3ABCEB50DB9A125CC908FDB71E12C2

How the key was reached, every step a link rather than a guess:

  - https://curl.se/download.html links "PGP Key" to
    https://daniel.haxx.se/address.html — curl and libssh2 share the signer,
    so curl's own page is where the pointer was found;
  - address.html prints the fingerprint above and links /mykey.asc.

⭐ AND A SECOND HOST AGREES ON THE IDENTITY, THOUGH NOT ON THE BYTES.
GitHub's account endpoint was tried first, the route that supplied the key for
rsync.samba.org and for kernel.org/linux-headers: https://github.com/bagder.gpg
returns an armour block with NO key in it and the line

  Note: The keys with the following IDs couldn't be exported and need to be
  reuploaded 5CC908FDB71E12C2

5CC908FDB71E12C2 is the last sixteen digits of the fingerprint above. So
GitHub binds that 64-bit key id to the account `bagder`, independently of
daniel.haxx.se, but cannot serve the key — the bytes verified against come from
daniel.haxx.se alone.

⚠ SO THE RUNG, STATED: the key is NOT on the tarball's host (libssh2.org
against daniel.haxx.se), which is more than continuity; and its 64-bit id is
corroborated by a second organisation; but the full fingerprint and the key
bytes have one publisher. Stronger than a single-host chain, weaker than
rsync.samba.org's, where the whole key was on the owning GitHub account.

No keyserver was asked. address.html also links a keys.openpgp.org search for
the same key; it was not followed, because a keyserver chooses what it returns.
EOT
}
