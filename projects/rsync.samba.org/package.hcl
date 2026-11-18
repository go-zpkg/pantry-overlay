# rsync.samba.org — and it is the recipe where this campaign's own heuristic
# turns out to be WRONG.
#
# ⛔ WRITTEN FROM RSYNC'S OWN FILES (go-zpkg/packages#431), at 3.5.2, read out
# of the signed release tarball.
#
# ⭐ WHY IT MATTERS HERE: `kernel.org/linux-headers` is a go-zpkg/base-toolchain
# MEMBER and its build needs rsync — recorded in go-zpkg/recipes#126, where the
# linux-headers recipe found it. A member's build dependency is as direct a
# blocker for go-zpkg/packages#440's measurement as a member itself.
#
# ⛔⛔ AND THE HEADLINE IS A REVERSAL. The five recipes before this one —
# cmake.org, python.org, gettext, and before them nghttp2 and ncurses — all
# moved the same way: a project vendors a library, we have the real one, point
# it at ours. Here that would BREAK THE WIRE PROTOCOL, and only the project's
# own file says so. See `--with-included-zlib` below.

summary = "rsync: fast incremental file transfer, over a remote shell or its own daemon"

# ⛔ GPLv3 WITH AN ADDITIONAL PERMISSION, AND COPYING LEADS WITH IT RATHER THAN
# WITH THE LICENCE. Its first line is "REGARDING OPENSSL AND XXHASH", followed
# by "as a special exception, the copyright holders give permission to link the
# code of this program with …" — the OpenSSL linking exception, needed because
# `--enable-openssl` below links a library whose licence GPLv2 considered
# incompatible. The GPL text itself begins at COPYING:11, "Version 3,
# 29 June 2007".
#
# SPDX has no identifier for this exception, and an additional PERMISSION does
# not change which licence governs, so the expression is the GPL alone. The
# exception is named here because a reader auditing the OpenSSL link needs to
# know it was granted deliberately.
license = "GPL-3.0-or-later"

platforms = ["linux", "darwin", "freebsd", "openbsd", "netbsd"]

versions {
  url   = "https://download.samba.org/pub/rsync/src/"
  match = "/rsync-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^rsync-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://download.samba.org/pub/rsync/src/rsync-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1977884 bytes, recorded with the builder's own fetcher and a verified
  # signature:
  #
  #   zpkb sourcepin --sig auto --key ./steadytao.gpg \
  #     --fingerprint "C0E1 0545 0570 4F75 7D92 5AB2 6A64 E8AA 2EFB CF5D" \
  #     --key-source "<see provenance>" --version 3.5.2 \
  #     https://download.samba.org/pub/rsync/src/rsync-3.5.2.tar.gz
  #
  #   signed by C0E1054505704F757D925AB26A64E8AA2EFBCF5D
  #   Zen Dodd <mail@steadytao.com>
  #   no keyserver was asked
  #   2 key(s) read from the file
  sha256 = {
    "3.5.2" = "a10d591825251e070f74c98df3daad195def4ed81b4a2de16169026aea33f6c8"
  }
}

