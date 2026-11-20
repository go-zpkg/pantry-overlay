# kerberos.org — MIT Kerberos 5: libkrb5 and its GSSAPI (libgssapi_krb5), the
# client programs (kinit, klist, kvno, kadmin, ktutil…), the KDC and the admin
# server. It was a three-line fragment (`openssl.org ^3` and nothing else, the
# rest inherited from the pantry's recipe); this is the whole recipe.
# go-zpkg/recipes#122: libcups links its GSSAPI (Negotiate authentication to a
# remote CUPS server) and subversion, serf, php, libpq, freetds and cyrus-sasl
# name it.
#
# ⛔ WRITTEN FROM KRB5 1.22.3'S OWN FILES (go-zpkg/packages#431), read out of the
# published source tarball, and BUILT, INSTALLED AND RUN in a scratch directory
# on darwin/arm64 and on linux/aarch64 (a debian:trixie container, with the
# distribution's OpenSSL standing in for the declared one). NOT built by the
# factory.
#
# ⭐ THE TEST RUNS A REALM, NOT A VERSION STRING. A KDC is started on a loopback
# port from the installed binaries, a principal and a service key are created
# with kadmin.local, `kinit` gets a TGT over the network, and a program linked
# to the installed libgssapi_krb5 does a full mutual-authentication exchange
# between an initiator (the ticket cache) and an acceptor (the keytab), then
# wraps and unwraps a message. The KDC's own log line "preauth pkinit failed to
# initialize: No pkinit_identity supplied" is the proof that the PKINIT plugin
# was found and loaded.
#
# ⭐⭐ WHERE IT LOOKS FOR CONFIGURATION: THE HOST FIRST, BY DESIGN. include/
# osconf.hin:53 builds the profile path as "/etc/krb5.conf" followed by
# `@SYSCONFCONF`, and configure.ac:9-16 appends `:<sysconfdir>/krb5.conf` unless
# sysconfdir is /etc. So a krb5 installed under a prefix reads the host's
# /etc/krb5.conf FIRST and needs no sysconfdir override — unlike CUPS, whose
# defaults had to be pointed at the host. The KDC's and the keytab's compiled-in
# directories (osconf.hin:72 KDC_DIR is `@LOCALSTATEDIR/krb5kdc`, :137 MECH_CONF)
# stay under the prefix: a KDC is run by whoever wants one and writes where it
# is told to; the client libraries do not read them.
#
# ⛔⛔ EVERY AUTO-DETECTED SWITCH, NAMED OR REFUSED (`./configure --help`, the
# configure.ac and aclocal.m4 it is generated from, read):
#
#   OpenSSL  three independent uses, each named. TLS (`--with-tls-impl`, default
#            `auto`, configure.ac:292-331): the k5tls plugin that lets a client
#            reach a KDC through an HTTPS proxy (KKDCP); NAMED `openssl`, fatal
#            if absent (:308-309). PKINIT (`--enable-pkinit`, default `try`,
#            :1138-1164): smartcard and certificate login; NAMED `yes`. SPAKE
#            (`--with-spake-openssl`, default `auto`, :357-370): the NIST
#            groups of the SPAKE preauth; NAMED `yes`. OpenSSL is a declared
#            dependency and is found through CPPFLAGS and LDFLAGS (the probes
#            are AC_CHECK_LIB, not pkg-config).
#   crypto   `--with-crypto-impl=builtin` (:266-285), the default, named: k5crypto
#            carries its own AES, SHA and camellia code rather than calling
#            libcrypto, so the Kerberos protocol core does not depend on
#            OpenSSL's version.
#   AES-NI   `--disable-aesni` (:374-410): on x86 linux the assembly is built
#            when `yasm` is on the PATH (:396-399), which makes the artifact
#            depend on the builder. No yasm is declared, so it is REFUSED and the
#            C implementation is used. COST: slower AES on x86-64 (the Kerberos
#            data path is the GSS wrap/unwrap, not ticket issuing).
#   keyutils `--without-keyutils` (:333-352): auto, and with libkeyutils it
#            compiles in the `KEYRING:` credential cache. REFUSED: no keyutils
#            recipe exists here. COST: no KEYRING:/KCM-in-kernel ccache type on
#            linux; FILE:, DIR:, MEMORY: and KCM: work.
#   LDAP     `--with-ldap` is OFF unless given (aclocal.m4:1400-1413); named
#            `--without-ldap`. The LDAP KDB backend is a server-side database
#            module (kdb5_ldap_util, plugins/kdb/ldap) and needs libldap.
#   LMDB     `--without-lmdb` (:1322-1339): auto, the `klmdb` KDB module. REFUSED,
#            no recipe; the default DB2 module (plugins/kdb/db2) is built, and
#            the test creates a database with it.
#   libedit  `--without-libedit` (:1349-1383): auto through pkg-config, line
#            editing in `kadmin` and `ktutil` (lib/ss). REFUSED, no recipe.
#            COST: no history or editing in their interactive prompts.
#            `--with-readline` is off by default and a GPL dependency; named
#            `--without-readline`.
#   verto    `--without-system-verto` (:1385-1406): auto through pkg-config
#            `libverto`; the bundled copy (util/verto) is NAMED, which is what
#            the KDC and kadmind link. A host's libverto would otherwise change
#            the artifact.
#   NLS      `--disable-nls` (:124-146): auto on libintl and `msgfmt`. REFUSED,
#            as the pantry did: messages stay English. COST: no translated
#            messages; no gettext dependency in the closure.
#   com_err, ss, Berkeley DB  `--without-system-et`, `--without-system-ss`,
#            `--without-system-db` (aclocal.m4:1138-1285): the defaults, named
#            so a future change cannot flip them. Private copies are built.
#   krb5-config  `--with-krb5-config=no` (:1457-1471): the DEFAULT RUNS an
#            existing `krb5-config` from the PATH and takes the ccache, keytab
#            and client-keytab names from it, so a builder that had MIT
#            Kerberos installed would bake its defaults in. REFUSED; the
#            hard-coded defaults of :1472-1485 apply (`FILE:/tmp/krb5cc_%{uid}`,
#            `FILE:/etc/krb5.keytab`; macOS builds `API:`).
#   yacc     `YACC="bison -y"` (kdc/getdate.y needs one; the first of `bison -y`,
#            byacc, yacc on the PATH is the default): the declared bison is
#            named, and a build without one stops at getdate.c (measured).
#   perl     lib/*/Makefile's `perl -p` builds the object lists of the shared
#            libraries (measured, in the link line of libgssrpc): a build
#            dependency.
#   Python, cmocka, resolv_wrapper, groff  (:1173-1208, :1408): used by the test
#            suite and by `make catman` only; nothing installed depends on them.
#   RSA SecurID (:1312-1317, libaceclnt) and the audit plugin (:241-262, libaudit,
#            `--enable-audit-plugin` default none): proprietary or absent, no
#            recipe; nothing is built for them.
#   The remaining switches keep their defaults and are not detections:
#   --enable-dns-for-realm off (aclocal.m4:1047; named `--disable-dns-for-realm`),
#   --with-hesiod and --with-netlib off (:722, :700), --with-vague-errors off
#   (:230), --enable-athena off, --enable-asan and --enable-ossfuzz off,
#   --enable-delayed-initialization and --enable-thread-support on (aclocal.m4:
#   118, :166), --disable-rpath off (:840: run-path flags kept, so the binaries
#   find their libraries), --disable-kdc-lookaside-cache off (:412),
#   --with-size-optimizations off, DEFCCNAME/DEFKTNAME/DEFCKTNAME/PKCS11_MODNAME
#   unset.
#
# ⛔⛔ UPSTREAM BUG ON DARWIN, PATCHED: libgssrpc DOES NOT LINK. lib/rpc/Makefile.
# in:18 links `-lgssapi_krb5 -lkrb5 -lk5crypto` and not libkrb5support, while the
# library calls `k5_secure_getenv`, which libkrb5support exports ONLY when the
# system lacks `secure_getenv` (configure.ac:211-218; darwin lacks it, glibc has
# it). `ld -undefined error` stops the build (measured on 1.22.3). The pantry
# worked around it with a `sed` over the generated Makefile; the one-line fix is
# committed beside this recipe (props/gssrpc-link-krb5support.patch) and applied
# on both platforms before configure.

