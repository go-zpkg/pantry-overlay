# gnu.org/gcc — the GNU C and C++ compilers. One of the projects the
# base-toolchain closure needed and this tree did not carry at all (`zpkb
# closure -build -require-standalone go-zpkg/base-toolchain`, 2026-11-20):
# zlib.net, tukaani.org/xz and lz4.org declare it for their tests, and zpkb's
# sovereign environment already reads this artifact's lib/gcc/<triple>/<ver>
# (buildscript/wrapper.go:885, ZPKB_LIBGCC, for rustc's bare `-lgcc`).
#
# ⛔ WRITTEN FROM GCC'S OWN FILES (go-zpkg/packages#431), at 16.2.0. The
# sibling gnu.org/gcc/libstdcxx is built from the SAME tarball, and the two
# pin the same versions on purpose: a program compiled by g++ N needs a
# libstdc++ at least as new as N at run time.
#
# ⭐⭐ WHAT WRITING IT FOUND — four choices GCC makes by DETECTION, each now
# either named so that a miss is fatal, or refused and stated:
#
#   1. zstd for LTO: probed and silently dropped when absent → declared, and
#      named so a miss is fatal (gcc/configure.ac:1577-1578).
#   2. isl for Graphite: probed, fatal only "if isl has been requested" →
#      refused (--without-isl), a stated downgrade; no isl recipe here.
#   3. plugin support: on by default and silently turned off when the host
#      cannot do it → named, which makes the same failure fatal.
#   4. ⛔ the C++ runtime of GCC's OWN programs: static only when the BUILD
#      compiler passes a probe that clang fails by construction → named.

summary = "GNU Compiler Collection: the C and C++ compilers"

# Same text and same reading as gnu.org/gcc/libstdcxx. The compiler is GPL-3.0-
# or-later (COPYING3). The runtime libraries it installs and links into every
# program it compiles (libgcc, libstdc++) carry the GCC Runtime Library
# Exception 3.1 (COPYING.RUNTIME; libstdc++-v3/src/c++11/mutex.cc:16-18 at
# 16.2.0). Without the exception every program compiled with this compiler
# would inherit the GPL, so it cannot be dropped from the expression.
license = "GPL-3.0-or-later AND GPL-3.0-or-later WITH GCC-exception-3.1"

versions {
  # ftp.gnu.org/gnu/gcc/ lists one DIRECTORY per release; the same block as
  # gnu.org/gcc/libstdcxx, so both resolve the same versions.
  url   = "https://ftp.gnu.org/gnu/gcc/"
  match = "/gcc-\\d+\\.\\d+\\.\\d+/"
  strip = [
    "/^gcc-/",
    "/\\/$/",
  ]
}

dependencies = {
  # ⛔ AT RUN TIME, not only at build time. cc1 and cc1plus link libgmp, libmpfr
  # and libmpc dynamically, so the compiler does not start without them. The
  # floors are GCC's own `choke me` blocks at 16.2.0: configure.ac:1795 (gmp
  # 4.2.3), :1813 (mpfr 3.1.0), :1830 (mpc 0.8.0).
  "gnu.org/gmp"  = ">=4.2.3"
  "gnu.org/mpfr" = ">=3.1.0"
  "gnu.org/mpc"  = ">=0.8.0"

  # lto1 and cc1 link libzstd once --with-zstd names it — see build. zstd
  # 1.3.0 is the floor gcc/configure.ac:1564-1569 checks for.
  "facebook.com/zstd" = ">=1.3.0"

  # The gcc driver runs `as` and `ld` for every object and every link. GCC does
  # not ship them, and configure records the assembler's features
  # (HAVE_AS_*) from the one it finds, so declaring it pins THAT too.
  "gnu.org/binutils" = "*"
}

