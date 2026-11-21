# NCO — the netCDF Operators (ncks, ncra, ncbo, ncatted, ...): command-line
# operators that read and write netCDF files.
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1), replacing the dependency-only fragment.

summary = "netCDF Operators: command-line tools to manipulate netCDF files"

# COPYING is "BSD 3-Clause License" (:1) with the standard three clauses
# (:7-11); COPYRIGHT:2 says the same.
license = "BSD-3-Clause"

versions {
  github = "nco/nco"
  ignore = ["/beta|alpha|rc/"]
}

distributable {
  # The project publishes no release asset (the GitHub release lists none), so
  # the source is the tag archive GitHub generates, which ships `configure`.
  # Fetched with `zpkb sourcepin` (6927557 bytes, 5.4.2). The second witness is
  # a separate fetch of the same tag from the other archive URL,
  # https://github.com/nco/nco/archive/refs/tags/5.4.2.tar.gz: it gives the
  # same digest. Both come from one host and no signature is published, so
  # this guards against a corrupted fetch, not a compromised host. (The
  # api.github.com tarball differs by its top directory name, as expected, and
  # is not used.)
  url              = "https://github.com/nco/nco/archive/{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "5.4.2" = "082a483ec08a8afe91a645cc2fcabae01c2070ae0cec9218c4ad43760dae4e5c"
  }
}

build {
  dependencies = {
    "gnu.org/gsl"              = "*"
    "gnu.org/make"             = "*"
    "hdfgroup.org/hdf5"        = "*"
    "unidata.ucar.edu/netcdf"  = "*"
    "unidata.ucar.edu/udunits" = "*"
  }

  env {
    # configure.ac options and probes, read at the lines given:
    #   :299  --enable-netcdf4  default yes; :293 netcdf is REQUIRED
    #   :357  --enable-openmp   default yes (uses the compiler's OpenMP)
    #   :363  --enable-gpu      default no: named off
    #   :388  --enable-dap      default yes, needs netcdf built with DAP
    #         (the netcdf recipe turns DAP on)
    #   :462-463 --enable-ncap2 / --enable-ncoxx: ncap2 needs ANTLR 2 and its
    #         C++ headers (:510 :524) and no ANTLR recipe exists, so ncap2 is
    #         turned OFF explicitly rather than left to a host probe
    #   :537  --enable-mpi      default no, "do not use": named off
    #   :543  --enable-fortran  default no, deprecated: named off
    #   :564  --enable-i18n     default no, experimental: named off
    #   :592  --enable-nco_cplusplus default no: named off
    #   :605  --enable-gsl      default yes, found through gsl-config (:608-614),
    #         so GSL_ROOT points at the gsl dependency
    #   :695  --enable-ccr, :726 --enable-nep: default no, no such libraries
    #         here: named off
    #   :754  --enable-regex    default yes
    #   :778-779 --enable-udunits2 default yes; :785-790 aborts configure if
    #         udunits2.h or libudunits2 is missing
    #   :1232 --enable-doc      needs makeinfo (:1245); documentation is not
    #         built here: named off
    # The CPPFLAGS/LDFLAGS reach netcdf, udunits and hdf5 (libnetcdf's own
    # dependency, needed at link time for the shared library).
    ARGS = [
      "--prefix={{prefix}}",
      "--enable-netcdf4",
      "--enable-openmp",
      "--disable-gpu",
      "--enable-dap",
      "--disable-ncap2",
      "--disable-mpi",
      "--disable-fortran",
      "--disable-i18n",
      "--disable-nco_cplusplus",
      "--enable-gsl",
      "--disable-ccr",
      "--disable-nep",
      "--enable-regex",
      "--enable-udunits2",
      "--disable-doc",
      "CPPFLAGS=-I{{deps.unidata.ucar.edu/netcdf.prefix}}/include -I{{deps.unidata.ucar.edu/udunits.prefix}}/include",
      "LDFLAGS=-L{{deps.unidata.ucar.edu/netcdf.prefix}}/lib -Wl,-rpath,{{deps.unidata.ucar.edu/netcdf.prefix}}/lib -L{{deps.unidata.ucar.edu/udunits.prefix}}/lib -Wl,-rpath,{{deps.unidata.ucar.edu/udunits.prefix}}/lib -L{{deps.hdfgroup.org/hdf5.prefix}}/lib -Wl,-rpath,{{deps.hdfgroup.org/hdf5.prefix}}/lib",
    ]
    GSL_ROOT = "{{deps.gnu.org/gsl.prefix}}"
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }}
make install
EOT
}

# src/nco/Makefile.am:14 `bin_PROGRAMS = ncatted ncbo ncecat ncflint ncks
# ncpdq ncra ncrename ncwa` (the :12 list adds the mp* operators for MPI,
# which is off). ncap2 is off.
provides = [
  "bin/ncatted",
  "bin/ncbo",
  "bin/ncecat",
  "bin/ncflint",
  "bin/ncks",
  "bin/ncpdq",
  "bin/ncra",
  "bin/ncrename",
  "bin/ncwa",
]

dependencies = {
  darwin = {
    "gnu.org/gettext" = "^1"
  }
  "unidata.ucar.edu/netcdf"  = "*"
  "unidata.ucar.edu/udunits" = "*"
  "gnu.org/gsl"              = "*"
}

test {
  script = [
    "ncks --version",
    "ncks --help",
    "test -x {{prefix}}/bin/ncra",
  ]
}

provenance {
  read = [
    "configure.ac",              # option and probe lines cited in the build env
    "src/nco/Makefile.am",       # :12 :14 bin_PROGRAMS
    "COPYING",                   # :1-11 BSD 3-clause
    "COPYRIGHT",                 # :2 BSD 3-clause
  ]

  consulted = []

  note = <<EOT
NOT BUILT: written from the sources; not run on a builder. ncap2 is OFF
because it needs ANTLR 2 (C++), for which there is no recipe; the documentation
build is off. The previous fragment also listed facebook.com/zstd: configure.ac
and the Makefile.am never link it (nco_flt.c only names the zstd filter id), so
it is not carried over. The openmp option relies on the toolchain's OpenMP
support, which was not checked on a builder.
EOT
}
