# python.org — the fragment is now a STANDALONE recipe, and the two
# mistyped-identifier defects it was opened for are kept below.
#
# ⛔ WRITTEN FROM CPYTHON'S OWN FILES (go-zpkg/packages#431), at 3.15.2, read
# out of the published source tarball.
#
# ⚠ THE HEADER THIS FILE CARRIED SAID "that is the next step, and it needs a
# factory build this session cannot run". THAT WAS TOO STRONG, and the campaign
# since has shown why: go-zpkg/recipes#157, #158, #159, #160 and #161 were all
# written without a build, each establishing the recipe's INPUTS — every switch,
# dependency, installed path and licence traced to a line in the project's own
# files — and saying plainly that the build is unproven. The same standard
# applies here. What a build would add is confirmation, not the content.
#
# ⭐ AND THE AUDIT FOUND A LIVE DEFECT IN THE FRAGMENT ITSELF: it declares
# `libexpat.github.io` and CPython's default is to IGNORE it. See
# `--with-system-expat` below.

summary = "Python: the CPython interpreter, its standard library and the tools that ship with it"

# ⛔ THE PSF LICENSE, and LICENSE's own structure is why this is not simply
# "Python-2.0". The file opens with the PSF LICENSE AGREEMENT FOR PYTHON
# 3.15.2 and then reproduces, in full, the three historical agreements the
# code is also distributed under — BeOpen, CNRI and CWI — because CPython's
# history passed through all four stewards and the grants accumulate rather
# than replace. SPDX's `Python-2.0` identifier is the composite that names
# exactly this stack, which is why it is used here rather than inventing an
# AND-expression over four names SPDX does not carry separately.
license = "Python-2.0"

# ⚠ wasip1 is excluded by omission and that is a measured exclusion rather than
# an oversight: configure.ac:7694-7698 turns ensurepip OFF for Emscripten, WASI
# and iOS, which is upstream saying those targets are a different build with
# different contents. This fleet has no WASI python target.
platforms = ["linux", "darwin", "windows", "freebsd", "openbsd", "netbsd"]

dependencies = {
  # ⛔⛔ THE CONSTRAINT WAS BELOW THE PROJECT'S OWN FLOOR, and the audit found
  # it. It read `= 2`. configure.ac:4403 requires `libmpdec >= 2.5.0` through
  # pkg-config, and configure.ac:4416-4418 enforces the same minimum in C:
  #
  #     #if MPD_VERSION_HEX < 0x02050000
  #     #  error "mpdecimal 2.5.0 or higher required"
  #
  # A `2` that resolved to 2.4.x would fail the link test, and — see the
  # module census below — that does NOT fail the build. It produces a Python
  # with no `_decimal`, which surfaces as `import decimal` failing at runtime
  # in whatever consumer reaches for it first.
  "bytereef.org/mpdecimal" = ">=2.5.0"

  darwin = {
    "gnu.org/gettext" = "^1"
  }
  "facebook.com/zstd"            = ">=1.5"
  "gnu.org/readline"             = 8
  "invisible-island.net/ncurses" = 6
  "libexpat.github.io"           = 2
  "openssl.org"                  = "^3"
  "sourceware.org/bzip2"         = 1
  "sourceware.org/libffi"        = 3
  "sqlite.org"                   = 3

  # ⚠ WHAT THIS PIN IS FOR WAS NEVER WRITTEN DOWN, and establishing it is what
  # found the two defects below. Upstream's only note is "9.0.2 introduced a
  # build issue on darwin", which says why the version is pinned and not why
  # the dependency exists at all.
  #
  # It exists for `_tkinter`, and CPython's own files say so exactly:
  #
  #   configure.ac:4602-4622  five pkg-config queries in order, the first being
  #                           `tcl >= 8.5.12 tk >= 8.5.12`; if none exists,
  #                           TCLTK_CFLAGS/TCLTK_LIBS fall back to empty
  #   configure.ac:4636-4643  a link test over `#include <tcl.h>` AND
  #                           `#include <tk.h>` together
  #   configure.ac:8544-8545  the `_tkinter` extension is built only
  #                           `if test "$have_tcltk" = "yes"`
  #
  # ⛔ So this needs TK, not just core Tcl — which is why splitting the
  # tcl-lang.org monolith cannot start here: nothing in this recipe passes a
  # tcltk flag, nothing names tk, and no test imports tkinter, so the module
  # would stop being built in silence. See #122.
  #
  # ⭐ And the chain that makes it work today was verified rather than assumed:
  # the monolith builds with `--includedir={{prefix}}/include/tcl-tk`, which is
  # not a default include path, so I expected tkinter to be broken already.
  # Tcl's own files refute it — `unix/tcl.pc.in` carries
  # `Cflags: -I${includedir}` and `unix/Makefile.in:828-830` installs that
  # `tcl.pc`, so the recipe's own includedir reaches pkg-config and pkg-config
  # reaches CPython.
  "tcl-lang.org" = "=8.6.16"

  "tukaani.org/xz" = 5
  "zlib.net"       = "=1.3.1"
}

