# openprinting.github.io/cups — CUPS, the printing system: here its CLIENT side,
# libcups with the `cups-config`, `ipptool` and `ippeveprinter` programs.
# go-zpkg/recipes#122: Tk 9 on X11 prints through it (`tk print` to a CUPS
# queue), and gtk and openjdk name it.
#
# ⛔ WRITTEN FROM CUPS 2.4.20'S OWN FILES (go-zpkg/packages#431), read out of the
# published source tarball, and BUILT AND INSTALLED in a scratch directory on
# darwin/arm64 (the darwin flag set below; its outcomes read back from the
# install). NOT built on linux and NOT built by the factory.
#
# ⭐ WHAT IS BUILT, AND WHY NOT THE SCHEDULER. `--with-components=core`
# (cups-common.m4:456-492) builds libcups, libcupsimage, the `tools` directory
# (ipptool, ippeveprinter, ippfind) and the examples. It does NOT build cupsd,
# the filters, the backends or the web interface. A scheduler is a system
# service: it owns /var/spool/cups and /etc/cups, runs as root and `lp`, talks
# to USB devices through root-run backends, and wants PAM, systemd or launchd
# and a user and group that a package prefix cannot create. The client library
# is what Tk, gtk and the JDK link, and it talks to whatever scheduler the HOST
# runs, over the host's own domain socket (next paragraph).
#
# ⭐⭐ THE CLIENT'S DEFAULTS POINT AT THE HOST, NOT AT THE PREFIX.
# cups-directories.m4:11-93 derives sysconfdir and localstatedir from the prefix
# when it is not "/": with `--prefix=<store>` the compiled-in server root would
# be `<store>/etc/cups`, the state directory `<store>/var/run/cups` and
# (cups-network.m4:66-81) the default socket `<store>/var/run/cups/cups.sock` —
# a path no scheduler listens on. libcups reads `client.conf` from the compiled
# server root (cups/usersys.c:1047) and uses the socket only if it exists, else
# falls back to `localhost` (:1249-1254). So the host's locations are passed
# explicitly: sysconfdir /etc and localstatedir /var on linux (the socket is
# then /var/run/cups/cups.sock, which is /run/cups/cups.sock on a current
# system), /private/etc and /private/var on darwin (socket
# /private/var/run/cupsd, cups-network.m4:70). The test reads both off the
# installed library.
#
# ⛔⛔ EVERY AUTO-DETECTED SWITCH, NAMED OR REFUSED (`./configure --help` and the
# config-scripts/*.m4 it is generated from, read):
#
#   TLS      `--with-tls` defaults to `yes` (cups-tls.m4:13-14), which takes
#            OpenSSL if pkg-config finds one (:25-65), then GnuTLS (:68-110),
#            then SecureTransport on darwin (:113-137): whichever the builder
#            has. NAMED: linux `openssl` (declared dependency, fatal if absent,
#            :62-63); darwin `cdsa`, Apple's own SecureTransport, so no OpenSSL
#            is dragged onto a macOS client. GnuTLS is REFUSED: no recipe here.
#   DNS-SD   `--with-dnssd` defaults to `yes` (cups-dnssd.m4:12-13): mDNSResponder,
#            else Avahi if pkg-config finds it. darwin NAMED `mdnsresponder`
#            (dns_sd.h is in the system, :33-41). linux REFUSED, `no`: Avahi is
#            not a recipe of this tree or of the pantry, and its client needs a
#            running avahi-daemon and libdbus. WHAT THAT COSTS, STATED: on linux
#            libcups cannot browse or resolve `.local` DNS-SD names
#            (cupsEnumDests, httpResolveURI in cups/dest.c and
#            cups/http-support.c under HAVE_AVAHI), and `ippfind` is not built
#            (IPPFIND_BIN is only set with DNS-SD, :41,:61,:88). Printing to a
#            queue on the host's scheduler, which is what `tk print` does
#            (cupsGetNamedDest, cupsCreateDestJob in Tk's unix/tkUnixPrint.c), does
#            not use it. A gap to close by an Avahi recipe, not a decision that
#            discovery is unwanted.
#   GSSAPI   `--enable-gssapi` defaults OFF and is marked deprecated
#            (cups-gssapi.m4:15,20), and the pantry's `kerberos.org` dependency
#            was therefore never linked. darwin NAMED `--enable-gssapi`: the
#            Kerberos and GSS frameworks are weak-linked from the system
#            (:22-32) and need no dependency. linux REFUSED: `kerberos.org` is
#            a dependencies-only fragment here, not a recipe (MIT krb5 is not
#            written), and declaring it would make this recipe unresolvable.
#            COST: Kerberos (Negotiate) authentication to a remote CUPS server
#            from linux. A gap, to close with a krb5 recipe.
#   PAM      `--disable-pam` (cups-pam.m4:21): used by cupsd and ippeveprinter
#            (tools/Makefile:151 PAMLIBS) for password checks; the scheduler is
#            not built and ippeveprinter's authentication is not wanted.
#   libusb   `--disable-libusb` (cups-common.m4:241): auto on non-darwin, used
#            only by the USB backend, which is not built.
#   DBus     `--disable-dbus` (:327,:332): auto, used by the scheduler's notifier.
#   ACL      `--disable-acl` (:313-314): auto, cupsd only (SERVERLIBS).
#   libpaper `--disable-libpaper` (:114-125): default off; named so it stays off.
#   libwrap  `--disable-tcp-wrappers` (:261-273): default off; cupsd only.
#   systemd/launchd `--with-ondemand=no` (cups-startup.m4:17-29): the default
#            `yes` probes libsystemd (:63-103) and launchd (:35-53) for the
#            scheduler's socket activation; no scheduler here.
#   AppArmor and snapd  (cups-container.m4:33-71): probed through pkg-config with
#            NO switch to turn them off. They only add a define and link flags
#            for the scheduler (neither macro occurs in cups/ or tools/), but a
#            probe that depends on the builder is closed anyway: PKG_CONFIG_LIBDIR
#            below lets pkg-config see ONLY the declared OpenSSL, so every one of
#            these probes (and libusb, dbus, systemd, avahi, gnutls) answers no
#            on every builder. The test then lists what libcups links.
#   libdir   cups-directories.m4:95-102 picks `lib64` on a linux builder that
#            has /usr/lib64, `lib` otherwise: a host-dependent layout. Pinned to
#            `{{prefix}}/lib`.
#   The remaining switches change only the scheduler's defaults or debugging,
#   and are kept at their defaults: --enable-static, --enable-mallinfo,
#   --enable-debug*, --enable-maintainer, --enable-unit-tests, --enable-relro,
#   --enable-sanitizer, --disable-largefile, --enable-page-logging,
#   --enable-sync-on-close, --disable-browsing, --disable-default-shared,
#   --disable-raw-printing, --enable-webif, every --with-*dir, --with-*-perm,
#   --with-cups-user/-group (probed from the build host's passwd file but only
#   consumed by cupsd), --with-languages (all).
#
# ⛔⛔ UPSTREAM BUG, PATCHED: THE DARWIN TLS BACKEND DOES NOT COMPILE IN 2.4.20.
# cups/tls-darwin.c:1269 calls `_cupsSetHTTPError(HTTP_STATUS_ERROR)` and
# cups/cups-private.h:295 declares `_cupsSetHTTPError(http_t *http,
# http_status_t status)`: "too few arguments to function call", measured with
# `--with-tls=cdsa` on macOS. The one-line fix is committed beside this recipe
# (props/tls-darwin-sethttperror.patch) and applied on both platforms (the file
# exists in the linux tree and is not compiled there).

