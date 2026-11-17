# facebook.com/zstd — Zstandard, the compression library 16 recipes in this
# tree link and the `zstd` command line around it.
#
# ⛔ WRITTEN FROM ZSTD'S OWN FILES (go-zpkg/packages#431), at 1.5.7. Second of
# the twenty-two that go-zpkg/recipes#143 measured, after openssl.org (#145),
# and chosen by counting consumers rather than by instinct: 16 recipes name it,
# behind only gnu.org/gettext's 26 — and that one leads for a reason that is
# partly an artefact, since glibc exports the gettext symbols itself and ten
# projects declare it on linux where nothing links -lintl (measured 2026-10-28,
# recorded on #143).
#
# ⚠ pkgxdev/pantry's recipe for this project was NOT opened. That tree carries
# no licence (go-zpkg/packages#431), so it may neither be copied nor translated;
# `consulted` is empty on purpose rather than by omission.

summary = "Zstandard: fast real-time compression — libzstd and the zstd command"

# ⛔ DUAL-LICENSED, AND THE PROJECT SAYS SO IN ONE SENTENCE. README.md:230:
# "Zstandard is dual-licensed under [BSD](LICENSE) OR [GPLv2](COPYING)."
# Both files ship. LICENSE is the THREE-clause BSD — :17 carries the third,
# "Neither the name Facebook, nor Meta, nor the names of its contributors" —
# which is what separates BSD-3-Clause from BSD-2-Clause, so the clause was
# read rather than the heading. COPYING is the plain GPLv2 text ("Version 2,
# June 1991") with no "or later" anywhere, and the README says "GPLv2" rather
# than "GPLv2+", so the identifier is -only.
license = "BSD-3-Clause OR GPL-2.0-only"

# ⛔⛔ THIS BLOCK WAS MEASURED, NOT WRITTEN FROM THE TAG NAMES — the mistake
# openssl.org's first draft made two hours earlier. zstd's GitHub release NAMES
# are not uniform, and three shapes live side by side:
#
#     Zstandard v1.5.7            ← a release
#     Zstandard v1.5.7-kernel     ← the version vendored into the linux kernel
#     Zstandard v1.5.6 - Chrome Edition
#     v1.5.2-kernel               ← older, without the "Zstandard " prefix
#
# A bare `strip = "/^Zstandard v/"` therefore yields `1.5.6 - Chrome Edition`
# and `1.5.7-kernel` as if they were versions.
versions {
  github = "facebook/zstd/releases"

  # ⛔⛔ AND THE FIRST ATTEMPT AT THIS DROPPED A REAL RELEASE. " - Chrome
  # Edition" was first written as an `ignore`, which is the obvious reading of
  # "that is not a version" — and measuring it showed the list going
  # 1.5.7, 1.5.5, 1.5.4: **1.5.6 was gone entirely**, because that release's
  # ONLY name carries the suffix. The suffix is decoration on a real version,
  # so it is STRIPPED. An ignore would have made 1.5.6 unresolvable for every
  # consumer, silently, and `^1` would still have looked healthy because 1.5.7
  # exists.
  strip = [
    "/^Zstandard v/",
    "/ - .*$/",
    "/^v/",
  ]

  ignore = [
    # The kernel drops. They are the snapshot the linux tree carries, not a
    # release of the library this tree links — a different artefact under a
    # similar name, which is the case `ignore` is actually for.
    "/-kernel$/",
  ]
}

