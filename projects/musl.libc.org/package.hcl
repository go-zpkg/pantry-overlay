# musl.libc.org — the second C library this tree can be rooted on, and the
# first that is not glibc.
#
# ⛔ WRITTEN FROM MUSL'S OWN FILES (go-zpkg/packages#431), at 1.2.6, read out of
# the signed release tarball rather than a distribution's branch. It is step 4
# of go-zpkg/packages#475, and it comes BEFORE step 3 on purpose: step 3 is
# "go-zpkg/base-toolchain stops hardcoding gnu.org/glibc", and until something
# else exists to name, that step removes a libc with nothing to put back.
#
# ⭐ WHAT MAKES THIS RECIPE SHORT IS THE PROJECT, NOT THE EFFORT. glibc's
# configure.ac holds 36 AC_ARG_ENABLE/AC_ARG_WITH; musl's hand-written
# `configure` holds TEN options in total, and its INSTALL names exactly two
# build prerequisites — GNU Make and a freestanding C99 compiler. Three of the
# ten still have a default that something outside this file decides, and all
# three are settled below.
#
# ⛔⛔ AND ONE OF THEM IS NOT A FEATURE SWITCH BUT AN ESCAPE FROM THE PREFIX.
# See `--syslibdir`: left at its default, `make install` writes to the BUILD
# MACHINE's /lib.

summary = "musl libc: a lightweight, correctness-oriented C library and dynamic linker for Linux"

# ⛔ MIT AS A WHOLE, WITH BSD-2-CLAUSE PORTIONS NAMED BY UPSTREAM ITSELF.
# COPYRIGHT:1 — "musl as a whole is licensed under the following standard MIT
# license" — and :111-112 — "Portions of this software are derived from
# third-party works licensed under terms compatible with the above MIT
# license". Of those portions, the ones upstream gives a LICENCE NAME to are
# 2-clause BSD: the TRE regex code (:115-116), the ARM memcpy taken from
# Bionic (:130-132) and the crypt code (:138).
#
# ⚠ The rest are described rather than named — "extremely permissive terms"
# for the FreeBSD/Sun/Arm math code (:121-128), and public domain with a
# permissive fallback (:142-143). They are NOT invented into an SPDX
# identifier here: naming a licence upstream did not name is a claim this tree
# does not make.
license = "MIT AND BSD-2-Clause"

# musl is a Linux libc. Its INSTALL lists only Linux ABIs, and its syscall
# layer is Linux's. Stated rather than left to fail late.
#
# ⚠ Our three arches are all in INSTALL's supported list — x86_64, AArch64 and
# "S390X (64-bit S390)" — so none of them is the reason a lane would not build.
platforms = ["linux"]

versions {
  # ⛔ THE RELEASES PAGE, BECAUSE THE RELEASES DIRECTORY IS NOT BROWSABLE:
  # https://musl.libc.org/releases/ answers 404 (measured 2026-11-18), so there
  # is no index to walk. releases.html links every tarball back to 0.5.0 and is
  # the page the project points at.
  #
  # ⭐ MEASURED RATHER THAN HOPED FOR: `zpkb versions -recipe …` resolves 77
  # versions against the live page, newest first — 1.2.6, 1.2.5, 1.2.4 … —
  # with the prefix and suffix stripped. A `match` that silently matched
  # nothing would look exactly like a project with no releases.
  url   = "https://musl.libc.org/releases.html"
  match = "/musl-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^musl-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://musl.libc.org/releases/musl-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1082499 bytes, recorded with the builder's own fetcher and a verified
  # signature:
  #
  #   zpkb sourcepin --sig auto --key ./musl.pub \
  #     --fingerprint "8364 8929 0BB6 B70F 99FF DA05 56BC DB59 3020 450F" \
  #     --key-source "<see provenance>" --version 1.2.6 \
  #     https://musl.libc.org/releases/musl-1.2.6.tar.gz
  #
  #   signed by 836489290BB6B70F99FFDA0556BCDB593020450F
  #   musl libc <musl@libc.org>
  #   no keyserver was asked
  #   1 key(s) read from the file
  #
  # and confirmed by a second, independent fetch-and-hash (`curl --fail` +
  # `shasum -a 256`): two paths, one answer.
  sha256 = {
    "1.2.6" = "d585fd3b613c66151fc3249e8ed44f77020cb5e6c1e635a616d3f9f82460512a"
  }
}