# ⛔⛔ DEFECT 1: THE IGNORE LIST ENUMERATES EXCLUSIONS, SO EVERYTHING IT FORGOT
# IS INCLUDED — AND IT FORGOT 1991.
#
# Upstream's block is `github: python/cpython/tags` with six ignore patterns
# (3.4.[0-1], 3.3.[1-7], 3.[0-2].x, 2.7.1[0-7], 2.7.[0-9], 2.[0-6].x). None of
# them matches a 0.x or 1.x tag, so `zpkb versions` on upstream's recipe
# resolves **271 versions** whose oldest four are
#
#   1.0.2  1.0.1  0.9.9  0.9.8
#
# Python 0.9.8 is from 1991. Measured, not assumed, with one request each:
#
#   https://www.python.org/ftp/python/0.9.8/Python-0.9.8.tar.xz   404
#   https://www.python.org/ftp/python/1.0.2/Python-1.0.2.tar.xz   404
#   https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz 200
#   https://www.python.org/ftp/python/3.15.2/Python-3.15.2.tar.xz 200
#
# So the recipe advertises versions it cannot fetch, and the comment claiming
# "We only currently have patches for 2.7.18 (EOL)" is true about 2.x and
# silent about everything below it.
#
# ⛔ The one-line fix is `/^[01]\./`, and it is NOT a cosmetic tidy: the
# existing patterns are an exclusion enumeration, which fails open by
# construction — every tag shape nobody thought of resolves. A positive floor
# would be better still, and the schema has no key for one; `sha256` is the
# real answer, because a recipe that pins is fail-closed ("building a version
# absent from the map is refused, not fetched unverified", schema/
# package.schema.json's own words on the field).
#
# ⭐ AND THAT ANSWER IS NOW IN PLACE: the `sha256` block below pins 3.15.2, so
# a build of any other version is REFUSED rather than fetched unverified. The
# ignore list is no longer the only thing standing between this recipe and a
# tarball from 1991 — it is now the thing that keeps `zpkb versions` readable.
#
# ⚠ `ignore` REPLACES upstream's rather than extending it — an overlay list
# does not merge (recipefile/overridden_test.go: "a list must replace") — so
# all six of upstream's patterns are carried here verbatim beside the new one.
# Dropping one by accident would silently re-admit a version line.
versions {
  github = "python/cpython/tags"
  ignore = [
    # Upstream's four that WORK, verbatim. They work because the digits pin
    # them: unanchored, the unescaped dots match any character and the bracket
    # classes do the real matching.
    "3.4.[0-1]",
    "3.3.[1-7]",
    "2.7.1[0-7]",
    "2.7.[0-9]",

    # ⛔ UPSTREAM'S OTHER TWO WERE INERT AND ARE REWRITTEN. `3.[0-2].x` and
    # `2.[0-6].x` are glob idioms in a REGEX field: the trailing `x` is a
    # literal, and no version string contains one. Measured on upstream's own
    # recipe — 3.1.x (5 versions), 3.2.x (6) and 2.6.x (9) all resolved.
    #
    # ⚠ AND THE OBVIOUS REWRITE OVER-MATCHES. `^v3\.[0-2]` would also match
    # `v3.10.*`, `v3.11.*` and `v3.12.*`, because after `3.1` comes `0`, `1` or
    # `2` — it would delete the three most used Python lines. The trailing
    # `\.` is what makes `v3.1.5` match and `v3.10.5` not, and the A/B below
    # was run for exactly that.
    # ⚠ AND THE ANCHOR NEEDS `v?` AND A BOUNDARY THAT IS NOT A LITERAL DOT,
    # which a fourth measurement showed: with `^v2\.[0-6]\.` the tags `v2.0`
    # (no patch segment, so no trailing dot) and `2.1` (NO `v` PREFIX AT ALL)
    # both survived. CPython's old tags are inconsistent about the prefix, so
    # anything anchored on `v` alone is wrong for part of the history.
    "^v?3\\.[0-2](\\.|$)",
    "^v?2\\.[0-6](\\.|$)",

    # ⛔⛔ AND THE TWO NOBODY WROTE AT ALL — which is the whole point of the
    # block being an exclusion list. See the long note above.
    #
    # The `v` is load-bearing and cost three wrong attempts: `ignore` is
    # matched against the CANDIDATE, which for `github: …/tags` is the raw tag
    # `v0.9.8`, not the parsed `0.9.8`. `^0\.` and `/^[01]\./` and `0.x` all
    # silently matched nothing. Reading versions/versions.go settled it —
    # `regexList(m["ignore"])` compiles Onigmo regexes applied to the
    # candidates — after guessing had failed three times.
    "^v?0\\.",
    "^v?1\\.",

    # ⛔ THE BARE `2.7` TAG, which `2.7.[0-9]` cannot reach — it needs a
    # character after `2.7.` and this tag has no patch segment. Measured:
    # python.org/ftp/python/2.7/Python-2.7.tar.xz is a **404**, so it is a
    # phantom exactly like 0.9.8.
    #
    # ⭐ Excluding it decides NOTHING about whether this factory wants Python 2,
    # and that is why it is safe to do here: 2.7.18 — the one version
    # upstream's comment says is supported — is ALREADY unresolvable, excluded
    # by `2.7.[0-9]` matching the `2.7.1` inside it. Measured: zero 2.7.*
    # versions resolve, before or after this line.
    # ⛔⛔ EVERY MAJOR.MINOR TAG WITH NO PATCH SEGMENT, in ONE pattern rather
    # than a list — and the list is what I tried first.
    #
    # CPython tags both `v3.9.7` and a bare `3.9`. The bare ones are not
    # releases and have no tarball: measured 404 for `3.4` and `3.9` at
    # python.org/ftp/python/<v>/Python-<v>.tar.xz, the same shape as 0.9.8.
    #
    # ⚠ I first excluded `2.7` and `3.3` individually and WROTE that they were
    # "the only bare survivors because they are the two lines upstream excluded
    # partially". The very next run said **7 bare tags left** — 3.4, 3.5, 3.6,
    # 3.7, 3.8, 3.9, 3.10. The reasoning was wrong and only the measurement
    # said so, which is the third time in this one block that a pattern I
    # argued for did nothing.
    #
    # So the fix states the SHAPE instead of enumerating instances — which is
    # the same lesson as the whole block: an exclusion list fails open at every
    # hole, and each hole is a line somebody wrote half of.
    #
    # ⭐ It does not touch real versions: `3.3.0` and `3.10.22` have a patch
    # segment, so `$` cannot follow the minor. Verified in the A/B below.
    "^v?\\d+\\.\\d+$",
  ]
}