summary = "MIT Kerberos 5: libkrb5, GSSAPI, the client tools, the KDC and the admin server"

# NOTICE lists the many components under their own terms; the MIT licence is
# the one covering the Kerberos code itself and the top of the file.
license = "MIT"

platforms = ["linux", "darwin"]

versions {
  github = "krb5/krb5/tags"
  strip = [
    "/^krb5-/",
    "/-final$/",
  ]
}

dependencies = {
  # TLS plugin, PKINIT, SPAKE (see the header). 1.22.3 builds against 3.x:
  # the probes are `PKCS7_get_signer_info` and `EVP_PKEY_get_bn_param`
  # (configure.ac:1150-1151), both in 3.x.
  "openssl.org" = "^3"
}

distributable {
  url              = "https://kerberos.org/dist/krb5/{{version.marketing}}/krb5-{{version.raw}}.tar.gz"
  strip-components = 1

  # 8758584 bytes. Recorded with `zpkb sourcepin --sig auto --key … --fingerprint …`
  # (zpkb v0.90.0, no keyserver asked) and confirmed by a second, independent
  # fetch-and-hash (`curl` + `shasum -a 256`). The signature chain is in
  # provenance.note.
  sha256 = {
    "1.22.3" = "fe90af8441ad9fa9b064b8e53077cefb782a96f8a68276b031dc54af1789ff0b"
  }
}

