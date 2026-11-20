# freedesktop.org/dbus — D-Bus: libdbus (the reference client library), the
# `dbus-daemon` message bus and its command-line tools. A NEW recipe: the
# pantry's was inherited, and it left the system bus at a path under the prefix.
# go-zpkg/recipes#122: Avahi's client library talks to avahi-daemon over this
# library, and libcups reaches DNS-SD through Avahi.
#
# ⛔ WRITTEN FROM D-BUS 1.16.4'S OWN FILES (go-zpkg/packages#431), read out of
# the published source tarball, and BUILT AND INSTALLED in a scratch directory on
# darwin/arm64 and on linux/aarch64 (a debian:trixie container, whose expat
# stood in for the declared one). The test block ran on both. NOT built by the
# factory.
#
# ⭐⭐ THE REASON THIS RECIPE EXISTS AS A RECIPE: THE SYSTEM BUS IS THE HOST'S.
# meson.build:959-964 defaults the system bus socket to
# `<prefix>/<runstatedir>/dbus/system_bus_socket`, and :997-999 hard-codes
# `unix:path=<that>` into libdbus as DBUS_SYSTEM_BUS_DEFAULT_ADDRESS. A libdbus
# built into a store prefix would therefore look for the system bus in the
# store, where no daemon listens, and avahi-client (client.c:449,
# dbus_bus_get_private(DBUS_BUS_SYSTEM)) could never reach the host's
# avahi-daemon. So `-Dsystem_socket=/var/run/dbus/system_bus_socket` (and the
# pid file) are passed, and the test reads that string out of the installed
# libdbus and makes the library try the system bus.
#
# ⛔⛔ EVERY AUTO-DETECTED SWITCH, NAMED OR REFUSED (meson_options.txt, and the
# meson.build lines that read each option):
#
#   feature options with value `auto` — each is stated, on both platforms:
#   apparmor        -Dapparmor=disabled   (:435) libapparmor, audit hooks of the
#                   system bus. REFUSED, no recipe.
#   selinux         -Dselinux=disabled    (:427) libselinux. REFUSED, no recipe.
#   libaudit        -Dlibaudit=disabled   (:563-571) REFUSED, no recipe.
#   systemd         -Dsystemd=disabled    (:499) libsystemd, at_console and
#                   the user-session unit. REFUSED: no recipe, and the system
#                   bus is the host's. COST: no `SystemdService=` activation.
#   x11_autolaunch  -Dx11_autolaunch=disabled (:650-668) `dbus-launch` starting
#                   a session bus from the X display. REFUSED (libX11 is
#                   available but the session bus is started by the login
#                   session or `dbus-run-session`, not from a screen).
#   launchd         darwin `enabled`, linux `disabled` (:481-495): the macOS
#                   session bus is launchd's; its agent plist is installed under
#                   the prefix (-Dlaunchd_agent_dir), never in ~/Library.
#   epoll / kqueue  linux `epoll=enabled`, `kqueue=disabled`; darwin the reverse
#   inotify         (:439-478). The platform's own event mechanism, named.
#                   inotify is linux only.
#   modular_tests   -Dmodular_tests=disabled (:379-405): needs GLib; test-only.
#   xml_docs, doxygen_docs, ducktype_docs, qt_help  disabled (:309-336): they
#                   find xsltproc, doxygen, ducktype, qhelpgenerator on the
#                   builder, and only produce documentation.
#   relocation      -Drelocation=disabled (:1027-1043): `auto` is already off
#                   outside Windows; named. A store prefix is final.
#   valgrind        disabled by default (:613); named.
#   Booleans keep their defaults and are not detections: message_bus (the
#   daemon is built, and the test starts one), tools, stats, checks,
#   traditional_activation, user_session, asserts, verbose_mode, intrusive_tests,
#   installed_tests all as meson_options.txt says.
#   expat           the one required library (:407-416), through pkg-config from
#                   the declared recipe; `--wrap-mode=nofallback` forbids the
#                   bundled subproject. GLib, GIO, libX11, libcap and the rest
#                   are not looked for with the options above, and the test
#                   greps the installed library and daemon for each name.
#   dbus_user       the default `messagebus` (meson.build:1009): the system bus's
#                   unprivileged user, which is the host's concern. The build
#                   needs no such user (measured: meson_post_install.py:94-124
#                   only skips the setuid launch helper with a message).
#
# ⚠ NOT CARRIED FROM THE PANTRY: its `-Ddbus_user=$(whoami)` (the build is fine
# without) and its darwin Homebrew patch of the launchd agent plist (a path
# fix for Homebrew's layout; this recipe's agent directory is the prefix).
#
# ⚠ BUILD TOOL: `mesonbuild.com` is not a recipe of this tree (it comes from the
# pantry). Meson is the only build system 1.16 has (the autotools build was
# removed).

