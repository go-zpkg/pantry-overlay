# findutils — GNU find, xargs, locate and updatedb.
#
# ⛔ WRITTEN FROM FINDUTILS' OWN FILES at 4.11.0, fourth of the fourteen (#88).
# The base toolchain asks for it by two of its four names: "find + xargs:
# nlnetlabs.nl/ldns walks its own man pages with them at install time"
# (base-toolchain/package.hcl:88-90).
#
# ⛔⛔ AND IT FOUND THE SAME DEFECT CLASS AS gnu.org/diffutils — WITH THE
# OPPOSITE CORRECT REMEDY, AND IN A FILE THE PRESCRIBED SWEEP DOES NOT READ.
# See the build block.

summary = "GNU findutils: find, xargs, locate and updatedb"

# COPYING is the GPLv3 text; find/ftsfind.c:6, xargs/xargs.c:6 and
# locate/locate.c:6 each carry "either version 3 of the License, or (at your
# option) any later version". Both, because only the second answers the
# "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/findutils/"
  match = "/findutils-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^findutils-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/findutils/findutils-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zpkb sourcepin --sig auto --key <james-youngman-C5DDACB9.asc>
  # --fingerprint 0CF4E8D871593224842832B888DD9E08C5DDACB9`: 2 451 424 bytes,
  # signed by James Youngman <james@youngman.org>, 1 key read from the file.
  #
  # ⭐⭐ AND THIS IS THE FIRST RECIPE HERE WHOSE KEY DID NOT COME FROM THE HOST
  # THAT SERVED THE TARBALL. Every GNU recipe before it noted the same limit:
  # gnu-keyring.gpg is fetched from ftp.gnu.org, which is continuity, not
  # independence. That keyring could not answer here at all — `zpkb sourcepin`
  # refused with "no key matching 0CF4E8D8… among the 402 primary key(s) that
  # could be read, and the packet stream stops being readable after them"
  # (go-zpkg/zpkb#450's own wording, distinguishing absent from unreadable). So
  # the key was fetched BY FINGERPRINT from keyserver.ubuntu.com instead, and
  # the warrant is now three hosts that do not derive from each other:
  #
  #   fingerprint   lists.gnu.org   — the release announcement prints it in full
  #   key material  keyserver.ubuntu.com
  #   tarball       ftp.gnu.org
  #
  # keys.openpgp.org was tried first and answers HTTP 404 for this fingerprint:
  # that host serves only keys their owner uploaded and verified. ⛔ Its first
  # fetch exited 56 ("failure receiving network data"), which reads as a network
  # fault; asking again WITH the status printed showed a clean 404. A refusal
  # and a silence are different answers and only one of them is about the key.
  #
  # ⛔ THE SIGNER IS NOT THE ANNOUNCER, and the difference is worth naming. The
  # announcement was sent by Bernhard Voelker and signed off "Bernhard Voelker &
  # James Youngman [on behalf of the GNU findutils maintainers]"; the tarball is
  # signed by Youngman's key, whose fingerprint that message publishes. The two
  # are consistent, but what is pinned is "the key that message named", not "the
  # key of the person who sent it".
  sha256 = {
    "4.11.0" = "bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd"
  }

  # ⭐ THE DIGEST HAS AN INDEPENDENT WITNESS, in hex this time — where
  # gnu.org/tar's announcement published base64 unpadded and gnu.org/diffutils'
  # published base64 padded, findutils' publishes the plain hexadecimal:
  #
  #   bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd
  #
  # character for character what our own fetch-and-hash produced, above.
  #
  # No `sha` field: that one means "where the expected SHA-256 is published" and
  # the build fetches it, so a signature URL there fails every build (#89). The
  # signature is in `provenance` below (go-zpkg/zpkb#282).
}

