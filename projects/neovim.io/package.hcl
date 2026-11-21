# neovim — Vim-based text editor.
#
# ⛔ WRITTEN FROM NEOVIM'S OWN FILES at v0.12.6 (go-zpkg/packages#440 step 1).
# Built with PUC Lua 5.1 (`lua.org`) and PREFER_LUA=ON, NOT LuaJIT (`luajit.org`
# stays a fragment: it has no pinnable release). Every dependency comes from the
# tree: no `cmake.deps` build is run, so none of its USE_BUNDLED_* options apply.

summary = "Vim-based text editor"

# LICENSE.txt:3-4: Apache 2.0, except parts contributed under the Vim license.
license = "Apache-2.0"

versions {
  github = "neovim/neovim/tags"
  strip  = "/^v/"
}

distributable {
  # The tag archive: the release carries only binary assets (nvim-linux-*,
  # nvim-macos-*, nvim-win*, appimages), no source asset. 13722771 bytes.
  #
  # Witnesses, three that agree: `zpkb sourcepin`; codeload.github.com fetched
  # and `shasum -a 256`; Homebrew's formula API `stable` 0.12.6 `checksum`
  # (a separate party's digest of the same archive).
  url              = "https://github.com/neovim/neovim/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "0.12.6" = "8629fdc5eb951daf89a76f68cad12f2f1e03fab0d539150ba3fe6d177d254b7f"
  }
}

# lpeg is a shared module (lpeg.so) found at configure time and loaded at run
# time, so it must stay installed. libintl comes from gettext. libiconv is not
# named: iconv.h (FindIconv.cmake:4-6) is supplied by the C library on Linux
# and macOS.
dependencies = {
  "gnu.org/gettext"      = "^1"
  "inf.puc-rio.br/lpeg"  = "^1.1"
}

build {
  dependencies = {
    "cmake.org"                    = "^3"
    "gnu.org/make"                 = "*"
    "gnu.org/gcc"                  = "*"
    "lua.org"                      = "^5.1"
    "github.com/luvit/luv"         = "^1.53"
    "libuv.org"                    = "^1.53"
    "inf.puc-rio.br/lpeg"          = "^1.1"
    "gnu.org/gettext"              = "^1"
    "github.com/neovim/unibilium"  = "^2"
    "tree-sitter.github.io"        = "^0.27"
    "github.com/JuliaStrings/utf8proc" = "^2"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",
      "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON",

      # CMakeLists.txt:105 prepends .deps/usr (absent: no cmake.deps build) to
      # CMAKE_PREFIX_PATH; every find module (cmake/Find.cmake find_library2
      # searches the prefix first) then resolves from the tree.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/luvit/luv.prefix}};{{deps.libuv.org.prefix}};{{deps.inf.puc-rio.br/lpeg.prefix}};{{deps.github.com/neovim/unibilium.prefix}};{{deps.tree-sitter.github.io.prefix}};{{deps.github.com/JuliaStrings/utf8proc.prefix}};{{deps.gnu.org/gettext.prefix}};{{deps.lua.org.prefix}}",

      # CMakeLists.txt:187-195 looks for `luajit` unless PREFER_LUA; src/nvim/
      # CMakeLists.txt:62-67 then does find_package(Lua 5.1 EXACT) and
      # :394-399 uses the vendored bit.c. LUA_GEN_PRG defaults to LUA_PRG
      # (CMakeLists.txt:202-206).
      "-DPREFER_LUA=ON",
      "-DLUA_PRG={{deps.lua.org.prefix}}/bin/lua",
      "-DLUA_INCLUDE_DIR={{deps.lua.org.prefix}}/include",

      # CMakeLists.txt:132-134, every optional dependency named.
      "-DENABLE_LIBINTL=ON",
      "-DENABLE_UNIBILIUM=ON",
      "-DENABLE_WASMTIME=OFF",
      "-DENABLE_LTO=ON",

      # CMakeLists.txt:165-168.
      "-DENABLE_ASAN_UBSAN=OFF",
      "-DENABLE_MSAN=OFF",
      "-DENABLE_TSAN=OFF",

      # src/nvim/po/CMakeLists.txt:1-4: OFF returns early, so no msgfmt or
      # xgettext is needed. Bundled treesitter parsers
      # (cmake.deps USE_BUNDLED_TS_PARSERS) are not built either.
      "-DENABLE_TRANSLATIONS=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

provides = ["bin/nvim"]

test {
  script = [
    "nvim --version",
    "echo 'print(vim.uv.version_string())' > t.lua",
    "nvim --headless -u NONE -l t.lua",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                      # :105 prefix path; :132-134 and :165-168 options; :187-208 Lua interpreter, COMPILE_LUA
    "src/nvim/CMakeLists.txt",             # :27-59 find_package of every dependency; :62-67 PREFER_LUA; :394-399 bit.c
    "src/nvim/po/CMakeLists.txt",          # :1-4 ENABLE_TRANSLATIONS default OFF
    "cmake/Find.cmake",                    # find_library2 search order
    "cmake/FindLuv.cmake",                 # luv/luv.h, luv_a / luv
    "cmake/FindLpeg.cmake",                # lpeg.so under lua/5.1
    "cmake/FindTreesitter.cmake",          # tree_sitter/api.h, tree-sitter
    "cmake/FindUnibilium.cmake",           # unibilium.h
    "cmake/FindUTF8proc.cmake",            # utf8proc.h
    "cmake/FindLibuv.cmake",               # uv.h, uv_a / uv
    "cmake/FindIconv.cmake",               # :4-6 iconv.h
    "cmake/FindLibintl.cmake",             # :16-23 libintl.h, :46-55 link check
    "cmake.deps/CMakeLists.txt",           # :29-40 USE_BUNDLED options, :104-110 non-bundled Lua
    "BUILD.md",                            # :60 USE_BUNDLED default, :341-353 and :481 non-bundled usage
    "LICENSE.txt",                         # :3-4 Apache 2.0 plus Vim-licensed parts
  ]

  consulted = [
    "https://formulae.brew.sh/api/formula/neovim.json",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the test block has not been
run on either platform.

  source     tag archive v0.12.6, 13722771 bytes (no source release asset)
  witnesses  zpkb sourcepin, codeload fetch + shasum, Homebrew stable checksum
  Lua        PUC Lua 5.1 with PREFER_LUA=ON; luajit.org remains a fragment
  libiconv   not a dependency, iconv.h comes from the C library
  untested   FindLua needs only LUA_INCLUDE_DIR here; the library is found
             through CMAKE_PREFIX_PATH
EOT
}
