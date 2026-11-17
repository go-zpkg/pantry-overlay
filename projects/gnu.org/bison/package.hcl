# gnu.org/bison — the GNU parser generator, and a base-toolchain member that
# glibc's configure calls CRITICAL.
#
# ⛔ WRITTEN FROM BISON'S OWN FILES (go-zpkg/packages#431), at 3.8.2, read out of
# the release tarball. Third of today's three: go-zpkg/recipes#126 wrote
# kernel.org/linux-headers and #127 gnu.org/glibc, which together took
# go-zpkg/recipes#88's measured gap from 9 to 7; this takes it to 6.
#
# ⭐ CHOSEN FOR A CONVERGENCE, not at random: #127 declares `gnu.org/bison` as
# one of glibc's four CRITICAL build dependencies (glibc configure.ac:553-555,
# gathered into `critic_missing` and aborting at :598-600), so writing it also
# makes #127's own closure resolvable from this tree.

summary = "The GNU parser generator: bison, the yacc interface and liby"

# ⛔ READ FROM BOTH PLACES THE WAY gnu.org/gzip DOES — COPYING says which TEXT
# ships, the source header says whether later versions are permitted:
# COPYING is the GPL version 3 text, and src/main.c:9-11 is
# "either version 3 of the License, or (at your option) any later version".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/bison/"
  match = "/bison-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^bison-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/bison/bison-{{version.raw}}.tar.xz"
  strip-components = 1

  # 2817324 bytes, recorded with the builder's own fetcher and a VERIFIED
  # signature:
  #
  #   zpkb sourcepin --sig auto --key ./akim-demaille.gpg \
  #     --fingerprint 7DF84374B1EE1F9764BBE25D0DDCAA3278D5264E \
  #     --key-source "<see provenance>" --version 3.8.2 \
  #     https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz
  #
  #   signed by 7DF84374B1EE1F9764BBE25D0DDCAA3278D5264E
  #   Akim Demaille <akim@epita.fr>
  #   no keyserver was asked
  #
  # and confirmed by an independent `curl --fail` + `shasum -a 256`: two paths,
  # one answer. ⭐ This is the cleanest chain in the tree so far, and why is in
  # `provenance.note` — the fingerprint is published by a third party who pins
  # THIS tarball.
  sha256 = {
    "3.8.2" = "9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2"
  }
}

