# libc++ and libc++abi for wasm32-wasip1: C++ for the wasip1 target.
#
# Cross toolchain part, published for the HOST platforms: the contents are wasm32
# archives and headers. Built with the llvm.org artifact from the llvm-project source
# of the SAME version, against the wasi-libc sysroot and the compiler-rt builtins
# artifacts, following WebAssembly/wasi-sdk's cmake/wasi-sdk-sysroot.cmake
# (define_libcxx_sub, lines 265-411 at wasi-sdk-34): the `runtimes` build of
# libcxx;libcxxabi, static, pthread API on (wasi-libc stubs it: wasi-libc README,
# "Building in pthread support"), filesystem on, no shared libraries, no LTO twin.
#
# EXCEPTIONS ARE OFF, as wasi-sdk's default for a clang older than 22/23. clang for
# wasm32-wasip1 does NOT default to -fno-exceptions (the first build referenced
# __cxa_throw: "undefined symbol: __cxa_allocate_exception"), and the cmake probe
# for the flag fails under these cross flags, so -fno-exceptions is stated in
# CMAKE_CXX_FLAGS here and in zpkb's C++ stencil. libc++/libc++abi are built without
# exceptions and without libunwind. A C++ project that throws needs the
# exceptions flavour (wasi-sdk "DUAL": -fwasm-exceptions + libunwind), not built yet.
#
# Layout (so that zpkb's stencil can name it, wrapper.go ZBK_WASI_CXX):
#   include/wasm32-wasip1/c++/v1   headers incl. __config_site
#   lib/wasm32-wasip1/libc++.a libc++abi.a

distributable {
  strip-components = 1
  url              = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{{ version }}/llvm-project-{{ version }}.src.tar.xz"
}

versions {
  github = "llvm/llvm-project"
  strip  = "/^llvmorg-/"
}

dependencies = {
  "github.com/WebAssembly/wasi-libc" = "*"
  "compiler-rt.llvm.org/wasi"        = "*"
}

build {
  dependencies = {
    "cmake.org" = ">=3<3.29"
    # cmake's own curl.se `>=5<8.13` resolves to 7.86.0 (libssl.so.1.1, absent from
    # the rootfs): see compiler-rt.llvm.org/wasi.
    "curl.se"                          = ">=8<8.13"
    "ninja-build.org"                  = 1
    "python.org"                       = "^3"
    "llvm.org"                         = "*"
    "github.com/WebAssembly/wasi-libc" = "*"
    "compiler-rt.llvm.org/wasi"        = "*"
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
    # Host build flags (the sovereign glibc sysroot, -fPIC, ...) are for the HOST;
    # the wasm flags travel in $XF. LLVM tools by ABSOLUTE path.
    "env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u LDFLAGS cmake -S runtimes -B build -G Ninja -DCMAKE_AR=\"$(command -v llvm-ar)\" -DCMAKE_RANLIB=\"$(command -v llvm-ranlib)\" -DCMAKE_C_FLAGS=\"$XF\" -DCMAKE_CXX_FLAGS=\"$XF -fno-exceptions\" -DCMAKE_ASM_FLAGS=\"$XF\" $ARGS",
    "ninja -C build cxx cxxabi",
    "ninja -C build install-cxx install-cxxabi",
  ]

  env {
    XF = "-mcpu=lime1 --target=wasm32-wasip1 --sysroot={{ deps.github.com/WebAssembly/wasi-libc.prefix }} -resource-dir={{ deps.compiler-rt.llvm.org/wasi.prefix }}"
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{ prefix }}",
      "-DCMAKE_INSTALL_INCLUDEDIR=include/wasm32-wasip1",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_SYSTEM_NAME=WASI",
      "-DCMAKE_SYSTEM_VERSION=1",
      "-DCMAKE_SYSTEM_PROCESSOR=wasm32",
      "-DCMAKE_MODULE_PATH=$SRCROOT/cmakemod",
      "-DCMAKE_SYSROOT={{ deps.github.com/WebAssembly/wasi-libc.prefix }}",
      "-DCMAKE_C_COMPILER=clang",
      "-DCMAKE_CXX_COMPILER=clang++",
      "-DCMAKE_C_COMPILER_WORKS=ON",
      "-DCMAKE_CXX_COMPILER_WORKS=ON",
      "-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=OFF",
      "-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=OFF",
      "-DLLVM_COMPILER_CHECKED=ON",
      "-DLLVM_ENABLE_RUNTIMES=libcxx;libcxxabi",
      "-DUNIX=ON",
      "-DLIBCXX_ENABLE_THREADS=ON",
      "-DLIBCXX_HAS_PTHREAD_API=ON",
      "-DLIBCXX_HAS_EXTERNAL_THREAD_API=OFF",
      "-DLIBCXX_HAS_WIN32_THREAD_API=OFF",
      "-DLIBCXX_ENABLE_SHARED=OFF",
      "-DLIBCXX_ENABLE_EXCEPTIONS=OFF",
      "-DLIBCXX_ENABLE_FILESYSTEM=ON",
      "-DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF",
      "-DLIBCXX_CXX_ABI=libcxxabi",
      "-DLIBCXX_HAS_MUSL_LIBC=OFF",
      "-DLIBCXX_ABI_VERSION=2",
      "-DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasip1",
      "-DLIBCXX_INCLUDE_TESTS=OFF",
      "-DLIBCXX_INCLUDE_BENCHMARKS=OFF",
      "-DLIBCXXABI_ENABLE_EXCEPTIONS=OFF",
      "-DLIBCXXABI_ENABLE_SHARED=OFF",
      "-DLIBCXXABI_SILENT_TERMINATE=ON",
      "-DLIBCXXABI_ENABLE_THREADS=ON",
      "-DLIBCXXABI_HAS_PTHREAD_API=ON",
      "-DLIBCXXABI_HAS_EXTERNAL_THREAD_API=OFF",
      "-DLIBCXXABI_HAS_WIN32_THREAD_API=OFF",
      "-DLIBCXXABI_USE_LLVM_UNWINDER=OFF",
      "-DLIBCXXABI_LIBDIR_SUFFIX=/wasm32-wasip1",
    ]
  }
}