build {
  dependencies = {
    "gnu.org/make"  = "*"
    "gnu.org/patch" = "*"
    "gnu.org/bison" = "^3"
    "perl.org"      = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--without-system-et",
      "--without-system-ss",
      "--without-system-db",
      "--without-system-verto",
      "--disable-nls",
      "--without-keyutils",
      "--disable-aesni",
      "--without-ldap",
      "--without-lmdb",
      "--without-libedit",
      "--without-readline",
      "--with-tls-impl=openssl",
      "--enable-pkinit",
      "--with-spake-openssl",
      "--with-crypto-impl=builtin",
      "--with-krb5-config=no",
      "--disable-dns-for-realm",
    ]

    CPPFLAGS = "-I{{deps.openssl.org.prefix}}/include"
    LDFLAGS  = "-L{{deps.openssl.org.prefix}}/lib"

    linux = {
      LDFLAGS = "-L{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib"
    }
  }

  script = [
    "patch -p1 --batch --forward < props/gssrpc-link-krb5support.patch",

    # The tarball's top directory holds `src/`; the build is in there.
    "cd src && ./configure $ARGS YACC=\"bison -y\"",
    "cd src && make --jobs {{ hw.concurrency }}",
    "cd src && make install",
  ]
}

# `make install` of 1.22.3, read off the install: bin/ (the client tools, the
# sample clients and compile_et) and sbin/ (the KDC, the admin server, the
# propagation tools and the sample servers).
provides = [
  "bin/compile_et",
  "bin/gss-client",
  "bin/k5srvutil",
  "bin/kadmin",
  "bin/kdestroy",
  "bin/kinit",
  "bin/klist",
  "bin/kpasswd",
  "bin/krb5-config",
  "bin/ksu",
  "bin/kswitch",
  "bin/ktutil",
  "bin/kvno",
  "bin/sclient",
  "bin/sim_client",
  "bin/uuclient",
  "sbin/gss-server",
  "sbin/kadmin.local",
  "sbin/kadmind",
  "sbin/kdb5_util",
  "sbin/kprop",
  "sbin/kpropd",
  "sbin/kproplog",
  "sbin/krb5-send-pr",
  "sbin/krb5kdc",
  "sbin/sim_server",
  "sbin/sserver",
  "sbin/uuserver",
]