# ⛔⛔ m4 IS A RUNTIME DEPENDENCY, NOT ONLY A BUILD ONE, and that is the single
# most important fact about packaging bison. `bison` EXECUTES m4 every time it
# processes a grammar — src/files.c:563-574:
#
#     char const *m4 = getenv ("M4");
#     …
#     char const *m4_relocated = relocate (M4);
#     …
#     return M4;
#
# where `M4` is the compile-time define. A bison installed without m4 reachable
# builds, installs, answers `--version`, and then fails on the first real
# grammar — which is exactly the shape of failure a `provides` check cannot see.
#
# ⚠ The floor is the PROJECT'S OWN, not a threshold invented here. m4/m4.m4:20
# documents the variable as "Location of GNU M4 1.4.6 or later", and its error
# message at :43-46 says "1.4.6 or later is required; 1.4.16 or newer is
# recommended", naming 1.4.15 and 1.4.11-1.4.15 as carrying strstr bugs. 1.4.16
# is taken rather than 1.4.6 BECAUSE the build-time quality check is switched
# off below, so this constraint is the only thing left standing between this
# package and a known-buggy m4. gnu.org/m4 resolves to 1.4.21, measured.
dependencies = {
  "gnu.org/m4" = ">=1.4.16"
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # The same m4, at build time, because configure runs it: after the path
    # check is pre-answered, m4/m4.m4:48-72 still executes `$M4 --help` twice to
    # decide M4_GNU (--gnu) and M4_DEBUGFILE (--debugfile vs --error-output).
    # Those two answers are compiled in, so m4 must be RUNNABLE here even
    # though its location is no longer searched for.
    "gnu.org/m4" = ">=1.4.16"
  }

  # ⛔⛔ THE DEFECT THIS RECIPE EXISTS TO PREVENT: BISON COMPILES IN THE
  # ABSOLUTE PATH OF THE m4 IT WAS BUILT WITH.
  #
  # The chain, read end to end:
  #
  #   m4/m4.m4:26   AC_PATH_PROGS_FEATURE_CHECK([M4], [m4 gm4 gnum4], …)
  #   m4/m4.m4:41     ac_cv_path_M4=$ac_path_M4      <- an ABSOLUTE path
  #   m4/m4.m4:47   M4=$ac_cv_path_M4
  #   configure.ac:269  AC_DEFINE_UNQUOTED([M4], ["$M4"], …)
  #   src/files.c:569   relocate (M4)                <- used at RUN time
  #
  # In this factory that absolute path is another project's VERSIONED STORE
  # PATH, `<store>/gnu.org/m4/v1.4.21/bin/m4` — stale the day m4 is rebuilt,
  # which is precisely what go-zpkg/zpkb#397 is about and what `zpkb
  # bakedpaths` refuses. And `relocate()` makes it worse rather than better: it
  # rewrites a compiled-in path relative to BISON's own install prefix, so a
  # relocated absolute path points inside bison's store entry, where no m4
  # exists.
  #
  # ⭐ THE FIX IS TO PRE-ANSWER THE CACHE VARIABLE, which is the same mechanism
  # gnu.org/gzip uses for `ac_cv_prog_LESS=less` and for the same reason — a
  # configure check whose ANSWER, not whose outcome, is the thing we need to
  # control. With `ac_cv_path_M4=m4`:
  #
  #   - m4/m4.m4:22's AC_CACHE_CHECK finds the variable already set and skips
  #     the PATH search entirely;
  #   - :47 then assigns the BARE NAME, so configure.ac:269 compiles in
  #     `#define M4 "m4"`;
  #   - gnulib's relocate() leaves a relative name alone, and src/files.c
  #     resolves it through PATH at run time — which is what the `dependencies`
  #     block above is for;
  #   - :48-72 still run `$M4 --help`, so M4_GNU and M4_DEBUGFILE are still
  #     measured rather than guessed.
  #
  # ⚠ Setting the PRECIOUS VARIABLE `M4=m4` instead would NOT work, and that is
  # worth writing down because it is the obvious first attempt: m4/m4.m4:20
  # declares M4 with AC_ARG_VAR, but :47 overwrites it unconditionally with
  # `M4=$ac_cv_path_M4`. The cache variable is the only lever.
  #
  # ⚠ AND THE COST, STATED: skipping that check also skips bison's own
  # screening of broken m4 versions (GNU M4 1.4.5, and the strstr bugs in
  # 1.4.11-1.4.15). The `>=1.4.16` constraint above replaces it, taken from
  # bison's own error text rather than chosen here.
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⚠ Upstream's default (configure.ac:249-252, `, [enable_yacc=yes]`),
      # RESTATED because it decides two entries in `provides` below: the `yacc`
      # wrapper script and lib/liby.a. A default that changes what the artifact
      # contains is worth naming even when it is not changed.
      "--enable-yacc",
    ]

    # ⛔ Not a flag: the pre-answered cache variable described above.
    ac_cv_path_M4 = "m4"
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ THE SWITCH CENSUS IS SHORT AND THAT IS A MEASUREMENT, NOT AN OMISSION.
# configure.ac holds exactly TWO AC_ARG_ENABLE and ZERO AC_ARG_WITH:
#
#   :88   --enable-gcc-warnings   developer warnings, opt-in, "(not
#                                 recommended)" in its own help text; it also
#                                 changes synclines in the Texinfo doc. Not
#                                 passed.
#   :249  --enable-yacc           default yes; passed explicitly above.
#
# ⭐ AND THERE IS NO AUTO-DETECTED LIBRARY AT ALL: `AC_CHECK_LIB` and
# `AC_SEARCH_LIBS` have ZERO occurrences in configure.ac, and libtextstyle —
# which bison can use for coloured diagnostics in some builds — is not
# mentioned either. So the defect class that bit curl (brotli/zstd), freetype
# (harfbuzz) and glibc (libgd, libselinux, libaudit nested inside it) does NOT
# apply here, and that is a measured negative rather than an assumption.
#
# ⚠ TWO OTHER AC_PATH_PROG CALLS WERE CHECKED AND ARE HARMLESS, which is the
# caution go-zpkg/recipes#93 earned — it is not enough to see the macro,
# one has to follow where its value GOES:
#
#   configure.ac:272  AC_PATH_PROG([PERL], [perl])
#   configure.ac:274  AC_PATH_PROG([XSLTPROC], [xsltproc])
#
# Both record absolute paths, and neither reaches an installed file: `@PERL@`
# and `@XSLTPROC@` are substituted only into Makefile.in and into the test
# harness (tests/atlocal.in, tests/bison.in). Nothing under bin/ or lib/ carries
# them.
#
# ⚠ `bin/yacc` DOES contain an absolute path — its own. src/yacc.in ends with
# `bindir=`relocate "@bindir@"`` / `exec "$bindir/bison" -y "$@"`, i.e. BISON's
# prefix, passed through the gnulib relocatable-shell helper. That is this
# package's own store entry, not another project's, so it is outside what
# go-zpkg/zpkb#397 and `zpkb bakedpaths` refuse.

