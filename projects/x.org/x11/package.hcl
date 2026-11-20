# x.org/x11 — libX11, the Xlib client library. Seventh and last of the chain
# go-zpkg/recipes#167 orders; mupdf.com, getclipboard.app and tcl-lang.org (Tk)
# declare it. The project name is the one those consumers already ask for.
#
# ⛔ WRITTEN FROM LIBX11'S OWN FILES (go-zpkg/packages#431), at 1.8.14.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE PANTRY'S `--enable-local-transport` IS A DEFECT ON EVERY PLATFORM THIS
#      TREE BUILDS. xtrans.m4:128-139 defaults LOCALCONN to "yes" on solaris and
#      "no" everywhere else — it is the SVR4 STREAMS transport — and forcing it
#      on makes xtrans compile Xtranslcl.c, whose line 81 includes <stropts.h>.
#      Measured on darwin: `fatal error: 'stropts.h' file not found`. It is
#      `--disable-local-transport` here, which is the default stated.
#   2. `--enable-loadable-i18n`, which the pantry also passes, is the opposite of
#      the default (configure.ac:119, "no"). Not carried: nothing in this chain
#      reads it, and it splits the i18n code into modules loaded at run time.
#   3. THE ARTIFACT DIFFERS BY BUILDER in seven places the configure script
#      decides by probe, and none of them fails a build when it goes the other
#      way: loadable xcursor (:137, dlopen), the XLOCALEDIR variable (:295,
#      issetugid/getresuid), XF86BigFont (:304-307, silently "no" when
#      xf86bigfontproto is missing), the compose cache (:326-331, mmap and
#      nl_langinfo), IPv6 (xtrans.m4:41, getaddrinfo), launchd (:182-186, a
#      `launchd` on PATH) and the thread-safety constructor. Each is NAMED
#      below, and the test reads three of them off the library.
#   4. libX11 prints its own summary of those choices at the end of configure
#      (configure.ac:429-442), which is the evidence a build log gives.
#   5. libpthread-stubs, which go-zpkg/recipes#167 lists as a dependency, is
#      required only when the thread-safety constructor is OFF and the host is
#      not linux/darwin/solaris/BSD (configure.ac:232-240). Neither holds, so it
#      is NOT declared.

summary = "X.Org libX11: the Xlib client library"

# COPYING is 899 lines, forty-odd notices (every line below is a heading read
# from it). The licences the notices fall into:
#   :14-:40    Jamey Sharp, Josh Triplett, Red Hat, Oracle — "Permission is
#              hereby granted, free of charge": MIT;
#   :42,:591   The Open Group — "…and sell … Except as contained in this notice,
#              the name of The Open Group shall not be used": MIT-open-group;
#   :68        X Consortium and XFree86 — "Permission is hereby granted, free of
#              charge … Except as contained in this notice, the name of the X
#              Consortium shall not be used": X11;
#   :95-:567 and most of the rest (Tektronix, Digital, Fujitsu, Oki, OMRON, Sony,
#              OSF, SGI, Wyse, TOSHIBA, Bruno Haible, IBM :839-858): "Permission
#              to use, copy, modify, and distribute this software … without fee
#              … that the name … not be used in advertising": HPND, and with
#              "and sell" HPND-sell-variant;
#   :793       Troy D. Hanson (uthash) — "Redistribution and use in source and
#              binary forms … Redistributions of source code must retain the
#              above copyright notice": BSD-1-Clause (the text was read to :801,
#              its end was not);
#   :886       Otto Moerbeek (reallocarray) — "Permission to use, copy, modify,
#              and distribute this software for any purpose with or without fee":
#              ISC.
# Not each of the 97 matching lines was read; those above are the notices of each
# kind that were.
license = "MIT AND MIT-open-group AND X11 AND HPND AND HPND-sell-variant AND BSD-1-Clause AND ISC"

versions {
  url   = "https://www.x.org/releases/individual/lib/"
  match = "/libX11-\\d+\\.\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = ["/libX11-/", "/\\.tar\\.xz/"]
}

dependencies = {
  # configure.ac:81 `xcb >= 1.11.1`, mandatory; x11.pc `Requires.private: xcb`.
  "x.org/xcb"      = "^1"
  # configure.ac:81, :318 xproto >= 7.0.25, xextproto, kbproto, inputproto; and
  # x11.pc `Requires: xproto kbproto`, so every consumer's pkg-config walk
  # reaches the protocol headers.
  "x.org/protocol" = "*"
}

