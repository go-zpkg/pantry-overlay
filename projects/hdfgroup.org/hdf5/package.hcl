# HDF5 — the HDF Group's hierarchical data format library and tools
# (h5dump, h5ls, h5diff, h5repack...). A dependency of netcdf-c.
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1), as the first link of the nco chain: hdf5, netcdf-c, nco.

summary = "Hierarchical Data Format 5: the library and its command line tools"

# LICENSE says "covered by the 3-clause BSD License" (:13).
license = "BSD-3-Clause"

versions {
  github = "HDFGroup/hdf5"
  ignore = ["/beta|alpha|rc|snapshot/"]
}

distributable {
  # THE STORED RELEASE ASSET hdf5-<version>.tar.gz, uploaded by the HDF Group
  # to the release (tag "2.2.0", no leading v). Fetched with `zpkb sourcepin`:
  # 42131403 bytes. The release also uploads hdf5-2.2.0.sha256sums.txt, fetched
  # separately: its line for hdf5-2.2.0.tar.gz carries the same digest, which
  # is the second witness (the project's own published checksum file; no
  # detached signature is published).
  url              = "https://github.com/HDFGroup/hdf5/releases/download/{{version.raw}}/hdf5-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "2.2.0" = "1a1ab8209b35586fbc1aa279ba76d102130b95badcb20ca329587219112d8c16"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
    "zlib.net"     = "*"
  }

  env {
    # Every optional feature is named, ON or OFF, so nothing is auto-detected.
    # All from CMakeBuildOptions.cmake unless another file is given:
    #   BUILD_STATIC_LIBS/BUILD_SHARED_LIBS=ON  :13-14, both kinds installed
    #   HDF5_ENABLE_ZLIB_SUPPORT=ON             :62 the deflate filter, from
    #                                           the zlib.net dependency
    #   ZLIB_USE_EXTERNAL=OFF                   config/HDF5UseZLIB.cmake:34,
    #                                           HDF5_ALLOW_EXTERNAL_SUPPORT=NO:
    #                                           never download zlib
    #   HDF5_ENABLE_SZIP_SUPPORT=OFF            :61 szip/libaec: no recipe yet
    #   HDF5_ENABLE_PARALLEL=OFF                :59 no MPI
    #   HDF5_ENABLE_THREADSAFE=OFF              :67
    #   HDF5_ENABLE_CONCURRENCY=OFF             :69
    #   HDF5_BUILD_FORTRAN=OFF  :86, HDF5_BUILD_CPP_LIB=OFF :88,
    #   HDF5_BUILD_JAVA=OFF     :90
    #   HDF5_ENABLE_HDFS=OFF    :57,  HDF5_ENABLE_PLUGIN_SUPPORT=OFF :81
    #   HDF5_BUILD_HL_LIB=ON    :84 the high level library (netcdf-c needs it)
    #   HDF5_BUILD_TOOLS=ON     :79 h5dump and friends
    #   HDF5_BUILD_EXAMPLES=OFF :98, BUILD_TESTING=OFF :100, HDF5_BUILD_DOC=OFF :74
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_STATIC_LIBS=ON",
      "-DBUILD_SHARED_LIBS=ON",
      "-DHDF5_ENABLE_ZLIB_SUPPORT=ON",
      "-DZLIB_USE_EXTERNAL=OFF",
      "-DHDF5_ALLOW_EXTERNAL_SUPPORT=NO",
      "-DHDF5_ENABLE_SZIP_SUPPORT=OFF",
      "-DHDF5_ENABLE_PARALLEL=OFF",
      "-DHDF5_ENABLE_THREADSAFE=OFF",
      "-DHDF5_ENABLE_CONCURRENCY=OFF",
      "-DHDF5_BUILD_FORTRAN=OFF",
      "-DHDF5_BUILD_CPP_LIB=OFF",
      "-DHDF5_BUILD_JAVA=OFF",
      "-DHDF5_ENABLE_HDFS=OFF",
      "-DHDF5_ENABLE_PLUGIN_SUPPORT=OFF",
      "-DHDF5_BUILD_HL_LIB=ON",
      "-DHDF5_BUILD_TOOLS=ON",
      "-DHDF5_BUILD_EXAMPLES=OFF",
      "-DBUILD_TESTING=OFF",
      "-DHDF5_BUILD_DOC=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{hw.concurrency}}",
    "cmake --install build",
  ]
}

provides = [
  "bin/h5diff",
  "bin/h5dump",
  "bin/h5ls",
  "bin/h5repack",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "h5dump --version",
    "test -f {{prefix}}/include/hdf5.h",
    "test -f {{prefix}}/include/hdf5_hl.h",
    "pkg-config --exists hdf5",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <hdf5.h>

int main(void) {
  unsigned maj, min, rel;
  if (H5get_libversion(&maj, &min, &rel) < 0) {
    puts("H5get_libversion failed");
    return 1;
  }
  if (maj != H5_VERS_MAJOR || min != H5_VERS_MINOR || rel != H5_VERS_RELEASE) {
    printf("header %d.%d.%d but library %u.%u.%u\n", H5_VERS_MAJOR, H5_VERS_MINOR, H5_VERS_RELEASE, maj, min, rel);
    return 1;
  }
  hid_t f = H5Fcreate("t.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
  if (f < 0) {
    puts("H5Fcreate failed");
    return 1;
  }
  H5Fclose(f);
  printf("hdf5 %u.%u.%u\n", maj, min, rel);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o version $(pkg-config --cflags --libs hdf5)"
    },
    "./version",
    "h5ls t.h5",
  ]
}

provenance {
  read = [
    "CMakeBuildOptions.cmake",         # :11-100 every option named in ARGS, with its default
    "config/HDF5UseZLIB.cmake",        # :30-37 ZLIB_USE_EXTERNAL and the find_package paths
    "src/CMakeLists.txt",              # :1429-1437 hdf5.pc installed under lib/pkgconfig
    "LICENSE",                         # :13 "3-clause BSD License"
    "hdf5-2.2.0.sha256sums.txt",       # release asset: digest of hdf5-2.2.0.tar.gz
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the sources and the release; not run on a builder.
The checksum file is a published digest list, not a signature: it comes from
the same release page as the tarball, so it guards against a corrupted fetch,
not against a compromised release. szip support is OFF because no libaec
recipe exists; HDF5 then cannot read or write szip-compressed datasets.
EOT
}
