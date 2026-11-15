# binutils — the GNU Binary Utilities: ar, nm, objdump, readelf, strip, and on
# linux also the assembler (as) and the BFD linker (ld).
#
# ⛔ WRITTEN FROM BINUTILS' OWN FILES at 2.47, eighth of the base-toolchain
# members (go-zpkg/packages#440, after m4, make, sed, gawk, help2man, coreutils).
# It was THREE LINES — one `dependencies` key naming facebook.com/zstd.
#
# ⛔⛔ AND IT IS THE FIRST ONE WHERE `provides` COULD NOT BE A LIST. The other
# seven install the same programs everywhere. binutils does not: the top-level
# `configure.ac:1103-1132` puts `ld gas gdb gprof` into `noconfigdirs` for
# EVERY darwin target, so on macOS this package ships no `as`, no `ld`, no
# `gprof` — and no flag turns them back on, because it is a `case "${target}"`
# and not an `--enable`. A flat list would be wrong on one platform or the
# other, whichever it was written on. See `provides` below.

summary = "GNU Binutils: ar, nm, objdump, readelf, strip, as and ld"

# COPYING3 is the GPLv3 text; the programs and the libraries they link say so
# in their own headers — `binutils/ar.c:7-8` ("either version 3 of the License,
# or"), `gas/as.c:7-8`, `bfd/bfd.c:8-9`.
#
# ⛔ The second id is NOT decoration and NOT a guess: `libiberty/argv.c:6-9` is
# "GNU Library General Public License … version 2 … or any later version",
# i.e. LGPL-2.0-or-later, and libiberty is linked into every program here.
# COPYING (GPLv2) and COPYING3.LIB (LGPLv3) also ship; this recipe does not
# claim to have classified every file in a 29 MB tarball, only the four it read.
license = [
  "GPL-3.0-or-later",
  "LGPL-2.0-or-later",
]

versions {
  url   = "https://ftp.gnu.org/gnu/binutils/"
  match = "/binutils-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^binutils-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/binutils/binutils-{{version.raw}}.tar.xz"
  strip-components = 1

  # 29 034 716 bytes, fetched and hashed with the builder's own fetcher.
  #
  #   signature    https://ftp.gnu.org/gnu/binutils/binutils-2.47.tar.xz.sig
  #   algorithm    RSA, SHA-512
  #   signed       2026-07-26 (the announcement is dated the same day, 18:18 GMT)
  #   identity     Nick Clifton (Chief Binutils Maintainer) <nickc@redhat.com>
  #   fingerprint  3A24BC1E8FB409FA9F14371813FCEF89DD9E3C4F
  #   verified     when the digest was recorded, not at every build
  #
  # ⭐ A SECOND WITNESS TO THE BYTES, ON A DIFFERENT HOST, WITH THE ALGORITHM
  # NAMED. The release announcement
  # (sourceware.org/pipermail/binutils/2026-July/150449.html, Nick Clifton,
  # Sun 26 Jul 2026 18:18:48 GMT) prints a block headed "Sha256 checksums:",
  # and its line for this file is
  #
  #   154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff  binutils-2.47.tar.xz
  #
  # byte for byte what our fetcher computed from ftp.gnu.org's copy. The two
  # sides CAN differ — one is a digest published by sourceware.org, the other a
  # digest we computed over bytes served by ftp.gnu.org — which is what makes
  # the agreement a control and not the useless kind that
  # gnu.org/coreutils produced (see that recipe's note).
  #
  # ⛔ THE KEY, HOWEVER, HAS ONLY ONE WITNESS, and this recipe says so rather
  # than implying otherwise. The announcement prints NO fingerprint and no key
  # id — checked, not assumed. So the fingerprint above comes from two places
  # that are not independent of each other: the signature's own issuer
  # subpacket, and GNU's keyring. That is the gnu.org/coreutils shape, not the
  # gnu.org/sed shape, where a mailing-list post on another host named the
  # fingerprint outright.
  sha256 = {
    "2.47" = "154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff"
  }

  # ⛔ NO `sha` FIELD: `sha` means "where the expected SHA-256 is PUBLISHED", a
  # file the build fetches and compares, so a `.sig` there fails every build
  # (go-zpkg/packages#89). The signature URL is in `provenance` below
  # (go-zpkg/zpkb#282).
}