distributable {
  url              = "https://ftp.gnu.org/gnu/gcc/gcc-{{version.raw}}/gcc-{{version.raw}}.tar.xz"
  strip-components = 1

  # 16.2.0: 107200820 bytes, signed 2026-08-07 by Richard Guenther's signing
  # SUBKEY 7F74F97C103468EE5D750B583AB00996FC26A641 — see provenance.note,
  # because the fingerprint gcc.gnu.org publishes is that subkey's, not the
  # primary's. Confirmed by a second, independent fetch-and-hash.
  #
  # 14.4.0: the digest gnu.org/gcc/libstdcxx pinned and verified (Jakub
  # Jelinek, D3A93CAD751C2AF4F8C7AD516C35B99309B5FA62). Kept here because
  # pantry recipes still ask for `gnu.org/gcc = 14`.
  sha256 = {
    "16.2.0" = "e6738e29597f733270731aa90600f37ffdc045079dfc27ec7e8192cc81085c3e"
    "14.4.0" = "752b6f567beac83159c77a7680b1316bdd784738bff9a9d070112c09da90f6d9"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--with-gmp={{deps.gnu.org/gmp.prefix}}",
      "--with-mpfr={{deps.gnu.org/mpfr.prefix}}",
      "--with-mpc={{deps.gnu.org/mpc.prefix}}",

      # C and C++ only, like gnu.org/gcc/libstdcxx. ⚠ STATED DOWNGRADE from the
      # upstream pantry, which also builds objc, obj-c++ and fortran: nothing in
      # the base-toolchain closure asks for gfortran, and each front end is a
      # compiler shipped untested.
      "--enable-languages=c,c++",

      # ⛔⛔ 1. zstd, NAMED. gcc/configure.ac:1557 runs
      # `AC_SEARCH_LIBS(ZSTD_compress, zstd, …)` whether or not zstd was asked
      # for. With no --with-zstd, a builder without libzstd silently produces a
      # compiler whose LTO cannot read zstd-compressed objects, and one with it
      # produces a compiler that links a library nobody declared. Given a PATH,
      # :1577-1578 turns the miss into "Unable to find zstd.h" and stops.
      "--with-zstd={{deps.facebook.com/zstd.prefix}}",

      # ⛔⛔ 2. isl, REFUSED. configure.ac:1999-2018: with --with-isl unset, the
      # check runs anyway and "Only execute fail-action, if isl has been
      # requested" — so Graphite is on or off depending on whether the builder
      # has an isl. This tree has no isl recipe. ⚠ STATED DOWNGRADE: the
      # -floop-* and -fgraphite-* optimizations are unavailable, and the
      # compiler says so (gcc/graphite.cc:529 "Graphite loop optimizations
      # cannot be used (isl is not available)"); the test asserts exactly that.
      "--without-isl",

      # ⛔ 3. PLUGINS, NAMED. config/gcc-plugin.m4:16-19 defaults --enable-plugin
      # to yes AND records default_plugin=yes. :114-116 turns it off when the
      # host lacks -fPIC -shared or dlopen, and :122-128 fails only when
      # default_plugin is NOT yes. Named on the command line, the same miss is
      # fatal.
      "--enable-plugin",

      # Bundled zlib: with no --with-system-zlib the top-level build uses GCC's
      # own copy (configure.ac:3086-3105). That is deterministic, so it is left
      # as it is rather than adding a dependency.

      # The same five choices as gnu.org/gcc/libstdcxx, for the same reasons.
      "--disable-bootstrap",
      "--disable-multilib",
      "--disable-nls",
      "--enable-threads=posix",
      "--enable-__cxa_atexit",
      "--enable-clocale=gnu",
      "--enable-libstdcxx-allocator=new",
      "--disable-libstdcxx-pch",

      # ⭐ NO LIBC LOCATION IS BAKED IN, on purpose. No --with-sysroot and no
      # --with-native-system-header-dir: this tree can have several libc roots
      # (glibc, musl…), and zpkb's build environment chooses one per build by
      # giving the compiler shims `--sysroot` (buildscript/wrapper.go:846). A
      # compiler that recorded one libc would make that choice for every
      # consumer.
    ]
  }

  # ⛔⛔ 4. THE C++ RUNTIME OF GCC'S OWN PROGRAMS. cc1plus, lto1 and the driver
  # are C++ programs, built here by the BUILD environment's compiler (one stage,
  # --disable-bootstrap). configure.ac:1943-1950 links them with
  # `-static-libstdc++ -static-libgcc` by default, but ONLY if
  # have_static_libs=yes, and :1519-1525 sets that by compiling
  #
  #   #if (__GNUC__ < 4) || (__GNUC__ == 4 && __GNUC_MINOR__ < 5)
  #   #error -static-libstdc++ not implemented
  #
  # clang defines __GNUC__ 4 and __GNUC_MINOR__ 2 (measured: `clang -dM -E`,
  # Apple clang 21), so with clang building — the sovereign environment's
  # compiler — the probe fails and the default becomes NO static runtime. GCC's
  # programs would then need, at run time, whichever C++ runtime the builder
  # used: libc++ in the sovereign environment (wrapper.go:587), the container's
  # libstdc++ outside it. Naming the flags removes the probe; the value carries
  # a space, so it is written on the configure line rather than in ARGS, which
  # the script expands unquoted. The test reads the result off cc1plus.
  script = [
    "mkdir -p build",
    "cd build && ../configure $ARGS --with-stage1-ldflags=\"-static-libstdc++ -static-libgcc\"",
    "cd build && make --jobs {{ hw.concurrency }}",
    "cd build && make install",

    # ⛔⛔ THE s390x TRIPLE-PREFIXED NAMES, carried from go-zpkg/packages
    # overrides/gnu.org-gcc.hcl (build.env.s390x TRIPLET = "s390x-linux-gnu" and
    # the `$TRIPLET-<tool>` loop), which stopped applying when zpkb v0.90.0 made
    # a standalone recipe the whole recipe (go-zpkg/zpkb#514, #516).
    #
    # `make install` names a native compiler by its CONFIGURE triple, which on
    # s390x is `s390x-ibm-linux-gnu`; the distribution spelling a consumer asks
    # for (Rust's `cc` crate probes `<triple>-gcc`, autoconf probes
    # `<host>-gcc`) is `s390x-linux-gnu`, and nothing installs that name. A name
    # that does not exist is the answer "no compiler" to a probe, silent. The
    # override's loop is kept as it was, including its `test -e` guard: `ar`,
    # `nm` and `ranlib` are not installed by this recipe (binutils owns them),
    # so only the names that exist get a link.
    #
    # Scoped to linux/s390x exactly as the override was: the other two
    # architectures were never given this, and `linux` alone would change what
    # they ship. x86-64 and aarch64 had their triple link from the pantry
    # recipe this tree replaced, not from the override, so they are not carried
    # here (named in the PR rather than decided in this file).
    {
      run = <<EOT
set -eu
cd "{{prefix}}/bin"
for tool in gcc g++ cpp c++ ar nm ranlib; do
  if test -e "$tool"; then ln -sf "$tool" "s390x-linux-gnu-$tool"; fi
done
EOT
      if  = "linux/s390x"
    },
  ]
}

