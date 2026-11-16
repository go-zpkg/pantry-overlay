# gnu.org/texinfo — makeinfo/texi2any, the info reader, and the install-info
# every autotools package calls. A base-toolchain member.
#
# ⛔ WRITTEN FROM TEXINFO'S OWN FILES (go-zpkg/packages#431), at 7.3, read out of
# the release tarball. Seventh of today's seven: #126, #127, #128, #129, #130
# and #131 took go-zpkg/pantry-overlay#88's measured gap from 9 to 3; this takes
# it to 2.
#
# ⭐ AND THE FIRST RECIPE TODAY WHOSE perl PIN IS NOT A JUDGEMENT CALL. zpkb
# hardcodes this project as XS-bearing — build/build.go:390,
# `perlXSToolchainProjects = []string{"gnu.org/texinfo", "gnu.org/help2man"}` —
# and `CheckToolchainPerl` refuses any constraint but `build.ToolchainPerl`
# exactly. See the `dependencies` block for why that is right rather than
# merely required.

summary = "GNU Texinfo: texi2any/makeinfo, the info reader, install-info, texindex and texi2dvi"

# ⛔ READ FROM BOTH: COPYING is the GPL version 3 text, and info/info.c:5-8 is
# "either version 3 of the License, or (at your option) any later version".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/texinfo/"
  match = "/texinfo-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^texinfo-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/texinfo/texinfo-{{version.raw}}.tar.xz"
  strip-components = 1

  # ⭐ THREE INDEPENDENT PATHS TO THIS DIGEST, the second recipe today to manage
  # it (after go-zpkg/pantry-overlay#129):
  #
  #   1. zpkb sourcepin, the builder's own fetcher, signature VERIFIED:
  #        signed by EAF669B31E31E1DECBD11513DDBC579DAB37FBA9
  #        Gavin Smith (Texinfo maintainer) <GavinSmith0123@gmail.com>
  #        no keyserver was asked
  #   2. an independent `curl --fail` + `shasum -a 256`;
  #   3. Arch Linux's own published `sha256sums` for pkgver=7.3 — the same
  #      string, over the SAME ftp tarball, since its `source=` names
  #      ftp.gnu.org/pub/gnu/texinfo/texinfo-7.3.tar.xz{,.sig} rather than a git
  #      checkout. Its `validpgpkeys` is this same fingerprint, so the
  #      fingerprint is independent of the host serving the archive.
  #
  # 6940392 bytes.
  sha256 = {
    "7.3" = "51f74eb0f51cfa9873b85264dfdd5d46e8957ec95b88f0fb762f63d9e164c72e"
  }
}