# ⛔⛔ A RUNTIME DEPENDENCY, AND A CONFIGURE-TIME ONE, FOR THE SAME REASON.
# `updatedb` is a SHELL SCRIPT and its pipeline is `find | sort | frcode`
# (locate/updatedb.sh:321). `sort` is coreutils'. Declaring it is not the
# interesting half, though — see the build block for the half that is: with no
# GNU sort present WHEN CONFIGURE RUNS, the generated updatedb silently stops
# being NUL-safe.
#
# ⛔ AND IT POINTS AT A FRAGMENT TODAY, WHICH IS SAID RATHER THAN HIDDEN.
# gnu.org/coreutils is one of the recipes that "states no versions, no
# distributable, no build" (#85) — it is a base-toolchain member too, so it is
# on the same list this recipe is working through. The dependency is declared
# because the need is real and measured, not because it resolves yet; until
# coreutils is completed, a build of findutils in a tree with no other source of
# `sort` will fail at the `-z` probe's expectations, and the test block says so
# out loud instead of producing a quietly weaker artifact.
dependencies = {
  "gnu.org/coreutils" = "*"
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",
      # `AM_GNU_GETTEXT([external])` (configure.ac:283) — findutils does not
      # bundle libintl, so NLS is a real dependency on gnu.org/gettext.
      "--disable-nls",
      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]

    # ⛔⛔ THE SECOND `AC_PATH_PROG` IN TWO RECIPES, AND THE SWEEP AS WRITTEN
    # WOULD HAVE MISSED IT.
    #
    # gnu.org/diffutils (#92) ended with a rule: run
    # `grep -n 'AC_PATH_PROG\|AC_PATH_PROGS' configure.ac` before writing any
    # autotools recipe. Run here, that command prints NOTHING. findutils has no
    # AC_PATH_PROG in configure.ac at all. The hit is in a LOCAL MACRO FILE,
    # m4/nullsort.m4:2, reached from configure.ac:271 by the single word
    # `jy_SORTZ`:
    #
    #   AC_DEFUN([jy_SORTZ],
    #     [AC_PATH_PROG([SORT], [sort], [sort])
    #
    # So the sweep's SCOPE was wrong, not its pattern — one file instead of the
    # macro search path. The ground truth is the GENERATED configure, which
    # holds every expanded macro: `grep -o 'ac_cv_path_[A-Za-z_0-9]*' configure`
    # returns 83 occurrences here. That is the sweep from now on, and it is
    # being made into a program and a gate rather than a habit.
    #
    # ⛔ WHAT IT WOULD HAVE BAKED. `$SORT` is substituted into the installed
    # `bin/updatedb` (locate/Makefile.am:62, updatedb.sh:111) as
    # `sort="@SORT@ -z"`. Found on PATH, the value is an ABSOLUTE PATH, so this
    # package's own installed script would carry
    # `$ZPKG_DIR/gnu.org/coreutils/v<ver>/bin/sort` — another package's
    # VERSIONED store path, stale the day coreutils is rebuilt. go-zpkg/zpkb#397
    # again, one package over.
    #
    # ⭐⭐ AND THE REMEDY IS THE OPPOSITE OF diffutils', FOR A REASON THAT IS
    # ABOUT THE CONSUMER, NOT THE MACRO. diffutils could not take a bare name:
    # src/util.c:849 runs `execv`, which does not search PATH, so there the
    # cache variable had to be emptied and the feature refused. Here the
    # consumer is a shell script — `$sort` in a pipeline — which DOES search
    # PATH, and `find -exec`/`xargs` use `execvp` as well (find/exec.c:349,
    # xargs/xargs.c:1383). So the right value is the bare NAME, which keeps the
    # artifact relocatable AND keeps the feature:
    #
    #   configure:72523   if test ${ac_cv_path_SORT+y}      — set, not non-empty
    #   configure:72529   "Let the user override the test with a path"
    #   configure:72551   test -z … && ac_cv_path_SORT="sort"
    #
    # — the macro's own fallback when nothing is found is this same bare name,
    # so the value is one upstream already ships with.
    ac_cv_path_SORT = "sort"

    # ⛔⛔ AND THE PROBE THAT CANNOT BE PRESET IS WHY coreutils IS DECLARED.
    # m4/nullsort.m4:10-29 then RUNS `$SORT -z -c` against two fixture files to
    # decide `SORT_SUPPORTS_Z`, and that answer is AC_SUBST'd straight into the
    # installed script (updatedb.sh:109-117):
    #
    #   if true          → sort="sort -z" ; print_option="-print0" ; frcode -0
    #   if false         → sort="sort"     ; print_option="-print"
    #
    # It is assigned unconditionally, with no cache variable and no AC_ARG_VAR,
    # so NOTHING in a recipe can preset it: the only way to get the NUL-safe
    # pipeline is for a GNU sort to be present when configure runs. A sandbox
    # without one yields a findutils that looks identical and whose updatedb
    # splits any filename containing a newline into two database entries. That
    # is gnu.org/tar's silently-degrading `--with-posix-acls` again
    # (tar/package.hcl:108-116), with a sharper consequence, and it is asserted
    # in the test block rather than hoped for.
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# find/Makefile.am:25 `bin_PROGRAMS = find`; xargs/Makefile.am:19
# `bin_PROGRAMS = xargs`; locate/Makefile.am:24-26 `bin_PROGRAMS = locate`,
# `bin_SCRIPTS = updatedb` and `libexec_PROGRAMS = frcode` — so four in bin and
# one in libexec, which is not listed here.
provides = [
  "bin/find",
  "bin/xargs",
  "bin/locate",
  "bin/updatedb",
]