summary = "D-Bus: libdbus, the dbus-daemon message bus and its tools, with the system bus at the host's address"

# COPYING:1-3 "your choice of the Academic Free License version 2.1, or the GNU
# General Public License version 2 (or, at your option any later version)";
# :11-12 "some source files" are more permissive BSD/MIT; :17-18 "some of the
# standalone binaries are under the GPL only", tools/dbus-cleanup-sockets.c among
# them.
license = "(AFL-2.1 OR GPL-2.0-or-later) AND GPL-2.0-only AND MIT"

platforms = ["linux", "darwin"]

versions {
  url   = "https://dbus.freedesktop.org/releases/dbus/"
  match = "/dbus-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^dbus-/",
    "/\\.tar\\.xz/",
  ]

  # Odd minor numbers (1.15.x) are the development series (the NEWS of every
  # one says so); stable releases have an even minor. A version absent from
  # `sha256` is refused anyway.
  ignore = ["/^\\d+\\.\\d*[13579]\\./"]
}

dependencies = {
  # meson.build:407-416, required when the message bus is built.
  "libexpat.github.io" = "^2"
}

distributable {
  url              = "https://dbus.freedesktop.org/releases/dbus/dbus-{{version.raw}}.tar.xz"
  strip-components = 1

  # 1124660 bytes. Recorded with `zpkb sourcepin --sig auto --key … --fingerprint …`
  # (zpkb v0.90.0, no keyserver asked) and confirmed by a second, independent
  # fetch-and-hash (`curl` + `shasum -a 256`). The signature chain is in
  # provenance.note.
  sha256 = {
    "1.16.4" = "d08b05526c2cb7966a5fb79210d6112b1aca3d135f315c1b302e14b4b0297dac"
  }
}

build {
  dependencies = {
    "mesonbuild.com"             = "*"
    "ninja-build.org"            = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--buildtype=release",
      "--wrap-mode=nofallback",

      # The host's system bus (see the header).
      "-Dsystem_socket=/var/run/dbus/system_bus_socket",
      "-Dsystem_pid_file=/var/run/dbus/pid",

      # Named or refused on both platforms (see the header).
      "-Dapparmor=disabled",
      "-Dselinux=disabled",
      "-Dlibaudit=disabled",
      "-Dsystemd=disabled",
      "-Dx11_autolaunch=disabled",
      "-Dmodular_tests=disabled",
      "-Dxml_docs=disabled",
      "-Ddoxygen_docs=disabled",
      "-Dducktype_docs=disabled",
      "-Dqt_help=disabled",
      "-Drelocation=disabled",
      "-Dvalgrind=disabled",
    ]

    # Only the declared expat is visible to pkg-config, which is how meson
    # finds it; the rpath lets the installed daemon and library find it and
    # each other (a meson install carries no run path of its own: measured, the
    # daemon stopped at "libdbus-1.so.3: cannot open shared object file").
    PKG_CONFIG_PATH = "{{deps.libexpat.github.io.prefix}}/lib/pkgconfig"

    linux = {
      ARGS = [
        "-Depoll=enabled",
        "-Dinotify=enabled",
        "-Dkqueue=disabled",
        "-Dlaunchd=disabled",
      ]
      LDFLAGS = "-Wl,-rpath,{{prefix}}/lib -Wl,-rpath,{{deps.libexpat.github.io.prefix}}/lib"
    }

    darwin = {
      ARGS = [
        "-Depoll=disabled",
        "-Dinotify=disabled",
        "-Dkqueue=enabled",
        "-Dlaunchd=enabled",
        "-Dlaunchd_agent_dir={{prefix}}/share/dbus-1/launchd",
      ]
    }
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build",
    "meson install -C build",
  ]
}

# `meson install` of 1.16.4, read off the install (bin/ only; the launch
# helper is in libexec/).
provides = [
  "bin/dbus-cleanup-sockets",
  "bin/dbus-daemon",
  "bin/dbus-launch",
  "bin/dbus-monitor",
  "bin/dbus-run-session",
  "bin/dbus-send",
  "bin/dbus-test-tool",
  "bin/dbus-update-activation-environment",
  "bin/dbus-uuidgen",
]

