# getclipboard.app — Clipboard (cb), a command line clipboard manager with
# history, named clipboards, notes, scripts and clipboard sharing.
#
# ⛔ WRITTEN FROM CLIPBOARD'S OWN CMAKE FILES (go-zpkg/packages#440), not from a
# fragment. The earlier fragment listed alsa-lib and wayland as Linux
# dependencies; neither has a recipe in this tree, so both are switched OFF here
# and said so (see the note), rather than left to be auto-detected.

summary = "Clipboard: a fast, cut/copy/paste command line clipboard manager"

# LICENSE:1-2 is "GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007", and the
# source headers (src/cb/src/main.cpp:5-7, src/gui/src/gui.cpp:5-7) say "either
# version 3 of the License, or (at your option) any later version".
license = "GPL-3.0-or-later"

versions {
  github = "Slackadays/Clipboard"
}

dependencies = {
  linux = {
    # CMakeLists.txt:4-5 sets CMAKE_CXX_STANDARD 23 REQUIRED.
    "gnu.org/gcc/libstdcxx" = 14
    # src/cbx11/CMakeLists.txt:5-8 links ${X11_LIBRARIES}; the module is built
    # when find_package(X11) succeeds (CMakeLists.txt:121-124).
    "x.org/x11" = 1
  }
  # src/cb/CMakeLists.txt:131-132: find_package(OpenSSL REQUIRED), linked as
  # OpenSSL::Crypto, on every platform.
  "openssl.org" = "^3"
}

distributable {
  # No source asset exists: every release asset is a built binary zip
  # (clipboard-linux-amd64.zip, clipboard-macos-arm64.zip, ...), so the GitHub
  # generated tag archive is the only source and its bytes are as stable as
  # GitHub keeps them. 31623894 bytes (the repository carries images).
  url              = "https://github.com/Slackadays/Clipboard/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`; a second, independent fetch (curl, then
  # shasum -a 256) gave the same digest. 0.10.0 is the newest tag
  # `zpkb versions` resolves.
  sha256 = {
    "0.10.0" = "741717ee505a7852fab5c69740b019e2b33f81d948232894ce294ed0a55e70fb"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",

      # CMakeLists.txt:37-39: with no build type the project selects Debug, which
      # adds --coverage (:74-79). Release takes the else branch at :81-86.
      "-DCMAKE_BUILD_TYPE=Release",

      # CMakeLists.txt:33-35 defaults CMAKE_INSTALL_LIBDIR to "lib" and
      # src/cb/CMakeLists.txt:95-101 bakes ${prefix}/lib plus $ORIGIN into the
      # rpath, which is where libcbx11.so is dlopen'ed from
      # (src/cb/src/platforms/x11wl.cpp:23).
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # Every optional input is named, none left to auto-detection:
      #
      # CMakeLists.txt:44 `if (NOT NO_ALSA)` then find_package(ALSA): OFF, there
      # is no alsa-lib recipe, and ALSA only plays a sound for the audio clips
      # (-DUSE_ALSA at :47).
      "-DNO_ALSA=ON",
      # CMakeLists.txt:131 `if(NOT NO_WAYLAND AND WAYLAND_CLIENT_FOUND)`: OFF,
      # there is no wayland recipe (src/cbwayland/CMakeLists.txt:5-6 would also
      # need wayland-scanner and wayland-protocols).
      "-DNO_WAYLAND=ON",
      # CMakeLists.txt:122 `if(NOT NO_X11 AND X11_FOUND AND NOT APPLE)`: left ON,
      # x.org/x11 is a dependency above. Ignored on macOS (NOT APPLE).
      "-DNO_X11=OFF",
      # :111 enable_lto: interprocedural optimisation is a compiler capability,
      # not a dependency, but check_ipo_supported answers differently per
      # toolchain, so it is fixed OFF for a reproducible build.
      "-DNO_LTO=ON",
      # :74 only read in Debug; named so a change of build type cannot add it.
      "-DNO_COVERAGE=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# src/cb/CMakeLists.txt:134 `install(TARGETS cb DESTINATION bin)`.
provides = [
  "bin/cb",
]

test {
  script = [
    "test -x {{prefix}}/bin/cb",
    # src/cb/CMakeLists.txt:136-137 installs the man page as cb.1 when X11WL or
    # APPLE, i.e. on both supported platforms.
    "test -f {{prefix}}/share/man/man1/cb.1",
    # Run with no action, `cb` prints its help text, whose first %s is
    # clipboard_version (src/cb/src/utils/utils.cpp:509), set from the project
    # VERSION at CMakeLists.txt:27. The help path exits, so no display and no
    # clipboard directory are needed.
    {
      run = "{ cb || true; } > help.txt 2>&1 </dev/null; grep -q '{{version}}' help.txt"
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                   # :4-5 C++23; :37-39 default Debug; :44 NO_ALSA; :111 NO_LTO; :122 NO_X11; :131 NO_WAYLAND
    "src/cb/CMakeLists.txt",            # :122-124 ALSA link; :131-132 OpenSSL; :134 install bin/cb; :136-149 man page, completions
    "src/cbx11/CMakeLists.txt",         # :5-8 X11 libraries; :14 installs libcbx11.so
    "src/cbwayland/CMakeLists.txt",     # :5-6 wayland-scanner, wayland-protocols required
    "src/gui/CMakeLists.txt",           # :1-7 static gui library
    "src/cb/src/platforms/x11wl.cpp",   # :23 the module libcbx11.so is dlopen'ed
    "src/cb/src/utils/utils.cpp",       # :509 the help text carries the version
    "LICENSE",                          # :1-2 GPL version 3
  ]

  consulted = [
    "pkgxdev/pantry projects/getclipboard.app/package.yml",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the build and test blocks have
not been run on either platform.

ALSA and Wayland support are OFF on Linux, on purpose and for a missing
dependency: this tree has no alsa-lib and no wayland recipe. Without Wayland, cb
reaches the clipboard through the X11 module (libcbx11.so) only. The earlier
fragment declared both; they were dropped from `dependencies` together with the
features.

CMakeLists.txt:11-23 runs `git rev-parse` and `git log` in the source directory.
In a tarball there is no repository, so GIT_BRANCH and GIT_COMMIT_HASH come out
empty and the help text shows an empty branch and commit: harmless, and not
worked around.
EOT
}
