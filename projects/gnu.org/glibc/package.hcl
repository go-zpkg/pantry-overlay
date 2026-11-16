# gnu.org/glibc — the C library every other package links, and the last of the
# two projects go-zpkg/pantry-overlay#88 puts on the floor of its campaign.
#
# ⛔ WRITTEN FROM GLIBC'S OWN FILES (go-zpkg/packages#431), at 2.44, read out of
# the release tarball rather than a mirror's branch. go-zpkg/pantry-overlay#126
# wrote the other one (kernel.org/linux-headers) and took the measured gap from
# 9 to 8; this takes it to 7.
#
# ⛔⛔ AND IT CORRECTS THE PROJECT'S OWN DOCUMENTATION, which was about to cost
# this campaign a fabricated blocker. INSTALL:478-503 says
#
#     * GCC 12.1 or newer
#       GCC 12.1 or higher is required.
#     * GNU 'binutils' 2.39 or later
#       You must use GNU 'binutils' (as and ld) to build the GNU C Library.
#
# and go-zpkg/base-toolchain's compiler is llvm.org. Read as written, glibc
# could not be built by this fleet's toolchain at all, and #88's floor would
# have needed a gnu.org/gcc nobody has written. THE CODE SAYS OTHERWISE, and
# the code is the authority — configure.ac:557-566:
#
#     # Require GCC 12.1 to build.
#     #if (!defined __GNUC__ || __GNUC__ < 12 || (__GNUC__ == 12 && __GNUC_MINOR__ < 1)) \
#         && (!defined __clang__ || __clang_major__ < 18)
#     #error insufficient compiler
#
# clang 18 or newer is accepted, and the comment one line above the test is as
# stale as INSTALL. The linker check says the same: configure.ac:516-522 accepts
# `LLD 13.0.0 or higher` explicitly, setting `libc_cv_with_lld=yes`, beside GNU
# ld >= 2.39 and gold >= 1.14. llvm.org resolves to 23.x, so both gates pass.
#
# ⭐ The lesson is the one go-pdfkit/reader#66 paid for four times in one pull
# request: a STATED rule can be wrong while the code is right. The prose here is
# upstream's, not ours, which makes it easier to believe and no more true.

summary = "The GNU C Library: libc, the dynamic loader, libm, libpthread and the NSS machinery"

# ⛔ READ FROM TWO PLACES, BECAUSE THE ARTIFACT CARRIES TWO LICENCES.
#
#   - the LIBRARY is LGPL 2.1 **or later**: csu/libc-start.c:5-7 — "under the
#     terms of the GNU Lesser General Public License ... either version 2.1 of
#     the License, or (at your option) any later version" — and COPYING.LIB is
#     the LGPL 2.1 text itself.
#   - `nscd`, a PROGRAM, is GPL 2 or later: nscd/nscd.c:4-7, "the GNU General
#     Public License ... version 2 of the License, or (at your option) any
#     later version".
#
# ⚠ So the expression depends on a build switch: with `--disable-build-nscd`
# below, the GPL daemon is not built and not installed. The GPL half is kept in
# the expression anyway rather than claiming an LGPL-only artifact, because
# `nscd` is the one GPL program this recipe READ — other programs under
# install-bin were not each opened, and narrowing a licence on an unread
# majority is the kind of claim this tree does not make.
license = "LGPL-2.1-or-later AND GPL-2.0-or-later"

# glibc builds for Linux and for Hurd; this fleet targets neither Hurd nor any
# non-Linux host for a libc. Stated rather than left to fail late.
platforms = ["linux"]

versions {
  url   = "https://ftp.gnu.org/gnu/glibc/"
  match = "/glibc-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^glibc-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/glibc/glibc-{{version.raw}}.tar.xz"
  strip-components = 1

  # 20620544 bytes, recorded with the builder's own fetcher and a verified
  # signature:
  #
  #   zpkb sourcepin --sig auto --key ./huettel.asc \
  #     --fingerprint "35B1 7DF5 7525 77CA 0C54  1CEB 94BF DF44 84AD 142F" \
  #     --key-source "<see provenance>" --version 2.44 \
  #     https://ftp.gnu.org/gnu/glibc/glibc-2.44.tar.xz
  #
  #   signed by 35B17DF5752577CA0C541CEB94BFDF4484AD142F
  #   Andreas K. Huettel (at work) <mail@akhuettel.de>
  #   no keyserver was asked
  #
  # and confirmed by a second, independent fetch-and-hash (`curl --fail` +
  # `shasum -a 256`): two paths, one answer. The trust chain, and the two
  # dead ends it took to find, are in `provenance.note`.
  sha256 = {
    "2.44" = "37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667"
  }
}

