# libpcap — the portable packet-capture library (pcap.h, libpcap, pcap-config).
#
# ⛔ WRITTEN FROM LIBPCAP'S OWN FILES at 1.11.0 (go-zpkg/packages#440 step 1).
# The `pcap` crate that sniffnet.net links needs it through pkg-config and no
# recipe existed.

summary = "Portable packet-capture library: libpcap and pcap-config"

# LICENSE opens "License: BSD" and carries the three-clause text (the third
# clause: "The names of the authors may not be used to endorse or promote
# products").
license = "BSD-3-Clause"

versions {
  github = "the-tcpdump-group/libpcap"
  strip  = ["/^libpcap-/"]
}

distributable {
  # The STORED release archive on tcpdump.org (not a generated one).
  #
  # 1.11.0: 736612 bytes, fetched with `zpkb sourcepin`, which also verified
  # libpcap-1.11.0.tar.xz.sig against signing-key-RSA-E089DEF1D9C15D0D.asc: good
  # signature by "The Tcpdump Group (Package signing key) <release@tcpdump.org>",
  # fingerprint 1F16 6A57 42AB B9E0 249A 8D30 E089 DEF1 D9C1 5D0D, made
  # 2026-09-13.
  #
  # ⚠ WHERE THE FINGERPRINT CAME FROM: tcpdump.org links the key but prints no
  # fingerprint. The key file name carries the 64-bit key id E089DEF1D9C15D0D
  # and the key file's own fingerprint ends in it, so the identity rests on the
  # project's download page linking that key beside the signature, not on a
  # second place. Said rather than hidden. No keyserver was asked.
  #
  # tcpdump.org's front page labels 1.11.0 "testing" and 1.10.7 the stable
  # branch; this recipe pins the newest tag the version source resolves.
  url              = "https://www.tcpdump.org/release/libpcap-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.11.0" = "9237f5bae9dcf3a91823d9963ec43b7c0e2e3374ef2ad57d92c8cd39530f4723"
  }
}

dependencies = {}

build {
  # ⛔ flex AND bison ARE REQUIRED: the tarball ships grammar.y and scanner.l
  # but no generated grammar.c / scanner.c (checked in the unpacked archive),
  # and configure.ac:1878 runs AC_PROG_LEX(noyywrap).
  dependencies = {
    "github.com/westes/flex" = "*"
    "gnu.org/bison"          = "^3"
    "gnu.org/make"           = "*"
  }

  # ⛔ EVERY OPTIONAL BACKEND IS NAMED, because each one is auto-detected and
  # would link whatever the build host has (configure --help, and the
  # AC_ARG_* lines in configure.ac):
  #
  #   --disable-usb        :2442  Linux usbmon capture
  #   --disable-netmap     :2540  netmap
  #   --disable-bluetooth  :2580  Bluetooth capture
  #   --disable-dbus       :2663  D-Bus capture
  #   --disable-rdma       :2746  RDMA capture (libibverbs)
  #   --without-libnl      :1066  nl80211 monitor-mode support on Linux
  #   --without-dag        :1327  Endace DAG cards
  #   --without-snf        :1492  Myricom SNF
  #   --disable-remote     :1622  remote capture (rpcapd; would need OpenSSL)
  #
  # The cost is stated: with libnl off, Linux monitor mode through nl80211 is
  # not offered. A consumer that needs it adds libnl (a whole recipe exists) and
  # drops --without-libnl.
  script = [
    "./configure --prefix={{prefix}} --disable-usb --disable-netmap --disable-bluetooth --disable-dbus --disable-rdma --without-libnl --without-dag --without-snf --disable-remote",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile.in:586 installs pcap-config into bindir. No other program: rpcapd is
# built only with --enable-remote.
provides = [
  "bin/pcap-config",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/pcap.h",
    "test -f {{prefix}}/lib/pkgconfig/libpcap.pc",
    "pkg-config --exists libpcap",
    "test \"$(pkg-config --modversion libpcap)\" = {{version.raw}}",
    "pcap-config --libs",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <pcap/pcap.h>

int main(void) {
  const char *v = pcap_lib_version();
  if (strstr(v, "libpcap version") == NULL) {
    printf("unexpected version string: %s\n", v);
    return 1;
  }
  /* Compiling a filter exercises the flex/bison-generated parser without
     needing a capture device or privileges. */
  pcap_t *p = pcap_open_dead(DLT_EN10MB, 65535);
  struct bpf_program prog;
  if (p == NULL || pcap_compile(p, &prog, "tcp port 80", 1, PCAP_NETMASK_UNKNOWN) != 0) {
    puts("filter did not compile");
    return 1;
  }
  pcap_freecode(&prog);
  pcap_close(p);
  printf("%s\n", v);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o probe $(pkg-config --cflags --libs libpcap)"
    },
    "./probe",
  ]
}

provenance {
  read = [
    "configure.ac",    # :19 AC_INIT; :724-:2746 the AC_ARG_ENABLE/WITH options; :1878 AC_PROG_LEX
    "Makefile.in",     # :383 all; :566 install; :586 pcap-config into bindir
    "LICENSE",         # "License: BSD", three clauses
    "configure --help",
  ]

  consulted = [
    "https://www.tcpdump.org/",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

  signature   https://www.tcpdump.org/release/libpcap-1.11.0.tar.xz.sig
  key         https://www.tcpdump.org/release/signing-key-RSA-E089DEF1D9C15D0D.asc
  identity    The Tcpdump Group (Package signing key) <release@tcpdump.org>
  fingerprint 1F166A5742ABB9E0249A8D30E089DEF1D9C15D0D
  signed at   2026-09-13

The fingerprint was read from the key file linked on the download page; the
page prints none. The key expires 2027-05-08.

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN: NOT BUILT. Stated rather than
implied.
EOT
}