provides = [
  "bin/gcc",
  "bin/g++",
  "bin/c++",
  "bin/cpp",
  "bin/gcc-ar",
  "bin/gcc-nm",
  "bin/gcc-ranlib",
  "bin/gcov",
  "bin/gcov-dump",
  "bin/gcov-tool",
  "bin/lto-dump",
]

test {
  # ⚠ THESE TESTS COMPILE AND DO NOT LINK, and the reason is the design above:
  # this compiler carries no libc location, so linking needs a sysroot the test
  # environment gives the `cc` shims, not this binary. Everything up to the
  # assembler is exercised: the driver, cc1/cc1plus and `as`.
  script = [
    "\"{{prefix}}/bin/gcc\" --version | grep -F \"{{version}}\"",

    # The s390x names are read off the artifact, and a link that points nowhere
    # does not count: `test -x` follows it.
    {
      run = <<EOT
set -eu
for tool in gcc g++ cpp c++; do
  test -x "{{prefix}}/bin/s390x-linux-gnu-$tool"
done
EOT
      if  = "linux/s390x"
    },

    {
      run = <<EOT
set -eu
printf 'int add(int a, int b) { return a + b; }\n' > t.c
"{{prefix}}/bin/gcc" -O2 -ffreestanding -c t.c -o t.o
printf 'template <typename T> T twice(T x) { return x + x; }\nint f() { return twice(21); }\n' > t.cc
"{{prefix}}/bin/g++" -O2 -ffreestanding -c t.cc -o t2.o
test -s t.o && test -s t2.o
EOT
    },

    # 1. zstd survived: gcc.cc:7751-7753 prints " zstd" after the zlib entry
    # only when it was built with zstd.
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/gcc" -v 2>&1 | grep -F "Supported LTO compression algorithms: zlib zstd" || {
  echo "gcc was built without zstd for LTO despite --with-zstd" >&2
  "{{prefix}}/bin/gcc" -v 2>&1 | grep -F "LTO compression" >&2 || true
  exit 1
}
EOT
    },

    # 2. isl stayed out: a builder's isl did not leak in. With it, this
    # compiles; without it, gcc/graphite.cc:529 refuses with this sentence.
    {
      run = <<EOT
set -eu
printf 'void f(int *a) { for (int i = 0; i < 100; i++) a[i] = i; }\n' > g.c
if "{{prefix}}/bin/gcc" -O2 -floop-nest-optimize -ffreestanding -c g.c -o g.o 2> g.err; then
  echo "Graphite works, so an isl was linked that this recipe refused" >&2
  exit 1
fi
grep -F "isl is not available" g.err
EOT
    },

    # 4. GCC's own C++ runtime is static: cc1plus names neither libstdc++ nor
    # libc++ as NEEDED. readelf is from the declared gnu.org/binutils.
    {
      run = <<EOT
set -eu
case "$(uname -s)" in
Linux)
  cc1plus="$("{{prefix}}/bin/gcc" -print-prog-name=cc1plus)"
  if readelf -d "$cc1plus" | grep -E 'NEEDED.*(libstdc\+\+|libc\+\+)'; then
    echo "cc1plus links a C++ runtime dynamically; --with-stage1-ldflags did not hold" >&2
    exit 1
  fi
  ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                    # :1511-1529 the static-runtime probe; :1795/:1813/:1830 the floors; :1935-1950 stage1-ldflags; :1999-2018 isl; :3086-3105 bundled zlib
    "gcc/configure.ac",                # :1511-1583 zstd and its fatal arm; :1645 AM_ICONV; :7541 GCC_ENABLE_PLUGINS
    "config/gcc-plugin.m4",            # :16-19 the default, :114-116 silent off, :122-128 fatal only when named
    "config/isl.m4",
    "gcc/gcc.cc",                      # :7751-7753 the LTO compression line the test reads
    "gcc/graphite.cc",                 # :529 the no-isl refusal the test reads
    "gcc/doc/install.texi",            # :2556-2566 --with-stage1-ldflags applies with --disable-bootstrap; :2784-2792 --with-build-sysroot
    "libstdc++-v3/src/c++11/mutex.cc", # :6-9 GPLv3-or-later, :16-18 the Runtime Library Exception
    "COPYING3",
    "COPYING.RUNTIME",
    "https://gcc.gnu.org/mirrors.html", # :55-78 the seven published signing keys
  ]

  consulted = [
    # Read for facts only: its dependency list (binutils at run time, zlib),
    # and that it links GCC's own C++ runtime statically on Linux through
    # --with-boot-ldflags. Nothing copied.
    "pkgxdev/pantry projects/gnu.org/gcc/package.yml",
    # How this tree supplies a libc to a compiler, which is why none is baked in.
    "go-zpkg/zpkb buildscript/wrapper.go:846-896, buildscript/libexec.go:38-72",
  ]

  note = <<EOT
