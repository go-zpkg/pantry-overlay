# gnu.org/automake — the Makefile.in generator, a base-toolchain member, and the
# consumer of the autoconf written in go-zpkg/pantry-overlay#129.
#
# ⛔ WRITTEN FROM AUTOMAKE'S OWN FILES (go-zpkg/packages#431), at 1.20, read out
# of the release tarball. Fifth of today's five: #126, #127, #128 and #129 took
# go-zpkg/pantry-overlay#88's measured gap from 9 to 5; this takes it to 4.
#
# ⭐⭐ AND IT IS THE RECIPE THAT SHOWS THE BAKED-PATH CLASS HAS A CLEAN SIDE.
# #128 (bison) and #129 (autoconf) each bake another project's absolute store
# path from `AC_PATH_PROG(S)`. automake needs the same kind of value — it
# EXECUTES autoconf at run time — and gets it RIGHT, by construction:
#
#   configure.ac:33   AC_SUBST([am_AUTOCONF], ["${AUTOCONF-autoconf}"])
#   bin/automake:5465 my $traces = ($ENV{AUTOCONF} || '@am_AUTOCONF@') . " ";
#
# `${AUTOCONF-autoconf}` is a shell default, not a PATH search, so `@am_AUTOCONF@`
# is the BARE NAME `autoconf` and is resolved through PATH at run time. Nothing
# to neutralise. That is the distinction this tree's own lesson already draws and
# which is easy to lose: `AC_PATH_PROG` engraves a PATH, a shell default or
# `AC_CHECK_PROG` engraves a NAME, and the two look identical from outside.

summary = "GNU Automake: automake and aclocal, which generate Makefile.in from Makefile.am"

# ⛔ READ FROM BOTH: COPYING is the GPL version 3 text, and bin/automake.in:6-9
# is "either version 3, or (at your option) any later version".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/automake/"
  match = "/automake-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^automake-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/automake/automake-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1694124 bytes, recorded with the builder's own fetcher and a VERIFIED
  # signature, then confirmed by an independent `curl --fail` + `shasum -a 256`:
  # two paths, one answer.
  #
  #   signed by 6C222EA6B2BD216AA406516AC868F0B6DE38409D
  #   Kamila Szewczyk <k@iczelia.net>
  #   no keyserver was asked
  #
  # ⛔⛔ AND THIS ONE WOULD HAVE READ AS "KEY NOT FOUND" WITHOUT THE LESSON FROM
  # #127. The signature is made by an EdDSA SUBKEY,
  # d5d527e7e338a682cbadb1c1217fcf7314636c07; the fingerprint anyone publishes is
  # the PRIMARY, 6c222ea6…de38409d. A primary-only comparison reports ABSENT for
  # a key that is right there. Matched against both namespaces, it is a subkey of
  # that primary, and the primary is what `--fingerprint` takes.
  sha256 = {
    "1.20" = "f6f34dad4cbe395715762b0710f7c511e39bd5cf777e6b95818ccbecf7714248"
  }

  # ⚠ THE APIVERSION COUPLING, stated here because it binds this block to
  # `provides` below: automake installs `automake-1.20` and `aclocal-1.20` as
  # well as the unversioned names, from configure.ac:52 `APIVERSION=1.20`. A
  # `provides` list is static — no recipe in this tree templates one and the
  # builder does not expand moustache there (`build.ProvidedCommands` reduces by
  # platform only) — so the two must move TOGETHER: a version bump changes the
  # digest above AND two entries below. Named rather than left as a trap.
}

