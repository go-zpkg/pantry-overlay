# getmonero.org — Monero, the privacy-focused cryptocurrency: the node daemon
# monerod and the command-line and RPC wallets (github.com/monero-project/monero).
# Written whole from Monero's own files at v0.18.5.4 (go-zpkg/packages#440
# step 1); the previous file was a fragment with dependencies only.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. THE SOURCE TARBALL IS THE ONE THAT HAS THE SUBMODULES, AND IS SIGNED.
#      A GitHub tag archive lacks external/randomx, external/supercop and
#      external/trezor-common (git submodules). downloads.getmonero.org/cli/
#      monero-source-v<version>.tar.bz2 contains them (all three are present in
#      the extracted tree), and its digest is in hashes.txt, a clear-signed file
#      verified here with gpg against binaryFate's key (see the digest note).
#   2. THE HARDWARE-WALLET AND STACK-TRACE DEPENDENCIES ARE OPTIONAL AND PROBED
#      FROM THE HOST. HIDAPI (CMakeLists.txt:605), libunwind (:551, STACK_TRACE
#      :561), protobuf and libusb (cmake/CheckTrezor.cmake, USE_DEVICE_TREZOR
#      defaults ON) are each found if present, so a silent recipe publishes
#      whatever the build host has. This tree has no hidapi, protobuf, libusb or
#      libunwind recipe, so each is turned off by name and Ledger and Trezor
#      support are NOT in this build. That is a stated limit, not an omission to
#      discover later.
#   3. THE ARCH DEFAULT IS THE BUILD HOST. CMakeLists.txt:618-623 sets ARCH to
#      `native` unless it is `default`, which would publish a binary that only
#      runs on the builder's CPU family; it is passed as `default` here (:722).
#   4. libzmq IS A DEPENDENCY WITH NO RECIPE UNTIL NOW. The old fragment named
#      `zeromq.org` = ^4.2 and none existed in the tree; projects/zeromq.org was
#      written with this recipe. Monero calls zmq.h (C API) only; no cppzmq
#      header is read anywhere under src/.
#   5. THE BINARIES ARE NAMED BY OUTPUT_NAME, NOT BY TARGET. The cmake targets
#      are `daemon`, `simplewallet` and `wallet_rpc_server`; they install as
#      monerod, monero-wallet-cli and monero-wallet-rpc (src/daemon/
#      CMakeLists.txt:74, src/simplewallet/CMakeLists.txt:64, src/wallet/
#      CMakeLists.txt:104). The blockchain_* tools are installed too
#      (src/blockchain_utilities/CMakeLists.txt) and are not promised here.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "Monero: node daemon (monerod) and command-line and RPC wallets"

# LICENSE is the BSD 3-clause text (Copyright (c) 2014-2022, The Monero Project,
# as the Makefile's header and each source file's say).
license = "BSD-3-Clause"

versions {
  github = "monero-project/monero/tags"
  strip  = ["/^v/"]
}

distributable {
  url              = "https://downloads.getmonero.org/cli/monero-source-v{{version.raw}}.tar.bz2"
  strip-components = 1

  # 15708323 bytes, recorded with `zpkb sourcepin` (v0.97.0). Second witness:
  # https://www.getmonero.org/downloads/hashes.txt, a clear-signed file that lists
  # `3c5aabb6e8abcabb58169cf4ad60b11be23cd7384c051a40ed2b23490d842bab
  # monero-source-v0.18.5.4.tar.bz2`, the same digest. Its signature was checked
  # with gpg in an isolated home directory against binaryfate.asc taken from
  # monero-project/monero utils/gpg_keys/ at ref v0.18.5.4, fingerprint
  # 81AC 591F E9C4 B65C 5806 AFC3 F0AF 4D46 2A0B DF92: "Good signature from
  # binaryFate". The key and the digest list come from two different hosts
  # (github.com and www.getmonero.org); the key's owner was not checked beyond
  # that.
  sha256 = {
    "0.18.5.4" = "3c5aabb6e8abcabb58169cf4ad60b11be23cd7384c051a40ed2b23490d842bab"
  }
}

provides = [
  "bin/monerod",
  "bin/monero-wallet-cli",
  "bin/monero-wallet-rpc",
]

dependencies = {
  # BOOST_MIN_VER 1.62 (CMakeLists.txt:1088); components filesystem thread
  # date_time chrono serialization program_options locale (:1096). The old
  # fragment said ^1.66.
  "boost.org" = "^1.66"

  # find_package(OpenSSL REQUIRED) (:592).
  "openssl.org" = "^3"

  # find_path zmq.h / find_library zmq, both FATAL_ERROR when absent (:1206-1222).
  "zeromq.org" = "^4.2"

  # find_library sodium (:1212); its include path is then REQUIRED (:1236-1245).
  "libsodium.org" = "*"

  # libunbound: README.md:176 "libunbound 1.4.16 ... YES (required)" for the
  # DNS resolver.
  "unbound.net" = "^1.4"

  # USE_READLINE ON (:1174), optional at configure time; named in so the
  # wallet has line editing.
  "gnu.org/readline" = "*"
}