test {
  fixture = <<EOT
#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef WANT_SYSTEM_ADDRESS
#error WANT_SYSTEM_ADDRESS is the system bus path of the host
#endif

int main(void)
{
	DBusError err;
	DBusConnection *c;
	int major, minor, micro, bad = 0;
	const char *sys;

	dbus_get_version(&major, &minor, &micro);
	if (major != 1 || minor != 16) {
		fprintf(stderr, "libdbus is %d.%d.%d\n", major, minor, micro);
		bad = 1;
	}

	/* The session bus the caller started: own a name and ask the bus who owns it. */
	dbus_error_init(&err);
	c = dbus_bus_get(DBUS_BUS_SESSION, &err);
	if (!c) {
		fprintf(stderr, "no session bus: %s\n", err.message);
		return 1;
	}
	if (dbus_bus_request_name(c, "org.zpkg.Probe", 0, &err) != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) {
		fprintf(stderr, "could not own org.zpkg.Probe: %s\n", dbus_error_is_set(&err) ? err.message : "refused");
		bad = 1;
	}
	if (!dbus_bus_name_has_owner(c, "org.zpkg.Probe", &err)) {
		fprintf(stderr, "the bus does not know org.zpkg.Probe\n");
		bad = 1;
	}

	/* A method call that goes to the daemon and back: ListNames. */
	{
		DBusMessage *m = dbus_message_new_method_call("org.freedesktop.DBus", "/org/freedesktop/DBus",
		    "org.freedesktop.DBus", "ListNames");
		DBusMessage *r = dbus_connection_send_with_reply_and_block(c, m, 5000, &err);
		DBusMessageIter it, arr;
		int found = 0;

		dbus_message_unref(m);
		if (!r) {
			fprintf(stderr, "ListNames failed: %s\n", err.message);
			return 1;
		}
		dbus_message_iter_init(r, &it);
		dbus_message_iter_recurse(&it, &arr);
		while (dbus_message_iter_get_arg_type(&arr) == DBUS_TYPE_STRING) {
			const char *s;
			dbus_message_iter_get_basic(&arr, &s);
			if (strcmp(s, "org.zpkg.Probe") == 0)
				found = 1;
			dbus_message_iter_next(&arr);
		}
		if (!found) {
			fprintf(stderr, "ListNames does not list org.zpkg.Probe\n");
			bad = 1;
		}
		dbus_message_unref(r);
	}

	/* The system bus the library was built to look for: the host's. With no
	 * DBUS_SYSTEM_BUS_ADDRESS, the refusal (or the connection) names that path. */
	unsetenv("DBUS_SYSTEM_BUS_ADDRESS");
	dbus_error_free(&err);
	dbus_error_init(&err);
	sys = NULL;
	if (dbus_bus_get_private(DBUS_BUS_SYSTEM, &err) == NULL) {
		sys = err.message;
		if (!sys || !strstr(sys, WANT_SYSTEM_ADDRESS)) {
			fprintf(stderr, "the system bus error does not name %s: %s\n", WANT_SYSTEM_ADDRESS, sys ? sys : "(none)");
			bad = 1;
		}
	}
	return bad;
}
EOT

  script = [
    "test -x \"{{prefix}}/bin/dbus-daemon\"",
    "test -f \"{{prefix}}/include/dbus-1.0/dbus/dbus.h\"",
    "test \"$(\"{{prefix}}/bin/dbus-daemon\" --version | head -1 | cut -d' ' -f5)\" = \"{{version.raw}}\"",
    "grep -q 'Version: {{version.raw}}' \"{{prefix}}/lib/pkgconfig/dbus-1.pc\"",

    # ⛔⛔ EVERY NAMED OR REFUSED CHOICE, READ OFF THE INSTALLED FILES.
    {
      run = <<EOT
set -eu
root="{{prefix}}"
case "$(uname -s)" in Darwin) sfx=dylib ;; *) sfx=so ;; esac
lib="$root/lib/libdbus-1.$sfx"
test -f "$lib"
grep -aq -e '/var/run/dbus/system_bus_socket' "$lib" || { echo "libdbus does not carry the host's system bus socket" >&2; exit 1; }
for f in "$lib" "$root/bin/dbus-daemon" "$root/bin/dbus-launch" "$root/bin/dbus-send"; do
  for r in libsystemd libselinux libaudit libapparmor libX11 libglib libgio libcap; do
    ! grep -aq -e "$r" "$f" || { echo "$f names $r, which this recipe refuses" >&2; exit 1; }
  done
done
grep -aq -e 'libexpat' "$root/bin/dbus-daemon" || { echo "dbus-daemon does not link libexpat" >&2; exit 1; }
EOT
    },

    # ⭐ A REAL BUS AND A CLIENT OF THE INSTALLED LIBRARY. A socket path is
    # limited to about 100 bytes (sun_path) and a scratch directory can be
    # longer, so the daemon makes its own name under /tmp and prints it. (The
    # default session configuration on darwin listens on launchd, hence
    # --address.)
    {
      run = <<EOT
set -eu
root="{{prefix}}"
d="$PWD/bus"
rm -rf "$d"
mkdir "$d"
cc -x c $FIXTURE -x none -o probe -DWANT_SYSTEM_ADDRESS='"/var/run/dbus/system_bus_socket"' -I"$root/include/dbus-1.0" -I"$root/lib/dbus-1.0/include" -L"$root/lib" -ldbus-1 -Wl,-rpath,"$root/lib"
"$root/bin/dbus-daemon" --session --address=unix:tmpdir=/tmp --fork --print-address=3 --print-pid=4 3> "$d/addr" 4> "$d/pid"
trap 'kill "$(cat "$d/pid")" 2>/dev/null || true' EXIT
DBUS_SESSION_BUS_ADDRESS="$(cat "$d/addr")" LD_LIBRARY_PATH="$root/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$root/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
EOT
    },
  ]
}