distributable {
  # 1897544 bytes. Recorded with `zpkb sourcepin --sig` (signature verified, see
  # provenance.note); the digest is the one go-zpkg/recipes#167 verified, and a
  # second, independent fetch-and-hash (curl + shasum) gave the same.
  url              = "https://www.x.org/releases/individual/lib/libX11-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "1.8.14" = "bbc78c46217174655c2b32b138ad119f3ac15f50808b4d0b3a2677a4b1afc950"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
    # configure.ac:98 (xtrans.m4's XTRANS_CONNECTION_FLAGS) is expanded when the
    # tarball's configure was GENERATED; at build, PKG_CHECK_MODULES(X11, …
    # xtrans …) at :348 needs xtrans.pc and the sources it installs.
    "x.org/xtrans"               = "^1"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ DOCUMENTATION AND TOOLS (configure:1645-1685). specs default yes,
      # xmlto/xsltproc auto, fop no, perl auto (XORG_WITH_PERL, configure.ac:35),
      # lint auto. All off.
      "--disable-specs",
      "--with-xmlto=no",
      "--with-fop=no",
      "--with-xsltproc=no",
      "--without-perl",
      "--without-lint",
      "--disable-lint-library",

      # ⛔ TRANSPORTS (xtrans.m4:111-139). unix: default yes except mingw; tcp:
      # yes; ipv6: default is whether getaddrinfo exists (:41); local: NO — see
      # finding 1.
      "--enable-unix-transport",
      "--enable-tcp-transport",
      "--enable-ipv6",
      "--disable-local-transport",

      # ⛔ finding 3, each named:
      "--enable-xthreads",                  # configure.ac:196, default yes
      "--enable-thread-safety-constructor", # :148, default yes
      "--enable-loadable-xcursor",          # :137, default = dlopen found
      "--disable-loadable-i18n",            # :119, default no — finding 2
      "--enable-xcms",                      # :272, default yes
      "--enable-xlocale",                   # :281, default yes
      "--enable-xlocaledir",                # :295, default = issetugid or getresuid; both targets have one
      "--enable-xf86bigfont",               # :304, default yes, silently no on a miss
      "--enable-xkb",                       # :313, default yes; makes kbproto and inputproto fatal (:318)
      "--enable-composecache",              # :331, default = mmap and nl_langinfo

      # configure.ac:249-252: defaults to the xproto include directory through
      # pkg-config; stated so the keysym tables come from the declared xorgproto.
      "--with-keysymdefdir={{deps.x.org/protocol.prefix}}/include/X11",
    ]

    # configure.ac:182-186: `--with-launchd` is `auto`, decided by whether a
    # `launchd` program is on PATH (/sbin on macOS). Pinned per platform so the
    # artifact does not depend on the builder: xtrans reads it for launchd
    # socket addresses (Xtrans.c:222-228) on macOS and has no use for it
    # elsewhere.
    darwin {
      LAUNCHD = "--with-launchd"
    }
    linux {
      LAUNCHD = "--without-launchd"
    }
  }

  script = [
    "./configure $ARGS $LAUNCHD",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

test {
  fixture = <<EOT
#include <X11/Xlib.h>
#include <X11/Xresource.h>
#include <stdio.h>

/* No display is needed: XInitThreads() is the call whose result is the
 * --enable-xthreads outcome (configure.ac:196-206), and the resource-manager
 * quarks are pure Xlib. */
int main(void)
{
	if (!XInitThreads()) {
		fprintf(stderr, "libX11 was built without thread support\n");
		return 1;
	}
	XrmInitialize();
	if (XrmStringToQuark("tk") == NULLQUARK) {
		fprintf(stderr, "XrmStringToQuark failed\n");
		return 1;
	}
	return 0;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/X11/Xlib.h\"",
    "test -f \"{{prefix}}/include/X11/XKBlib.h\"",
    "test -f \"{{prefix}}/lib/pkgconfig/x11.pc\"",
    "test -f \"{{prefix}}/lib/pkgconfig/x11-xcb.pc\"",

    # x11.pc: `Requires: xproto kbproto` and `Requires.private: xcb`.
    "grep -q '^Requires:.*xproto' \"{{prefix}}/lib/pkgconfig/x11.pc\"",
    "grep -q '^Requires:.*kbproto' \"{{prefix}}/lib/pkgconfig/x11.pc\"",
    "grep -q '^Requires.private:.*xcb' \"{{prefix}}/lib/pkgconfig/x11.pc\"",

    # ⛔ finding 3, read off the artifact: three of the probed choices leave a
    # string in the shared library — the XF86BigFont extension name (configure.ac
    # :304-307, a silent "no" on a miss), the XKB extension name (:313) and the
    # libXcursor name the loadable-xcursor path dlopens (:137).
    {
      run = <<EOT2
set -eu
lib=""
for f in "{{prefix}}"/lib/libX11.so "{{prefix}}"/lib/libX11.dylib; do
  if test -e "$f"; then lib=$(cd "$(dirname "$f")" && pwd -P)/$(basename "$f"); break; fi
done
test -n "$lib" || { echo "no libX11 shared library" >&2; exit 1; }
real=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
grep -aq 'XFree86-Bigfont' "$real" || { echo "libX11 was built without XF86BigFont" >&2; exit 1; }
grep -aq 'XKEYBOARD' "$real" || { echo "libX11 was built without XKB" >&2; exit 1; }
grep -aq 'libXcursor' "$real" || { echo "libX11 was built without loadable xcursor" >&2; exit 1; }
EOT2
    },

    # The thread constructor and Xlib itself, by running it.
    "cc -x c $FIXTURE -x none -o xlibcheck -I{{prefix}}/include -I{{deps.x.org/protocol.prefix}}/include -L{{prefix}}/lib -lX11",
    {
      run = <<EOT3
set -eu
libs="{{prefix}}/lib:{{deps.x.org/xcb.prefix}}/lib:{{deps.x.org/xau.prefix}}/lib:{{deps.x.org/xdmcp.prefix}}/lib"
LD_LIBRARY_PATH="$libs:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$libs:$${DYLD_LIBRARY_PATH:-}" ./xlibcheck
EOT3
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # :22-35 doc tools; :81-82 the requirement list; :88-98 xtrans at autoconf time; :100-151 dlopen, loadable i18n and xcursor, the thread constructor; :182-191 launchd; :193-241 xthreads and pthread-stubs; :249-267 keysymdef; :269-334 xcms, xlocale, xlocaledir, xf86bigfont, xkb, composecache; :348 PKG_CHECK_MODULES; :429-442 the summary
    "configure",     # :1645-1687 every switch and its default
    "xtrans.m4",     # (xtrans 1.6.0) :38-46 ipv6; :105-139 unix, tcp, local and their defaults
    "Xtrans.c",      # (xtrans 1.6.0) :222-228 and :867-869 launchd
    "Xtranslcl.c",   # (xtrans 1.6.0) :81 the stropts.h include that --enable-local-transport reaches
    "COPYING",       # :14-899 the notices cited in the licence comment
    "https://www.x.org/releases/individual/lib/", # the release listing and the .sig beside the archive
    "https://github.com/alanc.gpg",               # the signer's key, from GitHub's account endpoint
  ]

  consulted = [
    # Read for facts only: the name x.org/x11, the version listing, and the
    # switches it passes — among them the two this recipe does NOT carry,
    # --enable-local-transport and --enable-loadable-i18n. Nothing copied.
    "pkgxdev/pantry projects/x.org/x11/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, with a key from an account endpoint rather than a keyserver.

  signature   https://www.x.org/releases/individual/lib/libX11-1.8.14.tar.xz.sig
  signer      Alan Coopersmith <alan.coopersmith@oracle.com>
  fingerprint 3AB285232C46AE43D8E192F4DAB0F78EA6E7E2D2, as recorded in
              go-zpkg/recipes#167 (the first of the two keys in the file)
  key from    https://github.com/alanc.gpg (GitHub's account endpoint)

⚠ THE RUNG, STATED: the fingerprint comes from GitHub's account page for the
signer, a third party that is not X.Org; x.org publishes no page naming the
signing keys of its release archives.

zpkb v0.84.0 or later is needed (the key has lapsed: go-zpkg/zpkb#484).

⛔ BUILT ONCE, ON DARWIN, NOT BY THE FACTORY. A scratch build with these
arguments (xorgproto, xtrans, libxcb and the rest of the chain on
PKG_CONFIG_PATH, --with-launchd) configured, built and installed, and its
configure summary read "XF86BigFont support: yes", "Loadable xcursor library
support: yes", "XKB support: yes", "Compose table cache enabled: yes". The
previous attempt, with the pantry's --enable-local-transport, failed in make on
stropts.h — finding 1. The linux branch (--without-launchd) was not run.
EOT
}
