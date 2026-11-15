dependencies = {
  "github.com/thom311/libnl" = "^3"
}
platforms = [
  "linux",
]
provides = [
  "bin/ibv_devices",
  "bin/ibv_devinfo",
  "bin/rdma",
]

build {
  dependencies = {
    "cmake.org" = "^3"
    "freedesktop.org/pkg-config" = "^0.29"
    "ninja-build.org" = "^1"
    "python.org" = "^3"
  }
  script = [
    "cmake -G Ninja $ARGS",
    "ninja -C build",
    "ninja -C build install",
  ]

  env {
    ARGS = [
      "-B build",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DIN_PLACE=0",
      "-DNO_MAN_PAGES=1",
      "-DENABLE_STATIC=0",
    ]
  }
}

distributable {
  strip-components = 1
  url = "https://github.com/linux-rdma/rdma-core/releases/download/v{{version.raw}}/rdma-core-{{version.raw}}.tar.gz"
}

test {
  script = [
    "ibv_devices 2>&1 | grep -qE \"device|No IB devices found\"",
    "test -f {{prefix}}/lib/libibverbs.so",
    "test -f {{prefix}}/lib/librdmacm.so",
  ]
}

versions {
  github = "linux-rdma/rdma-core"
}

provenance {
  read = [
    "CMakeLists.txt", # :98-105 IN_PLACE; :107 GNUInstallDirs; :202-210 NO_MAN_PAGES; :212-214 ENABLE_STATIC
  ]

  note = <<EOT
Read at v66.0, the tag this recipe builds. The three `-D` flags that are not
boilerplate turn out to be three DIFFERENT kinds of thing, and only reading the
file tells them apart.

⛔ `-DIN_PLACE=0` PROTECTS ANOTHER FLAG. At `:98-105`, `if (IN_PLACE)`
overrides `CMAKE_INSTALL_PREFIX` to `$${PROJECT_BINARY_DIR}` along with BINDIR,
SBINDIR, SYSCONFDIR, LIBDIR and INCLUDEDIR. So with IN_PLACE on, the
`-DCMAKE_INSTALL_PREFIX={{prefix}}` above would be silently overwritten and
nothing would install into the store. It is not a tidiness flag; it is what
makes the prefix mean anything.

⛔ `-DCMAKE_INSTALL_LIBDIR=lib` IS LOAD-BEARING AND THE TEST PROVES IT. Outside
the IN_PLACE branch the value comes from `GNUInstallDirs` (`:107`), which on a
64-bit host can resolve to `lib64`. The two `test -f {{prefix}}/lib/libibverbs.so`
and `librdmacm.so` lines below assert the `lib` spelling, so a build that let
GNUInstallDirs choose would install correctly and still fail its own test —
which is the useful shape: the assertion and the flag are the same decision
stated twice.

⚠ `-DENABLE_STATIC=0` RESTATES THE PROJECT'S OWN DEFAULT, and that is worth
recording precisely because a reader cannot tell from the flag alone. `:212-214`
is `if (NOT DEFINED ENABLE_STATIC) set(ENABLE_STATIC "OFF" CACHE BOOL …)`, so
OFF is what happens anyway. Harmless, redundant, kept — a later change of
upstream's default would then be a change this recipe does not follow, which is
the one reason to keep saying it.

`-DNO_MAN_PAGES=1` is not cosmetic either: `:202-210` replaces
`rdma_man_pages()` and `rdma_alias_man_pages()` with empty stubs instead of
including `rdma_man`. That removes the man-page toolchain from the build, which
this recipe does not declare as a dependency.
EOT
}