# ⛔⛔ TWO RUNTIME DEPENDENCIES, AND NEITHER IS A PREFERENCE.
#
# perl.org — `bin/texi2any` IS a perl script and the package ships THIRTEEN
# compiled XS modules (`tta/perl/XSTexinfo/*.xs`, `tta/perl/CheckXS/TestXS.xs`).
# An XS module is built against one perl's ABI and refuses to load under
# another, which is why zpkb states the constraint once
# (build/build.go:380, `ToolchainPerl = "~5.44"`) and checks every XS-bearing
# toolchain member against it (`CheckToolchainPerl`, :392-429).
#
# ⚠ `~5.44` IS WRITTEN HERE AS A LITERAL AND THAT IS A KNOWN HAZARD, named
# because the check's own comment records what it cost: "the unit test that
# claimed to check this asserted the pin equalled the string "~5.42", which was
# texinfo's constraint on the day it was written. texinfo moved to ~5.44, the
# literal did not, and the test kept passing while every man-page-generating
# build broke." A recipe is data and cannot reference a Go constant; what keeps
# this honest is that `CheckToolchainPerl` reads THIS FILE rather than a copy.
#
# ⭐ Contrast go-zpkg/pantry-overlay#115, which correctly gives help2man `^5` —
# it declares perl under `build.dependencies`, which `CheckToolchainPerl` does
# not inspect, and with `--disable-nls` it ships no XS of its own. texinfo
# cannot take that route: its perl is needed at RUN time.
#
# invisible-island.net/ncurses — see the terminal-library note in `build` below.
# Without it `bin/info` is not built, and the build does not fail.
dependencies = {
  "perl.org"                     = "~5.44"
  "invisible-island.net/ncurses" = "*"
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # The same two at build time: perl builds and links the XS modules, and the
    # terminal library is what the `info` program links against.
    "perl.org"                     = "~5.44"
    "invisible-island.net/ncurses" = "*"
  }

  # ⛔⛔ THE TERMINAL LIBRARY IS AUTO-DETECTED FROM EIGHT CANDIDATES, AND ITS
  # ABSENCE IS A WARNING RATHER THAN AN ERROR. This is the sharpest instance of
  # the class this campaign keeps meeting, because it reaches `provides`:
  #
  #   configure.ac:213  TERMLIB_VARIANTS="tinfo tinfow ncurses ncursesw curses
  #                                       termlib termcap terminfo"
  #   configure.ac:214-217  for termlib in ${TERMLIB_VARIANTS}; do
  #                           AC_CHECK_LIB(${termlib}, tgetent,
  #                              [TERMLIBS="… -l${termlib}"; break])
  #   configure.ac:221-225  if test -z "$TERMLIBS" …; then
  #                           AC_MSG_WARN([info needs a terminal library, …])
  #                           have_termlib=no
  #   configure.ac:273  AM_CONDITIONAL(HAVE_TERMLIBS, [[test "x$TERMLIBS" != x]])
  #   Makefile.am:55,:69  the info/ build is inside that conditional
  #
  # So with no terminal library staged the build SUCCEEDS, prints a warning, and
  # ships an artifact with no `bin/info` in it. A warning in a build log is not
  # a gate, which is why `invisible-island.net/ncurses` is declared above and
  # why the test block asserts `bin/info` exists rather than assuming it.
  #
  # ⚠ WHICH of the eight is linked is NOT settled by this recipe, and that is
  # stated rather than glossed: the loop takes the FIRST candidate providing
  # `tgetent`, and `tinfo`/`tinfow` precede `ncurses`/`ncursesw` in the list —
  # ncurses builds commonly provide `libtinfo` as well, so the answer depends on
  # what our ncurses package actually ships. Settling it needs a built tree;
  # it is the first thing to look at on the first real build, like
  # `lib/libltdl.la` in go-zpkg/pantry-overlay#131.
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ `--enable-perl-xs` DOCUMENTS ITS DEFAULT AS "check" (configure.ac:317),
      # i.e. auto-detection: whether thirteen compiled modules enter the
      # artifact would otherwise depend on what the build sandbox happened to
      # offer.
      # Stated explicitly, and it is the ENABLED answer on purpose — the XS
      # modules are what make texi2any fast enough to run on every autotools
      # package's manual, and zpkb already treats this project as XS-bearing.
      "--enable-perl-xs",

      # ⛔ NLS OFF, which removes gettext from the picture entirely.
      # configure.ac:301-302 is `AM_GNU_GETTEXT_VERSION([0.26])` +
      # `AM_GNU_GETTEXT([external])` — EXTERNAL, so with NLS on this package
      # would need gnu.org/gettext, which this tree does not yet carry (it is
      # one of the two leaves go-zpkg/pantry-overlay#127 opened). Same decision
      # and same reasoning as go-zpkg/pantry-overlay#115 for help2man.
      #
      # ⚠ COST, STATED: texinfo's own diagnostics are English-only in this
      # artifact.
      "--disable-nls",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ NINE NAMES FROM THREE MECHANISMS ACROSS SIX MAKEFILES, which is why this