provides = [
  "bin/bison", # src/local.mk:18  bin_PROGRAMS = src/bison
  "bin/yacc",  # src/local.mk:159 nodist_bin_SCRIPTS = src/yacc, under ENABLE_YACC
]
# ⚠ `lib/liby.a` is installed too (lib/local.mk:27 `lib_LIBRARIES = lib/liby.a`,
# also under ENABLE_YACC) and is deliberately NOT listed: `provides` is
# documented as "Programs/paths this package provides, eg. bin/foo", and
# zlib.net — the tree's other library — lists nothing at all.

test {
  script = [
    # It runs at all.
    "\"{{prefix}}/bin/bison\" --version",

    # ⛔⛔ AND IT CAN ACTUALLY PARSE A GRAMMAR, which is the only test that
    # exercises the m4 path. `--version` passes with no m4 anywhere; this step
    # fails without it, because src/files.c resolves M4 and pipes the skeleton
    # through it. That is the difference between asserting the file exists and
    # asserting the package WORKS.
    {
      run = <<EOT
cat > conftest.y <<'GRAMMAR'
%token NUM
%%
expr: NUM
GRAMMAR
"{{prefix}}/bin/bison" -o conftest.c conftest.y
test -s conftest.c
EOT
    },

    # ⛔ THE REGRESSION WITNESS FOR THE BAKED PATH. If a future edit drops
    # `ac_cv_path_M4=m4`, configure finds m4 by PATH search and compiles its
    # absolute store path into the binary again. Asserted as an ABSENCE,
    # because that is the direction this defect travels, and matched on
    # `/bin/m4` rather than on a store prefix so it catches the host spelling
    # (/usr/bin/m4) as well as ours.
    {
      run = <<EOT
if grep -al '/bin/m4' "{{prefix}}/bin/bison" >/dev/null 2>&1; then
  echo "bison: an ABSOLUTE m4 path is compiled into bin/bison" >&2
  echo "  configure.ac:269 bakes \$M4, and m4/m4.m4:41 makes it absolute." >&2
  echo "  Restore ac_cv_path_M4=m4 in build.env (go-zpkg/zpkb#397's class)." >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",    # :88 and :249 are the ONLY two switches; :268-270 the M4/M4_GNU defines; :272-274 the two harmless AC_PATH_PROGs; no AC_CHECK_LIB anywhere
    "m4/m4.m4",        # :20-21 the documented floor, :26 AC_PATH_PROGS_FEATURE_CHECK, :41 and :47 the absolute path, :43-46 the buggy-version list, :48-72 the two checks that survive pre-answering
    "src/files.c",     # :563-574 M4 is read at RUN time, through relocate()
    "src/yacc.in",     # the installed wrapper and its own relocated @bindir@
    "src/local.mk",    # :18 bin_PROGRAMS, :159 nodist_bin_SCRIPTS
    "lib/local.mk",    # :27 lib_LIBRARIES = lib/liby.a
    "COPYING",         # the GPL version 3 text that ships
    "src/main.c",      # :9-11 "either version 3 … or any later version"
    "doc/",            # bison.info and bison.1 ship PREBUILT, so texinfo and help2man are not build dependencies
    "Makefile.in",     # where @PERL@/@XSLTPROC@ actually land
    "tests/atlocal.in",
    "tests/bison.in",
  ]

  consulted = [
    # Read for the SIGNING KEY only.
    "archlinux/packaging/packages/bison PKGBUILD (validpgpkeys, and pkgver=3.8.2)",
  ]

  note = <<EOT
⭐ THE CLEANEST TRUST CHAIN IN THIS TREE SO FAR, and it is worth saying why
rather than just recording the digest.

  signature   https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz.sig
  signer      7DF84374B1EE1F9764BBE25D0DDCAA3278D5264E
              Akim Demaille <akim@epita.fr>
  fingerprint from Arch Linux's packaging/packages/bison PKGBUILD:
              validpgpkeys=('7DF84374B1EE1F9764BBE25D0DDCAA3278D5264E')  # Akim Demaille
  key material extracted BY THAT FINGERPRINT from
              https://ftp.gnu.org/gnu/gnu-keyring.gpg

Three properties none of today's other recipes had together:

  - the fingerprint is published by a THIRD PARTY, not by the host that serves
    the tarball, so this is independence rather than the continuity gnu.org/gzip
    records and kernel.org/linux-headers repeats;
  - that third party pins THIS artifact: Arch's bison PKGBUILD has
    `pkgver=3.8.2` and builds the ftp tarball. (Contrast glibc, where Arch's
    keys turned out to verify GIT TAGS because its PKGBUILD builds from a
    `_commit` — a non-match there says nothing about the tarball.)
  - the signature is made by the PRIMARY key, so there is no primary-versus-
    signing-subkey step to get wrong. DSA keys sign directly; the issuer key id
    0ddcaa3278d5264e is the low 8 bytes of the primary fingerprint.

⭐⭐ AND IT REFUTED A PREDICTION ABOUT OUR OWN TOOL, which is the finding worth
carrying forward. This signature is DSA with SHA-1, created 2021-09-25 — the
exact combination go-zpkg/zpkb#482 reports as refused ("a DSA/SHA-1 signature is
refused as signature made by unknown entity"). I expected to be blocked by that
open defect and wrote the measurement down instead of the assumption:
`sourcepin` ACCEPTS it.

So #482's concluding mechanism — "ProtonMail/go-crypto declines that
combination" — cannot be right; its observation is true and the inference
attached to it is not. #482's own case still reproduces, so the defect is real;
four candidate discriminators were measured on both files and all four came back
identical (public-key algorithm DSA, hash SHA-1, key size 1024 bits, no expiry,
self-signature flags valid=false, signed by the primary in both). Reported there
with the ruled-out list rather than a fifth guess.

⚠ One measurement about the keyring, since this recipe depends on it: a
sequential reader stops after 402 of its 613 primary keys on an unparseable
packet, so "key not found" from it can mean "could not look". Akim Demaille's
key was located by a resynchronising scan and extracted into a single-key file
BY FINGERPRINT before `sourcepin` was pointed at it, which is also why the
`--key` above is one key and not the whole archive.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — both switches, the m4 chain end to end, every installed
name and both licence files traced to a line in bison's own files and cited in
`read`. The test block is the part written to fail loudly: it parses a real
grammar (which `--version` cannot do without m4) and asserts the absence of a
compiled-in absolute m4 path.
EOT
}
