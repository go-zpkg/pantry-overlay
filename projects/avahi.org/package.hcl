# avahi.org — Avahi, the mDNS/DNS-SD implementation: here its CLIENT side,
# libavahi-client and libavahi-common (and libavahi-core) with the `avahi-browse`,
# `avahi-resolve`, `avahi-publish` and `avahi-set-host-name` tools. A NEW recipe:
# neither this tree nor pkgxdev/pantry had one. go-zpkg/recipes#122:
# openprinting.github.io/cups links libavahi-client on linux, which is how libcups
# browses and resolves `.local` printers and how `ippfind` exists.
#
# ⛔ WRITTEN FROM AVAHI 0.8'S OWN FILES (go-zpkg/packages#431), read out of the
# published release tarball, and BUILT AND INSTALLED in a scratch directory on
# linux/aarch64 (a debian:trixie container, whose libdbus stood in for the
# declared one). The test block ran there. NOT built on darwin (platforms is
# linux: macOS has mDNSResponder, which the cups recipe names there) and NOT
# built by the factory.
#
# ⭐⭐ THE DECISION ABOUT avahi-daemon: IT IS NOT BUILT, AND THE CLIENT TALKS TO THE
# HOST'S. avahi-daemon is a system service: it runs as root and then as the user
# `avahi` (configure.ac:959-975 AVAHI_USER, AVAHI_GROUP), chroots itself
# (avahi-daemon/Makefile.am:97-105, ENABLE_CHROOT), owns UDP 5353 on every
# interface, listens on /run/avahi-daemon/socket (:1007-1008, hard-coded) and
# registers on the SYSTEM D-Bus as `org.freedesktop.Avahi`, which needs a policy
# file in the host's /etc/dbus-1/system.d and an init unit. A package prefix can
# create none of that, and a second daemon in the store would fight the host's
# for port 5353. libavahi-client (avahi-client/client.c:449,
# dbus_bus_get_private(DBUS_BUS_SYSTEM)) reaches whichever daemon the host runs,
# over the host's system bus; freedesktop.org/dbus pins that bus to
# /var/run/dbus/system_bus_socket for exactly this reason. The daemon is turned
# off by `--disable-libdaemon` (configure.ac:811-825; avahi-daemon/Makefile.am:23-24
# builds it only with libdaemon AND an XML library), which also drops
# avahi-dnsconfd. WHAT THAT COSTS, STATED: a host without avahi-daemon running
# gets `AVAHI_ERR_NO_DAEMON` from avahi_client_new (client.c:574-579) and libcups
# then simply finds no DNS-SD printers; nothing here starts one.
#
# ⛔⛔ EVERY AUTO-DETECTED SWITCH, NAMED OR REFUSED. In this configure.ac almost
# every optional part defaults to `yes` and is FATAL when the builder lacks it
# (PKG_CHECK_MODULES, AM_CHECK_PYMOD, AC_PATH_PROG mcs), so on a builder that has
# it the part is built and linked, and on one that has not the build stops: both
# are a result that depends on the builder. Each is therefore stated:
#
#   glib, gobject   `--disable-glib --disable-gobject` (:440-473) the GLib main
#                   loop glue and the GObject wrapper; REFUSED, no recipe wanted
#                   (libcups drives its own poll loop). GObject introspection
#                   (:478) is only reached through gobject.
#   libevent        `--disable-libevent` (:483-497) REFUSED.
#   Qt 3/4/5        `--disable-qt3 --disable-qt4 --disable-qt5` (:502-573)
#                   default OFF; named so they stay off.
#   GTK 2/3         `--disable-gtk --disable-gtk3` (:578-613): avahi-ui and the
#                   discover tool. REFUSED.
#   dbus            ON, the point of the recipe (:620-705): libavahi-client is
#                   built only with it (avahi-client/Makefile.am:23). Declared
#                   dependency, found through pkg-config.
#   dbus address    `--with-dbus-system-address=unix:path=/var/run/dbus/system_bus_socket`
#                   (:681-697): PASSED, because otherwise configure PROBES the
#                   builder's own file system for a socket among four candidate
#                   paths and bakes in whichever exists. NOTE: it is only the
#                   fallback of a libdbus without dbus_bus_get_private
#                   (client.c:453-473); the installed libdbus has it.
#   dbus system.d   `--with-dbus-sys` (:629,:674-677) only locates the daemon's
#                   policy file, not installed (no daemon); left at its default.
#   expat/bsdxml    `--with-xml=none` (:710-759): the daemon's configuration
#                   parser, not built.
#   gdbm, dbm       `--disable-gdbm --disable-dbm` (:767-806): `gdbm` defaults to
#                   yes and is fatal when absent; it holds the service-type
#                   database of avahi-utils/Makefile.am:33-42. REFUSED: the tools
#                   then show service types by their raw names.
#   libdaemon       `--disable-libdaemon`, see above.
#   python          `--disable-python --disable-pygobject --disable-python-dbus`
#                   (:830-883) the avahi-bookmarks / avahi-discover scripts.
#   mono            `--disable-mono --disable-monodoc` (:888-940) REFUSED.
#   autoipd         `--disable-autoipd` (:945-954) the IPv4LL daemon: a setuid
#                   system service as well.
#   distro          `--with-distro=none` (:256-288): otherwise read off
#                   /etc/debian_version, /etc/redhat-release and the like of the
#                   BUILDER; it only selects init scripts and D-Bus policy files
#                   that are not installed, and an unknown distro is a fatal error.
#   systemd         `--with-systemdsystemunitdir=no` (:1127-1134): the default is
#                   `pkg-config --variable=systemdsystemunitdir systemd` of the
#                   builder; no daemon, no unit.
#   chroot, inotify (:383-407) probe sys/capability.h, chroot() and
#                   sys/inotify.h: compile switches of avahi-daemon and
#                   avahi-core, which only change code paths of the daemon;
#                   left as the platform provides them.
#   stack protector `--enable-stack-protector` is the default and probes the
#                   compiler (:71-141); kept, it is a hardening flag.
#   manpages, nls   `--disable-manpages` (:1046-1080: otherwise xmltoman is
#                   looked for) and `--disable-nls` (gettext is not a dependency
#                   of the client).
#   static          `--disable-static`: libtool otherwise installs a .a beside
#                   each .so.
#   compat libs, tests, core docs  default off (:1033-1122): kept.
#   libdir          pinned to `{{prefix}}/lib`, so the layout does not depend on
#                   the builder.
#
# ⚠ KNOWN SECURITY FIXES AFTER 0.8, STATED. 0.8 (2020-02-18) is the last release;
# the project tagged v0.9-rc1 to rc5 (tags only: no release, no asset). Those
# tags carry fixes made after 0.8 that this recipe does NOT include; the
# fixes' content was not read here, so what they cover is unknown to this
# recipe. It pins the release, and moving to 0.9 is a one-line change once it
# is released. Tracked in go-zpkg/recipes#219.

