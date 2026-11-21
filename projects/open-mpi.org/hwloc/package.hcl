# hwloc — Portable Hardware Locality: the topology of a machine (packages,
# cores, caches, NUMA nodes) as a library, plus lstopo and the hwloc-* tools.
#
# ⛔ WRITTEN FROM HWLOC'S OWN FILES at 2.16.0 (go-zpkg/packages#440, go-zpkg/packages#431).
# It was a three-line fragment declaring one libxml2 dependency.

summary = "Portable hardware locality: machine topology library and lstopo"

# COPYING opens "SPDX-License-Identifier: BSD-3-Clause".
license = "BSD-3-Clause"

versions {
  github = "open-mpi/hwloc"
  strip  = "/^hwloc-/"
  ignore = ["/rc|alpha|beta/"]
}

distributable {
  # The STORED release asset (releases/download/hwloc-X/hwloc-X.tar.bz2, listed
  # by the releases API beside the .tar.gz and the windows zips), not a
  # generated archive/refs/tags tarball.
  url              = "https://github.com/open-mpi/hwloc/releases/download/hwloc-{{version.raw}}/hwloc-{{version.raw}}.tar.bz2"
  strip-components = 1

  # 5688639 bytes, recorded with `zpkb sourcepin --version 2.16.0`.
  #
  # NO SIGNATURE and no published checksum file beside the asset. The second
  # witness is a second independent fetch from the project's OTHER host:
  # https://download.open-mpi.org/release/hwloc/v2.16/hwloc-2.16.0.tar.bz2
  # (the S3 bucket behind www.open-mpi.org) gave the same 5688639 bytes and the
  # same digest as the GitHub asset. Two hosts agreeing shows we fetched what
  # was published, not who published it.
  sha256 = {
    "2.16.0" = "ad05eb466b915a4f0e0228173d7e09974ac38760c38d5b6f060254c050fca12d"
  }
}

dependencies = {
  # config/hwloc.m4:1609 HWLOC_PKG_CHECK_MODULES([LIBXML2], [libxml-2.0]); the
  # default is "use it when found" (:1605), and the library's XML export
  # otherwise falls back to a minimal built-in parser. Kept, and ENABLED
  # explicitly below so that it is not left to detection.
  "gnome.org/libxml2" = ">=2.14"

  # config/hwloc_internal.m4:405-428 probes for termcap support with no switch
  # to turn it off: `for curses in ncurses curses`, `-lncursesw -lncurses
  # -ltinfo -ltermcap`, linking tparm(). lstopo's ascii output links the result
  # (utils/lstopo/Makefile.am:42 HWLOC_TERMCAP_LIBS), so the artifact's
  # dependency would depend on the builder. Declared, so the probe always finds it.
  "invisible-island.net/ncurses" = "*"
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # Every optional backend named, none left to auto-detection
      # (config/hwloc_internal.m4:64-181, each is a --disable-X help line).
      "--enable-libxml2",

      # GPU and accelerator discovery: none of their SDKs is in this pantry.
      "--disable-cairo",
      "--disable-opencl",
      "--disable-cuda",
      "--disable-nvml",
      "--disable-rsmi",
      "--disable-levelzero",
      "--disable-gl",

      # libudev (:178) and PCI (:84): no libudev, no libpciaccess recipe here.
      # --disable-pci removes the PCI discovery build; the topology of the
      # processors, caches and NUMA nodes, which is what dependents use, is
      # unaffected.
      "--disable-libudev",
      "--disable-pci",

      # :49 doxygen, off in a release tarball and named anyway.
      "--disable-doxygen",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{hw.concurrency}} install
EOT
}

# utils/hwloc/Makefile.am:33-40 bin_PROGRAMS, :46 hwloc-ps, :72 bin_SCRIPTS
# hwloc-compress-dir; utils/lstopo/Makefile.am:19-20 lstopo-no-graphics, and
# :105-111 install-exec-hook links hwloc-ls and lstopo to it. Cairo is off, so
# no graphical lstopo of its own (:47-48).
provides = [
  "bin/hwloc-annotate",
  "bin/hwloc-bind",
  "bin/hwloc-calc",
  "bin/hwloc-compress-dir",
  "bin/hwloc-diff",
  "bin/hwloc-distrib",
  "bin/hwloc-info",
  "bin/hwloc-ls",
  "bin/hwloc-patch",
  "bin/hwloc-ps",
  "bin/lstopo",
  "bin/lstopo-no-graphics",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "lstopo-no-graphics --version",
    "hwloc-info --version",
    "test -f {{prefix}}/include/hwloc.h",
    "test -f {{prefix}}/lib/pkgconfig/hwloc.pc",
    "pkg-config --exists hwloc",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <hwloc.h>

int main(void) {
  if (hwloc_get_api_version() != HWLOC_API_VERSION) {
    printf("header %#x but library %#x\n", HWLOC_API_VERSION, hwloc_get_api_version());
    return 1;
  }

  hwloc_topology_t topo;
  if (hwloc_topology_init(&topo) != 0) {
    puts("topology_init failed");
    return 1;
  }
  hwloc_topology_destroy(topo);
  puts("libhwloc header and library agree");
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o apicheck $(pkg-config --cflags --libs hwloc)"
    },
    "./apicheck",
  ]
}

provenance {
  read = [
    "COPYING",                       # :1 SPDX-License-Identifier: BSD-3-Clause
    "config/hwloc_internal.m4",      # :64-204 every --enable/--disable switch; :405-428 the termcap probe
    "config/hwloc.m4",               # :1603-1627 libxml2 through pkg-config, default on when found
    "utils/hwloc/Makefile.am",       # :33-40, :46, :72 installed programs and scripts
    "utils/lstopo/Makefile.am",      # :19-20, :42, :47-48, :105-111 lstopo-no-graphics and its links
  ]

  consulted = [
    "GitHub releases API of open-mpi/hwloc (asset names)",
  ]

  note = <<EOT
NOT BUILT. Written from the project's files, linted, and the source digest
checked against two hosts; no build or test of this recipe was run.

No signature is published, so the digest's second witness is a fetch from
download.open-mpi.org, the project's own host behind www.open-mpi.org.

--disable-pci is a loss of PCI device discovery (lstopo's I/O objects), kept
off because no libpciaccess recipe exists in this tree; add it with
--enable-pci when one does.
EOT
}