distributable {
  url              = "https://www.python.org/ftp/python/{{version.raw}}/Python-{{version.raw}}.tar.xz"
  strip-components = 1

  # 27960396 bytes, recorded with the builder's own fetcher:
  #
  #   zpkb sourcepin --version 3.15.2 \
  #     https://www.python.org/ftp/python/3.15.2/Python-3.15.2.tar.xz
  #
  # ⭐ AND IDENTICAL TO THE SHA-256 PUBLISHED ON THE RELEASE PAGE ITSELF
  # (python.org/downloads/release/python-3152/, the "XZ compressed source
  # tarball" row). Two paths, one answer, the second being the project's own
  # statement rather than a second download of the same bytes.
  sha256 = {
    "3.15.2" = "8b5536d280142ecf6cdfe15d12a21ba1c65e300bbf7b28a8d0cdb849575797de"
  }
}

build {
  # ⛔⛔ THE CENSUS THAT MATTERS MOST HERE IS NOT THE SWITCHES — IT IS THE
  # THIRTY-ODD OPTIONAL MODULES THAT ARE BUILT ONLY IF THEIR LIBRARY IS FOUND,
  # AND THE BUILD DOES NOT FAIL WHEN ONE IS NOT. configure.ac:8220-8248
  # documents its own states:
  #
  #     dnl    n/a: marked unavailable on platform by PY_STDLIB_MOD_SET_NA()
  #     dnl    yes: enabled and supported
  #     dnl    missing: enabled and not supported
  #     dnl    disabled: not enabled
  #
  # and `missing` is what a found-nothing produces: `AM_CONDITIONAL(modcond,
  # [test "$modstate" = yes])` simply excludes the module, `make` exits 0, and
  # the artifact is a Python that cannot `import ssl`, or `sqlite3`, or
  # `decimal`. ⚠ There is no flag that turns this into an error —
  # `--with-missing-stdlib-config` (configure.ac:317-323) only supplies custom
  # MESSAGE text for the ones that went missing.
  #
  # ⭐ SO THE TEST BLOCK IS THE GATE, and it is written against exactly the
  # libraries this recipe declares: every one of them has an `import` below. A
  # dependency that stops being passed, or a library that stops being found,
  # fails there instead of in whichever consumer reaches for the module first.
  dependencies = {
    # ⚠ Not declared here and used anyway: `freedesktop.org/pkg-config`, which
    # configure needs for every PKG_CHECK_MODULES above. It arrives through
    # go-zpkg/base-toolchain, which names it among its members.
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ THE DEFECT THE AUDIT FOUND. configure.ac:4256-4261 ends with
      # `[with_system_expat="no"]` — the DEFAULT IS NO, and the help string
      # says so too ("default is no"). So CPython builds `pyexpat` against its
      # own bundled copy of expat and the `libexpat.github.io` dependency this
      # recipe declares is INERT: the library is staged, paid for in the
      # closure, and not linked.
      #
      # That is worse than cmake's twelve vendored libraries
      # (go-zpkg/recipes#160), because there the recipe did not claim
      # otherwise. Here the dependency list asserts a relationship the build
      # does not have, so `zpkb sonames` and the SBOM would both describe an
      # artifact that is not this one.
      "--with-system-expat",

      # ⚠ THE DEFAULT, RESTATED — AND VERIFIED AGAINST THE CODE RATHER THAN
      # THE HELP STRING, because this campaign has been burned by exactly that
      # (go-zpkg/recipes#150: "a help text is a claim, the generated configure
      # is the fact"). Here the help says "default is yes" and
      # configure.ac:4397's third argument is `[with_system_libmpdec="yes"]`,
      # so the two agree. Restated anyway: it decides whether a vendored
      # libmpdec enters the artifact.
      #
      # ⛔ AND THE FALLBACK IS NOT THE BUNDLED COPY. configure.ac:4402-4406:
      # if pkg-config does not answer for `libmpdec >= 2.5.0`, it does NOT
      # call USE_BUNDLED_LIBMPDEC — it sets `-lmpdec -lm` and runs a link test
      # (:4413-4421), and a failure there sets `have_mpdec=no`, which takes
      # `_decimal` out of the build. Hence the `>=2.5.0` on the dependency.
      "--with-system-libmpdec",

      # ⛔ ensurepip's DEFAULT IS PLATFORM-DEPENDENT, which is the shape this
      # campaign treats as worse than a plain default. configure.ac:7693-7698:
      #
      #     AS_CASE([$ac_sys_system],
      #       [Emscripten], [with_ensurepip=no],
      #       [WASI], [with_ensurepip=no],
      #       [iOS], [with_ensurepip=no],
      #       [with_ensurepip=upgrade])
      #
      # Pinned to `install`, which is what every platform this recipe lists
      # resolves to today, so the artifact's contents stop depending on which
      # branch `$ac_sys_system` took.
      #
      # ⚠ AND THE VENDORED-PIP QUESTION IS NAMED AND NOT DECIDED HERE.
      # ensurepip ships a wheel of pip inside the artifact, which is a bundled
      # third-party package invisible to `zpkb sonames` and to the advisory
      # machinery — the same class as cmake's twelve. Turning it off would
      # change what consumers of this package can do, which is an owner's call
      # and not a regex's; this recipe makes the behaviour DETERMINISTIC and
      # reports the concern rather than acting on it.
      "--with-ensurepip=install",

      # ⚠ Upstream's defaults, RESTATED rather than relied on, because each
      # changes what is in the artifact and each has an arm a future reader
      # might reach for:
      #
      #   --enable-optimizations  default no  (configure.ac:1858-1866) — PGO,
      #                           which also makes the build's output depend on
      #                           a training run
      #   --with-lto              default no  (configure.ac:1940-1941)
      #   --enable-shared         default no  (configure.ac:1512-1513), so
      #                           libpython is static and `bin/python3` is
      #                           self-contained
      "--disable-optimizations",
      "--without-lto",
      "--disable-shared",
    ]
  }

  # ⚠ `--enable-test-modules` DEFAULTS TO YES (configure.ac:8005-8008,
  # `[TEST_MODULES=yes]` as the third argument), so `Lib/test` — tens of
  # megabytes — IS installed. That default is a deterministic constant, so it
  # is not a defect by this campaign's standard and it is NOT changed here:
  # removing it would break `import test` for any consumer that uses it, which
  # is a behaviour change rather than a correctness fix. Named so the size is
  # a known quantity rather than a surprise.
  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ READ FROM Makefile.pre.in's OWN INSTALL RULES, not from a guess at what a