distributable {
  url              = "https://github.com/facebook/zstd/releases/download/v{{version.raw}}/zstd-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2434947 bytes, recorded with `zpkb sourcepin --version 1.5.7`, and
  # confirmed by an independent `curl` + `shasum -a 256` giving the same value.
  sha256 = {
    "1.5.7" = "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3"
  }

  # ⛔⛔ A SIGNATURE IS PUBLISHED AND IS DELIBERATELY NOT USED, which is the
  # opposite of what this tree managed for gnu.org/gzip and openssl.org, and
  # the reason is worth more than the signature would have been.
  #
  # zstd ships a detached signature beside the tarball — 858 bytes at
  # https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz.sig
  # — and publishes NO trust anchor for it. Looked for on 2026-11-17, three
  # surfaces, all negative:
  #
  #   README.md at v1.5.7      no "gpg", "pgp", "signature", "fingerprint" or
  #                            "public key" anywhere
  #   the release notes        releases.atom carries no "gpg", "pgp" or
  #                            "fingerprint"
  #   the repository root      the v1.5.7 tree has no KEYS, *.asc, *.gpg or
  #                            pubkey file
  #
  # ⛔ `--key-source` is mandatory here and no keyserver is ever asked, for the
  # reason Guix's `--key-download=auto` fails: in CI it fetches an unknown key
  # and accepts it, so the check degrades to "somebody signed it". With no
  # published fingerprint there is nothing a keyserver answer could be checked
  # AGAINST — Debian's uscan(1) puts it as an instruction rather than a
  # procedure: "You must verify the downloaded OpenPGP key using its full
  # fingerprint value WHICH YOU KNOW is the trusted one." Here there is nothing
  # to know.
  #
  # So the digest above is pinned and is the durable warrant, and this comment
  # records that a signature exists, where its anchor was looked for, and that
  # the gap is upstream's rather than ours. If zstd ever publishes a
  # fingerprint, this becomes a `sourcepin --sig --key --key-source
  # --fingerprint` run and a provenance block like openssl.org's.
}

# ⚠ NO RUNTIME DEPENDENCIES, and for this project that is a DECISION rather
# than an observation — see the three pinned probes in `build` below.

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      # programs/Makefile:382 and lib/Makefile:281 both default
      # `prefix ?= /usr/local`.
      "PREFIX={{prefix}}",

      # ⛔⛔ THE THREE PROBES THAT DECIDE WHAT THIS BINARY LINKS, PINNED.
      # programs/Makefile:78, :89 and :100 each define their flag as a
      # COMPILE-AND-LINK PROBE against whatever is staged:
      #
      #   HAVE_ZLIB ?= $(shell … $(CC) … -lz 2> /dev/null && echo 1 || echo 0)
      #   HAVE_LZMA ?= $(shell … -llzma …)
      #   HAVE_LZ4  ?= $(shell … -llz4 …)
      #
      # and :79-85, :90-96, :101-107 turn each one into both a FEATURE
      # (-DZSTD_GZCOMPRESS and friends) and a LINK (-lz, -llzma, -llz4, reaching
      # the binary through `zstd : LDLIBS +=` at :139).
      #
      # ⛔ So without these three lines the artifact's capabilities AND its
      # DT_NEEDED list are decided by what the sandbox happened to contain. Two
      # builds of this recipe on two machines would differ in what `zstd` can
      # open, and a build where zlib/xz/lz4 were staged would link three
      # libraries this recipe declares no runtime dependency on — which starts
      # as an `unlinked` finding and ends as a binary that cannot start in a
      # FROM-scratch image.
      #
      # ⭐ `?=` is the project's own lever, so pinning costs nothing and needs
      # no patch. Zero is chosen rather than one because the 16 recipes that
      # name this project link LIBZSTD — binutils, llvm.org, python.org,
      # mysql.com, boost.org, systemd.io — and none of them needs the CLI to
      # read a .gz. Turning them on is a real option (this tree already has
      # zlib.net, tukaani.org/xz and lz4.org) but it is a DIFFERENT recipe: it
      # must also declare three runtime dependencies, and that is a decision to
      # make deliberately rather than inherit from a probe.
      "HAVE_ZLIB=0",
      "HAVE_LZMA=0",
      "HAVE_LZ4=0",
    ]
  }

  # ⚠ NO `--libdir` EQUIVALENT IS NEEDED, and that was checked rather than
  # assumed, because openssl.org needed one three hours ago: lib/Makefile:285
  # is `libdir ?= $(EXEC_PREFIX)/lib`, a fixed `lib` with no multilib postfix
  # anywhere in the file. The absence is measured, not hoped for.
  script = [
    "make --jobs {{ hw.concurrency }} $ARGS",
    "make install $ARGS",
  ]
}

