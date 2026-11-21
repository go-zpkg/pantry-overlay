# luv — libuv bindings for Lua: the `vim.uv` layer of neovim.
#
# ⛔ WRITTEN FROM LUV'S OWN FILES at 1.53.0 (go-zpkg/packages#440 step 1), for
# neovim.io, which links libluv. Built against the PUC Lua 5.1 of `lua.org` and
# the libuv of `libuv.org`, not the copies luv vendors in deps/.

summary = "libuv bindings for Lua"

# LICENSE.txt is the Apache License, Version 2.0 (and cmake/Modules/FindLibuv.cmake
# carries the same notice, "Copyright 2016 The Luvit Authors").
license = "Apache-2.0"

versions {
  # Tags are `1.53.0-0`: the libuv version, a dash, and luv's own revision of the
  # binding. The `-N` is stripped, and when several revisions share a version the
  # resolver names ONE: `zpkb versions` answers 1.53.0 <- tag 1.53.0-0 (a
  # 1.53.0-1 tag exists, 2026-10-29, and is not resolvable), so the recipe pins
  # the -0 asset. Its CMakeLists.txt is byte-identical to the -1 one.
  github = "luvit/luv/tags"
  strip  = ["/-(\\d+)$/"]
}

distributable {
  # The RELEASE ASSET luv-1.53.0-1.tar.gz, not the tag archive: it is the one
  # the project builds and publishes, and it ships deps/ (lua-compat-5.3) that
  # the CMake build includes (CMakeLists.txt:223-229). 1584517 bytes.
  #
  # Witnesses: `zpkb sourcepin` and an independent curl + `shasum -a 256` of
  # the same URL gave the same digest. The project publishes no checksum file or
  # signature beside it; that is a second FETCH, not a second SOURCE, and the
  # provenance note says so.
  url              = "https://github.com/luvit/luv/releases/download/{{version.raw}}-0/luv-{{version.raw}}-0.tar.gz"
  strip-components = 1

  sha256 = {
    "1.53.0" = "fccabc7bb37fcc3b84ab258a19a862c55f67abc2059af0a744a1ae64119dfc6c"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
    "libuv.org"    = "^1.53"
    "lua.org"      = "^5.1"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_INSTALL_RPATH={{prefix}}/lib;{{deps.libuv.org.prefix}}/lib",

      # The two libraries by directory: FindLibuv.cmake:22-23 and Lua's
      # find_package both search CMAKE_PREFIX_PATH.
      "-DCMAKE_PREFIX_PATH={{deps.libuv.org.prefix}};{{deps.lua.org.prefix}}",

      # CMakeLists.txt:38-43: the engine defaults to LuaJIT. `Lua` is PUC Lua.
      "-DWITH_LUA_ENGINE=Lua",

      # CMakeLists.txt:45-50 defaults to `Static`, building a Lua out of deps/.
      # `System` (:119-145) uses ours, and wants LUA_INCLUDE_DIR.
      "-DLUA_BUILD_TYPE=System",
      "-DLUA_INCLUDE_DIR={{deps.lua.org.prefix}}/include",

      # CMakeLists.txt:18, :63-65: WITH_SHARED_LIBUV=ON takes libuv from the
      # tree through find_package(Libuv REQUIRED); OFF would build deps/libuv.
      "-DWITH_SHARED_LIBUV=ON",

      # All three products, named: the loadable module (require "luv"), the
      # static library and the shared library with its libluv.pc (installed
      # only with BUILD_SHARED_LIBS, CMakeLists.txt:327-334), which is what
      # neovim looks for.
      "-DBUILD_MODULE=ON",
      "-DBUILD_STATIC_LIBS=ON",
      "-DBUILD_SHARED_LIBS=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# ⚠ NO `provides`: the install is a Lua module, two libraries, headers and a
# pkg-config file (CMakeLists.txt:305-339); luv installs no program.

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "test -f {{prefix}}/include/luv/luv.h",
    "test -f {{prefix}}/lib/libluv.a",
    "test -f {{prefix}}/lib/pkgconfig/libluv.pc",
    "pkg-config --exists libluv",
    "ls {{prefix}}/lib/lua/5.1/luv.* > /dev/null",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                     # :15-18 options; :38-56 engine; :45-50 build type; :63-65 libuv; :119-145 System Lua; :213-216 Apple; :223-229 compat; :273 module dir; :295-339 installs
    "cmake/Modules/FindLibuv.cmake",      # :22-23 searches uv.h and libuv in CMAKE_PREFIX_PATH
    "libluv.pc.in",                       # Libs: -L${libdir} -lluv @LIBS@
    "LICENSE.txt",                        # Apache License 2.0
  ]

  consulted = [
    "https://github.com/luvit/luv/releases/tag/1.53.0-0",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the test block has not been
run on either platform.

  asset      luv-1.53.0-0.tar.gz, 1584517 bytes
  witnesses  zpkb sourcepin + independent curl/shasum: the same fetch twice;
             luv publishes no checksum file and no signature
  tag -1     1.53.0-1 exists (2026-10-29) but the version resolver cannot
             name it; CMakeLists.txt of -0 and -1 were diffed: identical
EOT
}