summary = "CUPS: the printing system's client library (libcups) and IPP tools, linked to the host's scheduler"

# LICENSE is the Apache License 2.0; NOTICE:38-52 adds "CUPS Exceptions to the
# Apache 2.0 License" (object-form embedding, and a GPLv2 combination waiver),
# which has no SPDX identifier; NOTICE:11-35 adds the Kerberos support code
# (compiled in only with HAVE_GSSAPI, i.e. on darwin here) and cups/md5.c:13
# carries Aladdin's zlib-style permission; both are the Zlib terms.
license = "Apache-2.0 AND Zlib AND LicenseRef-CUPS-exceptions"

platforms = ["linux", "darwin"]

versions {
  github = "OpenPrinting/cups"

  # v2.4rc1, v2.4b1 are prereleases and v2.3.3op1/op2 are the 2.3 branch's
  # OpenPrinting tags; a version absent from `sha256` is refused anyway.
  ignore = ["/^2\\.4(rc|b)\\d+$/", "/op\\d+$/"]
}

dependencies = {
  # cups-common.m4:278-290: a missing zlib silently drops HAVE_LIBZ, so it is
  # declared, passed by path, and read back by the test.
  "zlib.net" = "^1.2"

  # cups-tls.m4:25-65 on linux; darwin uses SecureTransport.
  linux = {
    "openssl.org" = "^3"
  }
}

