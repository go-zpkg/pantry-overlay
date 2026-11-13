dependencies = {
  "facebook.com/zstd" = "*"
  "gnome.org/libxml2" = "^2"

  # On s390x the caret is not an ABI bound. ld.lld NEEDs libxml2.so.16,
  # which gnome.org/libxml2 2.15 provides and 2.13 does not — 2.13's soname
  # is libxml2.so.2 — so "^2" installs a library whose soname the LINKER
  # cannot use:
  #
  #   ld.lld: error while loading shared libraries: libxml2.so.16
  #   cc: error: unable to execute command: No such file or directory
  #
  # Builds never met it: a build's environment drags libxml2 in through the
  # base toolchain. `zpkb factory --test-only` gives a package only itself and
  # its test.dependencies, and that lean environment is the first llvm's
  # linker ever ran in — reported by github.com/westes/flex, which has
  # nothing to do with libxml2.
  #
  # In BOTH halves, for the reason the build.dependencies comment below
  # already gives: go-zpkg/packages carries the same edit as an override for
  # the recipe zpkb builds, and this is the half a CONSUMER resolves from — the
  # one `zpkx +llvm.org` reads when it assembles a test environment.
  #
  # Scoped: an artifact links the soname that was in the store when it was
  # built, so tightening this for an arch whose artifact links .so.2 would
  # break it instead. Measured that the platform key wins and the others keep
  # "^2".
  #
  # The soname moved INSIDE a major, which is go-zpkg/packages#233's class.
  "linux/s390x" = {
    "gnome.org/libxml2" = "^2.15"
  }
  "zlib.net" = 1
}

build {
  dependencies = {
    "cmake.org" = ">=3<3.29"
    # darwin only. Every call to semverator in the script below sits in an
    # `elif`, behind `if test "{{hw.platform}}" = "linux"` — so on linux it is
    # installed and never run, and installing it is not free: it pulls
    # rust-lang.org and rust-lang.org/cargo, and cargo's own build needs
    # llvm.org. That cycle has no entry point, and on an architecture with no
    # artifacts yet it is where a seed stops.
    #
    # It has to be scoped in BOTH halves. go-zpkg/packages carries the same
    # change as an override for the recipe zpkb builds; this is the half a
    # consumer resolves from, and since go-zpkg/zpkb#224 the factory's closure
    # takes the UNION of the two — so leaving it unscoped here keeps the cycle
    # alive whichever way the other half is written. Measured: the pantry-only
    # closure for linux/s390x names neither rust nor semverator, and adding
    # this overlay put all three back.
    darwin = {
      "crates.io/semverator" = "*"
    }
    "ninja-build.org" = 1
    "python.org"      = ">=3<3.12"
  }
  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX=\"{{ prefix }}\"",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DLLVM_ENABLE_PROJECTS='lld;lldb;clang;clang-tools-extra'",
      "-DLLVM_INCLUDE_DOCS=OFF",
      "-DLLVM_INCLUDE_TESTS=OFF",
      "-DLLVM_ENABLE_RTTI=ON",
      "-DLLVM_BUILD_LLVM_DYLIB=ON",
    ]
    darwin = {
      ARGS = [
        "-DDEFAULT_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
        "-DLLVM_BUILD_LLVM_C_DYLIB=ON",
        "-DLLVM_ENABLE_LIBCXX=ON",
        "-DLIBCXX_HAS_ATOMIC_LIB=ON",
      ]
    }
    linux = {
      ARGS = [
        "-DCLANG_DEFAULT_LINKER=lld",
        "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON",
      ]
    }
    "linux/aarch64" = {
      ARGS = [
        "-DCMAKE_C_COMPILER_TARGET=\"aarch64-unknown-linux-gnu\"",
      ]
    }
    "linux/x86-64" = {
      ARGS = [
        "-DCLANG_DEFAULT_CXX_STDLIB=libstdc++",
        "-DCLANG_DEFAULT_RTLIB=libgcc",
        "-DCOMPILER_RT_INCLUDE_TESTS=OFF",
        "-DCOMPILER_RT_USE_LIBCXX=OFF",
        "-DCMAKE_C_COMPILER_TARGET=\"x86_64-unknown-linux-gnu\"",
      ]
    }
  }
  script = [
    {
      run = <<EOT
RUNTIMES="-DLLVM_ENABLE_RUNTIMES='compiler-rt'"
if test "{{hw.platform}}" = "linux"; then
  ARGS="$ARGS $RUNTIMES"
elif semverator satisfies '>=14' {{version}}; then
  ARGS="$ARGS $RUNTIMES"
elif test "{{hw.arch}}" = "x86-64" && semverator satisfies '>=14' {{version}}; then
  ARGS="$ARGS $RUNTIMES"
fi
EOT
    },
    "cmake ../llvm -G Ninja $ARGS",
    "ninja",
    "ninja install",
    {
      run = [
        "ln -sf clang cc",
        "ln -sf clang++ c++",
        "ln -sf clang-cpp cpp",
        <<EOT
for x in nm objcopy ranlib readelf strings strip; do
  ln -sf llvm-$x $x
done
EOT
        ,
      ]
      working-directory = "$${{prefix}}/bin"
    },
    {
      if                = "linux"
      run               = <<EOT
TARGET="$(find . -maxdepth 1 -type d -name \*-unknown-linux-gnu)"
if test -n "$TARGET"; then
  mv "$TARGET"/* .
  rmdir "$TARGET"
  ln -s . "$TARGET"
fi
EOT
      working-directory = "$${{prefix}}/lib"
    },
  ]
  working-directory = "build"
}

test {
  dependencies = {
    # darwin only, for the same reason as the build dependency above: the
    # linux arm of the chain in this script never calls it.
    darwin = {
      "crates.io/semverator" = "*"
    }
  }
  fixture = <<EOT
#include <stdio.h>
int main() {
  printf("Hello World!\n");
  return 0;
}
EOT
  script = [
    {
      run = <<EOT
if test "{{hw.platform}}" = "linux"; then
  ARGS="$ARGS -fsanitize=address,undefined"
elif test "{{hw.arch}}" = "x86_64" && semverator satisfies '>=13' {{version}}; then
  ARGS="$ARGS -fsanitize=address,undefined"
elif semverator satisfies '>=14' {{version}}; then
  ARGS="$ARGS -fsanitize=address,undefined"
fi
EOT
    },
    "mv $FIXTURE $FIXTURE.c",
    "clang $ARGS $FIXTURE.c",
    "./a.out",
    # ⛔ THIS WAS `build.receipt = ["LLVMConfig.cmake"]`, WHICH NEVER RAN.
    # `receipt` has zero occurrences in zpkb's and artifact's Go sources: the
    # schema accepted it (additionalProperties: true) and both sides ignored
    # it, so the assertion that the cmake package was produced has never been
    # made. The intent was right, so it moves to a step that executes.
    "test -f \"{{prefix}}/lib/cmake/llvm/LLVMConfig.cmake\"",
  ]

  # ⛔ `$PKGX_DIR` HERE EXPANDED TO NOTHING. The store variable is `ZPKG_DIR`
  # since the rename and nothing in zpkb or artifact sets the old spelling
  # (build/build.go:749, cmd/zpkb/builder.go:626, artifact/pkgx.go:381), so what
  # reached the linker was the empty `-Wl,-rpath,`. What that then did to the
  # test binary is NOT asserted here — it was not measured; what is measured is
  # that the flag named a variable nobody defines.
  env {
    ARGS = [
      "-Wl,-rpath,$ZPKG_DIR",
    ]
  }
}
