# net-snmp — SNMP agent (snmpd), trap daemon (snmptrapd), the command line
# tools (snmpget, snmpwalk, …) and libnetsnmp.
#
# ⛔ WRITTEN FROM NET-SNMP'S OWN FILES at 5.9.5.2 (go-zpkg/packages#440,
# go-zpkg/packages#431). It was a three-line fragment declaring openssl ^3.

summary = "SNMP agent, trap daemon, command line tools and libnetsnmp"

# ⛔ NOT ONE LICENCE. COPYING has FOURTEEN parts (`---- Part N:` at :4, :33,
# :65, :97, :136, :167, :200, :232, :263, :296, :320, :353, :386, :417): Part 1
# is the CMU/UCD notice (a permission-to-use-without-fee text, SPDX HPND), and
# parts 2-9 and 11-14 are labelled BSD by the file itself. Part 10 (Lennart
# Poettering) is labelled "BSD-like". Recorded as the two families the file
# names, not as one SPDX id that would under-report it.
license = "HPND AND BSD-3-Clause"

versions {
  github = "net-snmp/net-snmp"
  strip  = "/^v/"
  ignore = ["/rc|pre|alpha|beta/"]
}

dependencies = {
  # configure.d/config_project_with_enable:75-99 `tryopenssl=yes`; the
  # `--with-openssl` switch below makes it a hard requirement.
  "openssl.org" = "^3"
}

distributable {
  # SourceForge's download redirector, the place the project publishes the
  # releases (https://www.net-snmp.org/download.html). A GitHub tag archive is
  # a generated tarball, not the release.
  url              = "https://downloads.sourceforge.net/project/net-snmp/net-snmp/{{version.raw}}/net-snmp-{{version.raw}}.tar.gz"
  strip-components = 1

  # 6826866 bytes, recorded with `zpkb sourcepin --version 5.9.5.2 --sig auto`.
  #
  #   signed by  6E6718AEF1EB5C65C32D1B2A356BC0B552D53CAB
  #              Net-SNMP Administrators <net-snmp-admins@lists.sourceforge.net>
  #   signed at  2025-12-23
  #   key        https://www.net-snmp.org/net-snmp-admin.asc, the file the
  #              project's download page links as "GPG Key for signed files"
  #   no keyserver was asked.
  #
  # The fingerprint is not taken from the signature alone: the tarball's own
  # dist/makerelease.xml names it in the release recipe (`gpg -u 6E6718AE…
  # --detach-sign net-snmp-{VERSION}.tar.gz`, lines 548-553; `git tag -u`,
  # :510). That is the project's statement about its own key, carried inside
  # the signed archive — continuity, not an independent host.
  #
  # Signature URL: …/5.9.5.2/net-snmp-5.9.5.2.tar.gz.asc (SourceForge).
  sha256 = {
    "5.9.5.2" = "16707719f833184a4b72835dac359ae188123b06b5e42817c00790d7dc1384bf"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ WITHOUT THIS configure PROMPTS on stdin (config_project_with_enable:
      # 326-335, "Use defaults for prompted values", default `no`).
      "--with-defaults",

      # configure.d/config_project_with_enable:78-100: OpenSSL is on by default
      # and `yes` makes a missing one an error rather than a silent downgrade.
      "--with-openssl",

      # Every other optional input named off, none left to detection:
      #   :142-160 krb5 is `defaultyes`, searching /usr/kerberos
      "--without-krb5",
      #   :169-172 and :175-178 rpm and pcre (pcre is "maybe")
      "--without-rpm",
      "--without-pcre",
      #   :1177 libnl, :1174 elf
      "--without-nl",
      "--without-elf",
      #   :1180-1193 libwrap, zlib, bzip2 default to no; named anyway
      "--without-libwrap",
      "--without-zlib",
      "--without-bzip2",
      #   :1205 mysql (trap logging)
      "--without-mysql",
      #   :1074-1095 Perl modules and embedded Perl are "try"; :1107-1123 the
      #   Python bindings are off
      "--without-perl-modules",
      "--disable-embedded-perl",
      "--without-python-modules",

      # The two paths prompted for under --with-defaults would otherwise
      # default to /var (config_project_with_enable:489, :467): under the
      # prefix instead, because a package must not write outside it.
      "--with-persistent-directory={{prefix}}/var/net-snmp",
      "--with-logfile={{prefix}}/var/log/snmpd.log",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{hw.concurrency}}
make install
EOT
}

# apps/Makefile.in:56-77 INSTALLBINPROGS (only the names that are not behind a
# conditional) and :196-198 snmpinform, a link to snmptrap; INSTALLSBINPROGS
# snmptrapd; agent/Makefile.in:21 and config_project_with_enable:215 snmpd;
# Makefile.in:36 INSTALLBINSCRIPTS. The Perl scripts (snmpconf, mib2c, …) are
# left out: their Perl is not declared here.
provides = [
  "bin/net-snmp-config",
  "bin/net-snmp-create-v3-user",
  "bin/snmpbulkget",
  "bin/snmpbulkwalk",
  "bin/snmpdelta",
  "bin/snmpdf",
  "bin/snmpget",
  "bin/snmpgetnext",
  "bin/snmpinform",
  "bin/snmpps",
  "bin/snmpstatus",
  "bin/snmptable",
  "bin/snmptest",
  "bin/snmptranslate",
  "bin/snmptrap",
  "bin/snmpwalk",
  "sbin/snmpd",
  "sbin/snmptrapd",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "snmpget -V",
    "snmpd -v",
    "net-snmp-config --version",
    "test -f {{prefix}}/include/net-snmp/net-snmp-config.h",
    "test -f {{prefix}}/lib/pkgconfig/netsnmp.pc",
    "pkg-config --exists netsnmp",
    # snmpinform is a link to snmptrap (apps/Makefile.in:241-243).
    "test -x {{prefix}}/bin/snmpinform",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>

int main(void) {
  oid name[MAX_OID_LEN];
  size_t len = MAX_OID_LEN;
  init_snmp("recipe-test");
  if (!read_objid("1.3.6.1.2.1.1.1.0", name, &len) || len != 9) {
    puts("read_objid failed");
    return 1;
  }
  printf("libnetsnmp %s parsed an OID of %d arcs\n", netsnmp_get_version(), (int)len);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o oidcheck $(net-snmp-config --cflags) $(net-snmp-config --libs)"
    },
    "./oidcheck",
  ]
}

