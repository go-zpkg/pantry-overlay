# savannah.nongnu.org/acl — acl: POSIX access-control-list tools (getfacl,
# setfacl, chacl) and libacl.
#
# ⛔ WRITTEN FROM THE TARBALL'S OWN FILES (go-zpkg/packages#440), as a
# dependency of borgbackup.org, whose fragment named it without a recipe.

summary = "acl: POSIX access control lists — libacl, getfacl and setfacl"

# Per file: libacl/acl_get_fd.c:7-10 is the GNU Lesser General Public License
# "version 2.1 of the License, or (at your option) any later version", and
# tools/getfacl.c:9-12 the GNU General Public License "version 2 of the
# License, or (at your option) any later version". The tarball carries
# doc/COPYING and doc/COPYING.LGPL.
license = "LGPL-2.1-or-later AND GPL-2.0-or-later"

# Linux only, as attr is: the ACLs live in the system.posix_acl_* extended
# attributes.
platforms = ["linux"]

versions {
  url   = "https://download.savannah.nongnu.org/releases/acl/"
  match = "/href=\"acl-(\\d+\\.\\d+\\.\\d+)\\.tar\\.gz\"/"
  strip = [
    "/href=\"acl-/",
    "/\\.tar\\.gz\"/",
  ]
}

distributable {
  url              = "https://download.savannah.nongnu.org/releases/acl/acl-{{version.raw}}.tar.gz"
  strip-components = 1

  # 565843 bytes, recorded with `zpkb sourcepin --version 2.4.0`.
  sha256 = {
    "2.4.0" = "73c853c3d44e1f693e5a96a986f1bd19d3d0dac2c7d453e796177774bc4e5f6a"
  }
}

build {
  dependencies = {
    "gnu.org/make"                = "*"
    "savannah.nongnu.org/attr"    = "*"
  }

  script = [
    # configure.ac:86 AC_PACKAGE_NEED_ATTR_ERROR_H looks for
    # attr/error_context.h and exits if it is absent
    # (m4/package_attrdev.m4:16-23); the header is only a compile-time need
    # (libacl/perm_copy_file.c:28, perm_copy_fd.c:30), nothing links libattr.
    "./configure --prefix={{prefix}} CPPFLAGS=-I{{deps.savannah.nongnu.org/attr.prefix}}/include",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "bin/getfacl",
  "bin/setfacl",
  "bin/chacl",
]

test {
  script = [
    "test -f \"{{prefix}}/include/sys/acl.h\"",
    {
      run = <<EOT
ls "{{prefix}}"/lib/libacl.* >/dev/null
EOT
    },
    {
      run = <<EOT
"{{prefix}}/bin/getfacl" --version > version.txt
grep "{{version.raw}}" version.txt >/dev/null || { echo "getfacl --version did not report {{version.raw}}" >&2; cat version.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",              # :18 version; :22 default prefix /usr; :71 external gettext; :86 attr/error_context.h required
    "m4/package_attrdev.m4",     # :15-24 the header check and its message
    "libacl/perm_copy_file.c",   # :28 includes attr/error_context.h
    "libacl/acl_get_fd.c",       # :7-10 LGPL-2.1-or-later
    "tools/getfacl.c",           # :9-12 GPL-2.0-or-later
    "doc/COPYING",               # present
    "doc/COPYING.LGPL",          # present
  ]

  consulted = [
    "download.savannah.nongnu.org/releases/acl/", # the release listing the versions block reads
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED, AND THE SIGNATURE WAS NOT CHECKED. The listing publishes
acl-2.4.0.tar.gz.sig, but no fingerprint was looked for outside that listing,
and no keyserver is asked, so there is no anchor to verify it against. The
digest is the one `zpkb sourcepin` fetched; no second witness was read.

Not verified: that `--version` of getfacl prints the bare version number, and
that CPPFLAGS given to configure is enough for the header check (the check
compiles with it, but nothing was run).
EOT
}
