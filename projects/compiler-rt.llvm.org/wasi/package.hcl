# The LLVM compiler-rt BUILTINS for wasm32-wasip1, laid out as a clang
# RESOURCE DIRECTORY (lib/wasm32-unknown-wasip1/libclang_rt.builtins.a plus clang's
# own headers), so a wasip1 build passes `-resource-dir=<this prefix>`.
#
# It is a cross toolchain part: the contents are wasm32 archives, the artifact is
# published for the HOST platforms (it runs nowhere). Built with the llvm.org
# artifact from the llvm-project source of the SAME version, following WebAssembly/wasi-sdk's
# cmake/wasi-sdk-sysroot.cmake (compiler-rt-build-<target>, lines 90-119 at
# wasi-sdk-34): COMPILER_RT_BAREMETAL_BUILD, per-target runtime dir, only the
# default target, no sanitizers/profile/fuzzer/xray/orc, -mcpu=lime1.
#
# It exists because a Clang package ships no wasm32 builtins, and
# wasi-libc's build and every wasm link want libclang_rt.builtins ("undefined
# symbol: __muloti4" otherwise; wasi-libc README, "Other default libraries").

distributable {
  strip-components = 1
  url              = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{{ version }}/llvm-project-{{ version }}.src.tar.xz"
}

versions {
  github = "llvm/llvm-project"
  strip  = "/^llvmorg-/"
}

build {
  dependencies = {
    "cmake.org" = ">=3<3.29"
    # cmake depends on curl.se `>=5<8.13`, which resolves to the OLDEST artifact,
    # 7.86.0, linked against libssl.so.1.1 — and the rootfs has openssl 3 only:
    # "cmake: error while loading shared libraries: libssl.so.1.1" (exit 127, with
    # cmake 3.31 AND 3.28, factory runs 40323914067 and 40329351929). A curl 8
    # inside the same range is built against openssl 3.
    "curl.se"         = ">=8<8.13"
    "ninja-build.org" = 1
    "python.org"      = "^3"
    # A dependency constraint is not templated (`^{{ version.major }}` reached the
    # resolver verbatim: "no version of llvm.org satisfies"). Same-major clang is
    # what matters; the artifact's newest is used, which may lag the source patch
    # release by a version or two.
    "llvm.org" = "*"
  }

  script = [
    # CMake has no WASI platform module before the one wasi-sdk ships
    # (cmake/Platform/WASI.cmake: `set(WASI 1)`). The host's build flags
    # (sovereign sysroot, -fPIC, ...) are for the HOST: none may reach a wasm32 compile.
    {
      run = <<EOT
mkdir -p cmake/Platform
cp $PROP cmake/Platform/WASI.cmake
EOT
      prop = <<EOT
set(WASI 1)
EOT
    },
    # The LLVM tools by ABSOLUTE path: a bare `llvm-ar` in CMAKE_AR is resolved
    # against the build directory ("…/build/llvm-ar: No such file", run 40358065547,
    # at the very last step after all 150 objects had compiled).
    "env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u LDFLAGS cmake -S compiler-rt -B build -G Ninja -DCMAKE_AR=\"$(command -v llvm-ar)\" -DCMAKE_RANLIB=\"$(command -v llvm-ranlib)\" $ARGS",
    "ninja -C build",
    "ninja -C build install",
    # The resource dir must also carry clang's own headers (stddef.h, stdint.h,
    # ...): wasi-sdk copies the host compiler's include/ into its wasi-resource-dir
    # for the same reason (wasi-sdk-sysroot.cmake, compiler-rt-post-build).
    "cp -R \"$(clang -print-resource-dir)/include\" {{ prefix }}/include",
  ]

  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{ prefix }}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_SYSTEM_NAME=WASI",
      "-DCMAKE_SYSTEM_VERSION=1",
      "-DCMAKE_SYSTEM_PROCESSOR=wasm32",
      "-DCMAKE_MODULE_PATH=$SRCROOT/cmake",
      "-DCMAKE_C_COMPILER=clang",
      "-DCMAKE_CXX_COMPILER=clang++",
      "-DCMAKE_C_COMPILER_WORKS=ON",
      "-DCMAKE_CXX_COMPILER_WORKS=ON",
      "-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=OFF",
      "-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=OFF",
      "-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON",
      "-DCOMPILER_RT_BAREMETAL_BUILD=ON",
      "-DCOMPILER_RT_BUILD_XRAY=OFF",
      "-DCOMPILER_RT_INCLUDE_TESTS=OFF",
      "-DCOMPILER_RT_HAS_FPIC_FLAG=OFF",
      "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON",
      "-DCOMPILER_RT_BUILD_SANITIZERS=OFF",
      "-DCOMPILER_RT_BUILD_LIBFUZZER=OFF",
      "-DCOMPILER_RT_BUILD_PROFILE=OFF",
      "-DCOMPILER_RT_BUILD_CTX_PROFILE=OFF",
      "-DCOMPILER_RT_BUILD_MEMPROF=OFF",
      "-DCOMPILER_RT_BUILD_ORC=OFF",
      "-DCOMPILER_RT_BUILD_GWP_ASAN=OFF",
      "-DCMAKE_C_COMPILER_TARGET=wasm32-wasip1",
      # The .S files (wasm/__c_longjmp.S, __cpp_exception.S) are ASM, and CMake takes
      # --target for ASM from its own variable: without it they were compiled for
      # the HOST, and `-mcpu=lime1` failed on aarch64 ("unsupported argument 'lime1'
      # to option '-mcpu='", run 40386595428) — while on x86-64 it was silently
      # accepted, producing a host object inside a wasm archive.
      "-DCMAKE_ASM_COMPILER_TARGET=wasm32-wasip1",
      "-DCMAKE_CXX_COMPILER_TARGET=wasm32-wasip1",
      "-DCMAKE_C_FLAGS=-mcpu=lime1",
      "-DCMAKE_CXX_FLAGS=-mcpu=lime1",
      "-DCMAKE_ASM_FLAGS=-mcpu=lime1",
    ]
  }
}