summary = "Avahi: libavahi-client, libavahi-common and the browse, resolve and publish tools, talking to the host's avahi-daemon over D-Bus"

# LICENSE:2-3 is the GNU Lesser General Public License 2.1, and every .c file of
# avahi-common, avahi-client, avahi-core and avahi-utils carries the header
# "GNU Lesser General Public License ... either version 2.1 of the License, or
# (at your option) any later version" (checked: `grep -L` over the four
# directories finds none without it).
license = "LGPL-2.1-or-later"

platforms = ["linux"]

versions {
  github = "avahi/avahi"

  # v0.9-rc1 .. rc5 and 0.6.32-rc are release candidates; a version absent from
  # `sha256` is refused anyway.
  ignore = ["/-rc\\d*$/"]
}

dependencies = {
  # configure.ac:636 `dbus-1 >= 0.34`; the library avahi-client links.
  "freedesktop.org/dbus" = "^1.16"
}

distributable {
  url              = "https://github.com/avahi/avahi/releases/download/v{{version.raw}}/avahi-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1591458 bytes. The project publishes NO signature: the release has the one
  # asset, the tag is lightweight and its commit unsigned. Recorded by a first
  # fetch and a second, independent fetch-and-hash (`curl --fail` from the
  # github.com/avahi and the older github.com/lathiat URL, and `shasum -a 256`),
  # which gave the same digest. See provenance.note.
  sha256 = {
    "0.8" = "060309d7a333d38d951bc27598c677af1796934dbd98e1024e7ad8de798fedda"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--sysconfdir=/etc",
      "--localstatedir=/var",
      "--disable-static",
      "--disable-nls",
      "--disable-manpages",
      "--with-distro=none",
      "--with-systemdsystemunitdir=no",
      "--with-dbus-system-address=unix:path=/var/run/dbus/system_bus_socket",
      "--with-xml=none",
      "--disable-libdaemon",
      "--disable-autoipd",
      "--disable-glib",
      "--disable-gobject",
      "--disable-libevent",
      "--disable-qt3",
      "--disable-qt4",
      "--disable-qt5",
      "--disable-gtk",
      "--disable-gtk3",
      "--disable-python",
      "--disable-pygobject",
      "--disable-python-dbus",
      "--disable-mono",
      "--disable-monodoc",
      "--disable-gdbm",
      "--disable-dbm",
    ]

    # Only the declared D-Bus is visible to pkg-config (see the header: every
    # other probe, glib and systemd included, then answers no on any builder).
    PKG_CONFIG_LIBDIR = "{{deps.freedesktop.org/dbus.prefix}}/lib/pkgconfig"

    # The rpath lets libavahi-client find libdbus-1 and libavahi-common.
    LDFLAGS = "-Wl,-rpath,{{prefix}}/lib -Wl,-rpath,{{deps.freedesktop.org/dbus.prefix}}/lib"
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# `make install` of 0.8 with the switches above, read off the install.
provides = [
  "bin/avahi-browse",
  "bin/avahi-publish",
  "bin/avahi-resolve",
  "bin/avahi-set-host-name",
]

test {
  fixture = <<EOT
#include <avahi-client/client.h>
#include <avahi-common/error.h>
#include <avahi-common/simple-watch.h>
#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define NAME "org.freedesktop.Avahi"
#define IFACE "org.freedesktop.Avahi.Server"

/* The part of avahi-daemon the client asks about when it connects
 * (avahi-client/client.c:315-390,:737,:765): API version, state, version
 * string and host name. libdbus answers the Peer.Ping itself. */
static DBusHandlerResult fake(DBusConnection *c, DBusMessage *m, void *u)
{
	DBusMessage *r;
	dbus_uint32_t api = 0x0204;
	dbus_int32_t state = 2; /* AVAHI_SERVER_RUNNING */
	const char *s;

	(void)u;
	if (!dbus_message_has_interface(m, IFACE))
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
	if (!(r = dbus_message_new_method_return(m)))
		return DBUS_HANDLER_RESULT_NEED_MEMORY;
	if (dbus_message_has_member(m, "GetAPIVersion"))
		dbus_message_append_args(r, DBUS_TYPE_UINT32, &api, DBUS_TYPE_INVALID);
	else if (dbus_message_has_member(m, "GetState"))
		dbus_message_append_args(r, DBUS_TYPE_INT32, &state, DBUS_TYPE_INVALID);
	else if (dbus_message_has_member(m, "GetVersionString")) {
		s = "avahi 0.8 (zpkg probe)";
		dbus_message_append_args(r, DBUS_TYPE_STRING, &s, DBUS_TYPE_INVALID);
	} else if (dbus_message_has_member(m, "GetHostName")) {
		s = "zpkgprobe";
		dbus_message_append_args(r, DBUS_TYPE_STRING, &s, DBUS_TYPE_INVALID);
	} else {
		dbus_message_unref(r);
		return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
	}
	dbus_connection_send(c, r, NULL);
	dbus_connection_flush(c);
	dbus_message_unref(r);
	return DBUS_HANDLER_RESULT_HANDLED;
}

static void server(int ready)
{
	DBusError err;
	DBusConnection *c;

	dbus_error_init(&err);
	if (!(c = dbus_bus_get_private(DBUS_BUS_SESSION, &err)) ||
	    dbus_bus_request_name(c, NAME, 0, &err) != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) {
		fprintf(stderr, "fake daemon: %s\n", dbus_error_is_set(&err) ? err.message : "no name");
		_exit(2);
	}
	dbus_connection_add_filter(c, fake, NULL, NULL);
	if (write(ready, "x", 1) != 1)
		_exit(2);
	while (dbus_connection_read_write_dispatch(c, -1))
		;
	_exit(0);
}

static void cb(AvahiClient *c, AvahiClientState s, void *u) { (void)c; (void)s; (void)u; }

int main(void)
{
	AvahiSimplePoll *poll = avahi_simple_poll_new();
	AvahiClient *cl;
	int err = 0, bad = 0, fd[2], st;
	const char *addr = getenv("DBUS_SESSION_BUS_ADDRESS");
	pid_t pid;
	char b;

	if (!addr || !poll) {
		fprintf(stderr, "no session bus or no poll\n");
		return 1;
	}
	/* libavahi-client opens the SYSTEM bus; point it at the caller's bus. */
	setenv("DBUS_SYSTEM_BUS_ADDRESS", addr, 1);

	/* 1. A bus on which nobody owns org.freedesktop.Avahi: the client must
	 * report that there is no daemon (client.c:574-579). */
	cl = avahi_client_new(avahi_simple_poll_get(poll), 0, cb, NULL, &err);
	if (cl || err != AVAHI_ERR_NO_DAEMON) {
		fprintf(stderr, "expected AVAHI_ERR_NO_DAEMON, got %p / %s\n", (void *)cl, avahi_strerror(err));
		bad = 1;
	}

	/* 2. A stand-in daemon on the same bus: the client connects and reads
	 * the state, the version string and the host name over D-Bus. */
	if (pipe(fd) < 0 || (pid = fork()) < 0)
		return 1;
	if (pid == 0) {
		close(fd[0]);
		server(fd[1]);
	}
	close(fd[1]);
	if (read(fd[0], &b, 1) != 1) {
		fprintf(stderr, "the stand-in daemon did not start\n");
		return 1;
	}
	err = 0;
	cl = avahi_client_new(avahi_simple_poll_get(poll), 0, cb, NULL, &err);
	if (!cl) {
		fprintf(stderr, "avahi_client_new: %s\n", avahi_strerror(err));
		bad = 1;
	} else {
		if (avahi_client_get_state(cl) != AVAHI_CLIENT_S_RUNNING) {
			fprintf(stderr, "state is %d\n", (int)avahi_client_get_state(cl));
			bad = 1;
		}
		if (strcmp(avahi_client_get_version_string(cl) ? avahi_client_get_version_string(cl) : "", "avahi 0.8 (zpkg probe)") != 0) {
			fprintf(stderr, "version string is %s\n", avahi_client_get_version_string(cl) ? avahi_client_get_version_string(cl) : "(null)");
			bad = 1;
		}
		if (strcmp(avahi_client_get_host_name(cl) ? avahi_client_get_host_name(cl) : "", "zpkgprobe") != 0) {
			fprintf(stderr, "host name is %s\n", avahi_client_get_host_name(cl) ? avahi_client_get_host_name(cl) : "(null)");
			bad = 1;
		}
		avahi_client_free(cl);
	}
	kill(pid, 15);
	waitpid(pid, &st, 0);
	return bad;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/avahi-client/client.h\"",
    "test -f \"{{prefix}}/include/avahi-common/simple-watch.h\"",
    "for t in avahi-browse avahi-publish avahi-resolve avahi-set-host-name; do test -x \"{{prefix}}/bin/$t\"; done",
    "! test -e \"{{prefix}}/sbin/avahi-daemon\"",
    "PKG_CONFIG_PATH=\"{{prefix}}/lib/pkgconfig\" pkg-config --exact-version={{version.raw}} avahi-client",
    "\"{{prefix}}/bin/avahi-browse\" --version > ver.txt && grep -q \"avahi-browse {{version.raw}}\" ver.txt",

    # ⛔⛔ EVERY NAMED OR REFUSED CHOICE, READ OFF THE INSTALLED LIBRARY. The
    # library's names are strings in its dynamic table.
    {
      run = <<EOT
set -eu
root="{{prefix}}"
lib="$root/lib/libavahi-client.so.3"
test -f "$lib"
for w in libdbus-1.so libavahi-common.so; do
  grep -aq -e "$w" "$lib" || { echo "libavahi-client does not name $w" >&2; exit 1; }
done
for f in "$lib" "$root/lib/libavahi-common.so.3" "$root/lib/libavahi-core.so.7" "$root/bin/avahi-browse"; do
  for r in libglib libgobject libevent libdaemon libgdbm libexpat libsystemd libQt libgtk libpython libmono; do
    ! grep -aq -e "$r" "$f" || { echo "$f names $r, which this recipe refuses" >&2; exit 1; }
  done
done
# the static archives are not installed
for a in "$root"/lib/*.a; do
  ! test -e "$a" || { echo "static archive installed: $a" >&2; exit 1; }
done
EOT
    },

    # ⭐ A REAL BUS AND A CLIENT OF THE INSTALLED LIBRARY (the fixture's two
    # steps: no daemon on the bus, then a stand-in daemon). The bus is the
    # declared D-Bus's own `dbus-daemon`; a socket path is limited to about 100
    # bytes, so the daemon makes its own name under /tmp.
    {
      run = <<EOT
set -eu
root="{{prefix}}"
dbus="{{deps.freedesktop.org/dbus.prefix}}"
d="$PWD/bus"
rm -rf "$d"
mkdir "$d"
cc -x c $FIXTURE -x none -o probe -I"$root/include" -I"$dbus/include/dbus-1.0" -I"$dbus/lib/dbus-1.0/include" -L"$root/lib" -L"$dbus/lib" -lavahi-client -lavahi-common -ldbus-1 -Wl,-rpath,"$root/lib" -Wl,-rpath,"$dbus/lib"
"$dbus/bin/dbus-daemon" --session --address=unix:tmpdir=/tmp --fork --print-address=3 --print-pid=4 3> "$d/addr" 4> "$d/pid"
trap 'kill "$(cat "$d/pid")" 2>/dev/null || true' EXIT
DBUS_SESSION_BUS_ADDRESS="$(cat "$d/addr")" ./probe
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                        # :71-141 stack protector; :256-300 distro; :383-416 chroot, inotify, kqueue; :440-497 glib, gobject, libevent; :502-613 Qt, GTK; :620-705 D-Bus; :710-759 XML; :767-806 gdbm, dbm; :811-825 libdaemon; :830-883 python; :888-940 mono; :945-954 autoipd; :959-1010 users, groups, runtime dir; :1033-1134 docs, manpages, tests, compat libs, systemd",
    "Makefile.am",                         # :57-82 SUBDIRS; :132-240 which pkg-config files are installed
    "avahi-client/Makefile.am",            # :23-83 libavahi-client only with D-Bus
    "avahi-client/client.c",               # :41 API version; :305-441 GetState, GetAPIVersion, GetVersionString; :445-476 system bus; :478-623 avahi_client_new, AVAHI_ERR_NO_DAEMON
    "avahi-common/dbus.h",                 # :30-51 bus name, path, interface, API version 0x0204
    "avahi-daemon/Makefile.am",            # :23-24 daemon only with libdaemon and XML; :97-105 chroot
    "avahi-utils/Makefile.am",             # :25-66 the four tools, gdbm and dbm
    "LICENSE",
    "avahi-utils/avahi-browse.c",          # licence header
    "avahi-common/alternative.c",          # licence header
    "https://github.com/avahi/avahi/releases (asset list), refs/tags/v0.8, commits/f060abe (unsigned)",
  ]

  consulted = [
    # None: pkgxdev/pantry has no Avahi recipe (the code search and
    # projects/avahi.org both answered nothing, 2026-11-20).
  ]

  note = <<EOT
SIGNATURE CHAIN: THERE IS NONE, STATED. The v0.8 release carries one asset,
avahi-0.8.tar.gz, with no detached signature and no checksum file
(`gh api repos/avahi/avahi/releases/tags/v0.8`); the tag is lightweight, and the
commit it points to, f060abee2807c943821d88839c013ce15db17b58 (Trent Lloyd,
2020-02-18), is unsigned (`commit.verification.reason` "unsigned"). The digest
is therefore pinned by two independent fetches that agree: the asset from
github.com/avahi/avahi and from github.com/lathiat/avahi (the redirect of the
renamed repository), each hashed with `shasum -a 256`:
060309d7a333d38d951bc27598c677af1796934dbd98e1024e7ad8de798fedda. That detects
a corrupted or a re-uploaded asset after the fact; it does not authenticate the
release.

⛔ BUILT HERE ON LINUX/AARCH64 ONLY, NOT BY THE FACTORY. debian:trixie, libdbus
1.16 from Debian standing in for the declared D-Bus: configure printed the
"Building" table (libavahi-core, libavahi-client and avahi-utils yes;
avahi-daemon, avahi-dnsconfd, every binding and toolkit no), the build and
install completed, and the installed files were the four tools, the three
libraries (shared only) and their headers and pkg-config files. NOT RUN: the
factory, the declared D-Bus (freedesktop.org/dbus, merged in
go-zpkg/recipes#213), x86-64, a real avahi-daemon (the test's second step is a
stand-in that answers the four calls the client makes when it connects).
EOT
}