# python installs:
#
#   :2506  $(INSTALL_PROGRAM) $(BUILDPYTHON) $(BINDIR)/python$(LDVERSION)
#   :2571  the `python3` name, removed and recreated as a link
#   :3072  $(INSTALL_SCRIPT) python-config $(BINDIR)/python$(LDVERSION)-config
#   :3073  $(INSTALL_SCRIPT) $(SCRIPT_IDLE)  $(BINDIR)/idle$(VERSION)
#   :3074  $(INSTALL_SCRIPT) $(SCRIPT_PYDOC) $(BINDIR)/pydoc$(VERSION)
#
# ⚠ THE VERSIONED NAMES ARE DELIBERATELY ABSENT. `bin/python3.15`,
# `bin/idle3.15` and friends carry the minor version, so listing them would
# make `provides` wrong on the next line — and a `provides` entry that is wrong
# for 3.16 is the defect `zpkb lint` exists to catch. The unversioned names are
# the stable surface.
#
# ⚠ `bin/pip3` comes from ensurepip rather than from an install rule, and is
# listed because `--with-ensurepip=install` above makes it deterministic.
provides = [
  "bin/python3",
  "bin/python3-config",
  "bin/idle3",
  "bin/pydoc3",
  "bin/pip3",
]

test {
  script = [
    "\"{{prefix}}/bin/python3\" --version",

    # ⛔⛔ THE GATE FOR THE THIRTY-ODD OPTIONAL MODULES. Every entry here is a
    # module whose presence depends on a library this recipe DECLARES, and
    # configure.ac:8236 sets such a module to `missing` — silently, with the
    # build still exiting 0 — when the library is not found. One import each,
    # so the failure names the module rather than the package.
    #
    # The mapping is from CPython's own configure to this recipe's
    # `dependencies`:
    #
    #   _ssl, _hashlib → openssl.org          zlib    → zlib.net
    #   _sqlite3       → sqlite.org           bz2     → sourceware.org/bzip2
    #   _lzma          → tukaani.org/xz       _ctypes → sourceware.org/libffi
    #   readline       → gnu.org/readline     _curses → invisible-island.net/ncurses
    #   _decimal       → bytereef.org/mpdecimal
    #   pyexpat        → libexpat.github.io   (and ONLY once --with-system-expat
    #                                          is passed — see the build block)
    #   _tkinter       → tcl-lang.org         (tk, not just core Tcl; see #122)
    {
      run = <<EOT
set -e
"{{prefix}}/bin/python3" - <<'PY'
import sys
mods = [
    "ssl", "hashlib", "sqlite3", "bz2", "lzma", "ctypes",
    "readline", "curses", "decimal", "zlib", "pyexpat", "tkinter",
]
missing = []
for m in mods:
    try:
        __import__(m)
    except Exception as e:
        missing.append("%s (%s)" % (m, e))
if missing:
    print("python: optional stdlib modules are MISSING from this build:", file=sys.stderr)
    for m in missing:
        print("  " + m, file=sys.stderr)
    print("", file=sys.stderr)
    print("Each is built only when its library is found: configure.ac:8220-8248", file=sys.stderr)
    print("sets the module to 'missing' and the build still exits 0, so this is", file=sys.stderr)
    print("the only place it can be caught. Check the matching dependency.", file=sys.stderr)
    raise SystemExit(1)
PY
EOT
    },

    # ⭐ AND THE ONE THAT PROVES THE INTERPRETER WORKS RATHER THAN MERELY
    # STARTS: compute something, and check the two modules most likely to be
    # subtly wrong rather than absent.
    {
      run = <<EOT
set -e
"{{prefix}}/bin/python3" - <<'PY'
import decimal, ssl, sqlite3
assert decimal.Decimal(1) / decimal.Decimal(7) != 0
assert ssl.OPENSSL_VERSION_INFO[0] >= 3, ssl.OPENSSL_VERSION
con = sqlite3.connect(":memory:")
con.execute("create table t(x)")
con.execute("insert into t values (41)")
assert con.execute("select x + 1 from t").fetchone()[0] == 42
PY
EOT
    },

    # pip exists because --with-ensurepip=install was passed; if that is ever
    # dropped, this says so rather than leaving a `provides` entry dangling.
    "\"{{prefix}}/bin/pip3\" --version",
  ]
}