test {
  fixture = <<EOT
#include <gssapi/gssapi.h>
#include <gssapi/gssapi_krb5.h>
#include <stdio.h>
#include <string.h>

/* An initiator and an acceptor in one process, over the real KDC: the
 * initiator uses the credential cache kinit filled, the acceptor the keytab. */
static int fail(const char *what, OM_uint32 maj, OM_uint32 min)
{
	OM_uint32 m, ctx = 0;
	gss_buffer_desc msg;

	fprintf(stderr, "%s failed (major %u minor %u)", what, (unsigned)maj, (unsigned)min);
	do {
		if (gss_display_status(&m, min, GSS_C_MECH_CODE, GSS_C_NO_OID, &ctx, &msg) == GSS_S_COMPLETE) {
			fprintf(stderr, ": %.*s", (int)msg.length, (char *)msg.value);
			gss_release_buffer(&m, &msg);
		}
	} while (ctx != 0);
	fprintf(stderr, "\n");
	return 1;
}

int main(void)
{
	OM_uint32 maj, min, rmaj, ret_flags;
	gss_buffer_desc nb, in = GSS_C_EMPTY_BUFFER, out = GSS_C_EMPTY_BUFFER, msg, wrapped, plain, cn;
	gss_name_t target, client = GSS_C_NO_NAME;
	gss_ctx_id_t ictx = GSS_C_NO_CONTEXT, actx = GSS_C_NO_CONTEXT;
	gss_cred_id_t acred = GSS_C_NO_CREDENTIAL;
	int conf = 0, done = 0, rounds = 0;

	/* A full principal name, not a host-based service: the latter asks the
	 * resolver to canonicalise "localhost", which answers differently on every
	 * host (measured: localhost.<search domain>). */
	nb.value = (void *)"svc/localhost@TEST.LOCAL";
	nb.length = strlen("svc/localhost@TEST.LOCAL");
	maj = gss_import_name(&min, &nb, (gss_OID)GSS_KRB5_NT_PRINCIPAL_NAME, &target);
	if (maj != GSS_S_COMPLETE)
		return fail("gss_import_name", maj, min);

	maj = gss_acquire_cred(&min, target, 0, GSS_C_NO_OID_SET, GSS_C_ACCEPT, &acred, NULL, NULL);
	if (maj != GSS_S_COMPLETE)
		return fail("gss_acquire_cred (the keytab)", maj, min);

	while (!done && rounds++ < 8) {
		maj = gss_init_sec_context(&min, GSS_C_NO_CREDENTIAL, &ictx, target, (gss_OID)gss_mech_krb5,
		    GSS_C_MUTUAL_FLAG | GSS_C_CONF_FLAG | GSS_C_INTEG_FLAG, 0, GSS_C_NO_CHANNEL_BINDINGS,
		    &in, NULL, &out, &ret_flags, NULL);
		if (maj != GSS_S_COMPLETE && maj != GSS_S_CONTINUE_NEEDED)
			return fail("gss_init_sec_context (the ticket from the KDC)", maj, min);
		if (in.length)
			gss_release_buffer(&rmaj, &in);
		if (out.length) {
			maj = gss_accept_sec_context(&min, &actx, acred, &out, GSS_C_NO_CHANNEL_BINDINGS,
			    &client, NULL, &in, NULL, NULL, NULL);
			gss_release_buffer(&rmaj, &out);
			if (maj != GSS_S_COMPLETE && maj != GSS_S_CONTINUE_NEEDED)
				return fail("gss_accept_sec_context", maj, min);
		}
		done = (maj == GSS_S_COMPLETE && in.length == 0);
	}
	if (!done) {
		fprintf(stderr, "context not established\n");
		return 1;
	}

	/* The acceptor learned who the initiator is. */
	maj = gss_display_name(&min, client, &cn, NULL);
	if (maj != GSS_S_COMPLETE || cn.length != strlen("alice@TEST.LOCAL") ||
	    memcmp(cn.value, "alice@TEST.LOCAL", cn.length) != 0) {
		fprintf(stderr, "the acceptor saw %.*s, not alice@TEST.LOCAL\n", (int)cn.length, (char *)cn.value);
		return 1;
	}

	/* And the session key protects a message both ways. */
	msg.value = (void *)"kerberos-protected";
	msg.length = strlen("kerberos-protected");
	maj = gss_wrap(&min, ictx, 1, GSS_C_QOP_DEFAULT, &msg, &conf, &wrapped);
	if (maj != GSS_S_COMPLETE || !conf)
		return fail("gss_wrap", maj, min);
	maj = gss_unwrap(&min, actx, &wrapped, &plain, &conf, NULL);
	if (maj != GSS_S_COMPLETE || plain.length != msg.length || memcmp(plain.value, msg.value, msg.length) != 0)
		return fail("gss_unwrap", maj, min);
	return 0;
}
EOT

  script = [
    "test -x \"{{prefix}}/bin/kinit\"",
    "test -x \"{{prefix}}/sbin/krb5kdc\"",
    "test -f \"{{prefix}}/include/gssapi/gssapi_krb5.h\"",
    "test \"$(\"{{prefix}}/bin/krb5-config\" --version)\" = \"Kerberos 5 release {{version.raw}}\"",
    "PKG_CONFIG_PATH=\"{{prefix}}/lib/pkgconfig\" pkg-config --exact-version={{version.raw}} krb5-gssapi",

    # ⛔⛔ EVERY NAMED OR REFUSED CHOICE, READ OFF THE INSTALLED FILES. The
    # names are strings in the plugins' and libraries' dynamic tables, so a
    # plain binary grep reads them on both platforms.
    {
      run = <<EOT
set -eu
root="{{prefix}}"
case "$(uname -s)" in Darwin) sfx=dylib ;; *) sfx=so ;; esac
plug="$root/lib/krb5/plugins"
test -f "$plug/preauth/pkinit.so"
test -f "$plug/preauth/spake.so"
test -f "$plug/tls/k5tls.so"
test -f "$plug/kdb/db2.so"
! test -e "$plug/kdb/kldap.so" || { echo "the LDAP KDB module was built" >&2; exit 1; }
! test -e "$plug/kdb/klmdb.so" || { echo "the LMDB KDB module was built" >&2; exit 1; }
grep -aq -e 'libcrypto' "$plug/preauth/pkinit.so" || { echo "pkinit does not link libcrypto" >&2; exit 1; }
grep -aq -e 'libssl' "$plug/tls/k5tls.so" || { echo "k5tls does not link libssl" >&2; exit 1; }
grep -aq -e 'EC_POINT_new' "$plug/preauth/spake.so" || { echo "spake is not using OpenSSL" >&2; exit 1; }
for f in "$root/lib/libkrb5.$sfx" "$root/lib/libgssapi_krb5.$sfx" "$root/lib/libk5crypto.$sfx" "$root/sbin/krb5kdc" "$root/bin/kinit" "$root/bin/kadmin"; do
  for r in libkeyutils libldap liblber liblmdb libedit libreadline libintl libaudit libhesiod; do
    ! grep -aq -e "$r" "$f" || { echo "$f names $r, which this recipe refuses" >&2; exit 1; }
  done
done
grep -aq -e 'libverto' "$root/sbin/krb5kdc" || { echo "krb5kdc does not link libverto" >&2; exit 1; }
test -f "$root/lib/libverto.$sfx"
EOT
    },

    # ⭐ A REALM, AND A GSSAPI EXCHANGE THROUGH IT.
    {
      run = <<EOT
set -eu
root="{{prefix}}"
d="$PWD/realm"
rm -rf "$d"
mkdir "$d"
port=$((20000 + $$ % 20000))
cat > "$d/krb5.conf" <<EOF
[libdefaults]
 default_realm = TEST.LOCAL
 dns_lookup_kdc = false
 dns_lookup_realm = false
 dns_canonicalize_hostname = false
 rdns = false
[realms]
 TEST.LOCAL = {
  kdc = 127.0.0.1:$port
 }
EOF
cat > "$d/kdc.conf" <<EOF
[kdcdefaults]
 kdc_ports = $port
 kdc_tcp_ports = $port
[realms]
 TEST.LOCAL = {
  database_name = $d/principal
  key_stash_file = $d/.k5.TEST.LOCAL
  acl_file = $d/kadm5.acl
  supported_enctypes = aes256-cts-hmac-sha1-96:normal
 }
[logging]
 kdc = FILE:$d/kdc.log
 default = FILE:$d/kdc.log
EOF
export KRB5_CONFIG="$d/krb5.conf" KRB5_KDC_PROFILE="$d/kdc.conf" KRB5CCNAME="FILE:$d/cc" KRB5_KTNAME="FILE:$d/svc.keytab"
"$root/sbin/kdb5_util" create -s -P masterpw -r TEST.LOCAL
"$root/sbin/kadmin.local" -q "addprinc -pw alicepw alice"
"$root/sbin/kadmin.local" -q "addprinc -randkey svc/localhost"
"$root/sbin/kadmin.local" -q "ktadd -k $d/svc.keytab svc/localhost"
"$root/sbin/krb5kdc" -P "$d/kdc.pid"
trap 'kill "$(cat "$d/kdc.pid")" 2>/dev/null || true' EXIT
ok=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  if echo alicepw | "$root/bin/kinit" alice; then ok=1; break; fi
  sleep 1
done
test "$ok" = 1 || { cat "$d/kdc.log" >&2; echo "kinit could not get a ticket from the KDC" >&2; exit 1; }
"$root/bin/klist" > "$d/klist.txt"
grep -q 'krbtgt/TEST.LOCAL@TEST.LOCAL' "$d/klist.txt"
cc -x c $FIXTURE -x none -o gsscheck -I"$root/include" -L"$root/lib" -lgssapi_krb5 -lkrb5 -Wl,-rpath,"$root/lib"
LD_LIBRARY_PATH="$root/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$root/lib:$${DYLD_LIBRARY_PATH:-}" ./gsscheck
"$root/bin/klist" > "$d/klist2.txt"
grep -q 'svc/localhost@TEST.LOCAL' "$d/klist2.txt"
EOT
    },
  ]
}