test {
  script = [
    "find --version | grep {{version.raw}}",
    "xargs --version | grep {{version.raw}}",
    "locate --version | grep {{version.raw}}",

    # What the base toolchain actually asks for: ldns walks its own man pages
    # with find and xargs at install time, which is this exact shape.
    "mkdir -p t/d/sub && echo one > t/d/a.txt && echo two > t/d/sub/b.txt",
    "test \"$(find t/d -name '*.txt' -type f | wc -l | tr -d ' ')\" = 2",
    "find t/d -name '*.txt' -print0 | xargs -0 cat > t/cat.out",
    "grep -q one t/cat.out",
    "grep -q two t/cat.out",

    # -exec uses execvp (find/exec.c:349), so it resolves on PATH; asserted
    # because an artifact whose -exec cannot launch anything passes every test
    # above.
    "find t/d -name 'a.txt' -exec cat {} \\;",

    # ⛔⛔ THE ASSERTION FOR THE BAKED PATH. The installed updatedb must name
    # `sort` and nothing else: an absolute store path here is the defect this
    # recipe exists to avoid, and it is invisible in every other test.
    "grep -q 'sort=\"sort -z\"' {{prefix}}/bin/updatedb",
    "! grep -q 'sort=\"/' {{prefix}}/bin/updatedb",

    # ⛔⛔ THE ASSERTION FOR THE PROBE THAT CANNOT BE PRESET. `if true` is
    # SORT_SUPPORTS_Z, substituted at updatedb.sh:109. `if false` means the
    # sandbox had no GNU sort and this artifact's updatedb is not NUL-safe — a
    # difference nothing else observes.
    "grep -q '^if true$' {{prefix}}/bin/updatedb",

    # ⛔ THE COST OF KEEPING LOCATE_DB SELF-REFERENTIAL, STATED AS A TEST.
    # locate/Makefile.am:20+36 compile `-DLOCATE_DB=\"$(localstatedir)/locatedb\"`
    # into the binary, which under --prefix is this package's own versioned
    # store path, and locate.c:1775 uses it as the default. A store prefix is
    # read-only, so the database is never written there: `locate` with no -d and
    # no LOCATE_PATH reports that path missing (locate.c:1786-1789) and that is
    # the honest answer. `--localstatedir=/var` would make it work by reaching
    # into the HOST, which is the trade this recipe declines.
    "locate zzz-no-such-name > t/loc.out 2>&1 || true",
    "grep -q 'var/locatedb' t/loc.out",
  ]
}

