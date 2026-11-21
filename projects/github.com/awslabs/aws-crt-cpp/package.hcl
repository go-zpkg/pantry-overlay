# aws-crt-cpp — AWS Common Runtime: the C++ wrapper over the C libraries, the layer aws-sdk-cpp links
#
# ⛔ WRITTEN FROM AWS-CRT-CPP'S OWN FILES at v0.44.4 (go-zpkg/packages#440 step 1), the last
# link of the chain before aws-sdk-cpp. Its eleven C libraries, s2n-tls and OpenSSL are
# recipes of their own in this tree, so it is built with BUILD_DEPS=OFF and finds them in
# config mode instead of compiling the git submodules under crt/.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to commit 07b1d9a9 = tag
# v0.44.4 (GitHub contents API). The versions block resolves ONLY that tag, so
# --check-newest-pinned cannot demand a newer one whose C libraries were not read.

summary = "AWS Common Runtime C++ wrapper (aws-crt-cpp), the layer aws-sdk-cpp links"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-crt-cpp/tags"
  strip  = ["/^v/"]

  # Only 0.44.4; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!0\\.44\\.4$)/"]
}

distributable {
  # No stored release asset, so the generated tag archive. The crt/ submodules are not needed:
  # BUILD_DEPS=OFF never reads them.
  url              = "https://github.com/awslabs/aws-crt-cpp/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 0.44.4: 427609 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-crt-cpp/tar.gz/refs/tags/v0.44.4: same bytes, same digest.
  sha256 = {
    "0.44.4" = "b8a68949f84b785d37188df2baaaa02a27c84b978b4799be6220f2fa39f75eeb"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-auth"          = "*"
    "github.com/awslabs/aws-c-cal"           = "*"
    "github.com/awslabs/aws-c-common"        = "*"
    "github.com/awslabs/aws-c-compression"   = "*"
    "github.com/awslabs/aws-c-event-stream"  = "*"
    "github.com/awslabs/aws-c-http"          = "*"
    "github.com/awslabs/aws-c-io"            = "*"
    "github.com/awslabs/aws-c-mqtt"          = "*"
    "github.com/awslabs/aws-c-s3"            = "*"
    "github.com/awslabs/aws-c-sdkutils"      = "*"
    "github.com/awslabs/aws-checksums"       = "*"
    "github.com/aws/s2n-tls"                 = "*"
    "openssl.org"                            = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:155 find_package(aws-c-common REQUIRED) and :382-390 aws_use_package() of the
      # nine libraries it links; their own config files pull in the rest. Every prefix of the
      # closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-auth.prefix}};{{deps.github.com/awslabs/aws-c-cal.prefix}};{{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.github.com/awslabs/aws-c-compression.prefix}};{{deps.github.com/awslabs/aws-c-event-stream.prefix}};{{deps.github.com/awslabs/aws-c-http.prefix}};{{deps.github.com/awslabs/aws-c-io.prefix}};{{deps.github.com/awslabs/aws-c-mqtt.prefix}};{{deps.github.com/awslabs/aws-c-s3.prefix}};{{deps.github.com/awslabs/aws-c-sdkutils.prefix}};{{deps.github.com/awslabs/aws-checksums.prefix}};{{deps.github.com/aws/s2n-tls.prefix}};{{deps.openssl.org.prefix}}",

      # CMakeLists.txt:318: no type given to add_library, so BUILD_SHARED_LIBS decides: shared,
      # like the C libraries it links and like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # CMakeLists.txt:29 include(CTest) defines BUILD_TESTING; :447-456 tests and bin/ only under it.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:3: the point of this recipe. The C libraries are the recipes beside it.
      "-DBUILD_DEPS=OFF",

      # CMakeLists.txt:6: only checked when BUILD_DEPS is ON; stated OFF.
      "-DENFORCE_SUBMODULE_VERSIONS=OFF",

      # CMakeLists.txt:4: a TLS-less build. OFF, so aws-c-io's s2n-tls backend is used.
      "-DBYO_CRYPTO=OFF",

      # CMakeLists.txt:5 and :65-66: only read inside the BUILD_DEPS block, where it picks OpenSSL
      # over AWS-LC for libcrypto. The same choice (OpenSSL, the tree's openssl.org) is made by
      # the aws-c-cal and s2n-tls recipes; ON here keeps the three statements alike.
      "-DUSE_OPENSSL=ON",

      # CMakeLists.txt:16: needs a proxy server installed locally; OFF.
      "-DENABLE_PROXY_INTEGRATION_TESTS=OFF",

      # CMakeLists.txt:9: AWS_IOT_SDK_VERSION is declared with option() and no default, so it is
      # unset; it only changes the version string that the IoT SDK reports. Left unset on purpose.

      # Options of aws-c-common's cmake modules, which this CMakeLists includes from the
      # installed aws-c-common (CMakeLists.txt:161-162, :224, :392: AwsCFlags, AwsSharedLibSetup,
      # AwsCheckHeaders, AwsSanitizers; read at v1.0.5: AwsCFlags.cmake:8-14,
      # AwsSanitizers.cmake:6-8, AwsFeatureTests.cmake:7, AwsCheckHeaders.cmake:10).
      # All stated, none left to a default.
      "-DUSE_CPU_EXTENSIONS=ON",
      "-DPERFORM_HEADER_CHECK=OFF",
      "-DENABLE_SANITIZERS=OFF",
      "-DENABLE_SANITIZER_RECOVERY=OFF",
      "-DAWS_ENABLE_LTO=OFF",
      "-DLEGACY_COMPILER_SUPPORT=OFF",
      "-DAWS_SUPPORT_WIN7=OFF",
      "-DAWS_WARNINGS_ARE_ERRORS=OFF",
      "-DAWS_ENABLE_TRACING=OFF",
      "-DAWS_STATIC_MSVC_RUNTIME_LIBRARY=OFF",
      "-DSTATIC_CRT=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# A library: elasticurl_cpp, mqtt5_app and mqtt5_canary are built only under BUILD_TESTING.
provides = []

test {
  script = [
    "test -f {{prefix}}/include/aws/crt/Api.h",
    # The package file aws-sdk-cpp find_package()s (CMakeLists.txt:439-441 installs it under lib/cmake/aws-crt-cpp).
    "test -f {{prefix}}/lib/cmake/aws-crt-cpp/aws-crt-cpp-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :3-16 options; :21-22 and cmake/AwsCrtCppGetVersion.cmake (version from the VERSION file, git optional); :50-159 BUILD_DEPS block and its else branch; :161-162 included modules; :318 add_library; :382-390 aws_use_package; :397-407 header installs; :423-445 export, config and version files; :447-457 tests and bin/ under BUILD_TESTING",
    "cmake/AwsCrtCppGetVersion.cmake # reads VERSION; git is only tried, so a tarball without .git works",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4).
CMAKE_CXX_STANDARD is left to the project's own default of 11 (CMakeLists.txt:34-36).

⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