distributable {
  # The release asset, not GitHub's archive of the tag: it carries the generated
  # `configure`, and a detached signature sits beside it.
  url              = "https://github.com/OpenPrinting/cups/releases/download/v{{version.raw}}/cups-{{version.raw}}-source.tar.gz"
  strip-components = 1

  # 8164882 bytes. Recorded with `zpkb sourcepin --sig auto --key … --fingerprint
  # …` (zpkb v0.90.0, no keyserver) and confirmed by a second, independent
  # fetch-and-hash (`curl --fail` + `shasum -a 256`). The signature chain is in
  # provenance.note.
  sha256 = {
    "2.4.20" = "ab4d9cd7f3e58060091d2b24972223d6401675f11c49b65abf4f6ef31dea22ff"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
    "gnu.org/patch"              = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--with-components=core",
      "--disable-pam",
      "--disable-libusb",
      "--disable-dbus",
      "--disable-acl",
      "--disable-libpaper",
      "--disable-tcp-wrappers",
      "--with-ondemand=no",
    ]

    CPPFLAGS = "-I{{deps.zlib.net.prefix}}/include"
    LDFLAGS  = "-L{{deps.zlib.net.prefix}}/lib"

    # Carried from go-zpkg/packages overrides/openprinting.github.io-cups.hcl
    # (deleted with this change, go-zpkg/zpkb#514/#516). Makedefs.in:155 links
    # the shared libraries with ALL_DSOFLAGS, which does not include LDFLAGS, so
    # the -L above never reached the link of libcups; configure keeps a DSOFLAGS
    # given in the environment (cups-sharedlibs.m4:13).
    DSOFLAGS = "$LDFLAGS"

    linux = {
      ARGS = [
        "--sysconfdir=/etc",
        "--localstatedir=/var",
        "--with-tls=openssl",
        "--with-dnssd=no",
      ]
      # See the header: only the declared OpenSSL is visible to pkg-config.
      PKG_CONFIG_LIBDIR = "{{deps.openssl.org.prefix}}/lib/pkgconfig"
    }

    darwin = {
      ARGS = [
        "--sysconfdir=/private/etc",
        "--localstatedir=/private/var",
        "--with-tls=cdsa",
        "--with-dnssd=mdnsresponder",
        "--enable-gssapi",
      ]
      # A directory that does not exist: pkg-config answers no to everything.
      PKG_CONFIG_LIBDIR = "{{prefix}}/no-pkgconfig"
    }
  }

  script = [
    "patch -p1 --batch --forward < props/tls-darwin-sethttperror.patch",
    "./configure $ARGS",

    # Carried from the same override. `make install` runs install with -s
    # (Makedefs:49 and :54, INSTALL_BIN and INSTALL_LIB); GNU strip destroys a
    # Mach-O and exits 0, and a binary stripped after it is signed is killed by
    # the arm64 kernel with no message (go-zpkg/zpkb#161).
    "sed -i -E 's/^(INSTALL_(BIN|LIB)[[:space:]]*=.*[^-])[[:space:]]-s[[:space:]]*$/\\1/' Makedefs",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile:174-179 installs cups-config and cups.pc; tools/Makefile installs the
# rest. ippfind is built only with DNS-SD, so it is not promised.
provides = [
  "bin/cups-config",
  "bin/ipptool",
  "bin/ippeveprinter",
]

test {
  fixture = <<EOT
#include <cups/cups.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef WANT_SOCK
#error WANT_SOCK is the host's scheduler socket
#endif

int main(void)
{
	int bad = 0;
	unsigned char hash[32];
	const char *srv;
	ipp_t *req;

	/* The compiled-in default server: the host's socket when it is there,
	 * else localhost (cups/usersys.c:1249-1254). The caller points
	 * CUPS_SERVERROOT and HOME at nothing so no client.conf interferes. */
	unsetenv("CUPS_SERVER");
	srv = cupsServer();
	if (access(WANT_SOCK, R_OK) == 0 ? strcmp(srv, WANT_SOCK) != 0 : strcmp(srv, "localhost") != 0) {
		fprintf(stderr, "default server is %s, socket is %s\n", srv, WANT_SOCK);
		bad = 1;
	}

	/* The TLS library's hash path: SHA-256 of "abc". */
	if (cupsHashData("sha2-256", "abc", 3, hash, sizeof hash) != 32 ||
	    hash[0] != 0xba || hash[1] != 0x78 || hash[2] != 0x16 || hash[3] != 0xbf) {
		fprintf(stderr, "sha-256 of abc is wrong\n");
		bad = 1;
	}

	req = ippNewRequest(IPP_OP_GET_PRINTER_ATTRIBUTES);
	ippAddString(req, IPP_TAG_OPERATION, IPP_TAG_URI, "printer-uri", NULL, "ipp://localhost/printers/x");
	if (ippGetOperation(req) != IPP_OP_GET_PRINTER_ATTRIBUTES || ippLength(req) == 0) {
		fprintf(stderr, "ipp request not built\n");
		bad = 1;
	}
	ippDelete(req);
	return bad;
}
EOT

  script = [
    "test -x \"{{prefix}}/bin/cups-config\"",
    "test -x \"{{prefix}}/bin/ipptool\"",
    "test -x \"{{prefix}}/bin/ippeveprinter\"",
    "test -f \"{{prefix}}/include/cups/cups.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/cups.pc\"",
    "test \"$(\"{{prefix}}/bin/cups-config\" --version)\" = \"{{version.raw}}\"",
    "\"{{prefix}}/bin/ipptool\" --version > ver.txt && grep -q \"CUPS v{{version.raw}}\" ver.txt",
    "PKG_CONFIG_PATH=\"{{prefix}}/lib/pkgconfig\" pkg-config --exact-version={{version.raw}} cups",

    # ⛔⛔ EVERY NAMED OR REFUSED CHOICE, READ OFF THE INSTALLED LIBRARY. The
    # library's names are strings in its dynamic table, so a plain binary grep
    # reads them on both platforms without a tool the sandbox might lack.
    {
      run = <<EOT
set -eu
root="{{prefix}}"
case "$(uname -s)" in
  Darwin)
    lib="$root/lib/libcups.2.dylib"
    want="Security.framework GSS.framework Kerberos.framework libz DNSServiceBrowse gss_init_sec_context"
    refuse="libssl libcrypto libgnutls libavahi libdbus libpam libusb libwrap libacl libpaper libapparmor libsystemd"
    sock="/private/var/run/cupsd"
    sroot="/private/etc/cups"
    test -x "$root/bin/ippfind" || { echo "ippfind missing: DNS-SD was not built on darwin" >&2; exit 1; }
    ;;
  *)
    lib="$root/lib/libcups.so.2"
    want="libssl.so libcrypto.so libz.so"
    refuse="libgnutls libavahi libdbus libpam libusb libwrap libacl libpaper libapparmor libsystemd libgssapi libkrb5"
    sock="/var/run/cups/cups.sock"
    sroot="/etc/cups"
    ! test -e "$root/bin/ippfind" || { echo "ippfind was built: DNS-SD is on" >&2; exit 1; }
    ;;
esac
test -f "$lib"
for w in $want; do
  grep -aq -e "$w" "$lib" || { echo "libcups does not name $w" >&2; exit 1; }
done
for r in $refuse; do
  ! grep -aq -e "$r" "$lib" || { echo "libcups names $r, which this recipe refuses" >&2; exit 1; }
done
grep -aq -e "$sock" "$lib" || { echo "libcups does not carry the host socket $sock" >&2; exit 1; }
test "$("$root/bin/cups-config" --serverroot)" = "$sroot" || { echo "server root is not $sroot" >&2; exit 1; }
test "$("$root/bin/cups-config" --libs)" = "-lcups"
EOT
    },

    {
      run = <<EOT
set -eu
case "$(uname -s)" in
  Darwin) sock=/private/var/run/cupsd ;;
  *)      sock=/var/run/cups/cups.sock ;;