build {
  dependencies = {
    # ⛔ THE FOUR configure CALLS "critical" — it ABORTS on each, so these are
    # not politeness. Versions are glibc's OWN minimums, from the checks that
    # enforce them, not thresholds invented here:
    #
    #   make    >= 4.0     configure.ac:534-536
    #   gawk    >= 3.1.2   configure.ac:550-552
    #   bison   >= 2.7     configure.ac:553-555
    #   python3 >= 3.4     configure.ac:591-594
    #
    # all gathered into `critic_missing` and reported by :598-600
    # ("*** These critical programs are missing or too old").
    "gnu.org/make"  = ">=4"
    "gnu.org/gawk"  = ">=3.1.2"
    "gnu.org/bison" = ">=2.7"

    # ⚠⚠ python.org IS NOT IN go-zpkg/base-toolchain — checked against its 25
    # members name by name. So glibc, a member of that set, needs a tool the
    # set does not carry, exactly as kernel.org/linux-headers needed rsync
    # (go-zpkg/pantry-overlay#126). Reported on #88 rather than left for the
    # first person to run the factory.
    "python.org" = ">=3.4"

    # The three configure calls "auxiliary": it WARNS and disables features
    # (configure.ac:602-604). Declared anyway, because "some features will be
    # disabled" decided by what happened to be staged is the same defect class
    # as a library auto-detected into the artifact.
    #
    #   sed      >= 3.02   configure.ac:546-549
    #   makeinfo >= 4.7    configure.ac:542-545   (gnu.org/texinfo)
    #   msgfmt   >= 0.10.36 configure.ac:538-541  (gnu.org/gettext)
    "gnu.org/sed"     = ">=3.02"
    "gnu.org/texinfo" = ">=4.7"
    "gnu.org/gettext" = "*"

    # The linker, checked at configure.ac:506-530. GNU ld >= 2.39 is the arm
    # this takes; LLD >= 13 and gold >= 1.14 are the other two it would accept.
    "gnu.org/binutils" = ">=2.39"

    # ⛔⛔ AND THE HEADERS THE LIBC'S ABI IS CUT AGAINST — the reason
    # go-zpkg/pantry-overlay#126 came first. See `--with-headers` below for why
    # leaving this to the compiler's default is not an option.
    "kernel.org/linux-headers" = "*"
  }

  # ⛔⛔ THE SWITCH CENSUS. 36 AC_ARG_ENABLE/AC_ARG_WITH in configure.ac were
  # read; what follows states every one whose default is NOT a deterministic
  # constant — that is, every one where something outside the recipe decides
  # what lands in the artifact. The rest keep upstream's defaults, which are
  # fixed values in glibc's own files and so are defaults rather than guesses.
  #
  # ⛔ THREE LIBRARIES ENTER THIS ARTIFACT BY AUTO-DETECTION, and the third is
  # NESTED inside the second, which is what makes this worse than curl's
  # brotli/zstd case:
  #
  #   1. libgd (+ libpng, libz, libm) — configure.ac:1702-1710. Unless
  #      `--with-gd=no`, configure LINK-TESTS `-lgd -lpng -lz -lm` and sets
  #      LIBGD=yes if they happen to be there. malloc/Makefile:385-390 then
  #      reads that: `ifneq ($(cross-compiling),yes)` / `ifneq ($(LIBGD),no)` /
  #      `install-bin = memusagestat`. So FOUR libraries and one entry in
  #      `provides` all hang off what was staged.
  #   2. libselinux — configure.ac:164-168 defaults `with_selinux=auto`, and
  #      :1725 `AC_CHECK_LIB(selinux, is_selinux_enabled)` decides. Found means
  #      HAVE_SELINUX and nscd links it.
  #   3. libaudit — configure.ac:1738, `AC_CHECK_LIB(audit, ...)`, reached ONLY
  #      when selinux was found. A detection inside a detection: nothing in the
  #      recipe mentions audit, and whether it is linked depends on two
  #      unrelated libraries being present.
  #
  # Both are shut off below, which settles all four libraries and makes
  # `bin/memusagestat` deterministically absent.
  #
  # ⚠ `--enable-cet` is the fourth of this family and is NOT settled here:
  # configure.ac:383-394 defaults it to `$libc_cv_compiler_default_cet`, i.e.
  # to whether the COMPILER defines __CET__. That is decided by how llvm.org was
  # built, not by what is staged, and this recipe has not measured our clang's
  # answer — so it is left at upstream's default and named as unmeasured rather
  # than pinned to a value nobody checked.
  #
  # ⚠ `--enable-kernel` is deliberately NOT passed. configure.ac:290-303 gives
  # it no default at all, and `=current` would read the BUILDER's `uname -r`
  # (:301) — which would be the kernel.org/linux-headers defect over again. Left
  # unset, the value is glibc's own constant:
  # sysdeps/unix/sysv/linux/configure.ac:36 `arch_minimum_kernel=3.2.0`, with
  # per-arch overrides in the same tree — measured for our three targets:
  # x86-64 3.2.0, aarch64 3.7.0 (aarch64/configure.ac:4), s390x 3.2.0 (no
  # override). Deterministic and traceable, so a default and not a guess; a
  # number typed here instead would be a minimum-kernel policy this fleet has
  # never stated.
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ Settles libgd, libpng, libz and libm, and removes bin/memusagestat.
      "--with-gd=no",

      # ⛔ Settles libselinux AND, by consequence, libaudit.
      "--without-selinux",

      # ⛔⛔ THE ABI'S OWN INPUT. configure.ac:170-177 defaults `sysheaders=''`,
      # documented as "@<:@default=compiler default@:>@" — the kernel headers
      # the build COMPILER happens to find. A libc compiled against the
      # builder's headers rather than the target's is wrong in exactly the way
      # a wrong asm/ directory is wrong, and silently.
      "--with-headers={{deps.kernel.org/linux-headers.prefix}}/include",

      # ⛔ Names the assembler and linker instead of taking PATH's. Default is
      # `path_binutils=''` (configure.ac:159-163), i.e. whatever `as` and `ld`
      # resolve to in the build environment.
      "--with-binutils={{deps.gnu.org/binutils.prefix}}/bin",

      # ⛔ systemtap's sdt.h is a fourth would-be auto-detection:
      # configure.ac:318-339 defaults it to `no`, and `=auto` is a spelling
      # that compiles the probes in if sys/sdt.h is found. `no` is upstream's
      # default and is restated because the `auto` arm exists.
      "--disable-systemtap",

      # ⛔ The GPL daemon that pulls selinux/audit. Not built, not installed:
      # nscd/Makefile:45 `install-sbin := nscd`. And the client half, which
      # would otherwise try to reach a socket no artifact here provides, on
      # every NSS lookup (configure.ac:349-353 defaults `use_nscd=yes`).
      "--disable-build-nscd",
      "--disable-nscd",

      # ⚠ Upstream's defaults, RESTATED rather than relied on, because each has
      # a non-constant spelling a future reader might reach for:
      #   --enable-profile      default no   (configure.ac:220-224)
      #   --enable-mathvec      default `notset`, "depends on architecture"
      #                                      (configure.ac:377-381)
      #   --enable-build-nscd   default `default` (configure.ac:341-345)
      #   --enable-multi-arch   default `default` (configure.ac:312-316)
      # The last two are resolved per-arch later in configure; `multi-arch` is
      # left at `default` on purpose — it is the per-architecture IFUNC choice
      # and overriding it is a performance decision this recipe has not
      # measured.
      "--disable-profile",
    ]
  }

  # ⛔ GLIBC REFUSES TO BUILD IN ITS SOURCE DIRECTORY, and this is enforced, not
  # advised: configure.ac:115-117
  #
  #   if test "`cd $srcdir; pwd -P`" = "`pwd -P`"; then
  #     AC_MSG_ERROR([you must configure in a separate build directory])
  #
  # INSTALL:15-20 says the same and adds why ("the safest way to get a fresh
  # start"). So the whole build runs from a sibling directory.
  working-directory = "build"

  script = [
    "../configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ `provides` IS CONDITIONAL ON THREE SWITCHES, which is why it is written out
# rather than copied from anywhere. Read from the Makefiles that install them:
#
#   bin/   gencat          catgets/Makefile:33
#          pcprofiledump   debug/Makefile:386
#          sprof           elf/Makefile:209
#          locale          locale/Makefile:87-89
#          localedef       locale/Makefile:87-89
#          getent          nss/Makefile:300
#          makedb          nss/Makefile:300
#          getconf         posix/Makefile:415-416
#          zdump           timezone/Makefile:36      <- --enable-timezone-tools
#          memusagestat    malloc/Makefile:390       <- libgd AND not cross
#   sbin/  iconvconfig     iconv/Makefile:70
#          zic             timezone/Makefile:35      <- --enable-timezone-tools
#          nscd            nscd/Makefile:45          <- --enable-build-nscd
#
# `memusagestat` and `nscd` are therefore NOT listed: this recipe passes
# `--with-gd=no` and `--disable-build-nscd`, so neither is built. Listing a name
# the build does not produce is the defect `zpkb lint` exists to catch, and
# listing one that appears only when a library happened to be staged is worse —
# it would pass on the machine that had libgd and fail everywhere else.
#
# ⚠ The timezone pair IS listed, because --enable-timezone-tools keeps its
# upstream default (yes, configure.ac:230-234).
provides = [
  "bin/gencat",
  "bin/getconf",
  "bin/getent",
  "bin/locale",
  "bin/localedef",
  "bin/makedb",
  "bin/pcprofiledump",
  "bin/sprof",
  "bin/zdump",
  "sbin/iconvconfig",
  "sbin/zic",
]

test {
  script = [
    # The library and the loader are the point; assert they are installed
    # rather than running the 5000-test suite a package build has no business
    # running.
    "test -f \"{{prefix}}/lib/libc.so.6\" || test -f \"{{prefix}}/lib64/libc.so.6\"",

    # A program that has to WORK, not merely exist: getconf reads the libc's
    # own configuration and is the cheapest end-to-end witness.
    "\"{{prefix}}/bin/getconf\" GNU_LIBC_VERSION",

    # ⛔ AND THE TWO ASSERTIONS THAT WOULD CATCH THE AUTO-DETECTIONS COMING
    # BACK. If a future edit drops `--with-gd=no`, memusagestat reappears and
    # the artifact links libgd, libpng and libz; if it drops
    # `--disable-build-nscd`, nscd reappears and may link libselinux and
    # libaudit. Both are asserted as ABSENCES, because that is the direction
    # the defect travels.
    {
      run = <<EOT
for p in bin/memusagestat sbin/nscd; do
  if test -e "{{prefix}}/$p"; then
    echo "glibc: $p was installed, so an auto-detected library is back in this artifact" >&2
    echo "  memusagestat => libgd/libpng/libz (configure.ac:1702-1710, malloc/Makefile:385-390)" >&2
    echo "  nscd         => libselinux, and libaudit nested inside it (configure.ac:1721-1742)" >&2
    exit 1
  fi
done
EOT
    },
  ]
}

provenance {
  read = [
    "INSTALL",                                  # :15-20 separate build dir; :473-585 the tool list whose GCC/binutils prose the code contradicts
    "configure.ac",                             # the 36-switch census; :115-117 out-of-tree; :506-530 linker; :557-566 the clang>=18 arm; :598-604 critical vs auxiliary; :1702-1742 the three auto-detections
    "sysdeps/unix/sysv/linux/configure.ac",     # :36 arch_minimum_kernel=3.2.0, the default --enable-kernel takes
    "sysdeps/unix/sysv/linux/aarch64/configure.ac", # :4 arch_minimum_kernel=3.7.0
    "COPYING.LIB",                              # the LGPL 2.1 text that ships
    "csu/libc-start.c",                         # :5-7 "version 2.1 ... or any later version" — the -or-later
    "nscd/nscd.c",                              # :4-7 the GPL-2.0-or-later half
    "malloc/Makefile",                          # :382-390 memusagestat is conditional on LIBGD and on not cross-compiling
    "catgets/Makefile",                         # install-bin, for `provides`
    "debug/Makefile",
    "elf/Makefile",
    "locale/Makefile",
    "nss/Makefile",
    "posix/Makefile",
    "timezone/Makefile",
    "iconv/Makefile",
    "nscd/Makefile",
  ]

  consulted = [
    # Read for the SIGNING KEY only, never for the build. Arch's list turned
    # out not to cover this tarball (see the note); Gentoo's named the source
    # that did.
    "archlinux/packaging/packages/glibc PKGBUILD (validpgpkeys, and that it builds from a git commit)",
    "gentoo sec-keys/openpgp-keys-glibc-20251014.ebuild (HOMEPAGE and SRC_URI)",
  ]

  note = <<EOT
⛔⛔ FINDING THE SIGNING KEY TOOK THREE DEAD ENDS, AND EACH ONE WOULD HAVE READ
AS "THIS TARBALL CANNOT BE VERIFIED". Written down because the next GNU package
whose release manager has rotated a key will hit the same wall.

  1. THE PROJECT PUBLISHES NO FINGERPRINT WHERE YOU WOULD LOOK.
     sourceware.org/glibc/sources.html — the download page — says nothing about
     signatures at all (zero matches for sign/pgp/gpg/fingerprint).

  2. ARCH'S `validpgpkeys` DOES NOT COVER THIS FILE. It names
     7273542B...A25340F8 (Carlos O'Donell) and BC7C7372...F1CF2187 (Siddhesh
     Poyarekar), and sourcepin refused both with "signature made by unknown
     entity". The reason is in the same PKGBUILD: `pkgver=2.44+r78+gfcfb867c58ab`
     with a `_commit` — Arch builds glibc from a GIT COMMIT, so those keys
     verify TAGS, not the ftp tarball.

  3. NO WEB KEY DIRECTORY. carlos@redhat.com, siddhesh@gotplt.org and
     siddhesh@sourceware.org all answer 404 on both the advanced and direct WKD
     methods.

⭐ WHAT ACTUALLY ANSWERED, and it was a third party's curation rather than the
project: Gentoo's `sec-keys/openpgp-keys-glibc` is described as "OpenPGP keys
used to sign glibc releases", points its HOMEPAGE at
sourceware.org/glibc/wiki/SSDLC/Policy/glibc, and fetches
`https://www.akhuettel.de/key-atwork.txt` with the comment "this is a workaround
until a better source exists". That is Andreas K. Huettel's key, and he signed
this release.

⛔⛔ AND THE FINGERPRINT COMPARISON WAS WRONG THE FIRST TIME, in a way that
reported a false ABSENCE. A detached signature names the key that SIGNED, which
on a modern key is a signing SUBKEY; a published fingerprint is the PRIMARY.
Comparing one against the other said "not here" about a key that was right
there. Measured correctly:

  signing subkey  fd19e6d31b192ee4dc63ead3dc2b16215ed5412a   (RSA, SHA-256,
                  signature created 2026-07-25)
  primary         35b17df5752577ca0c541ceb94bfdf4484ad142f   Andreas K. Huettel

⭐ THE PRIMARY IS IN TWO INDEPENDENT PLACES, which is a BETTER chain than
gnu.org/gzip's and is worth saying so: that recipe records "the key came from
the SAME HOST as the tarball ... continuity, not independence". Here the same
primary key is served by akhuettel.de AND by ftp.gnu.org/gnu/gnu-keyring.gpg —
two hosts, one of which is not where the tarball lives.

⛔⛔ BUT THE GNU KEYRING'S COPY IS REFUSED, AND NOT FOR THE REASON THAT LOOKS
OBVIOUS. Verifying against the keyring's copy gives `openpgp: key expired`,
which is the symptom of go-zpkg/zpkb#484 (expiry judged at time.Now() rather
than at the signature's creation instant). It is NOT that defect, and calling it
that would have been a diagnosis invented to fit a symptom. Measured by reading
the expiries out of both copies:

  copy from ftp.gnu.org   self-sigs created 2024-04-06, key expiry 2026-04-06
                          (EXPIRED) — and the signing subkey with it
  copy from akhuettel.de  self-sigs created 2026-11-15, key expiry 2028-11-14
                          (valid) — signing subkey valid to 2028-11-14

Same primary, created 2013-04-06, in both. The author extended the key on
2026-11-15 and ftp.gnu.org still serves the 2024 snapshot. Against the keyring's
copy the key was expired at the signature's creation instant TOO, so the refusal
is correct for that file — #484 is about the opposite case. The lesson is about
the SOURCE, not the tool: the GNU keyring is a stale mirror for any key whose
owner rotates expiry, and a recipe that pins against it will start failing when
an unrelated person renews their key.

⚠ A SECOND READING OF THE SAME KEYRING, worth recording because gnu.org/gzip
relies on it: `sourcepin --fingerprint` walks it with a sequential reader that
stops at the first unparseable entity, which on this file is after 402 primary
keys, and reports "no key matching ... among the 402 primary key(s) that could
be read ... either the key is beyond that point in this file, or the selector is
wrong". The file actually holds 613 primary keys and 767 subkeys, with 6
unparseable packets that a resynchronising reader simply skips. gzip's key is
found only because it happens to sit before the break. An absence that might be
a failure to read is not an absence.

The digest was then recorded the normal way — the signature checked when the
hash was written, not at build time, which is Guix's division (its `origin`
record has no signature field; `guix refresh` does the checking) — and no
keyserver was asked at any point.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every switch, dependency, minimum version, installed path
and licence traced to a line in glibc's own files and cited in `read` above. The
build is unproven and should be read as such. The test block is written to fail
loudly on the two things most likely to go wrong later — a re-introduced
auto-detected library, and a libc that installs but cannot answer
`getconf GNU_LIBC_VERSION`.
EOT
}