provenance {
  read = [
    "COPYING",                              # :4-417 the fourteen licence parts
    "configure.d/config_project_with_enable", # :75-100 openssl; :142-160 krb5; :175 pcre; :326 --with-defaults; :1074-1123 perl, python; :1174-1205 nl, elf, libwrap, zlib, bzip2, mysql
    "apps/Makefile.in",                     # :56-77 installed programs; :196-198, :241-243 snmpinform
    "agent/Makefile.in",                    # :21 INSTALLSBINPROGS = snmpd
    "Makefile.in",                          # :36 INSTALLBINSCRIPTS; :38 pkg-config files
    "dist/makerelease.xml",                 # :510, :548-553 the release signing key's fingerprint
  ]

  consulted = [
    "https://www.net-snmp.org/download.html (links the signing key)",
  ]

  note = <<EOT
NOT BUILT. Written from the project's files and linted; no build or test of
this recipe was run.

The source signature was verified with `zpkb sourcepin` against the key the
project publishes at net-snmp.org/net-snmp-admin.asc (ed25519, expires
2033-03-31), fingerprint 6E6718AEF1EB5C65C32D1B2A356BC0B552D53CAB; no keyserver.

SourceForge's /files/net-snmp/5.10/ directory also exists, but the project's
git tags for 5.10 are rc1 and pre1-3 only, so 5.9.5.2 is the newest release.

Embedded Perl, the Perl modules and the Python bindings are off because no
Perl or Python is declared; the Perl helper scripts (snmpconf, mib2c) are
therefore not listed in `provides`.
EOT
}
