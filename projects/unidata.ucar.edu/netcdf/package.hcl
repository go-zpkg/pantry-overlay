# netCDF-C — Unidata's array-oriented scientific data library (libnetcdf,
# ncdump, ncgen, nc-config). A dependency of nco; builds on hdf5.
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1), second link of the nco chain: hdf5, netcdf-c, nco.

summary = "NetCDF C library and the ncdump and ncgen tools"

# COPYRIGHT is the 3-clause BSD text (":1-9": redistributions of source,
# redistributions in binary form, no endorsement).
license = "BSD-3-Clause"

versions {
  github = "Unidata/netcdf-c"
  ignore = ["/beta|alpha|rc/"]
}

distributable {
  # Unidata's own download server, which holds the release tarball
  # netcdf-c-<version>.tar.gz (13360012 bytes for 4.10.1; the GitHub release
  # has no uploaded asset, only a generated tag archive, so that is not used).
  # The tarball ships `configure` AND CMakeLists.txt; the CMake build is used.
  #
  # Fetched with `zpkb sourcepin`. The second witness is the project's own
  # checksum file next to the tarball, netcdf-c-4.10.1.tar.gz.sha256, fetched
  # separately; it says the same digest. It is served from the same host as the
  # tarball and no detached signature is published (the .asc answers 404), so
  # it guards against a corrupted fetch, not a compromised server.
  url              = "https://downloads.unidata.ucar.edu/netcdf-c/{{version.raw}}/netcdf-c-{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "4.10.1" = "db3b69ff4a5ee1a7d79a5c36664d2128b752c266e966369fcf7311ec5f927564"
  }
}

build {
  dependencies = {
    "cmake.org"                = "^3"
    "curl.se"                  = "*"
    "gnu.org/make"             = "*"
    "hdfgroup.org/hdf5"        = "*"
    "zlib.net"                 = "*"
  }

  env {
    # Every optional feature is named, ON or OFF (CMakeLists.txt line numbers):
    #   NETCDF_ENABLE_HDF5=ON / NETCDF_ENABLE_NETCDF_4=ON   :470 :458 netCDF-4
    #       files, found by cmake/dependencies.cmake:137 find_package(HDF5
    #       COMPONENTS C HL REQUIRED), in config mode through CMAKE_PREFIX_PATH
    #   NETCDF_ENABLE_DAP=ON :500, NETCDF_ENABLE_BYTERANGE=ON :597, and
    #       NETCDF_ENABLE_REMOTE_FUNCTIONALITY=ON :518: the DAP2/DAP4 client and
    #       byte-range reads, through libcurl (dependencies.cmake:245
    #       find_package(CURL))
    #   NETCDF_ENABLE_NCZARR=OFF :501, NETCDF_ENABLE_NCZARR_ZIP=OFF :692
    #   NETCDF_ENABLE_S3=OFF :750, NETCDF_ENABLE_S3_AWS=OFF :746,
    #       NETCDF_ENABLE_S3_INTERNAL=OFF :747
    #   NETCDF_ENABLE_PLUGINS=OFF :624
    #   NETCDF_ENABLE_FILTER_SZIP/BZ2/BLOSC/ZSTD=OFF :625-628: no such libraries
    #       are dependencies, so none is silently picked up from the host
    #   NETCDF_ENABLE_LIBXML2=OFF :820 use the bundled tinyxml2 parser
    #   NETCDF_ENABLE_PNETCDF=OFF :502, NETCDF_ENABLE_PARALLEL4=OFF :949
    #   NETCDF_ENABLE_HDF4=OFF :505
    #   NETCDF_ENABLE_TESTS=OFF :831, NETCDF_ENABLE_EXAMPLES=OFF :412,
    #       NETCDF_ENABLE_DAP_REMOTE_TESTS=OFF :604,
    #       NETCDF_ENABLE_DOXYGEN=OFF :1083
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_PREFIX_PATH={{deps.hdfgroup.org/hdf5.prefix}};{{deps.curl.se.prefix}};{{deps.zlib.net.prefix}}",
      "-DBUILD_SHARED_LIBS=ON",
      "-DNETCDF_BUILD_UTILITIES=ON",
      "-DNETCDF_ENABLE_HDF5=ON",
      "-DNETCDF_ENABLE_NETCDF_4=ON",
      "-DNETCDF_ENABLE_DAP=ON",
      "-DNETCDF_ENABLE_BYTERANGE=ON",
      "-DNETCDF_ENABLE_REMOTE_FUNCTIONALITY=ON",
      "-DNETCDF_ENABLE_NCZARR=OFF",
      "-DNETCDF_ENABLE_NCZARR_ZIP=OFF",
      "-DNETCDF_ENABLE_S3=OFF",
      "-DNETCDF_ENABLE_S3_AWS=OFF",
      "-DNETCDF_ENABLE_S3_INTERNAL=OFF",
      "-DNETCDF_ENABLE_PLUGINS=OFF",
      "-DNETCDF_ENABLE_FILTER_SZIP=OFF",
      "-DNETCDF_ENABLE_FILTER_BZ2=OFF",
      "-DNETCDF_ENABLE_FILTER_BLOSC=OFF",
      "-DNETCDF_ENABLE_FILTER_ZSTD=OFF",
      "-DNETCDF_ENABLE_LIBXML2=OFF",
      "-DNETCDF_ENABLE_PNETCDF=OFF",
      "-DNETCDF_ENABLE_PARALLEL4=OFF",
      "-DNETCDF_ENABLE_HDF4=OFF",
      "-DNETCDF_ENABLE_TESTS=OFF",
      "-DNETCDF_ENABLE_EXAMPLES=OFF",
      "-DNETCDF_ENABLE_DAP_REMOTE_TESTS=OFF",
      "-DNETCDF_ENABLE_DOXYGEN=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{hw.concurrency}}",
    "cmake --install build",
  ]
}

provides = [
  "bin/nc-config",
  "bin/ncdump",
  "bin/ncgen",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  script = [
    "nc-config --version",
    "test -f {{prefix}}/include/netcdf.h",
    "pkg-config --exists netcdf",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <netcdf.h>

int main(void) {
  int ncid, dimid, varid, rc;
  rc = nc_create("t.nc", NC_NETCDF4 | NC_CLOBBER, &ncid);
  if (rc != NC_NOERR) {
    printf("nc_create (netCDF-4/HDF5): %s\n", nc_strerror(rc));
    return 1;
  }
  nc_def_dim(ncid, "x", 3, &dimid);
  nc_def_var(ncid, "v", NC_INT, 1, &dimid, &varid);
  nc_enddef(ncid);
  int in[3] = {1, 2, 3};
  nc_put_var_int(ncid, varid, in);
  nc_close(ncid);
  printf("netcdf %s\n", nc_inq_libvers());
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o roundtrip $(pkg-config --cflags --libs netcdf)"
    },
    "./roundtrip",
    "ncdump t.nc",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",          # :66-1146 the option list named in ARGS, with defaults
    "cmake/dependencies.cmake", # :137 find_package(HDF5 ... C HL REQUIRED); :245 find_package(CURL)
    "COPYRIGHT",               # :1-9 3-clause BSD
    "netcdf-c-4.10.1.tar.gz.sha256", # published digest, same as the pin
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the sources; not run on a builder. The option names
are the NETCDF_ENABLE_* spelling of the 4.10 CMake build (older releases used
ENABLE_*), read from this tarball's CMakeLists.txt. NCZarr, S3, plugins and
the szip/bz2/blosc/zstd filters are OFF because no recipe for their libraries
exists.
EOT
}