# list is read out of the files rather than guessed:
#
#   bin_SCRIPTS            tta/perl/Makefile.am:35      texi2any
#                          texindex/Makefile.am:19      texindex
#                          util/Makefile.am:13          texi2dvi texi2pdf pdftexi2dvi
#                          Pod-Simple-Texinfo/…:18      pod2texi   (nodist_)
#   bin_PROGRAMS + rename  info/Makefile.am:24-25       ginfo        -> info
#                          install-info/Makefile.am:14,28  ginstall-info -> install-info
#   install-exec-hook      tta/perl/Makefile.am:407-409 makeinfo   (symlink to texi2any)
#
# ⚠ THE TWO RENAMES ARE LOAD-BEARING. The programs are BUILT as `ginfo` and
# `ginstall-info` — info/Makefile.am:21-23 says why, "to avoid confusion with
# the standard `info'" — and installed under their real names by
# `transform = s/ginfo/info/; $(program_transform_name)`. Listing `bin/ginfo`
# here would name a file that is never installed.
#
# ⚠ AND `bin/makeinfo` COMES FROM AN install-exec-hook, not from any bin_
# variable: :408-409 removes it and re-creates it as `$(LN_S) texi2any makeinfo`
# in `$(DESTDIR)$(bindir)`. A reader grepping only for `bin_SCRIPTS` would
# conclude the single most-used program in this package is not installed.
provides = [
  "bin/info",
  "bin/install-info",
  "bin/makeinfo",
  "bin/pdftexi2dvi",
  "bin/pod2texi",
  "bin/texi2any",
  "bin/texi2dvi",
  "bin/texi2pdf",
  "bin/texindex",
]

test {
  script = [
    # ⛔⛔ THE ASSERTION THAT CATCHES THE WARN-AND-SKIP PATH. If no terminal
    # library is found, configure warns, HAVE_TERMLIBS is false, info/ is not
    # built, and everything else still succeeds. This is the only thing standing
    # between that and an artifact silently missing its reader.
    "test -x \"{{prefix}}/bin/info\"",

    # makeinfo is a symlink made by an install hook; assert the link resolves
    # rather than merely exists.
    "test -x \"{{prefix}}/bin/makeinfo\"",
    "\"{{prefix}}/bin/makeinfo\" --version",

    # ⛔⛔ AND THE END-TO-END STEP, which is the only one that exercises perl and
    # the XS modules. `--version` runs the perl script; converting a document
    # drives the parser, which is what the thirteen .xs files implement. So this
    # fails if the XS modules were not built against this perl — the exact
    # failure `CheckToolchainPerl` exists to prevent.
    {
      run = <<EOT
mkdir -p conftestdir
cd conftestdir
cat > probe.texi <<'INPUT'
\input texinfo
@setfilename probe.info
@settitle Probe
@node Top
@top Probe
A paragraph that the parser has to read.
@bye
INPUT
"{{prefix}}/bin/makeinfo" --no-split -o probe.info probe.texi
test -s probe.info
grep -q 'Probe' probe.info
EOT
    },

    # install-info is what every other autotools package calls at install time;
    # it is a C program and the one whose name the rename produces.
    "\"{{prefix}}/bin/install-info\" --version",
  ]
}