provenance {
  read = [
    "configure.ac",      # :271 jy_SORTZ; :283 AM_GNU_GETTEXT external; :297-302 FAKETIME and GROFF; :56-85 the optimisation switches and DEFAULT_ARG_SIZE
    "m4/nullsort.m4",    # :2 AC_PATH_PROG(SORT); :10-29 the -z probe that cannot be preset
    "configure",         # :72523-72556 how SORT may and may not be overridden; :72600-72611 SORT_SUPPORTS_Z
    "locate/Makefile.am", # :20,36 LOCATE_DB compiled in; :45-66 how updatedb is generated; :82-83 GROFF only in check
    "locate/updatedb.sh", # :109-117 the two pipelines; :185,206,213 the substituted paths
    "locate/locate.c",   # :1775 LOCATE_DB as the default; :1786-1789 what a missing database says; :6 the licence
    "find/Makefile.am",  # :25 bin_PROGRAMS = find; :51 GROFF only in check
    "find/exec.c",       # :349 execvp, so -exec resolves on PATH
    "find/ftsfind.c",    # :6 "either version 3 … or any later version"
    "xargs/Makefile.am", # :19 bin_PROGRAMS = xargs
    "xargs/xargs.c",     # :1383 execvp
    "NEWS",              # 4.11.0 (2026-07-11) [stable]
    "COPYING",           # the GPLv3 text that ships
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/bug-findutils/2026-07/msg00050.html",
    "go-zpkg/base-toolchain/package.hcl", # :88-90, which asks for find and xargs by name
  ]

  note = <<EOT
Fourth of the fourteen base-toolchain members that had no recipe of ours (#88).

⛔⛔ THE ANNOUNCEMENT IS NOT ON info-gnu, AND THAT CORRECTS THE PROCEDURE #88
RECORDS. The three patterns written there were about what an announcement
PUBLISHES — a fingerprint, a long key id, or nothing findable. A fourth was
measured here and it is about where the announcement IS: every info-gnu monthly
index from 2026-07 to 2026-11 was fetched (HTTP 200) and none names findutils.
"GNU findutils 4.11.0 released" is on bug-findutils, 2026-07/msg00050, sent
2026-07-11. So "not in info-gnu" is not "no announcement", and gnu.org/patch —
classified as case (c), nothing reachable — is worth asking again on its own
list before anyone writes it on a weaker warrant.

⛔⛔ AND THE SWEEP #92 PRESCRIBED CAME BACK CLEAN ON A SOURCE THAT HAS THE
DEFECT. `grep -n AC_PATH_PROG configure.ac` prints nothing here; the macro is in
m4/nullsort.m4, reached by one word at configure.ac:271. A check whose scope is
one file cannot see a macro search path, and a clean result from it reads
exactly like an absence. The sweep is the generated `configure` from now on
(`ac_cv_path_*`, 83 occurrences in this tree), and because this is the second
occurrence of the same class in two recipes, it is being turned into a program
with a gate rather than a sentence in a note.

⛔ NEITHER groff NOR faketime IS A DEPENDENCY, which was checked rather than
assumed. `AC_CHECK_PROGS([GROFF],[groff],[:])` and the same for faketime
(configure.ac:297-302) default to the no-op `:`, and both are used only by
`check-local` / `check-all-manpages-local` (find/Makefile.am:51,
xargs/Makefile.am:29, locate/Makefile.am:83) — targets this recipe's script
never runs, since it is `configure` then `make install`. Named so that nobody
adds them from the configure log.

⭐ The switches that LOOK like host-dependent choices are not: leaf-optimisation
and the d_type optimization both default to yes with no probe
(configure.ac:56-78), and DEFAULT_ARG_SIZE is defined only when the variable is
passed (configure.ac:80-85), 128k in the source otherwise. The one real
host-dependent decision in this build is SORT_SUPPORTS_Z, and the test block
asserts it.

The digest is signature-verified:

  signature    https://ftp.gnu.org/gnu/findutils/findutils-4.11.0.tar.xz.sig
  key          fetched BY FINGERPRINT from keyserver.ubuntu.com
  identity     James Youngman <james@youngman.org>
  fingerprint  0CF4E8D871593224842832B888DD9E08C5DDACB9, from the release
               announcement on bug-findutils
  checked      when the digest was recorded, not at every build

⭐ This is the strongest warrant of the four so far, and the first one that does
not inherit the limit the other GNU recipes state. gnu.org/m4, gnu.org/gzip,
gnu.org/grep, gnu.org/tar and gnu.org/diffutils all verify against
gnu-keyring.gpg, which comes from the same host as the tarball and holds every
GNU maintainer's key — continuity, not independence. Here the keyring could not
answer (the key is past the point where its packet stream stops being readable,
or not in it), and the fallback is better than the thing it replaced: the
fingerprint from one host, the key material from a second, the tarball from a
third. No keyserver was consulted at verification time; the key is a file.
EOT
}
