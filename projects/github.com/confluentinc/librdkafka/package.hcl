# github.com/confluentinc/librdkafka — the Apache Kafka C/C++ client library.
#
# ⛔ WRITTEN FROM LIBRDKAFKA'S OWN FILES (go-zpkg/packages#440 step 1), at 2.16.0.
#
# ⭐⭐ WHAT WRITING IT FOUND: every optional dependency is a find_package whose
# failure silently flips its WITH_ switch (CMakeLists.txt:44-79, :106-121,
# :168-179), so a builder missing curl or zstd yields a working library that
# lacks them. And SASL is the trap: `WITH_SASL=ON` is what turns on SCRAM and
# OAUTHBEARER (:148-156), while Cyrus SASL itself is only added when libsasl2 is
# found on the HOST (:127-160). Cyrus SASL's recipe in this tree is a fragment, so
# it is not a dependency here; PkgConfig is switched off below so the host's
# libsasl2 cannot be picked up either, and SCRAM + OAUTHBEARER (which need only
# OpenSSL) stay on. Every switch is named, and the test asks the built library
# for each feature through `builtin.features` (src/rdkafka_conf.c:376-401).

summary = "librdkafka: the Apache Kafka C/C++ client library"

# LICENSE:1-14 and :16: two conditions and the disclaimer: BSD-2-Clause.
license = "BSD-2-Clause"

versions {
  github = "confluentinc/librdkafka"
  strip  = "/^v/"
}

dependencies = {
  # CMakeLists.txt:56-67 and :164-166: libcurl turns on HTTP and OIDC.
  "curl.se"           = "*"
  # :69-80
  "facebook.com/zstd" = "*"
  # :168-179: ENABLE_LZ4_EXT; without it a bundled copy is used.
  "lz4.org"           = "*"
  # :106-121; also SCRAM and OAUTHBEARER (:152-156).
  "openssl.org"       = "^3"
  # :43-54
  "zlib.net"          = "*"
}

distributable {
  # GitHub's generated archive of the tag: the releases carry no assets of their
  # own. That makes the digest a single-host rung, with the caveat that a
  # generated archive's bytes are the host's to change.
  url              = "https://github.com/confluentinc/librdkafka/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 5358616 bytes, fetched with `zpkb sourcepin`. The project publishes no
  # signature and no checksum. homebrew-core's API (formulae.brew.sh/api/formula/
  # librdkafka.json, stable 2.16.0) records the same digest for the same URL:
  # the second witness, and it is a third party's, not the author's.
  sha256 = {
    "2.16.0" = "e6b61de61d3282879a88e4ee3d9f634a8b05bf78a9198dfc25c4820c0c9ed231"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
    "gnu.org/gcc"  = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # CMakeLists.txt:182 builds the shared library unless this is ON.
      "-DRDKAFKA_BUILD_STATIC=OFF",
      # :183-184: the examples and the test suite (which needs a broker).
      "-DRDKAFKA_BUILD_EXAMPLES=OFF",
      "-DRDKAFKA_BUILD_TESTS=OFF",

      # Each is `option(... ${found_default})`: named, so the builder cannot
      # change them.
      "-DWITH_ZLIB=ON",
      "-DWITH_CURL=ON",
      "-DWITH_ZSTD=ON",
      "-DWITH_SSL=ON",
      "-DENABLE_LZ4_EXT=ON",
      "-DWITH_PLUGINS=ON",

      # :147-161. SASL on for SCRAM and OAUTHBEARER; the probe for the host's
      # libsasl2 (:127-146) lives inside `if(PkgConfig_FOUND)`, so disabling
      # that package makes Cyrus SASL unreachable. Cyrus SASL's recipe here is
      # a fragment.
      "-DWITH_SASL=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=TRUE",

      # :17-18 development asserts and refcount debugging.
      "-DENABLE_DEVEL=OFF",
      "-DENABLE_REFCNT_DEBUG=OFF",
      "-DWITHOUT_OPTIMIZATION=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  # Setting `builtin.features` to a list answers CONF_INVALID for any feature
  # this build lacks (src/rdkafka_conf.c:378-380, :381-400), so one call checks
  # every switch above. The version pair guards against a system librdkafka.
  fixture = <<EOT
#include <stdio.h>
#include <string.h>
#include <librdkafka/rdkafka.h>

int main(void)
{
	char err[512];
	if (rd_kafka_version() != RD_KAFKA_VERSION) {
		fprintf(stderr, "header %#x but library %#x\n", RD_KAFKA_VERSION, rd_kafka_version());
		return 1;
	}
	rd_kafka_conf_t *conf = rd_kafka_conf_new();
	if (rd_kafka_conf_set(conf, "builtin.features",
	        "gzip,snappy,ssl,lz4,zstd,sasl,sasl_plain,sasl_scram,sasl_oauthbearer,plugins,http,oidc",
	        err, sizeof err) != RD_KAFKA_CONF_OK) {
		fprintf(stderr, "librdkafka was built without a feature: %s\n", err);
		return 1;
	}
	rd_kafka_conf_destroy(conf);
	printf("librdkafka %s\n", rd_kafka_version_str());
	return 0;
}
EOT

  script = [
    "pkg-config --exists rdkafka",
    "cc -x c $FIXTURE -x none -o features $(pkg-config --cflags --libs rdkafka)",
    "./features",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                              # :28-33 PkgConfig; :43-80 zlib/curl/zstd; :94-121 plugins, OpenSSL; :123-166 SASL probe, SCRAM, OAUTHBEARER, OIDC; :168-184 LZ4 and the build options
    "src/CMakeLists.txt",                          # :87-134 sources by feature; :188-190 STATIC or SHARED; :289-355 the pkg-config files
    "src/rdkafka_conf.c",                          # :376-401 builtin.features
    "src/rdkafka.h",                               # :170 RD_KAFKA_VERSION; :181-189 rd_kafka_version, rd_kafka_version_str
    "packaging/cmake/Modules/FindLZ4.cmake",       # find_path/find_library, no pkg-config
    "packaging/cmake/Modules/FindZSTD.cmake",      # :9-12 find_path/find_library
    "LICENSE",                                     # :1-14 BSD-2-Clause
  ]

  consulted = [
    "formulae.brew.sh/api/formula/librdkafka.json (checksum only)",
  ]

  note = <<EOT
⚠ THE RUNG IS A THIRD PARTY'S DIGEST ON A GENERATED ARCHIVE. The project
publishes no signature or checksum and its releases carry no assets. The digest
was fetched with zpkb sourcepin and equals homebrew-core's for the same URL.

Cyrus SASL (and so GSSAPI through it) is deliberately absent: its recipe is a
fragment here, and this recipe does not write dependencies.

Prior recipe: a fragment holding only dependencies.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