esac
cc -x c $FIXTURE -x none -o probe "-DWANT_SOCK=\"$sock\"" -I{{prefix}}/include -L{{prefix}}/lib -lcups -Wl,-rpath,{{prefix}}/lib
CUPS_SERVERROOT="$PWD/no-such-root" HOME="$PWD" LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                      # :24-41 the m4 files that make up the configure
    "config-scripts/cups-common.m4",     # :100-109 mallinfo; :113-126 libpaper; :232-258 libusb; :260-273 libwrap; :275-292 zlib; :310-320 ACL; :322-360 DBus; :368-448 darwin frameworks; :456-498 components
    "config-scripts/cups-tls.m4",        # :12-17 default yes; :25-65 OpenSSL; :68-110 GnuTLS; :113-137 SecureTransport; :139-146
    "config-scripts/cups-gssapi.m4",     # :15-20 default off; :22-32 darwin frameworks; :49-59 krb5-config
    "config-scripts/cups-dnssd.m4",      # :11-16 default yes; :32-73 mDNSResponder; :76-100 Avahi
    "config-scripts/cups-pam.m4",        # :12-54
    "config-scripts/cups-startup.m4",    # :17-29, :35-53 launchd, :55-103 systemd
    "config-scripts/cups-container.m4",  # :33-71 AppArmor and snapd, no switch
    "config-scripts/cups-sharedlibs.m4", # :22-46 library names; :119-127 rpath only when exec_prefix is not /usr
    "config-scripts/cups-directories.m4", # :11-93 prefix-derived sysconfdir and localstatedir; :95-111 lib64; :258-279 server root, state dir
    "config-scripts/cups-network.m4",    # :57-87 default domain socket
    "cups/usersys.c",                    # :1047 client.conf from the compiled server root; :1238-1256 socket else localhost
    "cups/globals.c",                    # :269, :328 CUPS_SERVERROOT environment override
    "cups/Makefile",                     # :289-320 install-libs; :372 darwin install_name is libdir/libcups.2.dylib
    "Makefile",                          # :160-217 install targets; :174-179 cups-config and cups.pc
    "tools/Makefile",                    # :151, :191 DNSSDLIBS and PAMLIBS only for ippeveprinter and ippfind
    "cups/tls-darwin.c",                 # :1269 the call that does not compile
    "cups/cups-private.h",               # :295 the two-argument declaration
    "cups-config.in",                    # :99-109 --ldflags and --libs print only -L and -lcups
    "LICENSE",
    "NOTICE",                            # :11-35 the Kerberos code's licence; :38-52 the CUPS exceptions
    "unix/tkUnixPrint.c (Tk 9.0.4)",     # the cups calls Tk makes: cupsGetNamedDest, cupsCopyDestInfo, cupsCreateDestJob, cupsStartDestDocument
  ]

  consulted = [
    # Facts only: the release-asset URL shape, `--with-components=core`, and the
    # provides list. The pantry's recipe names no TLS backend, no DNS-SD choice,
    # no libdir and passes none of the switches above.
    "pkgxdev/pantry projects/openprinting.github.io/package.yml",
  ]

  note = <<EOT