test {
  script = [
    "test -s {{ prefix }}/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a",
    "test -s {{ prefix }}/include/stddef.h",
  ]
}

provenance {
  read = [
    "compiler-rt/CMakeLists.txt",            # :83 COMPILER_RT_BUILD_SANITIZERS, :119 COMPILER_RT_BAREMETAL_BUILD
    "compiler-rt/cmake/base-config-ix.cmake", # :191 declares COMPILER_RT_DEFAULT_TARGET_ONLY, :239 acts on it; :126-132 the per-target runtime dir
  ]

  consulted = [
    "WebAssembly/wasi-sdk cmake/wasi-sdk-sysroot.cmake", # the compiler-rt block, :90-119 at wasi-sdk-34
    "WebAssembly/wasi-libc README.md",                   # :74 "Other default libraries", :85-86 the __muloti4 error
  ]

  note = <<EOT
The project BUILT is llvm/llvm-project, so its own CMake files are what the
build derives from; wasi-sdk's `wasi-sdk-sysroot.cmake` is where the knowledge
of WHICH options a wasip1 target needs comes from, and that is somebody else's
packaging — bibliography, not expression.

⛔ AND CHECKING THE CITATION MOVED IT. The obvious `read` entry is
`compiler-rt/CMakeLists.txt` alone, and it is NOT where this recipe's most
load-bearing flag lives: at llvmorg-23.1.5 that file is 937 lines and
`COMPILER_RT_DEFAULT_TARGET_ONLY` appears in none of them. It is declared in
`compiler-rt/cmake/base-config-ix.cmake:191`

    option(COMPILER_RT_DEFAULT_TARGET_ONLY "Build builtins only for the default target" Off)

and acted on at :239. The same file reads `LLVM_ENABLE_PER_TARGET_RUNTIME_DIR`
at :126-132, which is what puts the archive at
`lib/wasm32-unknown-wasip1/libclang_rt.builtins.a` — the exact path the test
below asserts and that every consumer passes as `-resource-dir`. A provenance
naming only CMakeLists.txt would have looked right and pointed at the wrong
file for both facts that matter.

Confirmed, not copied: at `wasi-sdk-34`, `cmake/wasi-sdk-sysroot.cmake` is 515
lines and its compiler-rt block runs :90-119, the next definition beginning at
:120. wasi-libc's README at that tag carries "Other default libraries" at :74,
and the `__muloti4` error this package exists to prevent is quoted there at
:85-86 — "The build of wasi-libc itself depends on compiler-rt". So the reason
given at the top of this file is the upstream project's own statement, not an
inference of ours.
EOT
}