⛔⛔ THE PUBLISHED FINGERPRINT IS A SUBKEY'S, AND THAT IS NOT WHAT IT LOOKS LIKE.

  signature  https://ftp.gnu.org/gnu/gcc/gcc-16.2.0/gcc-16.2.0.tar.xz.sig
  issuer     7F74F97C103468EE5D750B583AB00996FC26A641 (RSA-2048, signed 2026-08-07)
  primary    13975A70E63C361C73AE69EF6EEB81F8981C74C7 (DSA-1024, 2001)
  identity   Richard Guenther <richard.guenther@gmail.com>

gcc.gnu.org/mirrors.html lines 70-71 list "2048R/FC26A641 2005-09-13 Richard
Guenther" with "Key fingerprint = 7F74 F97C 1034 68EE 5D75 0B58 3AB0 0996 FC26
A641". That reads as a key; it is the SIGNING SUBKEY of a 2001 DSA primary.
`zpkb sourcepin --fingerprint` compares on the primary key, so the published
value matched nothing. The check that was run: the key was fetched from
keyserver.ubuntu.com by that full fingerprint; `gpg --show-keys` lists
7F74…A641 as a [S] subkey of 13975A70…74C7; the signature's issuer
fingerprint (subpacket 33) is 7F74…A641; and sourcepin VERIFIED the signature
with the primary named, which checks the subkey's binding signature. So the
anchor is the project's published fingerprint, and the key bytes' source does
not matter: a key that does not hash to it would not have verified.

⚠ This key is NOT in https://ftp.gnu.org/gnu/gnu-keyring.gpg: all 614
primary keys were walked. gnu.org/gcc/libstdcxx's 14.4.0 signer (Jakub
Jelinek) is.

⛔⛔ AND GCC'S OWN PROGRAMS WOULD HAVE TAKEN THEIR C++ RUNTIME FROM THE
BUILDER. configure.ac decides whether to link cc1plus and lto1 with a static
libstdc++ by testing whether the BUILD compiler is GCC >= 4.5, through
__GNUC__/__GNUC_MINOR__. clang answers 4.2 for compatibility, so under the
sovereign environment's clang the default flips to a dynamic C++ runtime — and
that runtime is libc++ there, libstdc++ in a container. Named, and asserted on
the installed cc1plus.

⚠ OPEN, STATED: while GCC builds its target libraries (libgcc, libstdc++), the
compiler doing it is the freshly built xgcc, not a zpkb shim, so it does not
receive the environment's --sysroot. Where it finds libc's headers then is the
builder's default search path. gnu.org/gcc/libstdcxx has the same exposure and
asserts the one outcome known to depend on it (the clocale model); that
assertion is not repeated here because the same tarball and switches produce
the same library. --with-build-sysroot (install.texi:2784-2792) expects a
standard sysroot layout, which the sovereign glibc artifact is not
(lib/glibc-<ver>, kernel headers in another prefix), so it was not used.

⛔ NOT BUILT. No session here can run the factory, and this is a compiler.
What is established is the inputs: a verified signature, the floors and every
detection switch traced to a line in GCC's own files, and tests that read each
outcome off the installed compiler.
EOT
}