provenance {
  read = [
    "meson_options.txt",     # every option, its type and default
    "meson.build",           # :309-336 documentation tools; :377-405 message bus, modular tests; :407-416 expat; :427-435 selinux, apparmor; :439-495 inotify, epoll, kqueue, launchd; :499 systemd; :563-571 audit; :613 valgrind; :650-668 x11; :919-1022 runstatedir, system socket, pid file, dbus_user; :1027-1043 relocation; :1087-1109 session bus address",
    "meson_post_install.py", # :87-124 the launch helper's setuid, skipped with a message when dbus_user does not exist
    "bus/meson.build",       # :173-214 launch helper, systemd user session
    "NEWS",
    "COPYING",
    "https://dbus.freedesktop.org/releases/dbus/",
  ]

  consulted = [
    # Facts only: the release-listing URL and match, the tool names, the launchd
    # agent directory option. The pantry named no system socket, no feature
    # option, no rpath and no signature.
    "pkgxdev/pantry projects/freedesktop.org/dbus/package.yml",
  ]

  note = <<EOT
SIGNATURE CHAIN. The release has a detached signature
(https://dbus.freedesktop.org/releases/dbus/dbus-1.16.4.tar.xz.asc, OpenPGP
RSA-4096), made 2026-11-12 by the signing subkey 7A073AD1AE694FA25BFF62E5235C099D3EB33076
of the primary key DA98F25C0871C49A59EAFF2C4DE8FF2A63C7CC90, Simon McVittie
<smcv@pseudorandom.co.uk>. `zpkb sourcepin` verified the tarball against that
key file at the signing instant. WHERE THE FINGERPRINT CAME FROM, with no
keyserver as anchor: the release is Simon McVittie's (gitlab.freedesktop.org
dbus/dbus, tag dbus-1.16.4, whose release commit "Prepare v1.16.4" he authored),
and https://gitlab.freedesktop.org/smcv.gpg, the key published on his account
there, names DA98F25C0871C49A59EAFF2C4DE8FF2A63C7CC90 as the designated revoker
of its own key. The key file used came from keyserver.ubuntu.com and is trusted
only because its primary fingerprint is that one.

⚠ THE RUNG IS WEAKER THAN A PUBLISHED FINGERPRINT, STATED. The dbus site and the
tarball print no fingerprint, and the designated-revoker link ties two of one
person's keys together; it does not prove the second is the project's. The
account is the release manager's own.

SECOND INDEPENDENT FETCH: `curl --fail` and `shasum -a 256` gave
d08b05526c2cb7966a5fb79210d6112b1aca3d135f315c1b302e14b4b0297dac.

⛔ BUILT HERE, NOT BY THE FACTORY. darwin/arm64: meson 1.x from a scratch venv,
the SDK's expat standing in for the declared one, the darwin option set above,
installed, and the test block run (a session bus, a client of the installed
libdbus, ListNames, the system-bus address). linux/aarch64 (debian:trixie): the
linux option set, installed, and the test block run. NOT RUN: the factory, the
declared expat (the hosts' own was used, which is why the test only asserts that
the daemon names libexpat), x86-64.
EOT
}
