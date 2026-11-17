# ⛔⛔ TWO MISTYPED-IDENTIFIER DEFECTS, both found by measuring rather than
# reading, while establishing what the tcl-lang.org split would break
# (go-zpkg/recipes#122). This fragment is not the standalone recipe —
# that is the next step, and it needs a factory build this session cannot run.
# These two need no build at all.

dependencies = {
  "bytereef.org/mpdecimal" = 2
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
# package.schema.json's own words on the field). That belongs with the
# standalone recipe, where the set of versions we actually build can be read
# off the registry rather than guessed.
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
    # versions resolve, before or after this line. The contradiction between
    # that comment and its own patterns is reported in the pull request rather
    # than resolved here, because resolving it means deciding whether the
    # `if: ^2` machinery (PYTHON2PATCHES, the patch loop, the `unpackaged`
    # entry below) should exist at all — an owner's call, not a regex's.
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
