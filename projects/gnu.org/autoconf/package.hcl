# gnu.org/autoconf — the configure-script generator, a base-toolchain member,
# and automake's prerequisite.
#
# ⛔ WRITTEN FROM AUTOCONF'S OWN FILES (go-zpkg/packages#431), at 2.73, read out
# of the release tarball. Fourth of today's four:
# go-zpkg/recipes#126 (kernel.org/linux-headers), #127 (gnu.org/glibc)
# and #128 (gnu.org/bison) took go-zpkg/recipes#88's measured gap from 9
# to 6; this takes it to 5.
#
# ⭐⭐ AND IT MAKES #128'S FINDING A CLASS RATHER THAN A ONE-OFF. bison compiles
# the absolute path of its build-time m4 into its binary; autoconf ships the SAME
# macro — its own copy of `m4/m4.m4`, a different serial of the same file — and
# bakes the same path into TWO INSTALLED SCRIPTS. Two of the four recipes written
# today carry it, from independent copies of one upstream macro, which is what
# makes it worth a named remedy instead of a note per recipe.

summary = "GNU Autoconf: autoconf, autoreconf, autoheader, autom4te, autoscan, autoupdate and ifnames"

# ⛔ READ FROM THE FILES, AND THERE ARE THREE LICENCE TEXTS IN THE TARBALL —
# COPYINGv3 (GPL version 3), COPYING (GPL version **2**) and COPYING.EXCEPTION
# ("AUTOCONF CONFIGURE SCRIPT EXCEPTION, Version 3.0").
#
#   - the installed programs are GPL-3.0-or-later: bin/autoconf.in:13-16,
#     "either version 3 of the License, or (at your option) any later version".
#   - the MACRO LIBRARY additionally bears the exception, which is what makes a
#     generated `configure` freely licensable:
#     lib/autoconf/general.m4:20-27 — "the permissions described in the Autoconf
#     Configure Script Exception, version 3.0 … see the files COPYINGv3 and
#     COPYING.EXCEPTION respectively".
#
# ⚠ A GPLv2 text also ships, and this recipe does NOT narrow the expression to
# explain it: the files it covers were not each opened, and the glibc recipe's
# discipline applies — a licence is not narrowed on an unread majority. The
# exception is named because a file bearing it WAS read.
license = "GPL-3.0-or-later WITH Autoconf-exception-3.0"

versions {
  url   = "https://ftp.gnu.org/gnu/autoconf/"
  match = "/autoconf-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^autoconf-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/autoconf/autoconf-{{version.raw}}.tar.xz"
  strip-components = 1

  # ⭐ THREE INDEPENDENT PATHS TO THIS ONE DIGEST, which no earlier recipe here
  # has had:
  #
  #   1. zpkb sourcepin, the builder's own fetcher, with a VERIFIED signature:
  #        signed by 82F854F3CE73174B8B63174091FCC32B6769AA64
  #        Zack Weinberg <zackw@panix.com>   — no keyserver was asked
  #   2. an independent `curl --fail` + `shasum -a 256`;
  #   3. Arch Linux's own published `sha256sums` for pkgver=2.73, which is
  #      character-for-character the same string and is computed over the SAME
  #      ftp tarball (its `source=` names
  #      ftp.gnu.org/pub/gnu/autoconf/autoconf-2.73.tar.xz{,.sig}).
  #
  # 1417428 bytes.
  sha256 = {
    "2.73" = "9fd672b1c8425fac2fa67fa0477b990987268b90ff36d5f016dae57be0d6b52e"
  }
}