build {
  dependencies = {
    # --enable-openssl below. The OpenSSL linking exception at the top of
    # COPYING exists for exactly this.
    "openssl.org" = "^3"

    # --enable-zstd and --enable-lz4 below. Both are wire compression
    # algorithms rsync negotiates, so a peer that has them and a peer that
    # does not simply agree on something else — unlike zlib, see below.
    "facebook.com/zstd" = ">=1.5"
    "lz4.org"           = "*"
  }

  # ⛔⛔ THE CENSUS, AND THE FIRST ENTRY IS THE ONE THAT MATTERS MOST BECAUSE IT
  # GOES THE OTHER WAY. 51 distinct `--with|--without|--enable|--disable`
  # switches were read out of `configure.sh`; what follows states every one
  # whose default is not a deterministic constant, plus the two vendoring
  # decisions.
  #
  # ⛔⛔ zlib STAYS VENDORED, AND IT IS A PROTOCOL REQUIREMENT RATHER THAN
  # LAZINESS. `zlib/README.rsync` — a file the project ships for exactly this
  # question — opens in capitals:
  #
  #     READ THIS BEFORE TRYING TO DYNAMICALLY LINK RSYNC AND ZLIB!
  #
  #     zlib has been adapted slightly for use in rsync. … add Z_INSERT_ONLY
  #     to allow for efficient history updating without actually emitting any
  #     data. …
  #
  #     As a result of the first item, the streams from rsync's version of
  #     zlib are *not compatible* with those produced by the upstream version
  #     of rsync.  In other words, if you link rsync against your system's
  #     copy, it will not be able to interoperate with any other version if
  #     the -z option is used.  (Sorry.  Sometimes standard is better than
  #     better.)
  #
  # So pointing this at `zlib.net` — which this tree HAS, and which every
  # instinct built up over the last five recipes says to do — would produce an
  # rsync that cannot talk to any other rsync with `-z`. `zlib.net` is
  # therefore NOT declared above, and the vendoring is passed EXPLICITLY so
  # that it reads as a decision with a citation rather than as a default
  # nobody questioned.
  #
  # ⭐ THE LESSON, WORTH MORE THAN THE FLAG: "vendored is wrong" is a
  # heuristic, not a rule, and the thing that distinguishes the cases is the
  # project's own files. cmake.org's twelve are convenience copies;
  # python.org's expat was a declared dependency the build ignored; this one is
  # a fork with a wire-format change. Nothing but `zlib/README.rsync` separates
  # the third case from the first two, and `configure.ac:475` alone — "We
  # default to using our zlib" — would have read as laziness.
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ See the long note above. configure.ac:475-480 would default this to
      # `yes` anyway; it is stated so the reason travels with it.
      "--with-included-zlib=yes",

      # ⚠ popt IS VENDORED TOO, BUT FOR A DIFFERENT AND WEAKER REASON — and
      # saying so keeps the two apart. configure.ac:1184-1185: unless forced,
      # it runs `AC_CHECK_LIB(popt, poptGetContext)` and falls back to the
      # bundled copy when that fails. There is no popt recipe in this tree, so
      # the bundled copy is what we would get BY ACCIDENT OF ABSENCE. Passed
      # explicitly so it is a decision; a popt recipe is the reason to revisit,
      # and unlike zlib there is no protocol argument against it.
      "--with-included-popt=yes",

      # The three libraries this tree provides, stated rather than detected.
      # Each is auto-detected otherwise, so without these the artifact's
      # feature set would depend on what was staged.
      "--enable-openssl",
      "--enable-zstd",
      "--enable-lz4",

      # ⛔ THREE OPTIONAL LIBRARIES THIS TREE DOES NOT HAVE, settled OFF so
      # their absence is a decision and not a silent probe failure:
      #
      #   xxhash  faster checksums (configure.ac:574-580 probes xxhash.h)
      #   libidn2 internationalised hostnames
      #   libacl / libattr  what `rsync -A` and `rsync -X` need
      #
      # ⚠ THE ACL AND XATTR ONES ARE A REAL CAPABILITY LOSS AND ARE NAMED AS
      # SUCH: this rsync will not preserve POSIX ACLs or extended attributes,
      # because libacl and libattr have no recipe here. The alternative is a
      # build whose `-A` support depends on the machine, which is worse. The
      # fix is two recipes, not a flag.
      "--disable-xxhash",
      "--disable-idn",
      "--disable-acl-support",
      "--disable-xattr-support",

      # ⚠ iconv's DEFAULT IS DERIVED, not constant: configure.ac:1082-1084 sets
      # it from `$enable_iconv_open`, i.e. from whether `iconv_open` was found.
      # Enabled explicitly — the `--iconv` option is user-visible, and on our
      # platforms the function is present without a declared dependency (in
      # libc on glibc, in the system libiconv on darwin and the BSDs).
      "--enable-iconv",

      # ⚠ Upstream's default, RESTATED: configure.ac:458-464 defines
      # CONFIG_LOCALE unless `--disable-locale` is given. A constant, named
      # because it is user-visible behaviour.
      "--enable-locale",
    ]

    # ⛔⛔ TWO OPTIMISATION SWITCHES ARE ARCHITECTURE-SPECIFIC, AND ONE OF THEM
    # ERRORS OUT WHERE IT DOES NOT APPLY — so they cannot go in the list above.
    #
    # configure.ac:331-335: given `--enable-roll-simd` off x86_64, configure
    # calls AC_MSG_ERROR("The rolling-checksum SIMD optimizations are currently
    # x86_64|amd64 only"). A flag that aborts the build on aarch64 and s390x is
    # not a flag the common arm can carry.
    #
    # ⭐ AND THE SEVERITY IS THE *GOOD* KIND, which is worth stating because
    # this campaign has met the bad kind. sourceware.org/libffi
    # (go-zpkg/recipes#154) tunes itself to the BUILDER'S CPU and produces an
    # artifact that SIGILLs elsewhere. rsync's SIMD is the opposite:
    # configure.ac:280-290 compiles a probe using
    # `__attribute__((target("ssse3")))`, `("sse2")` and `("avx2")` — function
    # multi-versioning, so the binary carries ALL THREE variants and dispatches
    # on the CPU AT RUN TIME. The probe reads the COMPILER's capability, not
    # the machine's. That is the libpng.org class — reproducible — and passing
    # the flag makes it fail-closed: either the optimisation is in the
    # artifact or configure stops.
    #
    # ⚠ `--enable-md5-asm`'s default is PLATFORM *AND* ARCH dependent, which is
    # the shape this campaign treats as worse than a plain default.
    # configure.ac:526-534: unset, it becomes `no` on everything except linux,
    # and then requires host_cpu x86_64 or amd64. So the same recipe would put
    # MD5 assembly in a linux/x86-64 artifact and not in a darwin/x86-64 one,
    # decided by `$host_os`. Settled on both arms below.
  }

  # ⛔ THE TWO ARCH-SPECIFIC FLAGS ARE ADDED IN THE SCRIPT, NOT IN A KEYED
  # `env`, AND THAT IS DELIBERATE. A platform- or arch-keyed ARGS REPLACES the
  # list rather than extending it — the same "a list must replace" rule that
  # `ignore` follows in python.org — so keying these two would mean repeating
  # all fourteen flags above across six platform/arch combinations, with six
  # chances to drop one. llvm.org:102-108 solves it the same way, with a shell
  # conditional on {{hw.arch}}.
  #
  # ⭐ BOTH ARMS ARE EXPLICIT. Leaving the non-x86-64 arm silent would put the
  # recipe back where it started: md5-asm's default is not a constant, so "not
  # passing it" is not a decision.
  script = [
    {
      run = <<EOT
# rolling-checksum SIMD: x86_64 only, and configure ABORTS if asked for it
# elsewhere (configure.ac:331-335). Function multi-versioning, so the binary
# carries ssse3/sse2/avx2 variants and dispatches at run time — portable.
if test "{{hw.arch}}" = "x86-64"; then
  ARGS="$ARGS --enable-roll-simd"
else
  ARGS="$ARGS --disable-roll-simd"
fi

# MD5 assembly: configure.ac:534 requires host_cpu x86_64|amd64, and :527-530
# makes the unset default depend on $host_os being linux. Stated on both arms
# so neither the platform nor the arch decides it.
if test "{{hw.arch}}" = "x86-64"; then
  ARGS="$ARGS --enable-md5-asm"
else
  ARGS="$ARGS --disable-md5-asm"
fi
EOT
    },
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ READ FROM Makefile.in's INSTALL RULE, :128-143:
#
#   :130  rsync$(EXEEXT)            always
#   :131  $(srcdir)/rsync-ssl       always
#   :143  rrsync                    only under $(with_rrsync)
#
# ⚠ `rrsync` IS DELIBERATELY ABSENT. configure.ac:171-178 defaults
# `--with-rrsync` to `no`, and the tarball ships only `rrsync.1` and
# `rrsync.1.html` at the root — the script itself is generated. Listing it
# would make `provides` describe a build this recipe does not do.
#
# ⚠ AND `rsync-ssl` IS A BASH SCRIPT, not a binary: its first line is
# `#!/usr/bin/env bash`. That is a runtime dependency on bash, which is a
# go-zpkg/base-toolchain member, so it is satisfied — named because a `provides`
# entry gives no hint of it.
provides = [
  "bin/rsync",
  "bin/rsync-ssl",
]

test {
  script = [
    # ⭐ `--version` IS NOT A FORMALITY HERE: rsync prints its optimisation and
    # library feature set, so this line is where every flag above becomes
    # visible. A dropped `--enable-zstd` shows up as a missing capability
    # rather than as a silent behaviour change.
    "\"{{prefix}}/bin/rsync\" --version",

    # ⛔ THE FEATURES THIS RECIPE PAID FOR MUST BE THERE. rsync --version lists
    # them explicitly, so each declared library is asserted by name. A probe
    # that stopped finding one would otherwise produce a working rsync that
    # silently cannot use the algorithm a peer offers.
    {
      run = <<EOT
set -e
v=$("{{prefix}}/bin/rsync" --version)
for want in zstd lz4; do
  printf '%s' "$v" | grep -qi "$want" || {
    echo "rsync: --version does not list $want, but the recipe passed --enable-$want." >&2
    echo "  configure auto-detects these; a probe that stopped finding the" >&2
    echo "  library leaves a working rsync that cannot use the algorithm a" >&2
    echo "  peer offers. Check the matching dependency." >&2
    exit 1
  }
done
EOT
    },

    # ⭐ AND A REAL TRANSFER, because --version establishes nothing about
    # whether the thing copies files. Local-mode rsync with -z exercises the
    # vendored zlib, which is the decision this recipe is built around.
    {
      run = <<EOT
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/src/sub"
i=0
while [ $i -lt 50 ]; do
  echo "line $i of a compressible file" >> "$d/src/sub/a.txt"
  i=$((i + 1))
done
printf 'second\n' > "$d/src/b.txt"
"{{prefix}}/bin/rsync" -a -z "$d/src/" "$d/dst/"
cmp "$d/src/sub/a.txt" "$d/dst/sub/a.txt"
cmp "$d/src/b.txt" "$d/dst/b.txt"
# And the incremental half: a second run must transfer nothing new.
"{{prefix}}/bin/rsync" -a -z --stats "$d/src/" "$d/dst/" > "$d/stats.txt"
grep -q "Number of regular files transferred: 0" "$d/stats.txt"
EOT
    },
  ]
}

provenance {
  read = [
    "COPYING",            # :1 "REGARDING OPENSSL AND XXHASH" and the special exception; :11 "Version 3, 29 June 2007"
    "configure.ac",       # the switch census; :171-178 --with-rrsync defaults no; :181-185 the two --with-included-* declarations; :280-290 the SIMD probe's target attributes; :326-335 the x86_64-only error; :432-440 ipv6; :458-464 locale; :475-480 "We default to using our zlib"; :523-535 md5-asm's platform+arch default; :555-570 roll-asm; :574-580 the xxhash probe; :1082-1084 iconv derived from enable_iconv_open; :1184-1198 popt falling back to the bundled copy
    "configure.sh",       # the generated script, read for the 51-switch census rather than trusting configure.ac's macros
    "zlib/README.rsync",  # THE file that reverses this recipe's vendoring decision — quoted in full in the build block
    "Makefile.in",        # :128-143 the install rule: rsync, rsync-ssl always, rrsync conditionally
    "rsync-ssl",          # :1 `#!/usr/bin/env bash` — a script, not a binary
    "INSTALL.md",         # checked for a bundled-zlib note and found NONE, which is why zlib/README.rsync had to be looked for separately
  ]

  consulted = [
    # Read for the SIGNING KEY only, never for the build.
    "gentoo sec-keys/openpgp-keys-zendodd-20261107.ebuild (DESCRIPTION, HOMEPAGE, fingerprint)",
  ]

  note = <<EOT
⭐⭐ THE STRONGEST CHAIN THIS CAMPAIGN HAS RECORDED — FOUR PARTIES OVER THREE
HOSTS, and it is stronger than gnu.org/gettext's two:

  fingerprint, 1st source  rsync.samba.org/download.html, the PROJECT's own
                           download page, under "Release signing keys":
                           C0E1054505704F757D925AB26A64E8AA2EFBCF5D
  fingerprint, 2nd source  gentoo sec-keys/openpgp-keys-zendodd declares the
                           SAME fingerprint, with DESCRIPTION "OpenPGP keys
                           used by Zen Dodd" and HOMEPAGE citing that page —
                           an independent party, not the project
  key bytes                github.com/steadytao.gpg — GitHub's ACCOUNT
                           endpoint, which binds the key to the account that
                           publishes it. NOT a keyserver.
  tarball + signature      download.samba.org/pub/rsync/src/

Verified: `Zen Dodd <mail@steadytao.com>`, 2 keys read from the file, no
keyserver asked. This is the `github.com/besser82/libxcrypt` tier — an
independently published key bound to the owning account — and it is the only
recipe here where the fingerprint has two independent sources AND the key has a
non-keyserver home AND the tarball is on a third host.

⛔⛔ AND A FINDING THE PROJECT SHOULD FIX: ITS OWN KEY LINK IS THE WRONG FILE.
rsync.samba.org/download.html links `https://opencoder.net/WayneDavison.key`
beside the fingerprints. Measured 2026-11-18:

  the file holds TWO armoured blocks, headed `Version: PGP Key Server 0.9.6`
  and `Version: 2.6.2` — PGP 2.6.2 is from 1994
  neither published fingerprint is in it (sourcepin walked 1 primary key for
  each and found no match)
  reading it whole fails outright:
    "openpgp: invalid data: user ID self-signature invalid: openpgp: invalid
     signature: DSA verification failure"

So a session that follows the page's own key link cannot verify the signature,
and the error it gets ("no key with fingerprint … in the key file") reads as a
WRONG FINGERPRINT rather than as the wrong file. ⚠ That is the trap
gnu.org/glibc's note warns about from the other side — "An absence that might
be a failure to read is not an absence" — and the thing that broke the deadlock
was asking a DIFFERENT question: not "is the fingerprint in this file" but
"where else does this account publish its key".

⭐ Wayne Davison was rsync's maintainer for two decades; the key file is his,
and it is simply historical. The current release manager is Zen Dodd, whose key
the page names by fingerprint and does not host.

⛔ AND THE HOST WAS DOWN WHEN THIS WAS FIRST ATTEMPTED, which is recorded
because the conclusion could so easily have been "rsync cannot be pinned".
Measured around 15:45-15:51 CET: rsync.samba.org answered 200 while
download.samba.org answered 000 and 504 on three different paths. Six hours
later both were 200. A transport failure is not a property of a project.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every switch, dependency, installed path and licence
traced to a line in rsync's own files and cited in `read` above.
EOT
}
