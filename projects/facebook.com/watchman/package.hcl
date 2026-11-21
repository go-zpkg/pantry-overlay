# facebook.com/watchman — Watchman: a file-watching service that notifies tools
# of changes under a directory tree, as the C++ `watchman` binary (daemon and
# client in one program).
#
# ⛔ WRITTEN FROM WATCHMAN 2026.10.26.00'S OWN FILES (go-zpkg/packages#440). The
# date-like release is the one pinned across the stack (folly, fizz, wangle,
# mvfst, fbthrift, fb303, edencommon: 2026.10.26.00); v2026.11.09.00 and
# v2026.11.16.00 exist and are ignored, as edencommon ignores them. The two
# CMakeLists.txt differ between those releases (the newer one fetches
# dependencies and probes GMock differently), so nothing here is claimed for them.
#
# ⛔⛔ THE RUST COMMAND LINE (`watchmanctl`) IS NOT BUILT. See "THE PATCH" in the
# provenance note: it is a deliberate, stated omission.

summary = "Watchman: a file-watching service (the C++ daemon and client)"

# LICENSE is the MIT licence ("Copyright (c) Meta Platforms, Inc. and affiliates").
license = "MIT"

versions {
  github = "facebook/watchman"
  ignore = ["/^v2026\\.(1[12])\\./"]
}

dependencies = {
  "boost.org"                         = "<1.89"
  "facebook.com/edencommon"           = "^2026"
  "facebook.com/fb303"                = "^2026"
  "facebook.com/fbthrift"             = "^2026"
  "facebook.com/folly"                = "^2026"
  "facebook.com/mvfst"                = "^2026"
  "facebook.com/wangle"               = "^2026"
  "facebook.com/zstd"                 = "^1"
  "fmt.dev"                           = "^12"
  "gflags.github.io"                  = "^2.2"
  "github.com/Cyan4973/xxHash"        = "^0.8"
  "github.com/facebookincubator/fizz" = "^2026"
  "github.com/fastfloat/fast_float"   = "^8"
  "google.com/glog"                   = "^0.7"
  "google.github.io/snappy"           = "^1"
  "libevent.org"                      = "^2"
  "libsodium.org"                     = "^1"
  "lz4.org"                           = "^1"
  "openssl.org"                       = "^3"
  "pcre.org/v2"                       = "^10"
  "sourceware.org/bzip2"              = "^1"
  "tukaani.org/xz"                    = "^5"
  "zlib.net"                          = "^1"
}

distributable {
  # No release assets that hold the source (the releases carry packages): the
  # generated tag archive.
  url              = "https://github.com/facebook/watchman/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 4116419 bytes, `zpkb sourcepin`; an independent curl fetch hashed with
  # shasum gave the same digest (same GitHub generator: a check on the transfer,
  # not a signature).
  sha256 = {
    "2026.10.26.00" = "cb0ec3a700412f7ea83b4853783a51738cf7bfc3cbac30d324a14f603f83ce9d"
  }
}