# ⛔⛔ DEFECT 2: `arch: aarc64` — A MISSING `h`, AND THE DECLARATION THEREFORE
# NEVER MATCHES.
#
# Upstream states that python 2 is not packaged for darwin on 64-bit ARM:
#
#   unpackaged:
#     - version: ^2
#       platform: darwin
#       arch: aarc64        ← aarc64, not aarch64
#       reason: help-wanted
#
# Measured: `aarc64` appears ZERO times in zpkb's Go sources (which know only
# `aarch64`) and in exactly ONE recipe out of 1930 — this one. So it is a typo
# and not a second spelling the toolchain honours, and the consequence is that
# the factory is not told to skip a build upstream knows does not work.
#
# ⭐ Same defect family as `--without-libps1` in gnu.org/wget (#120): a
# mistyped identifier that reads as a statement and makes none. The difference
# is that configure PRINTS a warning for an unknown flag, while an unknown arch
# name here prints nothing at all — the entry simply never matches.
#
# Carried in full because `unpackaged` is a list and an overlay list replaces.
unpackaged = [
  {
    version  = "^2"
    platform = "darwin"
    arch     = "aarch64"
    reason   = "help-wanted"
  },
]

provenance {
  read = [
    "configure.ac",      # :317-323 --with-missing-stdlib-config is MESSAGES only; :1512-1513 --enable-shared default no; :1858-1866 --enable-optimizations default no; :1940-1941 --with-lto default no; :4256-4261 --with-system-expat default NO; :4382-4422 --with-system-libmpdec default yes and the link-test fallback that drops _decimal; :4602-4643 the tcl/tk probes; :7689-7698 ensurepip's platform-dependent default; :8005-8008 --enable-test-modules default yes; :8220-8248 PY_STDLIB_MOD and the four module states, including `missing`
    "Makefile.pre.in",   # :2506, :2571, :3072-3074 — the install rules `provides` is read from
    "LICENSE",           # the PSF agreement for 3.15.2 plus the BeOpen, CNRI and CWI agreements it reproduces
    "README.rst",        # the project's own description
  ]

  note = <<EOT
⛔⛔ CPYTHON NO LONGER PUBLISHES A PGP SIGNATURE, AND THAT IS A GAP IN THIS
FLEET'S TOOLING RATHER THAN IN THE PROJECT'S PRACTICE. python.org/download/
sigstore states it plainly: starting with Python 3.14, **Sigstore is the only
signing and verification method**; older releases keep "legacy OpenPGP
signatures". Measured on the 3.15.2 release page: the source rows carry
`Python-3.15.2.tar.xz`, `Python-3.15.2.tar.xz.sigstore` and
`Python-3.15.2.tar.xz.spdx.json` — a bundle and an SBOM, and **no `.asc`**.

So `zpkb sourcepin --sig` cannot be used here at all: it speaks PGP, and there
is nothing for it to read. The digest below is therefore recorded at the
"published checksum" rung — the project's own sha256 on its release page,
confirmed byte for byte by the builder's own fetcher.

⚠ WHAT VERIFYING THE BUNDLE WOULD TAKE, so it is one step and not a
rediscovery:

    python -m sigstore verify identity \
      --bundle Python-3.15.2.tar.xz.sigstore \
      --cert-identity <the release manager's address> \
      --cert-oidc-issuer https://accounts.google.com \
      Python-3.15.2.tar.xz

⛔ AND THE IDENTITY IS NOT A STABLE PIN THE WAY A FINGERPRINT IS. Sigstore's
certificate identity here is the RELEASE MANAGER'S EMAIL, and python.org says
it varies by release — 3.11 was `pablogsal@python.org`. A recipe that hardcoded
one identity would be wrong for the next line, which is a real difference from
a PGP fingerprint that outlives the release manager. Whatever this fleet builds
for Sigstore has to carry the identity PER VERSION, beside the digest, rather
than once per project.

⚠ AND THERE IS A BOOTSTRAP CIRCULARITY worth naming: the verification command
above is `python -m sigstore`. Verifying CPython's own tarball needs a working
Python. It is not a blocker — the check happens when the digest is RECORDED, on
a machine that already has one, which is Guix's division and the same reason
`sourcepin` checks PGP at pin time rather than at build time — but a fleet
Sigstore verb has to be built with that in mind rather than as a Python script.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every switch, dependency, installed path and licence
traced to a line in CPython's own files and cited in `read` above. The build is
unproven and should be read as such.

⭐ THE TEST BLOCK IS THE PART TO READ IF YOU READ ONE THING. CPython's optional
stdlib modules are the largest auto-detection in this tree — around thirty of
them, each built only if its library was found, with `make` exiting 0 either
way (configure.ac:8220-8248). No flag turns that into an error. So the twelve
imports in `test` are not a formality: they are the only thing standing between
a dependency that stops being linked and a consumer discovering it with
`import ssl` in production.
EOT
}