# ⛔⛔ BOTH ARE RUNTIME DEPENDENCIES.
#
#   perl.org        — bin/automake and bin/aclocal ARE perl scripts
#                     (bin/*.in open with `#!@PERL@`).
#   gnu.org/autoconf — automake EXECUTES it: bin/automake.in:5418-5465
#                     `scan_autoconf_traces` runs
#                     `($ENV{AUTOCONF} || '@am_AUTOCONF@') --trace`, i.e. every
#                     automake run shells out to autoconf.
#
# ⚠ Floors from automake's own text, cited rather than chosen:
#
#   configure.ac:86-90   `$PERL -e 'require 5.006;'` or "perl 5.6 or better is
#                        required; perl 5.10 or better is recommended".
#   configure.ac:121     required_autoconf_version = 2.65, enforced by THREE
#                        escalating checks at :122-167 — that autoconf runs at
#                        all, that it works on a smoke-test input, and that it
#                        accepts `AC_PREREQ([2.65])`. The comment at :117-120
#                        says why there are three: "some users were unable to
#                        figure out that their installation was broken since
#                        --version appeared to work."
#
# ⭐ 5.6 and not 5.10 is taken because nothing here is switched off: this recipe
# pre-answers no cache variable, so the project's REQUIREMENT is the honest
# bound and its recommendation is a recommendation. (Contrast #128 and #129,
# which take the recommended m4 floor precisely BECAUSE they skip a check.)
dependencies = {
  "perl.org"        = ">=5.6"
  "gnu.org/autoconf" = ">=2.65"
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # The same two at build time: configure runs perl for the version check
    # (configure.ac:85-90) and runs autoconf three times (:122-167).
    "perl.org"         = ">=5.6"
    "gnu.org/autoconf" = ">=2.65"
  }

  # ⛔ THE SWITCH CENSUS IS EMPTY, as it was for autoconf: ZERO AC_ARG_ENABLE and
  # ZERO AC_ARG_WITH in configure.ac. Nothing to shut off and nothing to restate.
  #
  # ⚠ AND NO CACHE VARIABLE IS PRE-ANSWERED HERE, deliberately — see the shebang
  # note in `provenance` for why `PERL=perl` is the one thing this recipe must
  # NOT do.
  env = {
    ARGS = [
      "--prefix={{prefix}}",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Read from bin/local.mk:21 (`bin_SCRIPTS = automake aclocal`) and :23-24 plus
# the install loop at :46-57, which also installs each name suffixed with
# $(APIVERSION) — 1.20, per configure.ac:52.
provides = [
  "bin/aclocal",
  "bin/aclocal-1.20",
  "bin/automake",
  "bin/automake-1.20",
]

test {
  script = [
    # Running them at all proves the `#!@PERL@` shebang resolved — which for a
    # perl script is not a given, and is the thing the provenance note is about.
    "\"{{prefix}}/bin/aclocal\" --version",
    "\"{{prefix}}/bin/automake\" --version",

    # The APIVERSION-suffixed names are claimed in `provides`, so they are
    # asserted rather than assumed.
    "test -x \"{{prefix}}/bin/aclocal-1.20\"",
    "test -x \"{{prefix}}/bin/automake-1.20\"",

    # ⛔⛔ AND THE END-TO-END STEP, which is the only one that exercises the
    # autoconf dependency. `--version` passes with no autoconf anywhere;
    # `automake` cannot scan a configure.ac without shelling out to
    # `autoconf --trace` (bin/automake.in:5418-5465). So this fails if
    # gnu.org/autoconf is missing or unreachable, which is exactly the failure a
    # `provides` check cannot see — same reasoning as #128's real-grammar step
    # and #129's generated-configure step.
    {
      run = <<EOT
mkdir -p conftestdir
cd conftestdir
cat > configure.ac <<'INPUT'
AC_INIT([probe], [1.0])
AM_INIT_AUTOMAKE([foreign])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
INPUT
cat > Makefile.am <<'INPUT'
bin_SCRIPTS =
INPUT
"{{prefix}}/bin/aclocal"
"{{prefix}}/bin/automake" --add-missing --foreign
test -s Makefile.in
grep -q 'probe' Makefile.in
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",      # ZERO AC_ARG_ENABLE/AC_ARG_WITH; :33 the BARE-NAME am_AUTOCONF; :52 APIVERSION; :70 AC_PATH_PROG(PERL); :86-90 the perl floor; :121-167 the three autoconf checks; :342-363 the test-runner shell search
    "bin/automake.in",   # :1 the `#!@PERL@` shebang with NO trampoline; :6-9 GPL-3.0-or-later; :5418-5465 scan_autoconf_traces executing autoconf
    "bin/aclocal.in",    # :1 the same shebang shape
    "bin/local.mk",      # :21 bin_SCRIPTS, :23-24 and :46-57 the APIVERSION-suffixed installs
    "Makefile.in",       # a @PERL@ destination, and where AM_TEST_RUNNER_SHELL stops
    "COPYING",           # the GPL version 3 text that ships
  ]

  consulted = [
    # Read for the signing key only, and it turned out NOT to speak for this
    # tarball — see the note.
    "archlinux/packaging/packages/automake PKGBUILD (validpgpkeys and source)",
  ]

  note = <<EOT
⛔⛔ THE SHEBANG PROBLEM IS WORSE HERE THAN IN go-zpkg/pantry-overlay#129, AND
THAT IS MEASURED RATHER THAN ASSUMED.

configure.ac:70 is `AC_PATH_PROG([PERL], [perl])`, which records an ABSOLUTE
path, and `@PERL@` becomes the first line of both installed programs. So each
carries the build-time perl's versioned store path, with no `$ENV` override
because a shebang is resolved by the kernel. That is go-zpkg/zpkb#397's class,
and `fixup/stagingscripts.go:90` does not reach it: it rewrites a shebang only
when the file contains the `+builddir` staging path.

#129 left open the possibility that `ac_cv_path_PERL=perl` might work there,
because autoconf's scripts carry the classic trampoline on their second line:

    eval 'case $# in 0) exec @PERL@ -S "$0";; *) exec @PERL@ -S "$0" "$@";; esac'
        if 0;

⭐ AUTOMAKE'S SCRIPTS HAVE NO SUCH LINE. Measured: grepping both bin/*.in for
`exec @PERL@` / `-S "$0"` returns NOTHING; bin/automake.in and bin/aclocal.in
begin `#!@PERL@` and go straight into perl. So here a bare name in the shebang
has no fallback at all and would simply fail to execute. What was "unmeasured,
therefore do not" in #129 is "measured, definitely not" in this recipe — which
is why `build.env` pre-answers nothing.

⚠ configure.ac:91 does document an override, `./configure PERL=/path/to/perl`,
but its documented form is an ABSOLUTE path: it exists to choose BETWEEN perls,
not to avoid naming one. Using it to pass a bare name would be using a supported
flag for an unsupported purpose.

So the absolute path stays, `perl.org` is declared as a RUNTIME dependency, and
the consequence is recorded here. Reported on go-zpkg/zpkb#397, where the remedy
belongs — this is the second recipe to meet it and the first to show that the
trampoline workaround is not general.

⚠ THE KEY CORROBORATION IS WEAKER THAN go-zpkg/pantry-overlay#129'S, and the
difference is worth stating rather than glossing. Arch Linux's automake PKGBUILD
does list this signer — `validpgpkeys=(… '6C222EA6B2BD216AA406516AC868F0B6DE38409D')
# Kamila Szewczyk` — but its `source=` is

    git+https://git.savannah.gnu.org/git/automake.git#tag=v1.20?signed

a signed GIT TAG, not this tarball, and it publishes `sha512sums` over that
checkout rather than a digest of these bytes. So Arch corroborates the PERSON as
an automake release key and says nothing about this artifact. That is exactly the
trap go-zpkg/pantry-overlay#127 fell into with glibc, where two Arch-listed keys
verified tags and neither had signed the tarball. Here the same primary DID sign
the tarball, so the chain holds — but with two paths to the digest, not #129's
three.

⭐ TWO MEASURED NEGATIVES, recorded so a later reader does not re-raise them.
The sweep this tree now runs is "follow where the value goes", not "find the
macro":

  - `AM_TEST_RUNNER_SHELL` (configure.ac:342-363) runs `AC_PATH_PROG` over
    eight shell names and records an absolute path — but every destination is
    under `t/` plus Makefile.in and configure itself. NOTHING under bin/. The
    name is honest: it is the test runner's shell, and `AM_SUBST_NOTMAKE`
    at :357 keeps the candidate out of Makefiles.
  - `am_AUTOCONF` is the clean case described at the top of this recipe: a shell
    default, so a bare name, so nothing to fix.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — an empty switch census, both runtime dependencies with
floors from automake's own text, all four installed names, and the destination of
every substituted tool path, each traced to a line cited in `read`. The test
block is the part written to fail loudly: it runs both programs (which proves the
shebang resolved) and then generates a real Makefile.in, which automake cannot do
without executing autoconf.
EOT
}
