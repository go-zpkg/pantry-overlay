# xz — the XZ Utils: the `xz` tools and liblzma, the LZMA2 reference
# implementation.
#
# ⛔ WRITTEN FROM XZ'S OWN BUILD SYSTEM, NOT CONVERTED (go-zpkg/packages#431).
# The `provenance` block at the end names the project's files this build was
# derived from and the other distributions read for facts.
#
# ⛔⛔ AND THIS IS THE PACKAGE WHERE "THE TARBALL IS NOT THE REPOSITORY" STOPPED
# BEING A THEORY. xz's own NEWS:
#
#     5.6.2 (2024-05-29)  * Remove the backdoor (CVE-2024-3094).
#     5.6.1 (2024-03-09)  IMPORTANT: This fixed bugs in the backdoor
#                         (CVE-2024-3094) (someone …)
#     5.6.0 (2024-02-24)  IMPORTANT: This added a backdoor (CVE-2024-3094).
#
# The payload lived in the RELEASE TARBALL's generated build system — an
# `m4/build-to-host.m4` that is not in the git tree — so a reader comparing the
# repository against the release would have found it and a reader trusting the
# release would not. Those tarballs were also signed by the maintainer who
# introduced it, so "verify the signature" is not the lesson either. The
# lesson is that a distributable needs a digest somebody attested AND a
# version set somebody chose.

summary = "XZ Utils: the xz tools and liblzma, the LZMA2 reference implementation"

# liblzma is public-domain-equivalent, the command line tools are GPL.
license = "0BSD AND GPL-2.0-or-later"

versions {
  github = "tukaani-project/xz"

  ignore = [
    # ⛔ THE BACKDOORED LINE IS EXCLUDED, NOT MERELY LEFT UNPINNED. Refusing to
    # pin them would already make them unbuildable here, since a recipe that
    # pins any version refuses one absent from the map — but that is a property
    # of the mechanism, and this is a decision. It should survive somebody
    # adding a digest without reading NEWS.
    "/^v?5\\.6\\.[01]$/",
    # Pre-releases: 5.7.2beta and friends are tagged in the same namespace.
    "/beta|alpha|rc/",
  ]
}

