# savannah.nongnu.org/attr — attr: extended-attribute tools (getfattr, setfattr)
# and libattr, whose error_context.h libacl's build requires.
#
# ⛔ WRITTEN FROM THE TARBALL'S OWN FILES (go-zpkg/packages#440), replacing a
# fragment that was never a recipe: nothing in the tree named this project, and
# savannah.nongnu.org/acl (which borgbackup.org names) needs its header.

summary = "attr: extended attributes — libattr, getfattr and setfattr"

# Per file: libattr/libattr.c:5-8 is the GNU Lesser General Public License
# "either version 2.1 of the License, or (at your option) any later version",
# and tools/getfattr.c:8-11 is the GNU General Public License "either version 2
# of the License, or (at your option) any later version". The tarball carries
# doc/COPYING and doc/COPYING.LGPL.
license = "LGPL-2.1-or-later AND GPL-2.0-or-later"

# Linux only: the extended-attribute system calls are Linux's, and configure.ac
# :85-87 tests for `linux*` (OS_LINUX).
platforms = ["linux"]

# The release directory is the source of versions. The match is anchored on
# href=" and on the closing quote so that `.tar.gz.sig` and the `.src.tar.gz`
# of the 2.4.x era are not read as releases.
versions {
  url   = "https://download.savannah.nongnu.org/releases/attr/"
  match = "/href=\"attr-(\\d+\\.\\d+\\.\\d+)\\.tar\\.gz\"/"
  strip = [
    "/href=\"attr-/",
    "/\\.tar\\.gz\"/",
  ]
}

distributable {
  url              = "https://download.savannah.nongnu.org/releases/attr/attr-{{version.raw}}.tar.gz"
  strip-components = 1

  # 506247 bytes, recorded with `zpkb sourcepin --version 2.6.0`.
  sha256 = {
    "2.6.0" = "d42fa374513180bb48cb11a46696f488240e5124ff1e6ad88b0abff706985612"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # configure.ac:22 defaults the prefix to /usr, so it is given.
    "./configure --prefix={{prefix}}",
    "make --jobs {{ hw.concurrency }}",

    # include/Makemodule.am:29 chains install-error_context_h into
    # install-data-local, so a plain install puts attr/error_context.h where
    # acl's configure (m4/package_attrdev.m4:16) looks for it.
    "make install",
  ]
}

provides = [
  "bin/getfattr",
  "bin/setfattr",
]

test {
  script = [
    "test -f \"{{prefix}}/include/attr/error_context.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libattr.* >/dev/null
EOT
    },
    {
      run = <<EOT
"{{prefix}}/bin/getfattr" --version > version.txt
grep "{{version.raw}}" version.txt >/dev/null || { echo "getfattr --version did not report {{version.raw}}" >&2; cat version.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",              # :18 version; :22 default prefix /usr; :69-70 external gettext; :85-87 OS_LINUX
    "include/Makemodule.am",     # :25-29 error_context.h is installed by install-data-local
    "libattr/libattr.c",         # :5-8 LGPL-2.1-or-later
    "tools/getfattr.c",          # :8-11 GPL-2.0-or-later
    "doc/COPYING",               # present
    "doc/COPYING.LGPL",          # present
  ]

  consulted = [
    "download.savannah.nongnu.org/releases/attr/", # the release listing the versions block reads
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED, AND THE SIGNATURE WAS NOT CHECKED. The listing publishes
attr-2.6.0.tar.gz.sig, but no fingerprint was looked for outside that listing,
and no keyserver is asked, so there is no anchor to verify it against. The
digest is the one `zpkb sourcepin` fetched; no second witness was read.

configure.ac:69-70 asks for an EXTERNAL gettext (`AM_GNU_GETTEXT([external])`),
so the C library supplies it on Linux; this recipe lists no gettext
dependency, and that has not been tried.

`zpkb versions` against the live listing resolved 2.6.0, 2.5.2, 2.5.1, newest
first, so the anchored match does skip the `.sig` and `.src` entries; the digest
pins only 2.6.0.
EOT
}
