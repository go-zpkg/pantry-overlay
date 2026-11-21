# unibilium — a terminfo parser library, the one neovim links to read terminfo.
#
# ⛔ WRITTEN FROM UNIBILIUM'S OWN FILES at 2.1.4 (go-zpkg/packages#440 step 1),
# as the first link of neovim's dependency chain.

summary = "Terminfo parser library"

# LICENSE:1-3: "This library is under the GNU Lesser General Public License
# (either version 3 or (at your option) any later version)"; LGPLv3 and GPLv3
# sit beside it.
license = "LGPL-3.0-or-later"

versions {
  # Tags are `v2.1.4`; the project publishes no release assets.
  github = "neovim/unibilium"
  strip  = ["/^v/"]
}

distributable {
  # GitHub's generated tag archive, because the project uploads nothing else:
  # the release carries no assets (`gh release view v2.1.4` lists none).
  url              = "https://github.com/neovim/unibilium/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 2.1.4: 126284 bytes, fetched with `zpkb sourcepin`. Second witness: an
  # independent fetch of codeload.github.com/neovim/unibilium/tar.gz/refs/tags/v2.1.4
  # with curl, then `shasum -a 256`, gave the same digest. The project signs
  # nothing and publishes no checksum file.
  sha256 = {
    "2.1.4" = "7360907bcf79ba49f6fc4a504767ff86e93ab9018477026fcc70d5ab77e1f2c1"
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
      "-DCMAKE_BUILD_TYPE=Release",

      # CMakeLists.txt:4-6 are the three option()s, all ON by default.
      # Man pages need the doc/ subdirectory's pod tooling; tools and tests
      # are not what neovim links. All three OFF, named.
      "-DBUILD_MAN_PAGES=OFF",
      "-DBUILD_TOOLS=OFF",
      "-DBUILD_TESTS=OFF",

      # CMakeLists.txt:75-78 installs the target with ARCHIVE and PUBLIC_HEADER
      # destinations only: a static library is what the install rules were
      # written for. BUILD_SHARED_LIBS is CMake's own switch, default OFF,
      # stated so the install keeps its shape.
      "-DBUILD_SHARED_LIBS=OFF",
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# ⚠ NO `provides`: BUILD_TOOLS is OFF, the install is a library, a header and
# a pkg-config file.

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  script = [
    "test -f {{prefix}}/include/unibilium.h",
    "test -f {{prefix}}/lib/pkgconfig/unibilium.pc",
    "pkg-config --exists unibilium",
    "test \"$(pkg-config --modversion unibilium)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libunibilium.a > /dev/null",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",   # :2 project VERSION 2.1.4; :4-6 options; :22-47 TERMINFO_DIRS probe; :58 unibilium.pc; :75-78 install
    "unibilium.pc.in",  # the pkg-config module is `unibilium`, libs -lunibilium
    "LICENSE",          # :1-3 LGPL v3 or later
  ]

  consulted = [
    "https://github.com/neovim/unibilium/releases/tag/v2.1.4",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the test block has not been
run on either platform.

CMakeLists.txt:22-47 runs `ncurses*6-config --terminfo-dirs` at CONFIGURE time
and falls back to a fixed list of system directories. This recipe does not set
TERMINFO_DIRS or TERMINFO, so the compiled-in search path is whatever the build
host answers: a decision left open, not made.
EOT
}