provenance {
  read = [
    "src/configure.ac",         # :9-16 SYSCONFCONF; :124-146 NLS; :230-237 vague errors; :241-262 audit; :266-288 crypto-impl; :292-331 TLS; :333-352 keyutils; :357-371 SPAKE; :374-410 AES-NI; :412-418 lookaside cache; :425-458 asan, ossfuzz; :1138-1164 PKINIT; :1173-1208 Python, cmocka, resolv_wrapper; :1271-1307 LDAP; :1312-1317 SecurID; :1322-1339 LMDB; :1349-1383 libedit, readline; :1385-1406 verto; :1408 groff; :1454-1500 default names; :211-218 secure_getenv",
    "src/aclocal.m4",           # :118 delayed initialization; :166 threads; :506 size optimizations; :700 netlib; :722 hesiod; :840 rpath; :1047 dns-for-realm; :1138-1285 com_err, ss, db; :1400-1413 --with-ldap
    "src/include/osconf.hin",   # :53 profile path; :72 KDC_DIR; :137 MECH_CONF
    "src/lib/rpc/Makefile.in",  # :18 SHLIB_EXPLIBS without libkrb5support
    "src/util/support/secure_getenv.c",
    "src/man/Makefile.in",      # GROFF only for the catman targets
    "NOTICE",
    "https://kerberos.org/dist/index.html", # the signing fingerprints
  ]

  consulted = [
    # Facts only: the `src` working directory, bison as a build dependency, the
    # darwin libgssrpc link failure, the `provides` list. The pantry named no
    # TLS, PKINIT, SPAKE, LDAP, LMDB, libedit or krb5-config choice and linked
    # `openssl ^1.1`; the darwin work-around was a `sed` and is a patch here.
    "pkgxdev/pantry projects/kerberos.org/package.yml",
  ]

  note = <<EOT
SIGNATURE CHAIN. The source archive has a detached signature
(https://kerberos.org/dist/krb5/1.22/krb5-1.22.3.tar.gz.asc, OpenPGP RSA-4096),
made 2026-11-09 by key C4493CB739F4A89F9852CBC20CBA08575F8372DF, Greg Hudson
<ghudson@mit.edu>. WHERE THE FINGERPRINT CAME FROM: https://kerberos.org/dist/
index.html, the project's own download page, which lists three signing keys
("Current releases are signed with one of the following PGP keys": this one,
C1BD1C744EA66EA2DDF11B43CFE28FC7253AAB87 and 2C732B1C0DBEF678AB3AF606A32F17FD0055C305,
tlyu@mit.edu). THE KEY FILE ITSELF came from keyserver.ubuntu.com
(`pks/lookup?op=get&search=0xC4493CB7…`) and is trusted ONLY because its
fingerprint equals the page's: the keyserver is a file host, not the anchor.
`zpkb sourcepin` verified the tarball against it. The project publishes no KEYS
file (kerberos.org/dist/KEYS, web.mit.edu/kerberos/KEYS: 404). Only 1.22.3 is
recorded, so the other two keys are not pinned.

SECOND INDEPENDENT FETCH: `curl --fail` and `shasum -a 256` gave
fe90af8441ad9fa9b064b8e53077cefb782a96f8a68276b031dc54af1789ff0b, the digest of
the builder's own fetcher.

⛔ BUILT HERE, NOT BY THE FACTORY. darwin/arm64: configured with the flags above
(system OpenSSL 3 from /opt/homebrew, Apple's bison 2.3 standing in for the
declared one), built and installed with the patch, and the test block's
commands run against the install. linux/aarch64: the same in a debian:trixie
container, where the test block ran to the end (a KDC, kinit, the GSSAPI
exchange). Measured on linux: the KDC log said "preauth pkinit failed to
initialize: No pkinit_identity supplied for realm" and "preauth spake failed to
initialize: No SPAKE preauth groups configured", i.e. both plugins loaded and
declined for want of configuration, which is what a realm with neither
configured should do. NOT RUN: the factory, a hermetic OpenSSL prefix (the
container's was /usr), x86-64.
EOT
}
