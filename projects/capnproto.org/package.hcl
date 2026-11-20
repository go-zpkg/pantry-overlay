# capnproto.org — Cap'n Proto: a typed binary serialisation and RPC system,
# with the `capnp` schema compiler and the KJ C++ base library.
#
# ⛔ WRITTEN FROM CAP'N PROTO'S OWN FILES (go-zpkg/packages#431), at 1.5.0,
# from the capnproto-c++ release tarball's CMakeLists.txt and src/*/CMakeLists.txt.
#
# ⭐⭐ WHAT WRITING IT FOUND: the top-level CMakeLists.txt makes THREE
# libraries optional by looking at the build machine, each with `AUTO`:
#
#   WITH_OPENSSL AUTO  (CMakeLists.txt:50,66-72)  libkj-tls exists only if
#                      OpenSSL is found; otherwise it is simply not built
#   WITH_ZLIB    AUTO  (:55,84-90)                libkj-gzip likewise, and
#                      kj-http loses its gzip support (src/kj/CMakeLists.txt:191)
#   WITH_FIBERS  AUTO  (:95,103-137)              kj-async is built with or
#                      without fibers; src/kj/CMakeLists.txt:158,163 define
#                      KJ_USE_FIBERS=1 or =0 PUBLICLY, but async.h:30-36 sets
#                      it from the PLATFORM when the consumer does not
#
# The upstream fragment declared zlib and (linux only) openssl and asserted
# nothing, so a builder without either would have shipped a library with
# neither and a green build. Each is pinned to ON below, which makes a missing
# one FATAL (:73-75, :91-93, :135).

summary = "Cap'n Proto: insanely fast data serialisation and capability-based RPC"

# LICENSE.txt:1-5: "Licensed under the MIT License".
license = "MIT"

versions {
  # capnproto.org/install.html names the release tarball; the tags of
  # github.com/capnproto/capnproto are the versions.
  github = "capnproto/capnproto"
}

dependencies = {
  # Pinned to ON below on every platform. The fragment declared openssl for
  # linux only; kj-tls is built from OpenSSL everywhere (src/kj/CMakeLists.txt:204).
  "openssl.org" = "^3"
  "zlib.net"    = "*"
}

distributable {
  url              = "https://capnproto.org/capnproto-c++-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1869727 bytes. Recorded with `zpkb sourcepin` and confirmed by a second,
  # independent fetch-and-hash (curl + shasum). The release carries no
  # signature and no checksum file.
  sha256 = {
    "1.5.0" = "77dbc13ca82d9c87ddb4581dd49559d45b63096433d3dadea08b7f31b360a5ba"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",

      # ⛔ CMakeLists.txt:11 includes CTest when top-level, which defines
      # BUILD_TESTING ON: the whole test suite (src/capnp/CMakeLists.txt:227-320,
      # src/kj/CMakeLists.txt:253) would be compiled and not installed.
      "-DBUILD_TESTING=OFF",

      # ⛔⛔ 1. TLS. :50-75 — AUTO builds libkj-tls only when OpenSSL is found.
      "-DWITH_OPENSSL=ON",
      # ⛔⛔ 2. GZIP. :55-93 — AUTO builds libkj-gzip only when zlib is found.
      "-DWITH_ZLIB=ON",
      # ⛔⛔ 3. FIBERS. :95-137 — AUTO falls back to OFF when makecontext is
      # missing from libc and libucontext is not found. ON makes that fatal.
      "-DWITH_FIBERS=ON",

      # The two options that change what is built are left at their OFF
      # defaults, named so a change of default is visible: EXTERNAL_CAPNP
      # (:35) would use a `capnp` from the builder's PATH, CAPNP_LITE (:36)
      # removes every reflection API and the whole RPC layer.
      "-DEXTERNAL_CAPNP=OFF",
      "-DCAPNP_LITE=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# src/capnp/CMakeLists.txt:181-221: capnp_tool (OUTPUT_NAME capnp), capnpc_cpp
# (capnpc-c++), capnpc_capnp (capnpc-capnp), and a capnpc copy/symlink of capnp.
provides = [
  "bin/capnp",
  "bin/capnpc",
  "bin/capnpc-c++",
  "bin/capnpc-capnp",
]

test {
  # kj/compat/tls.h and kj/compat/gzip.h exist only when WITH_OPENSSL and
  # WITH_ZLIB were ON (src/kj/CMakeLists.txt:223-224, 246-247) and the
  # libraries link only then. Without KJ_USE_FIBERS, FiberPool's run path is
  # `KJ_UNIMPLEMENTED("Fibers are not implemented ...")` (src/kj/async.c++:1536-1545),
  # which throws, so running a fiber reads the WITH_FIBERS choice back.
  fixture = <<EOT
#include <kj/async.h>
#include <kj/compat/gzip.h>
#include <kj/compat/tls.h>
#include <kj/io.h>
#include <kj/string.h>
#include <stdio.h>

int main()
{
	kj::VectorOutputStream sink;
	{
		kj::GzipOutputStream gz(sink);
		gz.write("hello hello hello hello", 23);
		gz.finish();
	}
	kj::ArrayInputStream src(sink.getArray());
	kj::GzipInputStream un(src);
	char buf[64];
	size_t n = un.tryRead(buf, 23, 64);
	if (n != 23) { fprintf(stderr, "gzip round trip read %zu bytes\n", n); return 1; }

	kj::TlsContext tls;
	kj::FiberPool pool(65536);
	pool.runSynchronously([]() {});
	return 0;
}
EOT

  script = [
    "c++ -x c++ $FIXTURE -x none -std=c++14 -pthread -o probe -I{{prefix}}/include -L{{prefix}}/lib -lkj-tls -lkj-gzip -lkj-async -lkj",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
EOT
    },
    "capnp --version",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",           # :11 CTest, :35-36 EXTERNAL_CAPNP/CAPNP_LITE, :50-137 the three AUTO options
    "src/kj/CMakeLists.txt",    # :157-163 KJ_USE_FIBERS, :191 http gzip, :204-247 tls and gzip targets
    "src/capnp/CMakeLists.txt", # :181-221 the installed tools, :227-320 tests
    "src/kj/async.h",           # :30-36 KJ_USE_FIBERS default from the platform
    "src/kj/async.c++",         # :1511-1545 fiber switch behind KJ_USE_FIBERS, else KJ_UNIMPLEMENTED
    "LICENSE.txt",
  ]

  consulted = [
    # Read for facts only: the tarball URL shape. Nothing copied.
    "pkgxdev/pantry projects/capnproto.org/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. capnproto.org serves the tarball over
HTTPS with no signature and no checksum file; the digest was fetched twice,
independently, and agreed.

⛔ NOT BUILT. No session here can run the factory. kj::FiberPool and
kj::TlsContext are used in the fixture as the consumer-visible witness of the
build choices; their signatures were checked against the 1.5.0 headers
(async.h:509,532, compat/tls.h:117, compat/gzip.h:57,77, io.h:195,214) but the
fixture has never been compiled.
EOT
}