build {
  dependencies = {
    "cmake.org"                 = "^3"
    "github.com/google/googletest" = "^1"
    "gnu.org/make"              = "*"
    "gnu.org/patch"             = "*"
  }

  # Every option CMakeLists.txt declares (:35 BUILD_SHARED_LIBS, :45
  # USE_SYS_PYTHON, :57 ENABLE_EDEN_SUPPORT, :166-177 the state directory),
  # stated:
  #   ENABLE_EDEN_SUPPORT OFF  :97, :372-377, :495-501, :583, :730, :758: Eden
  #                       support is what needs fizz, wangle, FBThrift, fb303 and
  #                       cpptoml (`find_package(cpptoml CONFIG REQUIRED)` at
  #                       :377), and no cpptoml recipe exists. COST: no Eden
  #                       virtual-filesystem watcher; the inotify/FSEvents
  #                       watchers are what remains.
  #   BUILD_SHARED_LIBS OFF   :35, the default, stated.
  #   USE_SYS_PYTHON OFF      :45, :397-403: the default, stated. It only picks
  #                       where FindPython3 searches, and Python is off (next).
  #   CMAKE_DISABLE_FIND_PACKAGE_Python3 ON  CMake's own switch (cmake
  #                       --help-variable CMAKE_DISABLE_FIND_PACKAGE_<PackageName>:
  #                       every non-REQUIRED find_package() of that package
  #                       fails). The find_package(Python3 ...) calls at :406 and
  #                       :412 are not REQUIRED, so Python3_Development_FOUND is
  #                       false and :416-449 is skipped: no pywatchman (:417-445),
  #                       no watchman/python scripts, no watchman/integration, and
  #                       the :789 test target. WHY: :438-439 installs pywatchman
  #                       with `setup.py install --root $DESTDIR${CMAKE_INSTALL_PREFIX}`,
  #                       setup.py's --root is a ROOT that the install prefix is
  #                       appended to, so the files land under <prefix>/<prefix>/...
  #                       (a doubled path). There is no watchman option to turn
  #                       Python off or to set that path. COST: no pywatchman, no
  #                       watchman-make / watchman-wait. The C++ `watchman` binary
  #                       is unaffected (no Python in its sources, :735).
  #                       The other Python3 uses are in fbcode_builder modules
  #                       (FBPythonBinary, FBThriftPythonLibrary) reached only
  #                       from :446 or from Eden/Thrift code, both off.
  #   WATCHMAN_USE_XDG_STATE_HOME ON  :173: the state directory is per user
  #                       ($XDG_STATE_HOME/watchman), not a path baked under the
  #                       install prefix; INSTALL_WATCHMAN_STATE_DIR OFF (:168,
  #                       the default) so install creates no directory.
  # GMock is REQUIRED (:143 `find_package(GMock MODULE REQUIRED)`), and the unit
  # tests (:769-822, `t_test`) are always built: googletest is a build
  # dependency, found by FindGMock.cmake through find_package(GTest CONFIG).
  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.facebook.com/edencommon.prefix}};{{deps.facebook.com/fb303.prefix}};{{deps.facebook.com/fbthrift.prefix}};{{deps.facebook.com/folly.prefix}};{{deps.facebook.com/mvfst.prefix}};{{deps.facebook.com/wangle.prefix}};{{deps.facebook.com/zstd.prefix}};{{deps.fmt.dev.prefix}};{{deps.gflags.github.io.prefix}};{{deps.github.com/Cyan4973/xxHash.prefix}};{{deps.github.com/facebookincubator/fizz.prefix}};{{deps.github.com/fastfloat/fast_float.prefix}};{{deps.github.com/google/googletest.prefix}};{{deps.google.com/glog.prefix}};{{deps.google.github.io/snappy.prefix}};{{deps.libevent.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.lz4.org.prefix}};{{deps.openssl.org.prefix}};{{deps.pcre.org/v2.prefix}};{{deps.sourceware.org/bzip2.prefix}};{{deps.tukaani.org/xz.prefix}};{{deps.zlib.net.prefix}}",
      "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON",
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON",
      "-DENABLE_EDEN_SUPPORT=OFF",
      "-DBUILD_SHARED_LIBS=OFF",
      "-DUSE_SYS_PYTHON=OFF",
      "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON",
      "-DWATCHMAN_USE_XDG_STATE_HOME=ON",
      "-DINSTALL_WATCHMAN_STATE_DIR=OFF",
    ]
  }

  script = [
    # THE PATCH: drops `add_subdirectory(watchman/cli)` (:767), see the note.
    "patch -p1 --batch --forward < props/no-rust-cli.patch",
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

provides = [
  "bin/watchman",
]

test {
  script = [
    "test -x {{prefix}}/bin/watchman",
    "watchman --version",
    "test ! -e {{prefix}}/bin/watchmanctl",
    "test ! -e {{prefix}}/bin/watchman-make",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                                  # :35-57 options; :143 GMock; :166-188 state directory; :289-377 find_package calls; :392-413 Python; :735 the watchman executable; :765 its install; :767 watchman/cli; :769-822 the unit tests
    "watchman/cli/CMakeLists.txt",                     # rust_executable(watchmanctl); install_rust_executable(watchmanctl)
    "watchman/cli/Cargo.toml",                         # crates.io dependencies: clap, tokio, serde, serde_json, nix, anyhow, ahash
    "build/fbcode_builder/CMake/FindGMock.cmake",      # find_package(GTest CONFIG) and the GTest::gmock targets
    "LICENSE",
  ]

  consulted = [
    "the previous fragment in this tree (versions of dependencies only)",
  ]

  note = <<EOT
NOT BUILT. Written from CMakeLists.txt; neither the build, the patch (which was
checked to apply cleanly to this release's CMakeLists.txt with patch(1) and to
leave no `watchman/cli` line) nor the test block has been run.

⛔⛔ THE PATCH (props/no-rust-cli.patch) removes CMakeLists.txt:767,
`add_subdirectory(watchman/cli)`, which builds and installs the Rust program
`watchmanctl`. WHY: the tarball ships no Cargo.lock (searched the whole tree: the
four Cargo.toml files under watchman/ have none), and watchman/cli/Cargo.toml
depends on crates.io crates (clap, tokio, serde, nix, ...), so `cargo --locked`
cannot run and an unlocked build needs the NETWORK for a crate fetch. No option
turns it off: the call is unconditional. The recipe therefore builds without it.
COST: no `watchmanctl`. INSTALLED: `bin/watchman`, the C++ binary that is both
the daemon and the client (CMakeLists.txt:735, :765). The test refuses a
`watchmanctl` so the omission cannot go unnoticed.

PYTHON IS OFF, STATED. CMakeLists.txt:434-447 builds and installs pywatchman
and watchman/python's scripts (watchman-make, watchman-wait, ...) when a Python
with development files is found, and `setup.py install --root <prefix>` (:438-439)
takes the prefix as a ROOT that the install prefix is appended to, so those landed
under a doubled path inside the prefix. No option of the project turns this off,
so `-DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON` (a CMake variable, documented in
`cmake --help-variable CMAKE_DISABLE_FIND_PACKAGE_<PackageName>`) makes the
non-REQUIRED find_package(Python3) at :406 and :412 fail. The python.org
dependency is gone with it. COST: no pywatchman and no watchman-make /
watchman-wait. Not verified by a build: that nothing else in the configure step
needs Python3 (the grep over the tree found the other uses in fbcode_builder's
FBPythonBinary and FBThriftPythonLibrary modules, reached from :446 and from
Thrift/Eden code only).

Dependencies: the fragment's linux-only libstdcxx/libcxx lines are dropped (the
sibling recipes in this stack, edencommon among them, carry none). With Eden off
CMakeLists.txt links only edencommon, folly, fmt, boost, glog, gflags, libevent,
PCRE2 and OpenSSL directly; the rest of the stack is listed because
edencommon's installed config re-finds them (find_dependency), and each is
named in CMAKE_PREFIX_PATH so that lookup cannot go to the host.

Not read: watchman/cli beyond its two files, the sources of the daemon, and the
bodies of the FBPythonBinary and FBThriftPythonLibrary modules (only their
find_package and Python3_ lines were found by grep).
EOT
}