test {
  dependencies = {
    "llvm.org" = "*"
  }
  script = [
    "test -s {{ prefix }}/lib/wasm32-wasip1/libc++.a",
    "test -s {{ prefix }}/lib/wasm32-wasip1/libc++abi.a",
    "test -s {{ prefix }}/include/wasm32-wasip1/c++/v1/vector",
  ]
}

provenance {
  read = [
    "runtimes/CMakeLists.txt",   # the build this recipe drives: -S runtimes, LLVM_ENABLE_RUNTIMES
    "libcxx/CMakeLists.txt",     # the LIBCXX_* options set below are this file's own option() names
    "libcxxabi/CMakeLists.txt",  # likewise the LIBCXXABI_* ones
  ]

  consulted = [
    "WebAssembly/wasi-sdk cmake/wasi-sdk-sysroot.cmake", # define_libcxx_sub, :265-411 at wasi-sdk-34
    "WebAssembly/wasi-libc README.md",                   # :92-94 "Building in pthread support"
  ]

  note = <<EOT
⛔ `read` AND `consulted` ARE NOT THE SAME CLAIM HERE, and this recipe is the
clearest case of it in the tree. The project BUILT is llvm/llvm-project, so its
own `runtimes/`, `libcxx/` and `libcxxabi/` CMakeLists are what the build
derives from — every LIBCXX_* and LIBCXXABI_* name in `ARGS` is an `option()`
declared there. What wasi-sdk's `wasi-sdk-sysroot.cmake` provides is the
knowledge of WHICH of those options a wasip1 target needs, which is packaging
by somebody else: bibliography, not expression. A fact has no author; their
arrangement of it does.

The citations were CONFIRMED rather than copied out of the prose above. At
`wasi-sdk-34`, `cmake/wasi-sdk-sysroot.cmake` is 515 lines and
`define_libcxx_sub` is at :265, with the next definition at :408-412.

⚠ So the comment at the top of this file was slightly wrong and is corrected
here: it said "lines 272-411". The function begins at 265. Nothing downstream
depended on the number, which is exactly why it could drift unnoticed — and why
a provenance block is checked against the file rather than trusted.

Where the reading shows in the result, rather than being decorative:

  - `-DLIBCXX_HAS_PTHREAD_API=ON` is only correct because wasi-libc STUBS the
    pthread API; its README says so at :92-94, under "Building in pthread
    support". Against a libc without those stubs the same flag would produce a
    library that fails to link.
  - `-DLIBCXX_ENABLE_EXCEPTIONS=OFF` is not a preference: clang for
    wasm32-wasip1 does not default to `-fno-exceptions`, so the first build
    referenced `__cxa_throw` and failed on "undefined symbol:
    __cxa_allocate_exception". The cmake probe for the flag cannot run under
    these cross flags, so the flag is STATED instead of detected.
  - `-DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasip1` and
    `-DCMAKE_INSTALL_INCLUDEDIR=include/wasm32-wasip1` are what make the layout
    at the top of this file true, and zpkb's stencil names those paths
    (wrapper.go, ZBK_WASI_CXX): the two have to agree or a C++ wasip1 build
    finds no headers.
EOT
}