build {
  # ⛔ THE TOOL LIST IS MEASURED FROM THE MAKEFILE, NOT COPIED FROM INSTALL.
  # INSTALL:16-24 names only "GNU Make and a freestanding C99 compiler
  # toolchain" — true of the COMPILE, and incomplete about the build, which
  # also generates two headers with `sed`.
  dependencies = {
    # INSTALL:16-18, "The only build-time prerequisites for musl are GNU Make
    # and a freestanding C99 compiler toolchain". No version is checked
    # anywhere in `configure`, so none is invented here.
    "gnu.org/make" = "*"

    # ⛔ UNCONDITIONAL, AND IN THE GENERATED-HEADER PATH:
    #   Makefile:99   sed -f tools/mkalltypes.sed … > obj/include/bits/alltypes.h
    #   Makefile:103  sed -n -e s/__NR_/SYS_/p  … >> bits/syscall.h
    # Without it the build fails before a compiler runs, on a prerequisite the
    # project's own INSTALL does not list.
    "gnu.org/sed" = "*"

    # ⚠ CONDITIONAL, AND DECLARED ANYWAY. Makefile:137-141 pipes every .s file
    # through `awk -f tools/add-cfi.*.awk` when ADD_CFI=yes, and
    # configure:421-428 sets that only when CFLAGS carries `-g`. This recipe
    # keeps `--disable-debug`, so the arm is not taken — but a tool need that
    # depends on a flag is the same shape as a library that depends on what
    # was staged, and gawk is already in go-zpkg/base-toolchain, so declaring
    # it costs nothing and removes the condition.
    "gnu.org/gawk" = "*"
  }

  # ⛔⛔ THERE IS NO kernel.org/linux-headers HERE, AND THAT IS THE SHARPEST
  # DIFFERENCE FROM gnu.org/glibc. INSTALL:26-27 states it outright:
  #
  #     The system used to build musl does not need to be Linux-based, nor do
  #     the Linux kernel headers need to be available.
  #
  # glibc's recipe passes `--with-headers=…` precisely because leaving that to
  # the compiler's default cuts the libc's ABI against the BUILDER's headers.
  # musl has no such input: it carries its own syscall numbers
  # (arch/*/bits/syscall.h.in, filtered by Makefile:103). One less thing that
  # can be silently wrong.
  #
  # ⛔ THE SWITCH CENSUS. All ten options in `configure`'s usage block were
  # read. What follows states every one whose default is NOT a deterministic
  # constant — that is, every one where something outside this recipe decides
  # what lands in the artifact — plus the one constant default that writes
  # outside the prefix.
  #
  # ⚠ ONE AUTO-DETECTION IS LEFT UNSETTLED AND NAMED RATHER THAN GUESSED AT:
  # `LIBCC`, the compiler runtime library. configure:618-623 tries, in order,
  # `-lgcc`/`-lgcc_eh`, then `-lcompiler_rt`, then `$CC
  # -print-libgcc-file-name`, then `-print-file-name=libpcc.a`. Which one
  # answers depends on how llvm.org was built, which this recipe has not
  # measured — and llvm.org reaches the build through go-zpkg/base-toolchain
  # rather than through this file, so there is no prefix here to point at. A
  # value typed in would be a claim nobody checked. Same treatment as
  # `--enable-cet` in gnu.org/glibc.
  env = {
    ARGS = [
      # ⛔ The default prefix is /usr/local/musl (configure:17), and INSTALL
      # :122-127 is unusually emphatic about it: "DO NOT set the prefix to
      # '/usr', '/usr/local', or '/' unless you're upgrading libc on an
      # existing musl-based system."
      "--prefix={{prefix}}",

      # ⛔⛔ THE ONE THAT ESCAPES THE PREFIX, AND IT IS NOT A FEATURE SWITCH.
      # The default is the absolute path `/lib` (configure:132, Makefile:18),
      # and it is not decoration:
      #
      #   Makefile:76   LDSO_PATHNAME = $(syslibdir)/ld-musl-$(ARCH)$(SUBARCH).so.1
      #   Makefile:215  install-libs: … $(if $(SHARED_LIBS),$(DESTDIR)$(LDSO_PATHNAME),)
      #   Makefile:212  $(DESTDIR)$(LDSO_PATHNAME): $(DESTDIR)$(libdir)/libc.so
      #
      # `make install` therefore writes `$(DESTDIR)/lib/ld-musl-<arch>.so.1`,
      # and this builder runs `make install` with DESTDIR unset — so the
      # target is the BUILD MACHINE's /lib. Without privileges that fails;
      # with them it silently installs a dynamic linker into the image. Either
      # way the artifact would not carry its own loader.
      #
      # INSTALL:136-144 explains why upstream chose an absolute default — the
      # path is hard-coded into every dynamic-linked program, so a system
      # wants it in one place — and names `--syslibdir` as the escape for
      # exactly our case ("if you are installing without root privileges").
      "--syslibdir={{prefix}}/lib",

      # ⛔ THE TARGET, WHICH OTHERWISE COMES FROM THE COMPILER.
      # configure:316: `test -n "$target" || target=$($CC -dumpmachine …)`.
      #
      # ⚠ SEVERITY, STATED, BECAUSE IT IS NOT THE WORST KIND: this reads the
      # COMPILER's configured target, not the builder's CPU. It is therefore
      # reproducible — the libpng case, not the libffi one, where a CPUID read
      # produced an artifact that SIGILLs elsewhere. It is still passed,
      # because a cross build must say what it targets rather than inherit it.
      #
      # ⭐ AND THE `-gnu` IN OUR TRIPLE IS HARMLESS HERE, which a reader will
      # otherwise take for a defect. zpkb's Target.Triple is still
      # `x86_64-unknown-linux-gnu` even for a musl target — deliberately, see
      # go-zpkg/zpkb#502 — and configure:322-345 converts the triple to an ARCH
      # by matching the PREFIX only (`x86_64*` → x86_64, `aarch64*` → aarch64,
      # `s390x*` → s390x). The suffix is never read. It would NOT be harmless
      # for a compiler driver, which is why the triple is still owed a fix
      # rather than excused.
      "--target={{hw.target}}",

      # ⛔ WHETHER musl IS OPTIMISED DEPENDS ON SOMEBODY ELSE'S FLAGS.
      # The default is `auto` (configure:137), and configure:436-442 resolves
      # it by looking at the ENVIRONMENT:
      #
      #     if fnmatch '-O*|*\ -O*' "$CFLAGS_AUTO $CFLAGS" ; then
      #       printf "using provided CFLAGS\n" ; optimize=no
      #
      # `optimize=no` skips musl's own `-O2` and its eight `-fno-align-*` /
      # `-fira-*` tuning flags (:449-462) AND the per-module `-O3` for
      # `internal,malloc,string` (:463). Measured: zpkb exports CFLAGS
      # (buildscript/wrapper.go:799) and today that value carries `-fPIC` and
      # sysroot flags but no `-O`, so `auto` would resolve to `yes`. That is a
      # fact about zpkb's flags, not about musl — a `-O` added there later
      # would silently change what this artifact is, with nothing failing.
      # `yes` is upstream's own intent when nothing is provided, restated as a
      # constant.
      "--enable-optimize=yes",

      # ⛔⛔ THE ARTIFACT'S BINARIES WOULD DEPEND ON THE BUILD COMPILER'S OWN
      # LIBC. The default is `auto` (configure:142), and configure:282-310
      # decides by compiling a probe that requires `__GLIBC__`:
      #
      #     echo "#if ! __GLIBC__" … "#error no"
      #     if test "$wrapper" = auto && ! $CC -c … ; then  echo "none"
      #     elif test "$cc_family" = gcc  ; then gcc_wrapper=yes
      #     elif test "$cc_family" = clang ; then clang_wrapper=yes
      #
      # So THREE different artifacts are possible from one recipe:
      # `bin/musl-gcc` + `lib/musl-gcc.specs` on a glibc-targeting gcc,
      # `bin/musl-clang` + `bin/ld.musl-clang` on a glibc-targeting clang, and
      # NOTHING on a compiler that does not target glibc — which is precisely
      # what the sovereign lane this recipe exists for would be.
      #
      # ⚠ And the wrappers bake absolute paths at generation time:
      # Makefile:181 and :188 substitute `$(LDSO_PATHNAME)`, `$(includedir)`
      # and `$(libdir)` into the generated scripts. A relocatable artifact must
      # not ship them.
      #
      # Off. `provides` below is then empty and stays empty, rather than being
      # a list that is right on whichever machine happened to build.
      "--disable-wrapper",

      # ⚠ Upstream defaults, RESTATED rather than relied on, because each has
      # a spelling a future reader might reach for and because two of them
      # change what is in the artifact:
      #
      #   --with-malloc   default mallocng (configure:145); `oldmalloc` is a
      #                   real alternative, present at src/malloc/oldmalloc.
      #   --enable-debug  default disabled (configure usage:32). It also
      #                   settles ADD_CFI, and with it the awk dependency
      #                   above (configure:421-428).
      "--with-malloc=mallocng",
      "--disable-debug",
    ]
  }

  # ⚠ NOT an out-of-tree build. glibc REFUSES to configure in its source
  # directory (configure.ac:115-117 is an AC_MSG_ERROR); musl has no such
  # check, and its own INSTALL:113-121 describes running `./configure` from
  # the top-level source directory. Said here because the two libc recipes
  # differ on this and the difference looks like an omission.
  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ DELIBERATELY EMPTY, AND THEREFORE ABSENT. With `--disable-wrapper` the
# only things musl would install into bin/ are gone (configure:304-310 is the
# sole writer of `tools`/`tool_libs`, Makefile:219 installs them). A `provides`
# listing musl-gcc would be a name the build does not produce on our toolchain
# — the defect `zpkb lint` exists to catch — and listing one that appears only
# when the build compiler happened to target glibc is worse: it would pass on
# the machine that had one and fail everywhere else.
#
# bytereef.org/mpdecimal is the precedent for a recipe with no `provides`.

test {
  script = [
    # The library itself, in both forms. SHARED_LIBS and STATIC_LIBS are both
    # on by default (Makefile:67-68); neither --disable-shared nor
    # --disable-static is passed.
    "test -f \"{{prefix}}/lib/libc.a\"",
    "test -f \"{{prefix}}/lib/libc.so\"",

    # ⛔⛔ THE LOADER MUST BE INSIDE THE PREFIX. This is the assertion that
    # catches `--syslibdir` being dropped: at the default the file lands in
    # the build machine's /lib and nothing here would exist. The name carries
    # the arch (Makefile:76), so it is matched rather than spelled.
    {
      run = <<EOT
set -e
if ! ls "{{prefix}}"/lib/ld-musl-*.so.1 >/dev/null 2>&1 ; then
  echo "musl: no ld-musl-*.so.1 under the prefix." >&2
  echo "  --syslibdir defaults to the ABSOLUTE path /lib (configure:132," >&2
  echo "  Makefile:18/76/212/215), so make install wrote the loader to the" >&2
  echo "  build machine instead of into this artifact." >&2
  exit 1
fi
EOT
    },

    # ⛔ AND THE WRAPPERS MUST NOT COME BACK. If a future edit drops
    # --disable-wrapper, what appears depends on whether the build compiler
    # targeted glibc and whether it was gcc or clang — so the artifact stops
    # being a function of the recipe. Asserted as an ABSENCE, because that is
    # the direction the defect travels.
    {
      run = <<EOT
for p in bin/musl-gcc bin/musl-clang bin/ld.musl-clang lib/musl-gcc.specs; do
  if test -e "{{prefix}}/$p"; then
    echo "musl: $p was installed, so --disable-wrapper is gone" >&2
    echo "  configure:282-310 picks gcc, clang or nothing by probing the BUILD" >&2
    echo "  compiler for __GLIBC__, so this artifact now depends on the machine" >&2
    echo "  that made it; and Makefile:181/188 bake absolute paths into it." >&2
    exit 1
  fi
done
EOT
    },

    # ⚠ The compatibility archives are EMPTY ON PURPOSE — Makefile:64-65,
    # `EMPTY_LIB_NAMES = m rt pthread crypt util xnet resolv dl`. musl puts
    # all of it in libc; the archives exist so that `-lm -lpthread` keeps
    # working. Asserted so a reader who finds a zero-length libm.a does not
    # take it for a broken install.
    "test -f \"{{prefix}}/lib/libm.a\"",
    "test -f \"{{prefix}}/lib/libpthread.a\"",
  ]
}

provenance {
  read = [
    "INSTALL",      # :16-24 the two prerequisites; :26-27 no kernel headers needed; :113-127 build procedure and the prefix warning; :136-144 the loader's absolute path and --syslibdir
    "configure",    # the ten-option usage block; :132 syslibdir=/lib; :137/436-463 --enable-optimize=auto reads CFLAGS; :142/282-310 the wrapper probe for __GLIBC__; :145 mallocng; :316/322-345 target detection and the arch-prefix match; :421-428 ADD_CFI needs -g; :618-623 the LIBCC search; :829-831 what reaches config.mak
    "Makefile",     # :18 syslibdir; :55-57 tools; :64-65 EMPTY_LIB_NAMES; :67-71 the lib and tool sets; :76 LDSO_PATHNAME; :78 config.mak overrides the defaults above it; :99/103 the two sed-generated headers; :137-141 the awk CFI pass; :181/188 wrappers bake absolute paths; :212-221 the install rules
    "COPYRIGHT",    # :1-4 MIT as a whole; :111-112 third-party portions; :115-116 TRE 2-clause BSD; :121-128 the math code's unnamed permissive terms; :130-132 ARM memcpy from Bionic; :138 crypt; :142-143 public domain
    "VERSION",      # 1.2.6
  ]

  consulted = [
    # Read for the SIGNING KEY only, never for the build.
    "gentoo sec-keys/openpgp-keys-musl-20220407.ebuild (DESCRIPTION, HOMEPAGE, SRC_URI)",
  ]

  note = <<EOT
⭐ THE PROJECT PUBLISHES ITS OWN FINGERPRINT, WHICH IS RARE ENOUGH IN THIS
CAMPAIGN TO BE WORTH NAMING. musl.libc.org/releases.html, under "Verifying
integrity": "Since 1.1.7, releases are signed with the project GPG key", with
the fingerprint written out —

  8364 8929 0BB6 B70F 99FF DA05 56BC DB59 3020 450F

— and the key linked beside it as musl.pub. gnu.org/glibc needed three dead
ends and a third party's curation to get this far; here it is on the download
path, stated by the project.

⚠ AND THE CHAIN IS SINGLE-HOST, WHICH IS CONTINUITY RATHER THAN INDEPENDENCE.
The tarball, the .asc, the fingerprint on releases.html and musl.pub itself all
come from musl.libc.org. One compromise of that host defeats all four at once.
This is the same caveat gnu.org/gzip's recipe records about its key, and it is
weaker than gnu.org/glibc's chain, where the primary key is served by
akhuettel.de AND by ftp.gnu.org — two hosts, one of which is not where the
tarball lives.

⛔ AND THE OBVIOUS SECOND SOURCE IS NOT ONE. Gentoo packages the key as
`sec-keys/openpgp-keys-musl`, with DESCRIPTION "OpenPGP keys used to sign musl"
and HOMEPAGE musl.libc.org/releases.html — but its SRC_URI is
`https://musl.libc.org/musl.pub`. It corroborates WHICH key is the right one;
it does not corroborate the key's BYTES, because it fetches them from the same
place. Written down so the next reader does not mistake a second NAME for a
second SOURCE. (Arch's packaging could not be read at all: gitlab.archlinux.org
answered an Anubis challenge page, not a PKGBUILD — an unobtained answer, not
an absence.)

⭐ WHAT THE FINGERPRINT PIN BUYS HERE, concretely: `--fingerprint` reported
"1 key(s) read from the file", so musl.pub holds exactly one key and the pin is
unambiguous. That is the opposite of gnu.org/gzip's case, where the key came
from a 3.7 MB GNU keyring holding 613 primary keys and `--key` alone would have
meant "somebody in that file signed it".

The identity on the signature is `musl libc <musl@libc.org>` — a PROJECT key,
not a maintainer's personal one, which matches what releases.html says.

The digest was recorded the normal way — the signature checked when the hash
was written, not at build time, which is Guix's division (its `origin` record
has no signature field; `guix refresh` does the checking) — and no keyserver
was asked at any point.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every switch, dependency, installed path and licence
traced to a line in musl's own files and cited in `read` above. The build is
unproven and should be read as such.

⭐ THE TEST BLOCK IS WRITTEN AGAINST THE TWO THINGS MOST LIKELY TO GO WRONG
LATER, and both are absence/presence assertions rather than behaviour: a loader
that went to the build machine's /lib because --syslibdir was dropped, and
toolchain wrappers that came back and made the artifact a function of whoever
compiled it. Neither can be caught by reading a build log that says "ok".
EOT
}
