# llama.cpp — inference for GGUF models, CPU everywhere, Metal on darwin.
#
# Written because go-wasmcontainers was building it by hand from a clone to get
# LLM baselines (go-wasmcontainers/gpu#18): a tool we have no recipe for is
# ours to add, not theirs to build locally.
#
# ⛔ GGML_NATIVE=OFF IS NOT A TUNING CHOICE. Upstream defaults it ON, which
# compiles with `-march=native` — the build machine's own instruction set baked
# into the binary. That is correct for someone building on the machine they
# will run on, and wrong for every artifact, which is built on a CI runner and
# run somewhere else: the first host without AVX-512 gets SIGILL. The artifact
# keeps ggml's runtime CPU dispatch instead, which is what it is for.

display-name = "llama.cpp"
dependencies = {
  # TLS for the model downloader. llama.cpp carries its own HTTP client
  # (cpp-httplib, `common/http.h`) rather than libcurl, and that client only
  # speaks https when it is compiled against a TLS library: without one,
  # `common_http_client` refuses at RUN time with a message listing
  # -DLLAMA_OPENSSL=ON and friends. `LLAMA_OPENSSL` defaults ON and "requires
  # OpenSSL dev files installed", so leaving this undeclared gets a build that
  # either fails on a scratch builder or quietly ships without https.
  #
  # ^3 for consistency with the rest of the fleet; it resolves to 3.5.x, which
  # is a supported line. 4.0 is supported too, and moving the fleet to it is a
  # decision for the fleet, not for a new recipe to make on its own.
  "openssl.org" = "^3"
}
platforms = [
  "darwin/aarch64",
  "darwin/x86-64",
  "linux/x86-64",
  "linux/aarch64",
]
provides = [
  "bin/llama-bench",
  "bin/llama-cli",
  "bin/llama-server",
]

build {
  dependencies = {
    "cmake.org"                   = "^3"
    "freedesktop.org/pkg-config"  = "*"
  }
  script = [
    "cmake .. $ARGS",
    "cmake --build . --config Release --parallel {{ hw.concurrency }}",
    "cmake --install .",
  ]
  working-directory = "build"

  env {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX=\"{{prefix}}\"",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DGGML_NATIVE=OFF",
      "-DLLAMA_BUILD_TESTS=OFF",
      "-DLLAMA_BUILD_EXAMPLES=OFF",
      "-DLLAMA_BUILD_TOOLS=ON",
      "-DLLAMA_BUILD_SERVER=ON",
      # ⛔ BUILDING THE TOOLS IS NOT INSTALLING THEM. Every `install(TARGETS)`
      # for llama-cli, llama-bench and llama-server sits behind
      # `if(LLAMA_TOOLS_INSTALL)`, so without it `cmake --install` would place
      # the libraries and none of the three binaries this recipe `provides`.
      #
      # It currently defaults to LLAMA_STANDALONE, which is ON for a top-level
      # build like ours, so this changes nothing TODAY. It is stated because
      # `provides` depends on it: if upstream flips the default, the recipe
      # should keep installing what it promises rather than start publishing a
      # artifact with no executables in it.
      "-DLLAMA_TOOLS_INSTALL=ON",
      # Stated rather than left to the default, so that a builder without
      # OpenSSL fails here instead of silently producing a binary that cannot
      # fetch a model over https.
      #
      # ⛔ NOT `-DLLAMA_CURL=OFF`. I wrote that first, from the older build
      # documentation. At this tag `LLAMA_CURL` is deprecated AND ignored —
      # `llama_option_depr(WARNING LLAMA_CURL)` with no replacement, CMakeLists
      # line 196 — and libcurl appears nowhere in the build. Setting it OFF
      # does nothing at all, including not disabling downloads.
      "-DLLAMA_OPENSSL=ON",
    ]

    darwin {
      # Metal is upstream's default on darwin and is what the platform is for.
      # EMBED_LIBRARY puts the shader source inside the binary: without it the
      # library is looked up next to the executable at RUN time, which a
      # relocatable artifact cannot promise.
      ARGS = [
        "-DGGML_METAL=ON",
        "-DGGML_METAL_EMBED_LIBRARY=ON",
      ]
    }

    linux {
      # CPU only. No BLAS vendor is selected, so ggml uses its own kernels —
      # the configuration go-wasmcontainers' baselines were measured against.
      ARGS = [
        "-DGGML_METAL=OFF",
        "-DGGML_BLAS=OFF",
      ]
    }
  }
}

distributable {
  strip-components = 1
  url = "https://github.com/ggml-org/llama.cpp/archive/refs/tags/{{version.tag}}.tar.gz"
}

test {
  script = [
    "test -f {{prefix}}/bin/llama-cli",
    "test -f {{prefix}}/bin/llama-bench",
    "test -f {{prefix}}/bin/llama-server",
    # --version writes to stderr and exits non-zero on some builds, so the
    # check is on the text, not on the status.
    "llama-cli --version 2>&1 | grep -q 'version'",
    # ⛔ THE BACKEND IS PART OF THE TEST. A darwin artifact that silently lost
    # Metal would still pass every file-exists check above and would simply be
    # slow, which is the kind of regression nobody notices for months.
    "llama-bench --help 2>&1 | grep -q 'usage'",
    # ⛔ THIS WAS A `darwin { script = … }` BLOCK, AND IT NEVER RAN.
    # buildscript.Generate reads only `script`, `working-directory`, `env`
    # and the node's fixture; a platform-keyed sub-block is not one of them,
    # and the schema accepted it anyway (additionalProperties: true). So the
    # Metal assertion above — written precisely because a darwin artifact that
    # lost Metal passes every other check and is merely slow — has never been
    # made on any build.
    #
    # `if` is the mechanism that works: buildscript.matchGuard resolves a
    # platform, an arch or an <os>/<arch> against the build target.
    {
      if  = "darwin"
      run = "llama-cli --version 2>&1 | grep -qi 'metal'"
    },
  ]
}

versions {
  github = "ggml-org/llama.cpp/tags"
  strip  = "/^v/"

  # THREE TAG SCHEMES LIVE IN THIS REPOSITORY AT ONCE: semver (`v0.8.0`, the
  # current one), `bNNNN` (the older per-build scheme) and `master-<sha>`
  # nightlies, plus a stray `tmp-testing-0`.
  #
  # There is deliberately no `ignore` here. I wrote one — /^master-/, /^tmp-/,
  # /^b\d+$/ — and then ran it against a control with the ignores REMOVED:
  # both produced the same 11 versions, newest 0.8.0 from tag v0.8.0
  # (measured 2026-11-02). The semver parse already drops everything the
  # ignore list named, so the list did nothing while looking like the thing
  # keeping nightlies out of the version table. Dead configuration that reads
  # as a safeguard is worse than none, because the next person trusts it.
  #
  # If upstream ever tags something that DOES parse as a version but is not a
  # release, this is where the ignore goes — and it should be added with the
  # same control, not on the assumption that it works.
}