SIGNATURE CHAIN. The release asset has a detached signature
(https://github.com/OpenPrinting/cups/releases/download/v2.4.20/cups-2.4.20-source.tar.gz.sig,
OpenPGP ed25519). Its issuer is 7082A0A50A2E92640F3880E0E4522DCC9B246FF7,
Zdenek Dohnal <zdohnal@redhat.com>. WHERE THE FINGERPRINT CAME FROM, with no
keyserver: github.com/zdohnal.gpg, the key published on the account of the
person who published the release (`gh api repos/OpenPrinting/cups/releases/tags/v2.4.20`
author zdohnal), who is a member of the OpenPrinting organization
(`gh api orgs/OpenPrinting/members`). `zpkb sourcepin` verified the tarball
against that key file at the signing instant, 2026-10-05.

⚠ THE RUNG IS A GITHUB ACCOUNT, STATED. The CUPS source tree and site print no
fingerprint; the anchor is the releaser's own GitHub account and the
organization's member list, which the project controls. CONTINUITY, measured:
the same key signed 2.4.10 (2024-06-18), 2.4.16 (2025-12-04) and 2.4.20;
2.4.19 was published by michaelrsweet and signed by another key
(9086C3CDC66C3F563CF8F405BE67C75EC81F3244), which is NOT pinned here because
only 2.4.20 is recorded. The annotated tag is unsigned.

SECOND INDEPENDENT FETCH: `curl --fail` and `shasum -a 256` gave
ab4d9cd7f3e58060091d2b24972223d6401675f11c49b65abf4f6ef31dea22ff, the digest of
the builder's own fetcher.

⛔ BUILT HERE ON DARWIN/ARM64 ONLY, NOT BY THE FACTORY. With the darwin flag set,
unpatched, make stopped at cups/tls-darwin.c:1269; patched it built and
installed, `config.h` had HAVE_CDSASSL, HAVE_MDNSRESPONDER and HAVE_GSSAPI and
no HAVE_OPENSSL, HAVE_DBUS, HAVE_LIBUSB or HAVE_LIBAPPARMOR, and libcups
linked only system libraries. The installed binaries carried an invalid
signature (the install step modified them) and were killed on launch until
re-signed: the factory's Mach-O fixup is what is relied on for that. NOT RUN:
the linux flag set (OpenSSL through pkg-config, DNS-SD off) and the test block
as the factory executes it.

⚠ Tk on darwin is Aqua and never uses libcups (unix/configure.ac:430, the whole
block sits inside `tk_aqua = no`), so tcl-lang.org/tk declares this recipe on
linux only.
EOT
}
