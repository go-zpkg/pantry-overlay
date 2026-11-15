dependencies = {
  "dri.freedesktop.org" = "*"
  "elfutils.org" = "*"
  "github.com/numactl/numactl" = "*"
}
display-name = "ROCr"
platforms = [
  "linux/x86-64",
]
provides = []

build {
  dependencies = {
    "cmake.org" = "^3"
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/coreutils" = "*"
  }
  script = [
    <<EOT
h=../runtime/hsa-runtime/core/inc/signal.h
awk '/^\/\/ Allow hsa_signal_t to be keys in STL structures\.$/ {
       print "inline bool operator<(const hsa_signal_t\& x, const hsa_signal_t\& y) { return x.handle < y.handle; }"
       print ""
     }
     { print }' "$h" > "$h.new"
mv "$h.new" "$h"
grep -q 'inline bool operator<(const hsa_signal_t' "$h" \
  || { echo "signal.h did not take the operator< insertion" >&2; exit 1; }
EOT
,
    <<EOT
found=0
for s in $(grep -rl 'xxd -i' .. --include='*.sh'); do
  {
    echo '#!/bin/sh -e'
    echo 'xxd() {'
    echo '  f=$2'
    echo '  echo "unsigned char $f[] = {"'
    echo "  od -An -v -tx1 \"\$f\" | sed -e 's/[0-9a-f][0-9a-f]/0x&,/g'"
    echo '  echo "};"'
    echo '  echo "unsigned int $${f}_len = $(wc -c < "$f");"'
    echo '}'
    tail -n +2 "$s" | sed -e "s/echo -e '\\\\n'/echo/"
  } > "$s.new"
  mv "$s.new" "$s"
  chmod +x "$s"
  echo "de-xxd'd $s"
  found=$((found + 1))
done
# If upstream stops using xxd this loop would silently do nothing and the
# build would fail on a bash shebang with no explanation here.
test "$found" -gt 0 || { echo "no xxd-based generator found; is this still needed?" >&2; exit 1; }
EOT
,
    <<EOT
libcdir=$(dirname "$($CC -print-file-name=libc.so)")
test -f "$libcdir/libc.so" || {
  echo "cannot locate libc.so: $CC -print-file-name=libc.so said $($CC -print-file-name=libc.so)" >&2
  exit 1
}
echo "libc.so found in $libcdir"
cmake .. $ARGS -DCMAKE_LIBRARY_PATH="$libcdir"
EOT
,
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
  working-directory = "build"

  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX=\"{{prefix}}\"",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DIMAGE_SUPPORT=OFF",
    ]
  }
}

distributable {
  strip-components = 1
  url = "https://github.com/ROCm/ROCR-Runtime/archive/refs/tags/{{version.tag}}.tar.gz"
}

test {
  fixture = <<EOT
#include <hsa/hsa.h>
#include <stdio.h>
int main(void) {
  printf("hsa_init=%d\n", (int)hsa_init());
  return 0;
}
EOT
  script = [
    "test -f {{prefix}}/lib/libhsa-runtime64.so",
    "test -f {{prefix}}/include/hsa/hsa.h",
    "test -f {{prefix}}/include/hsa/hsa_ext_amd.h",
    "test -f {{prefix}}/lib/libhsakmt.a",
    "mv $FIXTURE test.c",
    "cc test.c -lhsa-runtime64 -o test",
    "./test | grep -q '^hsa_init='",
  ]
}

versions {
  github = "ROCm/ROCR-Runtime/tags"
  strip = "/^rocm-/"
}

provenance {
  read = [
    "runtime/hsa-runtime/core/inc/signal.h",                            # :74 the awk anchor; :75-83 upstream's std::less specialisation; NO free operator< in 730 lines
    "runtime/hsa-runtime/CMakeLists.txt",                               # :265-268 IMAGE_SUPPORT defaults ON on x86_64 — where the one real departure is declared
    "CMakeLists.txt",                                                   # :51-54 BUILD_SHARED_LIBS defaults ON; :115-121 libhsakmt is built HERE
    "runtime/hsa-runtime/core/runtime/blit_shaders/create_blit_shader_header.sh",   # xxd -i
    "runtime/hsa-runtime/core/runtime/trap_handler/create_trap_handler_header.sh",  # xxd -i
    "runtime/hsa-runtime/image/blit_src/create_hsaco_ascii_file.sh",               # xxd -i, and excluded by IMAGE_SUPPORT=OFF
  ]

  note = <<EOT
Read at rocm-7.2.4, the tag this recipe builds. Three patches, and reading the
project explains each one — including one that turns out to be a genuine
departure and one that only restates a default.

⭐ THE operator< PATCH SUPPLIES WHAT UPSTREAM'S OWN COMMENT PROMISES. At
`signal.h:74` the file says:

    // Allow hsa_signal_t to be keys in STL structures.

and what follows, :75-83, is a specialisation of `std::less<hsa_signal_t>` with
an `operator()`. A free `operator<` appears NOWHERE in the file's 730 lines, so
the comment's promise holds for `std::map`/`std::set` at their default
comparator and not for code that compares two `hsa_signal_t` directly. The awk
inserts the free operator immediately above that comment, which is the right
place for it: beside the thing it completes.

⛔ IMAGE_SUPPORT=OFF IS THE ONE REAL DEPARTURE, and it is declared in
`runtime/hsa-runtime/CMakeLists.txt:265-268`, NOT in the root CMakeLists:

    if (NOT DEFINED IMAGE_SUPPORT AND CMAKE_SYSTEM_PROCESSOR MATCHES "i?86|x86_64|…")
      set (IMAGE_SUPPORT ON)

Default ON for x86, and `platforms` above is `linux/x86-64` only — so this
recipe turns OFF something upstream turns ON for exactly the platform it
targets. ⚠ By contrast `-DBUILD_SHARED_LIBS=ON` merely restates the project's
own default (root `CMakeLists.txt:51-54`), which is recorded because a reader
cannot tell a departure from a restatement by looking at a flag.

⭐ AND THE TWO FACTS JOIN UP. The de-xxd loop rewrites every `*.sh` containing
`xxd -i`, and there are exactly THREE at this tag:
`core/runtime/blit_shaders/create_blit_shader_header.sh`,
`core/runtime/trap_handler/create_trap_handler_header.sh` and
`image/blit_src/create_hsaco_ascii_file.sh`. The third lives under `image/`,
which `IMAGE_SUPPORT=OFF` excludes from the build — so `found` is 3 while only
2 are ever invoked. The loop is right to rewrite all three anyway: a filter
keyed on the build configuration would be a second place where IMAGE_SUPPORT
is interpreted.

⭐ EVERY ONE OF THE THREE PATCHES VERIFIES ITSELF, which is why this recipe is
the one to copy. The awk greps for its own insertion; the de-xxd loop refuses
when `found` is 0, with a comment saying exactly why — "if upstream stops using
xxd this loop would silently do nothing" — and the libc probe refuses when
`$CC -print-file-name=libc.so` names a file that is not there. A patch whose
pattern stops matching reports success and changes nothing; these three turn
that silence into a failure.

The test's `test -f {{prefix}}/lib/libhsakmt.a` is explained by root
`CMakeLists.txt:115-121`: `add_rocm_subdir(libhsakmt …)` builds the thunk as
part of this project, which it did not always be — the CPACK lines at :219-223
still carry `REPLACES "hsakmt-roct,…"` for packages that expect it separately.
EOT
}