# WHAT THE ARTIFACT LINKS. Both of these replace a copy that would otherwise be
# silently chosen for us — see the two flags in `build.env.ARGS`.
dependencies = {
  # `config/zstd.m4:16` is `PKG_CHECK_MODULES(ZSTD, [libzstd >= 1.4.0], …)`, so
  # 1.4.0 is the stated floor and `^1.4` is the constraint the project actually
  # has. The three-line fragment this recipe replaces said `^1`, which is true
  # but looser than what the file says.
  "facebook.com/zstd" = "^1.4"

  # `config/zlib.m4:1-3`, verbatim: "A function to check if the system's zlib
  # library should be used. The builtin zlib is used by default unless the user
  # configured with --with-system-zlib." So without that flag the artifact
  # carries a VENDORED zlib and declares nothing — see the flag below.
  #
  # No floor: binutils states none anywhere, and inventing one asserts a
  # requirement the project does not have (the mistake gnu.org/grep's inherited
  # `=10.47` pin was).
  "zlib.net" = "^1"
}

build {
  # `PKG_CHECK_MODULES` in config/zstd.m4 is what needs this — the same
  # justification as gnu.org/grep/package.hcl:83-86, and the same constraint.
  # Without pkg-config the macro takes its failure branch, and with
  # `--with-zstd=yes` that branch is `AC_MSG_ERROR`, so the build stops instead
  # of quietly dropping zstd. That is the behaviour we want, but it means
  # pkg-config is a real build dependency and not a convenience.
  #
  # `go-zpkg/base-toolchain/package.hcl:114` also stages it, so this is a
  # declaration of what the build needs rather than a request for something new.
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  # ⛔ NO texinfo AND NO help2man DEPENDENCY, and the reason is a near miss.
  #
  # `configure.ac:3963-3974` is `AC_CHECK_PROGS([MAKEINFO], makeinfo, [$MISSING
  # makeinfo])`, with a version check that also falls back to `$MISSING` for a
  # makeinfo older than 4.7. `missing` is automake's, scriptversion
  # 2013-10-28 — the same copy gnu.org/coreutils reads — and it exits with the
  # program's status (127) WITHOUT touching the target. So any `.info` that has
  # to be rebuilt fails the install outright.
  #
  # Nothing has to be rebuilt, because the built pages ship:
  # `binutils/doc/binutils.info`, `gas/doc/as.info`, `ld/ld.info`,
  # `ld/ldint.info`. Our fetcher preserves the tarball's mtimes
  # (go-zpkg/zpkb fetch.go:332, TestExtractRestoresModTimes), so each `.info`
  # stays newer than its `.texi` and make never fires the rule. Man pages ship
  # too (`binutils/doc/*.1`, `gas/doc/as.1`, `ld/ld.1`), so help2man is not
  # needed either.
  #
  # ⛔⛔ EXCEPT IN ONE COMPONENT, AND THAT IS HALF OF WHY gprofng IS OFF.
  # `gprofng/doc/` ships `.texi` sources and `.1` man pages and NO `.info` at
  # all — the only component in the tree missing its built page — while
  # `gprofng/doc/Makefile.am:33` declares `info_TEXINFOS = gprofng_ug.texi`.
  # With gprofng enabled and no makeinfo on PATH, `make install` reaches
  # `$MISSING makeinfo` on a target that does not exist and the build dies.
  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Same reason as every other GNU recipe here: NLS off removes the
      # libintl coupling, and with it the darwin gettext dependency the pkgx
      # overrides had to declare for sed, coreutils and m4.
      "--disable-nls",

      # ⛔⛔ THE FOURTH AUTO-DETECTION INSTANCE IN THIS CAMPAIGN, and the one
      # the three-line fragment existed to patch around. `config/zstd.m4:12`
      # is
      #
      #     [], [with_zstd=auto]
      #
      # so on a builder that happens to have libzstd.pc the artifact can read
      # zstd-compressed debug sections, and on one that does not it silently
      # cannot — same recipe, same version, two different binutils. The flag
      # makes the choice ours: `:18-19` is
      #
      #     if test "$with_zstd" = yes; then
      #       AC_MSG_ERROR([--with-zstd was given, but pkgconfig/libzstd.pc is not found])
      #
      # which fails LOUDLY at configure time instead of shipping a reduced
      # artifact. Paired with the declared `facebook.com/zstd` above.
      #
      # ⭐ The witness that it took effect is in the test block, and it is an
      # `#ifdef`, not a guess: `binutils/objcopy.c:580-584` defines
      # `ZSTD_OPT "|zstd"` only under `HAVE_ZSTD`, and `:711` interpolates it
      # into the `--compress-debug-sections[={none|zlib|zlib-gnu|zlib-gabi%s}]`
      # help line.
      "--with-zstd=yes",

      # ⛔⛔ THE FIFTH, AND IT IS NOT A PROBE BUT A VENDORED COPY — which is
      # worse, because nothing about the builder can make it come out right.
      # `zlib/` ships inside the tarball and `config/zlib.m4:7-15` points every
      # host subdir at it unless this flag is given. Our artifact would then
      # carry a second zlib that the registry does not know about, so a CVE in
      # zlib would have to be fixed in binutils too.
      #
      # With the flag, `configure.ac:250-253` drops `zlib` from `configdirs`
      # and `:2997-3003` appends `--with-system-zlib` to `extra_host_args`, so
      # it reaches bfd and libctf as well; `zlibdir`/`zlibinc` go empty and
      # plain `-lz` is used. Paired with the declared `zlib.net` above.
      #
      # It also removes `zlib/contrib/minizip/Makefile.am:4`
      # (`bin_PROGRAMS = miniunzip minizip`) from the tree, which is the only
      # other `bin_PROGRAMS` in the census below.
      "--with-system-zlib",

      # ⛔⛔ gprofng OFF, for two measured reasons, neither of them taste.
      #
      # 1. ITS PRESENCE DEPENDS ON THE libc, WHICH `provides` CANNOT KEY ON.
      #    `configure.ac:417-423` adds it to `configdirs` only for
      #    `x86_64|i?86|aarch64|riscv64-*-linux*`, and an earlier `*-musl*`
      #    arm excludes musl outright. The schema's platform keys are an OS
      #    and optionally an arch (`schema/package.schema.json:83`); there is
      #    no key for "glibc but not musl". So with gprofng on, `provides`
      #    would be unstatable rather than merely long — it would be right on
      #    a glibc linux and wrong on a musl one with no way to say so.
      #
      # 2. IT IS THE ONE COMPONENT THAT NEEDS makeinfo — see the note above
      #    this env block. Its `.info` is the only one not distributed.
      #
      # What is given up is named rather than waved away: `bin/gprofng`,
      # `bin/gprofng-archive`, `bin/gprofng-collect-app`, the rest of
      # `gprofng/src/Makefile.am:164`, and the `gprofng-display-html` script
      # (`gprofng/gp-display-html/Makefile.am:22`) — a profiler, on linux only.
      # Nothing else in this pantry depends on it.
      "--disable-gprofng",

      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# ⛔⛔ PLATFORM-KEYED, AND THE SPLIT IS THE WHOLE POINT. The shape is the one
# `build.ProvidedCommands` documents and implements (build/build.go:563-616,
# with podman as its example); a flat list is read for every platform, a keyed
# map only for the matching key.
#
# WHERE THE NAMES COME FROM — not from man pages, which is the mistake
# gnu.org/coreutils made (`man/*.x` and `man/*.1` agreed at 108 and 108 and
# five of the names were never installed). Here the source is each component's
# own install rule:
#
#   binutils/Makefile.am:93    bin_PROGRAMS = size objdump ar strings ranlib
#                              objcopy addr2line readelf elfedit, plus five
#                              @BUILD_*@ substitutions
#   binutils/configure.ac:329-361  every one of those five is empty unless the
#                              target is PE/COFF, hms or spu — so on linux and
#                              darwin alike there is no dlltool, windres,
#                              windmc, dllwrap or srconv, and `BUILD_MISC`
#                              (bin2c) and `BUILD_INSTALL_MISC` (embedspu) are
#                              empty too
#   binutils/Makefile.am:107-108, :553-559  the three RENAMED_PROGS are
#                              installed from noinst with `-new` stripped and
#                              `cxxfilt` rewritten: nm-new→nm, strip-new→strip,
#                              cxxfilt→$(DEMANGLER_NAME)
#   binutils/configure.ac:185-190  DEMANGLER_NAME = c++filt (only go32/msdos
#                              get `cxxfilt`)
#   gas/Makefile.am:381, :572-579  noinst_PROGRAMS = as-new, installed into
#                              bindir with `-new` stripped → bin/as
#   ld/Makefile.am:130-131, :777-795  bin_PROGRAMS = ld-new, transformed to
#                              $(installed_linker), and hardlinked to `ld` when
#                              install_as_default is yes
#   ld/configure.ac:119-137    installed_linker = ld.bfd in ALL THREE branches,
#                              and install_as_default defaults to yes — so BOTH
#                              names are installed, which is why both are listed
#   gprof/Makefile.am:40       bin_PROGRAMS = gprof
#
# ⛔ `gold` IS NOT HERE AND IT IS NOT AN OVERSIGHT: 2.47 drops it from the
# source tarball (there is no `gold/` directory), so there is no `ld.gold` and
# no `dwp`. The release coverage says the same.
#
# The census was taken over the whole tree, not one directory: the only other
# `bin_PROGRAMS`/`bin_SCRIPTS` lines in any Makefile.am belong to
# `zlib/contrib/minizip` (removed by --with-system-zlib) and to gprofng
# (disabled above).
provides = {
  # The twelve from binutils/, which are everything this package installs on
  # macOS — `configure.ac:1106` (aarch64-*-darwin*) and `:1129` (*-*-darwin*)
  # both put `ld gas gdb gprof` in noconfigdirs.
  darwin = [
    "bin/addr2line",
    "bin/ar",
    "bin/c++filt",
    "bin/elfedit",
    "bin/nm",
    "bin/objcopy",
    "bin/objdump",
    "bin/ranlib",
    "bin/readelf",
    "bin/size",
    "bin/strings",
    "bin/strip",
  ]

  # The same twelve, plus the assembler, the two names of the BFD linker, and
  # the profiler that darwin does not get.
  linux = [
    "bin/addr2line",
    "bin/ar",
    "bin/as",
    "bin/c++filt",
    "bin/elfedit",
    "bin/gprof",
    "bin/ld",
    "bin/ld.bfd",
    "bin/nm",
    "bin/objcopy",
    "bin/objdump",
    "bin/ranlib",
    "bin/readelf",
    "bin/size",
    "bin/strings",
    "bin/strip",
  ]
}

test {
  script = [
    # Every program prints "GNU <tool> (GNU Binutils) <version>", so one grep
    # per tool asserts both that it exists and that it is OURS rather than the
    # host's.
    "ar --version | grep {{version.raw}}",
    "nm --version | grep {{version.raw}}",
    "objdump --version | grep {{version.raw}}",
    "readelf --version | grep {{version.raw}}",
    "strip --version | grep {{version.raw}}",
    "size --version | grep {{version.raw}}",
    "strings --version | grep {{version.raw}}",
    "addr2line --version | grep {{version.raw}}",
    "objcopy --version | grep {{version.raw}}",
    "ranlib --version | grep {{version.raw}}",
    "elfedit --version | grep {{version.raw}}",

    # ⛔ THE RENAME, ASSERTED. `c++filt` is installed from a binary built as
    # `cxxfilt` (binutils/Makefile.am:553-559 + configure.ac:185), so the name
    # existing at all is the install rule working. The demangling is the real
    # check: _Z3foov is the Itanium ABI mangling of `foo()`.
    "test \"$(c++filt _Z3foov)\" = 'foo()'",

    # ⛔ AND THE TWO THAT ARE INSTALLED FROM `-new` BINARIES. A build where
    # install-exec-local did not run leaves `nm-new`/`strip-new` in the build
    # tree and nothing in bin/, which every `--version` line above would catch
    # for nm and strip but for no other tool — so they are worth naming.
    "test ! -e {{prefix}}/bin/nm-new",
    "test ! -e {{prefix}}/bin/strip-new",

    # ⛔⛔ THE ZSTD FLAG'S WITNESS, tied to an `#ifdef` and not to a feeling.
    # binutils/objcopy.c:580-584 defines ZSTD_OPT as "|zstd" under HAVE_ZSTD
    # and as "" otherwise; :711 interpolates it into the help line. So this
    # exact substring appears if and only if --with-zstd=yes took effect, and
    # an auto-detected build on a zstd-less builder fails here.
    "objcopy --help | grep 'zlib-gabi|zstd'",

    # ar and ranlib on a real archive: create one, list it, index it. This is
    # what every `./configure` in this factory actually calls them for, and it
    # exercises the member table rather than the version banner.
    "cd /tmp && rm -f bu-m.txt bu-t.a && printf 'x' > bu-m.txt && ar rcs bu-t.a bu-m.txt && ar t bu-t.a | grep bu-m.txt && ranlib bu-t.a",

    # ⛔⛔ THE PLATFORM SPLIT, ASSERTED IN BOTH DIRECTIONS rather than skipped
    # on the platform where it is awkward. On linux the assembler, both linker
    # names and the profiler must be present AND be ours; on darwin they must
    # be ABSENT, because `configure.ac:1103-1132` cannot build them there. A
    # one-sided test would pass on a darwin build that somehow shipped a host
    # `as`, and that is exactly the confusion `provides` exists to prevent.
    "if test \"$(uname)\" = Darwin; then test ! -e {{prefix}}/bin/as && test ! -e {{prefix}}/bin/ld && test ! -e {{prefix}}/bin/ld.bfd && test ! -e {{prefix}}/bin/gprof; else as --version | grep {{version.raw}} && ld.bfd --version | grep {{version.raw}} && ld --version | grep {{version.raw}} && gprof --version | grep {{version.raw}}; fi",

    # ⛔ AND THE DISABLED COMPONENT, on every platform: --disable-gprofng must
    # leave nothing behind. Without this, turning the flag off by accident would
    # be invisible until `zpkb provides` compared bin/ against the list above.
    "test ! -e {{prefix}}/bin/gprofng",
    "test ! -e {{prefix}}/bin/gprofng-archive",
    "test ! -e {{prefix}}/bin/gprofng-display-html",
  ]
}

provenance {
  read = [
    "configure.ac",                   # :246-253 bundled zlib unless --with-system-zlib; :412-424 gprofng only on glibc linux x86_64/i?86/aarch64/riscv64, musl excluded; :1103-1132 EVERY darwin target drops ld gas gdb gprof; :2997-3003 --with-system-zlib propagates via extra_host_args; :3963-3974 MAKEINFO = $MISSING makeinfo
    "config/zstd.m4",                 # :12 with_zstd=auto is AUTO-DETECTION; :16 libzstd >= 1.4.0 via PKG_CHECK_MODULES; :18-19 AC_MSG_ERROR when =yes and no .pc
    "config/zlib.m4",                 # :1-3 "the builtin zlib is used by default"; :7-15 zlibdir/zlibinc point into the vendored copy unless --with-system-zlib
    "missing",                        # automake scriptversion 2013-10-28: no touch, exits with the program's status
    "binutils/Makefile.am",           # :93 bin_PROGRAMS; :95 bin_SCRIPTS = @BUILD_INSTALL_MISC@; :107-108 RENAMED_PROGS and noinst_PROGRAMS; :113 TOOL_PROGS (tooldir, not bin); :553-559 install-exec-local strips -new and renames cxxfilt
    "binutils/configure.ac",          # :185-190 DEMANGLER_NAME = c++filt; :329-361 BUILD_SRCONV/BUILD_MISC/BUILD_INSTALL_MISC and the PE-only BUILD_DLLTOOL family, all empty here
    "binutils/objcopy.c",             # :580-584 ZSTD_OPT under #ifdef HAVE_ZSTD; :711 the help line it lands in; :3959-3961 the fatal when zstd is asked for without support
    "gas/Makefile.am",                # :381 noinst_PROGRAMS = as-new; :567-590 install-exec-bindir installs it as bin/as, install-exec-tooldir links tooldir/bin/as
    "gas/configure.ac",               # :222 install_tooldir = install-exec-tooldir
    "ld/Makefile.am",                 # :130-131 transform ld-new -> $(installed_linker); :777-795 install-exec-local, and the install_as_default hardlink to `ld`
    "ld/configure.ac",                # :119-137 installed_linker = ld.bfd in all three branches; install_as_default defaults to yes
    "gprof/Makefile.am",              # :40 bin_PROGRAMS = gprof
    "gprofng/doc/Makefile.am",        # :33 info_TEXINFOS = gprofng_ug.texi — and gprofng/doc ships NO .info, the only component that does not
    "gprofng/src/Makefile.am",        # :164 bin_PROGRAMS — what --disable-gprofng gives up, named
    "gprofng/gp-display-html/Makefile.am", # :22 bin_SCRIPTS = gprofng-display-html
    "zlib/contrib/minizip/Makefile.am",    # :4 bin_PROGRAMS = miniunzip minizip — the only other bin_PROGRAMS in the tree, removed with the vendored zlib
    "bfd/configure.ac",               # :232 "Link in zlib/zstd if we can. This allows us to read compressed debug sections."
    "Makefile.def",                   # :141-143 host_modules zlib with no_install; :489 all-bfd depends on all-zlib
    "Makefile.tpl",                   # :412 MAKEINFO = @MAKEINFO@; :718 it is passed down to every subdir
    "COPYING3",                       # the GPLv3 text that ships
    "binutils/ar.c",                  # :7-8 "either version 3 of the License, or"
    "gas/as.c",                       # :7-8 the same; :742 "the GNU General Public License version 3 or later"
    "bfd/bfd.c",                      # :8-9 the same
    "libiberty/argv.c",               # :6-9 GNU Library GPL version 2 or later — linked into every program here
  ]

  consulted = [
    "https://sourceware.org/pipermail/binutils/2026-July/150449.html", # the announcement: "Sha256 checksums:" block, and NO key fingerprint
    "go-zpkg/packages overrides/gnu.org-binutils.hcl",                 # nothing to carry: the overlay fragment WAS the whole override
    "gnu.org/coreutils/package.hcl",                                   # the "beyond the break but exportable" key shape, and the man-page cross-check that was worthless
    "gnu.org/grep/package.hcl",                                        # :83-86, why pkg-config is declared and why an exact pin is wrong
    "gnu.org/sed/package.hcl",                                         # the shape these follow
  ]

  note = <<EOT
Eighth of the base-toolchain members written from the project's own files
(go-zpkg/packages#440). The fragment it replaces was THREE LINES:

    dependencies = {
      "facebook.com/zstd" = "^1"
    }

⭐⭐ WHAT WRITING IT FOUND, which is the point of writing rather than
converting:

  - `provides` CANNOT BE A LIST HERE, and that was not visible from the
    fragment or from anything upstream says. `configure.ac:1103-1132` drops
    `ld gas gdb gprof` for every darwin target, with no `--enable` to put them
    back. A recipe written on either platform alone would have shipped a list
    that was wrong on the other, and nothing in the build would have said so —
    the same silent class as gnu.org/coreutils' five phantom names, reached by
    a different road.
  - THE FRAGMENT'S OWN CONSTRAINT WAS LOOSER THAN THE FILE. `^1` versus the
    `libzstd >= 1.4.0` that `config/zstd.m4:16` states. Not wrong; just not
    measured.
  - A VENDORED zlib NOBODY HAD NOTICED. `config/zlib.m4:1-3` says the builtin
    copy is used by default, so every binutils this factory has built carries
    a zlib the registry does not know about. `--with-system-zlib` plus a
    declared `zlib.net` fixes it, and `configure.ac:2997-3003` was read to
    confirm the flag actually reaches bfd and libctf rather than stopping at
    the top level.
  - gprofng HAD TO GO, and the decisive reason is not the one I expected. Its
    linux-only build is awkward but statable; what is NOT statable is that it
    is excluded on musl, because `provides` keys on OS and arch and there is no
    key for a libc (schema/package.schema.json:83). The second reason is
    independent and would have been enough on its own: `gprofng/doc` is the
    only component in the tree that ships no built `.info`, so it is the only
    one that genuinely needs makeinfo at install time.
  - `gold` IS GONE IN 2.47. Checked in the tree (no `gold/` directory) before
    the release coverage was read, not after, so `ld.gold` and `dwp` are absent
    from `provides` for a reason and not by omission.

⛔ THE TRUST CHAIN IS STRONG ON THE BYTES AND SINGLE-WITNESSED ON THE KEY, and
the recipe says which is which instead of letting "verified" cover both.

  signature    https://ftp.gnu.org/gnu/binutils/binutils-2.47.tar.xz.sig
  algorithm    RSA, SHA-512 — not the DSA/SHA-1 that gnu.org/help2man's
               verifier refuses
  identity     Nick Clifton (Chief Binutils Maintainer) <nickc@redhat.com>
  fingerprint  3A24BC1E8FB409FA9F14371813FCEF89DD9E3C4F
  key source   ftp.gnu.org/gnu/gnu-keyring.gpg, local copy — and it sits
               BEYOND THE BREAK. The OpenPGP reader stops at the entity with
               multiple embedded signatures (402 primary keys read), as it did
               for gnu.org/make and gnu.org/coreutils; `gpg --export` of the
               single key produced a 3106-byte file that reads cleanly:
               "1 key(s) read from the file". Positional, not absolute — the
               measurement gnu.org/sed's recipe established.
  digest       published independently by sourceware.org in a block headed
               "Sha256 checksums:", identical to ours byte for byte
  NOT verified the fingerprint against a second host: the announcement prints
               no key id. gnu.org/sed's chain has that leg; this one does not,
               and claiming it would be the easiest kind of false measured
               claim to publish (gnu.org/make's recipe had to be corrected in
               go-zpkg/packages#116 for exactly that).
  checked      when the digest was recorded, not at every build

No keyserver was asked. An unknown key is a refusal here, not a download.
EOT
}
