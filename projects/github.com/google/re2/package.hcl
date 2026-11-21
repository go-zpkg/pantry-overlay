# RE2 — a regular expression library with guaranteed linear-time matching
# (the engine gRPC uses).
#
# Written whole from the project's own files (campaign go-zpkg/packages#440,
# step 1). It is a dependency of grpc.io, and no recipe existed.

summary = "Fast, safe regular expression library (linear time)"

# LICENSE: three-clause BSD ("Redistribution and use ...", "Neither the name of
# Google Inc."), copyright The RE2 Authors.
license = "BSD-3-Clause"

dependencies = {
  "abseil.io" = "*"
}

versions {
  # The tags are dates (2025-11-05), and the repository also holds a tag that is
  # not one (abseil.old), which the match below leaves out.
  github = "google/re2"
  match  = "/^\\d{4}-\\d{2}-\\d{2}$/"
}

distributable {
  # THE STORED RELEASE ASSET, not the generated tag archive: the release uploads
  # re2-<version>.zip, whose bytes do not change.
  #
  # {{version.tag}} and not {{version.raw}}: `versions` normalises the date tag
  # 2025-11-05 to 2025.11.05, and the asset is named with the tag.
  url              = "https://github.com/google/re2/releases/download/{{version.tag}}/re2-{{version.tag}}.zip"
  strip-components = 1

  # Fetched with `zpkb sourcepin` (457594 bytes). The project publishes no
  # signature and no checksum file. SECOND WITNESS: the Bazel Central Registry
  # records "sha256-x7Gnp8aNLXz400PcVmVcG1qMiq3twBfbRT1MHYkTuEQ=" for the same URL
  # in modules/re2/2025-11-05/source.json; that base64 decodes to the hex below.
  #
  # The pin is keyed by the NORMALISED version (2025.11.05, which `versions`
  # prints), while the URL uses the raw tag (2025-11-05): `lint
  # --check-newest-pinned` refused the dashed key.
  #
  # ⛔ WHAT THAT PROVES: the registry is a third party's record of the digest it
  # saw, not a signature by the project. It agrees with the bytes fetched here.
  sha256 = {
    "2025.11.05" = "c7b1a7a7c68d2d7cf8d343dc56655c1b5a8c8aadedc017db453d4c1d8913b844"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/make"               = "*"
  }

  env {
    # The Makefile (the project's plain build; CMake is the other one) reads
    # prefix, and finds Abseil through `pkg-config` (Makefile:6-24, ABSL_DEPS),
    # so PKG_CONFIG_PATH must reach the Abseil prefix. `all` builds BOTH
    # obj/libre2.a and the shared library (Makefile:110), and `install` installs
    # both plus re2.pc (Makefile:322-348). The tests need GoogleTest and
    # Benchmark and are not built by `all`.
    PKG_CONFIG_PATH = "{{deps.abseil.io.prefix}}/lib/pkgconfig"
  }

  script = [
    "make --jobs {{hw.concurrency}} prefix={{prefix}}",
    "make install prefix={{prefix}}",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/gcc"                = "*"
  }

  env {
    PKG_CONFIG_PATH = "{{prefix}}/lib/pkgconfig:{{deps.abseil.io.prefix}}/lib/pkgconfig"
  }

  script = [
    "test -f {{prefix}}/include/re2/re2.h",
    "pkg-config --exists re2",
    {
      # The project's own install test (testinstall.cc), the same call the
      # Makefile's `shared-testinstall` makes.
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <re2/filtered_re2.h>
#include <re2/re2.h>

int main() {
  re2::FilteredRE2 f;
  int id;
  f.Add("a.*b.*c", RE2::DefaultOptions, &id);
  std::vector<std::string> v;
  f.Compile(&v);
  std::vector<int> ids;
  f.FirstMatch("abbccc", ids);

  int n;
  if (RE2::FullMatch("axbyc", "a.*b.*c") &&
      RE2::PartialMatch("foo123bar", "(\\d+)", &n) && n == 123) {
    printf("PASS\n");
    return 0;
  }

  printf("FAIL\n");
  return 2;
}
EOT
        extname = "cc"
      }
      run = "g++ $FIXTURE -o testinstall -std=c++17 $(pkg-config --cflags --libs re2)"
    },
    "./testinstall",
  ]
}

provenance {
  read = [
    "Makefile",        # :6-24 Abseil via pkg-config; :61 prefix; :85 SONAME; :110 all; :322-348 install
    "LICENSE",         # BSD three-clause
    "testinstall.cc",  # the test the fixture reproduces
    "re2.pc.in",       # the installed pkg-config file
  ]

  consulted = [
    "https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/main/modules/re2/2025-11-05/source.json",
  ]

  note = <<EOT
NOT BUILT: written from the sources and the stored release asset; not run on a
builder. The Abseil recipe (abseil.io) is written in the same campaign.
EOT
}