distributable {
  # The GitHub release asset, which is what both homebrew-core and nixpkgs use
  # as their primary for this project. tukaani.org no longer serves the
  # tarballs at a stable path (404 for 5.8.4 on 2026-11-08); SourceForge does,
  # and homebrew-core carries it as a mirror — but see the note on why it is
  # not the URL here.
  url              = "https://github.com/tukaani-project/xz/releases/download/v{{version.raw}}/xz-{{version.raw}}.tar.gz"
  strip-components = 1

  # ⛔⛔ CORROBORATED BY TWO INDEPENDENT PATHS, WHICH IS THE POINT. GitHub's
  # release CDN was answering 504 while this was written, so the bytes were
  # fetched from the SourceForge mirror with `zbk sourcepin` — the builder's
  # own fetcher, which checks the status, resumes a truncated body and refuses
  # one whose magic bytes are not the archive's:
  #
  #     2799797 bytes
  #     sha256 = { "5.8.4" = "0014c788…91d9" }
  #
  # and that digest is byte-identical to the one homebrew-core records for the
  # same release, verified by another party at another time through a different
  # URL. Agreement between an independently fetched artefact and a third
  # party's record is a stronger warrant than either alone — and it is needed
  # HERE in particular, because our own fetcher carries a note that SourceForge
  # "had handed the runner something else" and cost pcre.org 8.45 a whole
  # factory run (zbk fetch/download.go). One source would not have been enough
  # for this package.
  sha256 = {
    "5.8.4" = "0014c7886930454fe8bd4228665b51af55eeae560ea135c9c4cd33f55b2591d9"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # Plain autotools, as INSTALL documents. Nothing exotic is passed, and the
  # options that were considered and rejected are in the note below rather than
  # commented out here.
  script = [
    "./configure --prefix={{prefix}} --disable-dependency-tracking",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

# The library is the half other packages consume: `pkgx` itself links
# `@rpath/tukaani.org/xz/v5/lib/liblzma.5.dylib` on darwin, which is how this
# project came to be declared a runtime dependency of it at all
# (go-zpkg/pantry-overlay#28). The shell wrappers xz installs — xzdiff, xzgrep,
# xzless, xzmore — are deliberately NOT listed: they are /bin/sh scripts, so
# they do not run in an empty image (go-zpkg/zpkgx#151), and naming them here
# would promise something this bottle cannot keep everywhere.
provides = [
  "bin/xz",
  "bin/unxz",
  "bin/xzcat",
  "bin/xzdec",
  "bin/lzmainfo",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "xz --version",
    # The installed surface: the library, its header and the pkg-config file
    # that consumers actually read.
    "test -f {{prefix}}/include/lzma.h",
    "test -f {{prefix}}/lib/pkgconfig/liblzma.pc",
    "pkg-config --exists liblzma",
    # A real round trip through the TOOL, not just a link check: compress
    # known bytes, decompress them, and compare. `xz --test` on the compressed
    # stream is the integrity check xz itself offers.
    {
      run = "printf 'the quick brown fox jumps over the lazy dog\\n' > sample && xz -k sample && xz --test sample.xz && unxz -c sample.xz > back && cmp sample back"
    },
    # And through the LIBRARY, because that is what every dependent uses.
    # LZMA_VERSION_STRING and lzma_version_string() must agree, for the same
    # reason zlib.net's test checks its pair: a disagreement is how a build
    # picks up a system liblzma instead of the one it just made.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <lzma.h>

int main(void) {
  if (strcmp(LZMA_VERSION_STRING, lzma_version_string()) != 0) {
    printf("header %s but library %s\n", LZMA_VERSION_STRING, lzma_version_string());
    return 1;
  }

  const char text[] = "the quick brown fox jumps over the lazy dog";
  uint8_t packed[512];
  size_t packed_pos = 0;
  if (lzma_easy_buffer_encode(LZMA_PRESET_DEFAULT, LZMA_CHECK_CRC64, NULL,
                              (const uint8_t *)text, sizeof text,
                              packed, &packed_pos, sizeof packed) != LZMA_OK) {
    puts("encode failed");
    return 1;
  }

  uint8_t back[512];
  size_t in_pos = 0, out_pos = 0;
  uint64_t memlimit = 1 << 26;
  if (lzma_stream_buffer_decode(&memlimit, 0, NULL, packed, &in_pos, packed_pos,
                                back, &out_pos, sizeof back) != LZMA_OK) {
    puts("decode failed");
    return 1;
  }

  if (out_pos != sizeof text || memcmp(text, back, sizeof text) != 0) {
    puts("round trip did not return the input");
    return 1;
  }

  printf("liblzma %s round-tripped %zu bytes\n", lzma_version_string(), sizeof text);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o roundtrip $(pkg-config --cflags --libs liblzma)"
    },
    "./roundtrip",
  ]
}

provenance {
  read = [
    "README",      # what the package is and what it installs
    "INSTALL",     # the configure options, and which are for which tool
    "NEWS",        # which release added, patched and removed CVE-2024-3094
  ]

  consulted = [
    "homebrew-core Formula/x/xz.rb",
    "nixpkgs (for the GitHub-release-first source order)",
    "go-zpkg/pantry-overlay#28 (our own: the darwin liblzma link)",
    "go-zpkg/zbk#397 (our own: this project bakes its localedir)",
  ]

  note = <<EOT
./configure --prefix then make install, as INSTALL documents. The version set
is the decision this recipe carries: 5.6.0 and 5.6.1 are excluded because xz's
own NEWS says they added and then patched a backdoor, and the digest is
corroborated by two independent paths rather than taken from one host.

⛔ --disable-nls was CONSIDERED AND REJECTED, and the reason is a lesson about
reading sources. go-zpkg/zbk#397 is titled "xz lzmainfo localedir": this
project compiles its localedir into its binaries as data, where no rpath
rewrite reaches it, and --disable-nls would remove that. But INSTALL:788-789
offers that flag only for xzdec and lzmadec — "There are and will be no
translated messages for xzdec and lzmadec, so it is fine to pass also
--disable-nls" — and xz itself DOES have translations. Passing it to the whole
package would delete something that exists, to fix something cosmetic. The
baked localedir therefore stays; a relocated store falls back to untranslated
messages, which is a degradation and not a failure. Setting TEXTDOMAINDIR
through `runtime.env` is the candidate fix and is NOT applied here, because
whether gettext honours it for this binary has not been verified.

Not acted on either: xz publishes a detached .sig beside every tarball, and
this format has no field for it. Worth having — but note that it would not have
caught CVE-2024-3094, since those tarballs were signed by the person who
introduced the backdoor.
EOT
}
