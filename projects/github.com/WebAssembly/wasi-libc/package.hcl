# The wasm32-wasip1 C library SYSROOT (include/wasm32-wasip1, lib/wasm32-wasip1:
# libc.a, the libwasi-emulated-{signal,mman,process-clocks,getpid}.a emulation
# libraries, libsetjmp.a, crt1*.o). A wasip1 build passes `--sysroot=<this prefix>`.
#
# Cross toolchain part: its contents are wasm32, the artifact is published for the
# HOST platforms. Built from source with the llvm.org artifact and the
# compiler-rt builtins artifact, following wasi-sdk's cmake/wasi-sdk-sysroot.cmake
# (define_wasi_libc_sub, lines 171-239 at wasi-sdk-34): the wasi-libc CMake
# build with TARGET_TRIPLE=wasm32-wasip1, BUILTINS_LIB pointing at OUR compiler-rt
# (wasi-libc's README: left unset it DOWNLOADS one, which a sovereign build must
# never do), static only (BUILD_SHARED=OFF) and -mcpu=lime1.
#
# The version is the wasi-sdk release tag wasi-libc is tagged with
# (wasi-sdk-34 -> 34), the revision wasi-sdk itself pins.

distributable {
  strip-components = 1
  url              = "https://github.com/WebAssembly/wasi-libc/archive/refs/tags/{{ version.tag }}.tar.gz"
}

versions {
  github = "WebAssembly/wasi-libc/tags"
  strip  = "/^wasi-sdk-/"
}

dependencies = {
  "compiler-rt.llvm.org/wasi" = "*"
}

build {
  dependencies = {
    "cmake.org" = ">=3.26<3.29"
    # cmake's own curl.se `>=5<8.13` resolves to 7.86.0 (libssl.so.1.1, absent
    # from the rootfs): see compiler-rt.llvm.org/wasi.
    "curl.se"                   = ">=8<8.13"
    "ninja-build.org"           = 1
    "llvm.org"                  = "*"
    "compiler-rt.llvm.org/wasi" = "*"
  }

  script = [
    {
      run = <<EOT
mkdir -p cmakemod/Platform
cp $PROP cmakemod/Platform/WASI.cmake
EOT
      prop = <<EOT
set(WASI 1)
EOT
    },
    # Host build flags (the sovereign glibc sysroot, -fPIC, ...) are for the HOST.
    # LLVM tools by ABSOLUTE path (a bare name in CMAKE_AR is resolved against the
    # build directory; see compiler-rt.llvm.org/wasi).
    "env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u LDFLAGS cmake -S . -B build -G Ninja -DCMAKE_AR=\"$(command -v llvm-ar)\" -DCMAKE_RANLIB=\"$(command -v llvm-ranlib)\" $ARGS",
    "ninja -C build",
    "ninja -C build install",
  ]

  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{ prefix }}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_SYSTEM_NAME=WASI",
      "-DCMAKE_SYSTEM_VERSION=1",
      "-DCMAKE_SYSTEM_PROCESSOR=wasm32",
      "-DCMAKE_MODULE_PATH=$SRCROOT/cmakemod",
      "-DCMAKE_C_COMPILER=clang",
      "-DCMAKE_CXX_COMPILER=clang++",
      "-DCMAKE_C_COMPILER_WORKS=ON",
      "-DCMAKE_CXX_COMPILER_WORKS=ON",
      "-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=OFF",
      "-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=OFF",
      "-DTARGET_TRIPLE=wasm32-wasip1",
      "-DBUILD_SHARED=OFF",
      "-DBUILTINS_LIB={{ deps.compiler-rt.llvm.org/wasi.prefix }}/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a",
      "-DCMAKE_C_FLAGS=-mcpu=lime1",
      "-DCMAKE_ASM_FLAGS=-mcpu=lime1",
    ]
  }
}

test {
  dependencies = {
    "llvm.org"                  = "*"
    "compiler-rt.llvm.org/wasi" = "*"
  }
  script = [
    "test -s {{ prefix }}/lib/wasm32-wasip1/libc.a",
    "test -s {{ prefix }}/include/wasm32-wasip1/stdio.h",
    {
      # ⛔ A QUOTED STRING, NOT A HEREDOC. The yaml said `run: >-`, which folds
      # AND strips the final newline; an HCL heredoc always keeps one. The two
      # documents then differ by a single trailing byte inside a compile
      # command — which parses, lints clean, and is not what the recipe said.
      # Caught by comparing the decoded documents, not by the linter.
      run = "clang --target=wasm32-wasip1 --sysroot={{ prefix }} -resource-dir={{ deps.compiler-rt.llvm.org/wasi.prefix }} -mcpu=lime1 -o hello.wasm $FIXTURE"
      fixture = {
        extname = "c"
        content = <<EOT
#include <stdio.h>
int main(void) { puts("hello wasip1"); return 0; }
EOT
      }
    },
    "test -s hello.wasm",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :29 TARGET_TRIPLE, :53 BUILTINS_LIB, :58 BUILD_SHARED, :121-122 the sysroot layout
    "README.md",      # :38 the documented triples, :41-42 BUILTINS_LIB downloads one if unset, :74 "Other default libraries"
  ]

  consulted = [
    "WebAssembly/wasi-sdk cmake/wasi-sdk-sysroot.cmake", # define_wasi_libc_sub, :171-239 at wasi-sdk-34
  ]

  note = <<EOT
This is the one of the three wasi recipes whose `read` IS the project it builds:
wasi-libc's own CMakeLists and README. All line numbers confirmed at
`wasi-sdk-34`, the tag this recipe resolves to.

Every flag in `ARGS` that is not boilerplate comes from one of those two files,
and two of them are choices AGAINST the project's own default rather than
agreements with it:

  - `CMakeLists.txt:58` is `option(BUILD_SHARED "Whether or not to build shared
    libraries" ON)` — ON by default. `-DBUILD_SHARED=OFF` is therefore an active
    decision, which is also why it belongs in a record: a reader cannot tell a
    deliberate departure from an inherited default by looking at the flag.
  - `CMakeLists.txt:53` is `set(BUILTINS_LIB "" CACHE STRING …)`, empty by
    default, and the README at :41-42 says what that emptiness means:
    "optional path to compiler-rt which, if not present, **will be downloaded
    automatically**". ⛔ That is the sentence this recipe exists to obey. A
    sovereign build may not fetch a toolchain component from the network
    mid-build, so BUILTINS_LIB is pointed at our own compiler-rt artifact. The
    flag is not an optimisation; omitting it would silently reintroduce a
    download.

  - `CMakeLists.txt:121-122` derive `SYSROOT_INC = $${SYSROOT}/include/$${TARGET_TRIPLE}`
    and `SYSROOT_LIB = $${SYSROOT}/lib/$${TARGET_TRIPLE}`. With
    `TARGET_TRIPLE=wasm32-wasip1` (:29, and the triple is documented at
    README:38) that is exactly the `include/wasm32-wasip1` and
    `lib/wasm32-wasip1` layout stated at the top of this file and asserted by
    the two `test -s` lines below. The layout is thus DERIVED from the project's
    build, not observed once and written down.

The README's "Other default libraries" section at :74 is also where the
dependency on compiler-rt is stated by upstream itself — ":85-86, The build of
wasi-libc itself depends on compiler-rt … undefined symbol: __muloti4" — so the
`dependencies` edge above is the project's claim, not our inference.
EOT
}