# ⛔⛔ BOTH OF THESE ARE RUNTIME DEPENDENCIES, AND NEITHER IS OPTIONAL.
#
#   m4   — bin/autom4te:94 and bin/autoupdate:61 are `my $m4 = $ENV{"M4"} ||
#          '@M4@';`, i.e. m4 is EXECUTED every time autoconf runs.
#   perl — every one of the seven installed programs IS a perl script:
#          bin/*.in open with `#! @PERL@` and re-exec through
#          `eval 'case $# in 0) exec @PERL@ -S "$0";; …'`.
#
# ⚠ The floors are the PROJECT'S OWN, cited rather than chosen:
#
#   m4/m4.m4:13,21,55  "GNU M4 1.4.8 or later is required; 1.4.16 or newer is
#                       recommended", with 1.4.5, 1.4.6-1.4.7 (no
#                       --debug=aflq) and 1.4.11-1.4.15 (strstr bugs) named.
#   configure.ac:161-163  `$PERL -e 'require 5.006;'` or
#                       "Perl 5.006 or better is required".
#
# ⭐ 1.4.16 and not 1.4.8 is taken for the same reason as in #128: the
# build-time quality check is pre-answered below, so this constraint is what
# stands in its place. ⚠ NOTE THE TWO PROJECTS DISAGREE — bison's copy of the
# same macro says 1.4.6, autoconf's says 1.4.8. They ship different serials of
# one upstream file, so each recipe cites ITS OWN rather than sharing a number.
dependencies = {
  "gnu.org/m4" = ">=1.4.16"
  "perl.org"   = ">=5.6"
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # The same two at build time: configure runs m4 for its feature checks
    # (m4/m4.m4:59-73, `$M4 --help` twice) and runs perl for the version and
    # Fcntl::flock checks (configure.ac:161, :169-179).
    "gnu.org/m4" = ">=1.4.16"
    "perl.org"   = ">=5.6"
  }

  # ⛔ THE SWITCH CENSUS IS EMPTY, AND THAT IS A MEASUREMENT. configure.ac holds
  # ZERO AC_ARG_ENABLE and ZERO AC_ARG_WITH — autoconf has no options of its own
  # beyond the ones Autoconf itself provides (--prefix and friends). So there is
  # no auto-detected library to shut off and nothing to restate; the only thing
  # this block decides is the one cache answer below.
  env = {
    ARGS = [
      "--prefix={{prefix}}",
    ]

    # ⛔⛔ THE SAME DEFECT go-zpkg/recipes#128 FOUND IN BISON, from an
    # independent copy of the same upstream macro. autoconf's m4/m4.m4:
    #
    #   :27   AC_PATH_PROGS_FEATURE_CHECK([M4], [m4 gm4 gnum4], …)
    #   :52     ac_cv_path_M4=$ac_path_M4        <- an ABSOLUTE path
    #   :58   M4=$ac_cv_path_M4
    #
    # and Makefile.in:434 `M4 = @M4@` carries it into bin/autom4te:94 and
    # bin/autoupdate:61. In this factory that is another project's versioned
    # store path, `<store>/gnu.org/m4/v1.4.21/bin/m4` — stale the day m4 is
    # rebuilt, which is go-zpkg/zpkb#397's class and what `zpkb bakedpaths`
    # refuses.
    #
    # ⭐ Pre-answering the cache variable is the same remedy, and it is a
    # BETTER fit here than in bison: the two scripts read `$ENV{"M4"} ||
    # '@M4@'`, so a bare name is resolved through PATH exactly as the env
    # override would be. m4/m4.m4:23's AC_CACHE_CHECK skips the search, :58
    # assigns the bare name, and :59-73 still run `$M4 --help` so M4_GNU and
    # M4_DEBUGFILE stay measured.
    ac_cv_path_M4 = "m4"
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Read from bin/local.mk:19-26 `bin_SCRIPTS`, which lists exactly these seven.
provides = [
  "bin/autoconf",
  "bin/autoheader",
  "bin/autom4te",
  "bin/autoreconf",
  "bin/autoscan",
  "bin/autoupdate",
  "bin/ifnames",
]

test {
  script = [
    # It runs at all — which for a perl script also proves the shebang resolved.
    "\"{{prefix}}/bin/autoconf\" --version",

    # ⛔⛔ AND IT ACTUALLY GENERATES A configure, which is the only test that
    # exercises the m4 path. `--version` passes with no m4 anywhere; this fails
    # without it, because autoconf drives autom4te, which executes m4. Same
    # reasoning as #128's real-grammar step: the difference between asserting a
    # file exists and asserting the package WORKS.
    {
      run = <<EOT
mkdir -p conftestdir
cd conftestdir
cat > configure.ac <<'INPUT'
AC_INIT([probe], [1.0])
AC_PROG_CC
AC_OUTPUT
INPUT
"{{prefix}}/bin/autoconf"
test -s configure
grep -q 'probe' configure
EOT
    },

    # ⛔ THE REGRESSION WITNESS FOR THE BAKED PATH, asserted as an ABSENCE
    # because that is the direction the defect travels. If a future edit drops
    # `ac_cv_path_M4=m4`, configure resumes the PATH search and writes an
    # absolute m4 into these two scripts. Matched on `/bin/m4` so it catches the
    # host spelling (/usr/bin/m4) as well as a store path.
    {
      run = <<EOT
for f in bin/autom4te bin/autoupdate; do
  if grep -q '/bin/m4' "{{prefix}}/$f"; then
    echo "autoconf: an ABSOLUTE m4 path is baked into $f" >&2
    echo "  m4/m4.m4:52 makes \$M4 absolute; Makefile.in:434 carries it in." >&2
    echo "  Restore ac_cv_path_M4=m4 in build.env (go-zpkg/zpkb#397's class)." >&2
    exit 1
  fi
done
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",             # ZERO AC_ARG_ENABLE/AC_ARG_WITH; :131 AC_PATH_PROG(EXPR); :142 AC_PROG_GNU_M4; :156 AC_PATH_PROG(PERL); :161-163 the perl floor; :169-179 the flock check
    "m4/m4.m4",                 # :13,:21,:55 the m4 floor and the buggy-version list; :27,:52,:58 the absolute path; :59-73 the checks that survive pre-answering
    "Makefile.in",              # :423 EXPR = @EXPR@ (build-time only), :434 M4 = @M4@ (reaches installed scripts)
    "bin/autom4te.in",          # :1 and :5 the @PERL@ shebang and re-exec; :94 $ENV{"M4"} || '@M4@'
    "bin/autoupdate.in",        # :61 the second baked @M4@
    "bin/autoconf.in",          # :1,:5 the shebang shape; :13-16 GPL-3.0-or-later
    "bin/local.mk",             # :19-26 bin_SCRIPTS, the seven installed names
    "lib/autoconf/general.m4",  # :20-27 the Autoconf Configure Script Exception notice
    "COPYINGv3",                # the GPL version 3 text
    "COPYING",                  # a GPL version 2 text ALSO ships — see the licence comment
    "COPYING.EXCEPTION",        # "AUTOCONF CONFIGURE SCRIPT EXCEPTION, Version 3.0"
  ]

  consulted = [
    # Read for the signing key AND for a third digest path; see the note.
    "archlinux/packaging/packages/autoconf PKGBUILD (validpgpkeys, pkgver, source and sha256sums)",
  ]

  note = <<EOT
⭐⭐ THE STRONGEST WARRANT IN THIS TREE, because three independent paths agree on
one digest instead of two:

  sourcepin, builder's own fetcher, signature VERIFIED
      82F854F3CE73174B8B63174091FCC32B6769AA64  Zack Weinberg <zackw@panix.com>
  curl --fail + shasum -a 256
      9fd672b1c8425fac2fa67fa0477b990987268b90ff36d5f016dae57be0d6b52e
  Arch Linux's published sha256sums for pkgver=2.73
      9fd672b1c8425fac2fa67fa0477b990987268b90ff36d5f016dae57be0d6b52e

and the third is independent in the way that matters: Arch's `source=` names the
SAME ftp tarball (not a git commit, which is what made its glibc keys answer the
wrong question in go-zpkg/recipes#127), so its digest is a statement about
these exact bytes by someone who is not us and not ftp.gnu.org.

The fingerprint likewise comes from Arch (`validpgpkeys=('82F854F3…6769AA64')  #
Zack Weinberg`) rather than from the host serving the tarball — independence, not
the continuity gnu.org/gzip records — and the signature is made by the PRIMARY
key, so there is no primary-versus-signing-subkey step to get wrong. Key material
was extracted BY THAT FINGERPRINT from ftp.gnu.org/gnu/gnu-keyring.gpg with a
resynchronising reader, because a sequential one stops after 402 of its 613
primary keys and "not found" from it can mean "could not look".

⛔⛔ AND ONE FINDING THIS RECIPE CANNOT FIX, REPORTED RATHER THAN PAPERED OVER:
THE SHEBANGS.

configure.ac:156 is `AC_PATH_PROG([PERL], [perl], [no])`, which records an
ABSOLUTE path, and `@PERL@` lands in the `#!` line of all seven installed
programs. So every one of them carries the build-time perl's versioned store
path, and unlike `@M4@` there is NO runtime override: a shebang is resolved by
the kernel, not by $ENV.

That is go-zpkg/zpkb#397's class, and the builder does not currently cover it:
`fixup/stagingscripts.go:90` rewrites a shebang only when it contains the
`+builddir` staging path (`!strings.Contains(string(b), buildInstall)`), so a
shebang pointing into ANOTHER PROJECT's store entry survives into the artifact
untouched.

⚠ What this recipe does NOT do is guess a way around it. `ac_cv_path_PERL=perl`
would put a bare name in the `#!` line, and these scripts do carry the classic
trampoline on line 5 (`eval 'exec @PERL@ -S "$0"'`) which exists precisely for
systems that cannot use the shebang — but whether that path is taken depends on
how the script is invoked, and that is unmeasured here. Shipping a package whose
programs might not start, on an untested theory, is worse than shipping one with
a documented store-path reference. Reported on go-zpkg/zpkb#397 with the
measurement instead.

⛔ NOT BUILT. No session here can run the factory, so what is established is this
recipe's INPUTS — an empty switch census, both runtime dependencies with floors
from autoconf's own text, all seven installed names, three licence texts and the
full @M4@/@PERL@/@EXPR@ substitution map, each traced to a line cited in `read`.
⚠ @EXPR@ is the measured NEGATIVE of that map: configure.ac:131 records an
absolute `expr` too, but Makefile.in:423 is its only destination, so it never
reaches an installed file — the same shape as bison's perl/xsltproc in #128, and
the reason that check is "follow where the value goes" rather than "find the
macro".
EOT
}
