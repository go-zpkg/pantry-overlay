# github.com/google/googletest — Google Test and Google Mock: the C++ unit-test
# and mocking libraries.
#
# ⛔ WRITTEN FROM THE RELEASE TARBALL'S OWN FILES (go-zpkg/packages#440), at
# 1.18.0, as a dependency of watchman (whose CMakeLists.txt requires
# `find_package(GMock MODULE REQUIRED)` with no switch to turn it off). Useful
# beyond watchman: it is the C++ test harness half the tree's dependants name.

summary = "GoogleTest: Google's C++ test framework and its GoogleMock mocking library"

# LICENSE:1 "Copyright 2008, Google Inc.", the three-clause BSD text.
license = "BSD-3-Clause"

versions {
  github = "google/googletest"
}

distributable {
  # The STORED release asset (v1.18.0 uploads googletest-1.18.0.tar.gz).
  url              = "https://github.com/google/googletest/releases/download/v{{version.raw}}/googletest-{{version.raw}}.tar.gz"
  strip-components = 1

  # 894741 bytes, fetched with `zpkb sourcepin`; an independent curl fetch hashed
  # with shasum gave the same digest. No signature is published, so none was
  # checked.
  sha256 = {
    "1.18.0" = "6e3191c1455468b3fc35a417fb565c1c5071aee1b7e7f85e30cf48a98d37d8b5"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  # Every option the three CMakeLists.txt files declare, stated:
  #   CMakeLists.txt:19   BUILD_GMOCK ON: googlemock builds gtest too, and
  #                       watchman's FindGMock needs gmock and gmock_main.
  #   CMakeLists.txt:20   INSTALL_GTEST ON: the point of this recipe.
  #   CMakeLists.txt:21   GTEST_HAS_ABSL OFF: ON would need absl and re2 found.
  #   googletest/CMakeLists.txt:13-27 and googlemock/CMakeLists.txt:11 the
  #                       tests, samples and Windows options, all OFF.
  #   BUILD_SHARED_LIBS   OFF (googletest/CMakeLists.txt:61, stated): static
  #                       archives, as every dependant links them.
  #   POSITION_INDEPENDENT_CODE ON: so a dependant may fold the archives into a
  #                       shared object.
  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_GMOCK=ON",
      "-DINSTALL_GTEST=ON",
      "-DGTEST_HAS_ABSL=OFF",
      "-Dgtest_build_tests=OFF",
      "-Dgtest_build_samples=OFF",
      "-Dgtest_disable_pthreads=OFF",
      "-Dgtest_force_shared_crt=OFF",
      "-Dgtest_hide_internal_symbols=OFF",
      "-Dgmock_build_tests=OFF",
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

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "test -f {{prefix}}/include/gtest/gtest.h",
    "test -f {{prefix}}/include/gmock/gmock.h",
    "test -f {{prefix}}/lib/cmake/GTest/GTestConfig.cmake",
    "pkg-config --exists gtest gmock gtest_main gmock_main",
    "test \"$(pkg-config --modversion gtest)\" = \"{{version.raw}}\"",
    {
      fixture = {
        content  = <<EOT
#include <gmock/gmock.h>
#include <gtest/gtest.h>

struct Source {
  virtual ~Source() = default;
  virtual int next() = 0;
};

struct MockSource : Source {
  MOCK_METHOD(int, next, (), (override));
};

TEST(Mock, ReturnsTheStubbedValue) {
  MockSource source;
  EXPECT_CALL(source, next()).WillOnce(::testing::Return(7));
  EXPECT_EQ(source.next(), 7);
}
EOT
        extname = "cpp"
      }
      run = "g++ -std=c++17 $FIXTURE -o mocked $(pkg-config --cflags --libs gmock_main)"
    },
    "./mocked",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                  # :4 cmake 3.16; :7 version; :19-21 BUILD_GMOCK, INSTALL_GTEST, GTEST_HAS_ABSL; :32-36 the subproject
    "googletest/CMakeLists.txt",       # :13-27 the options; :96 the config version file; :155 install
    "googlemock/CMakeLists.txt",       # :11 gmock_build_tests; :116 install
    "LICENSE",                         # three-clause BSD
    "watchman 2026.10.26.00 build/fbcode_builder/CMake/FindGMock.cmake", # :14-25 find_package(GTest CONFIG) and the GTest::gmock targets: what the install must provide
  ]

  consulted = [
    "the release's own googletest-1.18.0.tar.gz, extracted and read",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the test
block has been run, on either platform.

Not read: the install_project function (cmake/internal_utils.cmake), so the
GTestConfig.cmake path and the .pc file names tested above come from the
presence of cmake/Config.cmake.in and gtest.pc.in in the tarball and from
CMake's GNUInstallDirs, not from the install rules; if the first run puts them
elsewhere, those test lines are the ones to fix.
EOT
}