# ⛔ THE SYMLINKS ARE LISTED AND THE SHELL SCRIPTS ARE NOT, and both halves come
# from programs/Makefile:417-421:
#
#     ln -sf zstd$(EXT) $(DESTDIR)$(BINDIR)/zstdcat$(EXT)
#     ln -sf zstd$(EXT) $(DESTDIR)$(BINDIR)/unzstd$(EXT)
#     ln -sf zstd$(EXT) $(DESTDIR)$(BINDIR)/zstdmt$(EXT)
#     $(INSTALL_SCRIPT) zstdless  $(DESTDIR)$(BINDIR)/zstdless
#     $(INSTALL_SCRIPT) zstdgrep  $(DESTDIR)$(BINDIR)/zstdgrep
#
# `zstdcat`, `unzstd` and `zstdmt` are SYMLINKS TO THE ELF — the binary reads
# argv[0] and changes mode — so they run anywhere the binary runs, including an
# empty image. `zstdless` and `zstdgrep` are `#!/bin/sh` (read from
# programs/zstdless:1 and programs/zstdgrep:1), and a script cannot run where
# there is no interpreter to find.
#
# ⚠⚠ THIS IS THE THIRD TIME THIS TREE HAS DECIDED THAT BY HAND. tukaani.org/xz
# excluded xzdiff/xzgrep/xzless/xzmore for it (go-zpkg/zpkx#151); openssl.org
# excluded c_rehash for it today (#145); here it is zstdless and zstdgrep. Three
# recipes reaching the same conclusion from the same evidence is the shape that
# should become a check in `zpkb lint` — a `provides` entry naming an installed
# file whose first two bytes are `#!` is a promise the artifact cannot keep —
# rather than a fourth comment. Filed as a note on go-zpkg/recipes#143.
provides = [
  "bin/zstd",
  "bin/unzstd",
  "bin/zstdcat",
  "bin/zstdmt",
]

test {
  script = [
    # What 16 recipes actually consume.
    "test -f \"{{prefix}}/include/zstd.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libzstd.* >/dev/null
EOT
    },

    # The version the binary reports, not the one the recipe asked for.
    {
      run = <<EOT
"{{prefix}}/bin/zstd" --version | grep -q "v{{version}}"
EOT
    },

    # ⛔ A ROUND TRIP, because "the binary starts" is not "the codec works".
    # Compress and decompress real bytes and compare them back.
    {
      run = <<EOT
printf 'the quick brown fox jumps over the lazy dog\n' > rt.txt
"{{prefix}}/bin/zstd" -q -o rt.zst rt.txt
"{{prefix}}/bin/unzstd" -q -o rt.out rt.zst
cmp rt.txt rt.out
EOT
    },

    # ⛔⛔ THE REGRESSION TEST FOR THE THREE PINNED PROBES. If HAVE_ZLIB,
    # HAVE_LZMA or HAVE_LZ4 is ever dropped from the make line, a sandbox that
    # happens to stage zlib, xz or lz4 silently produces a DIFFERENT artifact —
    # one that links three undeclared libraries. `zstd -v` lists the formats it
    # was built with, so the absence is assertable here, in the recipe that
    # caused it, rather than in an `unlinked` sweep three repositories away.
    #
    # ⚠ Asserted on the INSTALLED binary rather than on the build log, for the
    # reason naming-a-switch-does-not-always-pin-it records: a value named on a
    # command line can still be rewritten by the build, so the witness has to be
    # the artifact.
    {
      run = <<EOT
v="$("{{prefix}}/bin/zstd" -v --version 2>&1)"
for fmt in gzip lzma xz lz4; do
  if printf '%s' "$v" | grep -qi "$fmt"; then
    echo "zstd reports $fmt support, but HAVE_* were pinned to 0: $v" >&2
    exit 1
  fi
done
EOT
    },
  ]
}