provenance {
  read = [
    "configure.ac",                      # :211-225 the eight-candidate termlib loop and its WARNING; :273 AM_CONDITIONAL(HAVE_TERMLIBS); :301-302 AM_GNU_GETTEXT([external]); :304-311 the three --with-external-* defaults; :316-317 --enable-perl-xs "default: check"; the whole 16-switch census
    "Makefile.am",                       # :55,:69 the info/ build inside HAVE_TERMLIBS
    "info/Makefile.am",                  # :21-25 ginfo and the s/ginfo/info/ transform
    "install-info/Makefile.am",          # :14,:27-28 ginstall-info and its transform
    "tta/perl/Makefile.am",              # :35 bin_SCRIPTS = texi2any; :68-70 the makeinfo link; :407-409 the install-exec-hook that installs it
    "texindex/Makefile.am",              # :19
    "util/Makefile.am",                  # :13
    "Pod-Simple-Texinfo/Makefile.am",    # :18
    "tta/perl/XSTexinfo/",               # the thirteen .xs sources that make this an XS-bearing package
    "info/info.c",                       # :5-8 "either version 3 … or any later version"
    "COPYING",                           # the GPL version 3 text that ships
  ]

  consulted = [
    # Read for the signing key AND for a third digest path; both are in the note.
    "archlinux/packaging/packages/texinfo PKGBUILD (validpgpkeys, pkgver, source, sha256sums)",
    # ⭐ Read BEFORE writing, and it changed the perl constraint — see the note.
    "go-zpkg/pantry-overlay#115 (gnu.org/help2man) pull request body",
    "go-zpkg/zpkb build/build.go:377-429 (ToolchainPerl and CheckToolchainPerl)",
  ]

  note = <<EOT
⭐⭐ PRIOR ART CHANGED THIS RECIPE BEFORE A LINE OF IT WAS WRITTEN, which is the
whole argument for reading it first.

go-zpkg/pantry-overlay#115 wrote gnu.org/help2man and recorded that BOTH of its
declared dependencies were wrong — gettext was unnecessary with NLS off, and its
perl pin was `~5.44` copied out of zpkb's `ToolchainPerl` where `^5` was the
honest bound. Read naively, that is an argument for giving texinfo `^5` too.

⛔ It is the opposite here, and #115 says why in its own aside: zpkb requires
base-toolchain members that ship compiled perl XS modules to match
`ToolchainPerl` EXACTLY, because an XS module built against one perl refuses to
load under another. texinfo ships thirteen `.xs` files. So:

  - help2man: perl under `build.dependencies`, no XS of its own -> `^5` honest.
  - texinfo:  perl needed at RUN time, thirteen XS modules -> `~5.44` required.

And it is enforced rather than trusted: build/build.go:390 names
`gnu.org/texinfo` in `perlXSToolchainProjects`, and `CheckToolchainPerl` reads
THIS FILE's `dependencies["perl.org"]` and reports any value that is not
`ToolchainPerl`. ⚠ The literal `~5.44` in this recipe is therefore a known
hazard with a known guard — the check's comment records the last time a copy of
it went stale: "texinfo moved to ~5.44, the literal did not, and the test kept
passing while every man-page-generating build broke."

⛔⛔ THE FINDING OF THIS RECIPE: A WARNING DECIDES WHAT IS IN THE ARTIFACT.
configure picks a terminal library by taking the first of EIGHT candidates that
provides `tgetent` (configure.ac:213-217), and if none does it merely WARNS
(:221-225) and clears `HAVE_TERMLIBS`, which removes the whole `info/` build
(Makefile.am:55,:69). A build with no terminal library staged therefore
succeeds, prints one line nobody reads, and ships an artifact with no `bin/info`.

That is the same family as curl's brotli/zstd and glibc's libgd/libselinux, with
one difference that makes it worse: those decide what the artifact LINKS, this
decides what the artifact CONTAINS — a name in `provides` that would be present
on the machine that had a termlib and absent everywhere else. Hence the
dependency above and the `test -x bin/info` assertion below it.

⚠ WHICH of the eight is unresolved, and deliberately not guessed: `tinfo` and
`tinfow` precede `ncurses` in the list, and ncurses builds commonly ship
`libtinfo`, so the answer depends on what our ncurses package provides. Left for
the first real build, named rather than assumed.

⭐ THREE MEASURED NEGATIVES, so a later reader does not re-raise them:

  - the three `--with-external-*` switches (configure.ac:304-311) each document
    "(default: no)" — Unicode-EastAsianWidth, Text::Unidecode and libintl-perl
    come from texinfo's own bundled copies unless asked for. No external perl
    module enters by detection.
  - `--enable-using-c-texi2any` (:327) installs a C texi2any only "if built",
    and nothing here builds it.
  - the remaining switches of the sixteen — ptys-tests, additional-checks,
    t2a-tests, refcounts-checks, pod-simple-texinfo-tests, perl-api-texi-build,
    install-warnings, multiplatform, xs-perl-libintl, --with-swig — are test,
    developer or platform-packaging switches whose defaults are fixed constants.

⚠ gnu.org/gettext is avoided by `--disable-nls` rather than declared. It is one
of the two leaves go-zpkg/pantry-overlay#127 opened and is still absent from
this tree, so declaring it would have deepened that hole for the sake of
translated diagnostics in a build tool.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — the sixteen-switch census with every non-constant default
stated, both runtime dependencies with the reason each is not optional, all nine
installed names across three install mechanisms including two renames and one
symlink hook, and the licence from two files, each traced to a line cited in
`read`. The test block is written to fail loudly on the three things most likely
to be wrong: a missing `bin/info` (the warn-and-skip path), a `bin/makeinfo`
symlink that does not resolve, and XS modules built against the wrong perl —
which only converting a real document can detect.
EOT
}