build {
  dependencies = {
    "cmake.org"                  = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # Every prefix goes on CMAKE_PREFIX_PATH so find_package, find_path and
      # find_library look there; BOOST_IGNORE_SYSTEM_PATHS (:407) keeps boost
      # from being found on the host.
      "-DCMAKE_PREFIX_PATH={{deps.boost.org.prefix}};{{deps.openssl.org.prefix}};{{deps.zeromq.org.prefix}};{{deps.libsodium.org.prefix}};{{deps.unbound.net.prefix}};{{deps.gnu.org/readline.prefix}}",
      "-DBOOST_ROOT={{deps.boost.org.prefix}}",
      "-DBOOST_IGNORE_SYSTEM_PATHS=ON",

      # The source tarball has no .git; without this :357-367 runs `git
      # submodule status` and refuses.
      "-DMANUAL_SUBMODULES=1",

      # Point 3.
      "-DARCH=default",

      # Dynamic link to this tree's libraries (:475, STATIC default false on a
      # normal host) and internal libraries static (:478-482).
      "-DSTATIC=OFF",
      "-DBUILD_SHARED_LIBS=OFF",

      # Point 2: optional probes named off. Trezor needs protobuf, libusb and
      # Python (cmake/CheckTrezor.cmake:1-4); HIDAPI and libunwind are found
      # from the host otherwise.
      "-DUSE_DEVICE_TREZOR=OFF",
      "-DCMAKE_DISABLE_FIND_PACKAGE_HIDAPI=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_Libunwind=ON",
      "-DSTACK_TRACE=OFF",

      # Not for a consumer: tests, doxygen docs (:412-413), ccache (:51),
      # sanitizers (:514), coverage (:630), clang-tidy (:79-80), GUI deps (:1298).
      "-DBUILD_TESTS=OFF",
      "-DBUILD_DOCUMENTATION=OFF",
      "-DUSE_CCACHE=OFF",
      "-DSANITIZE=OFF",
      "-DCOVERAGE=OFF",
      "-DUSE_CLANG_TIDY_C=OFF",
      "-DUSE_CLANG_TIDY_CXX=OFF",
      "-DBUILD_GUI_DEPS=OFF",

      # :1025 USE_LTO defaults false; stated so that the build is not changed
      # by a cache variable on the host.
      "-DUSE_LTO=OFF",

      # :161, :169 default OFF.
      "-DRELINK_TARGETS=OFF",
      "-DSTRIP_TARGETS=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
for b in monerod monero-wallet-cli monero-wallet-rpc; do
  test -x "{{prefix}}/bin/$b"
done
# src/version.cpp.in:2 DEF_MONERO_VERSION is the project version, and
# MONERO_VERSION_FULL is "<version>-<tag>".
OUT="$("{{prefix}}/bin/monerod" --version)"
case "$OUT" in
  *"{{version.raw}}"*) ;;
  *) echo "monerod --version printed '$OUT', not {{version.raw}}" >&2; exit 1 ;;
esac
OUT="$("{{prefix}}/bin/monero-wallet-cli" --version)"
case "$OUT" in
  *"{{version.raw}}"*) ;;
  *) echo "monero-wallet-cli --version printed '$OUT'" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                       # :357-367 submodule check, MANUAL_SUBMODULES; :407 BOOST_IGNORE_SYSTEM_PATHS; :412-413 docs, tests; :475-482 STATIC, BUILD_SHARED_LIBS; :551-561 libunwind, STACK_TRACE; :592 OpenSSL REQUIRED; :605 HIDAPI; :618-623 ARCH; :1025 USE_LTO; :1088-1111 Boost 1.62 and components; :1174-1193 USE_READLINE; :1206-1255 zmq and sodium lookups
    "README.md",                            # :169-191 the dependency table; :259-306 `make` and the cmake release build
    "Makefile",                             # :90-95 the release target is cmake -D CMAKE_BUILD_TYPE=Release plus make
    "cmake/CheckTrezor.cmake",              # :1-4 USE_DEVICE_TREZOR and its options
    "src/daemon/CMakeLists.txt",            # :74 OUTPUT_NAME monerod; :75 install
    "src/simplewallet/CMakeLists.txt",      # :64 OUTPUT_NAME monero-wallet-cli; :65 install
    "src/wallet/CMakeLists.txt",            # :104 OUTPUT_NAME monero-wallet-rpc; :105 install
    "src/blockchain_utilities/CMakeLists.txt",  # the install(TARGETS blockchain_* DESTINATION bin) lines
    "src/version.cpp.in",                   # :2 DEF_MONERO_VERSION
    "LICENSE",                              # BSD 3-clause
  ]

  consulted = [
    "projects/github.com/awslabs/aws-c-common in this tree",  # the cmake configure/build/install shape
  ]

  note = <<EOT
⚠ THE SOURCE RUNG: two witnesses from different hosts; the digest list is
clear-signed and the signature was verified. That the key belongs to the
Monero release signer rests on the key file being shipped inside the project's
own repository at the release tag.

⚠ NO LEDGER OR TREZOR SUPPORT, and no stack traces: see point 2 of the header.

⚠ SELECTED BY READING, NOT TRIED: that boost.org in this tree (1.92) is accepted
by 0.18.5.4's code (BOOST_MIN_VER is a floor, no ceiling was read); that the
tree's boost builds every component listed above; that CMAKE_DISABLE_FIND_
PACKAGE_<name> switches off find_package(HIDAPI) and find_package(Libunwind)
(the module files were not read); that BUILD_DOCUMENTATION=OFF and the cmake
install step place the three binaries in bin/ (install(TARGETS ... DESTINATION
bin) was read, an install run was not); that `--version` of monerod prints the
version string.

⛔ NOT BUILT by the factory, and not by hand. Lint only. The first factory run is
this file's test.
EOT
}