provenance {
  read = [
    "README.md",            # :230 "dual-licensed under BSD OR GPLv2"
    "LICENSE",              # :10,:13,:17 — the three BSD clauses, the third naming Facebook/Meta
    "COPYING",              # the plain GPLv2 text, no "or later"
    "Makefile",             # :183-185 install recurses into lib/ then programs/
    "lib/Makefile",         # :281 prefix ?= /usr/local; :285 libdir ?= $(EXEC_PREFIX)/lib — a fixed `lib`
    "programs/Makefile",    # :78,:89,:100 the three link probes; :79-107 what each turns on; :139 LDLIBS; :46,:171 the binary is built from the library sources; :225 zstd-dll is the separate target that LINKS the shared lib; :410-421 what install puts in bin/
    "programs/zstdless",    # :1 #!/bin/sh
    "programs/zstdgrep",    # :1 #!/bin/sh
  ]

  consulted = []

  note = <<EOT
⭐⭐ THE DEFECT THIS RECIPE EXISTS TO PREVENT IS AN AUTO-DETECTION, and it is
the shape this project has now met often enough to recognise on sight:
programs/Makefile decides whether `zstd` supports .gz, .xz/.lzma and .lz4 — and
whether it LINKS -lz, -llzma and -llz4 — by compiling a probe against whatever
is staged in the sandbox. Nothing in a recipe says it, two machines can disagree,
and the losing case is a binary carrying three DT_NEEDED entries no dependency
map mentions. The three `HAVE_*=0` assignments pin it, and the test block
asserts the result on the installed binary.

⛔ A SIGNATURE IS PUBLISHED AND IS NOT USED, which is new for this tree and is
upstream's gap rather than ours. zstd ships `zstd-1.5.7.tar.gz.sig` and
publishes no fingerprint on its README, in its release notes, or anywhere in its
repository root — all three checked on 2026-11-17. A signature with no anchor
verifies that somebody signed something, which is exactly the degradation
`--key-source` is mandatory to prevent. Contrast openssl.org (#145), where the
primary key's fingerprint is published on the same page as the downloads and
served by a DIFFERENT origin from the archive, and gnu.org/gzip, where the
keyring at least comes from the same host. The honest ladder is
anchor-from-elsewhere > anchor-from-the-same-host > signature-with-no-anchor >
digest alone, and zstd sits one rung above the bottom only because the digest is
pinned.

⚠ THE RPATH QUESTION WAS ASKED AND ANSWERED DIFFERENTLY HERE than for
openssl.org, which is why it is recorded rather than assumed. openssl needed an
explicit `-Wl,-rpath,$(LIBRPATH)` because its `openssl` links libcrypto.so and
zpkb's fixup can only OVERWRITE an existing RUNPATH slot, never add one — so a
missing slot is a tolerated skip and a broken artifact. zstd's `zstd` target is
built from the library sources compiled locally (programs/Makefile:46, :171),
not by linking -lzstd; `zstd-dll` at :225 is the separate target that links the
shared library and is not what `make` builds. So the same tolerant skip in
fixup is CORRECT for this artifact: it is the "statically-linked" case its own
comment names. ⚠ That is read from the Makefile, not measured on a built
binary — this recipe has not been built.

⚠ NOT BUILT. Measured here: the digest by two independent paths, the version
enumeration (`zpkb versions`, after designing the strip/ignore from the real
release names rather than from the tags), the switch census against the
project's own Makefiles, and `zpkb lint`. The build and test scripts are a claim
about zstd's build system read from that build system, and they stay a claim
until a factory runs them.
EOT
}
