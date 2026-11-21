# lua — PUC-Rio Lua, pinned to the 5.1 series: the interpreter and C API that
# neovim's code generators, luv and lpeg are written against.
#
# ⛔ WRITTEN FROM LUA'S OWN FILES at 5.1.5 (go-zpkg/packages#440 step 1), to
# unblock neovim.io: neovim's CMakeLists.txt:187-195 requires a Lua interpreter
# (`luajit`, or `lua5.1`/`lua5.2`/`lua`), and LuaJIT cannot be pinned (no tags,
# no tarballs). THE SERIES IS A DECISION: 5.1, not 5.4. LuaJIT implements the 5.1
# language and ABI, so luv and lpeg built here are the ones neovim would also
# load under LuaJIT; a newer Lua would be a different language for them.

summary = "Lua 5.1 scripting language (PUC-Rio)"

# COPYRIGHT:12 "Copyright (C) 1994-2012 Lua.org, PUC-Rio." followed by the MIT
# permission text.
license = "MIT"

versions {
  # lua.org's download directory lists every release of every series. The match
  # keeps ONLY 5.1.x, so "the newest it resolves" is 5.1.5 (2012-02-13), the
  # last 5.1 release.
  url   = "https://www.lua.org/ftp/"
  match = "/lua-5\\.1\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^lua-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://www.lua.org/ftp/lua-{{version.raw}}.tar.gz"
  strip-components = 1

  # 5.1.5: 221213 bytes, fetched with `zpkb sourcepin`. The second witness is the
  # checksum the project PUBLISHES: https://www.lua.org/ftp/ lists
  # lua-5.1.5.tar.gz with sha256
  # 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333, the same
  # digest (an independent curl + `shasum -a 256` gave it too).
  sha256 = {
    "5.1.5" = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gcc"  = "*"
  }

  # Makefile:8 PLAT defaults to `none`, and src/Makefile:98-102 `linux` and
  # `macosx` both pull in -lreadline (-lhistory -lncurses on linux). Neither is
  # wanted: READLINE IS OFF, NAMED. luaconf.h:273 enables line editing only under
  # -DLUA_USE_READLINE, which this build does not define, so the REPL has none.
  #
  # What is on, from src/Makefile:113-116 (`posix`, `solaris`) and luaconf.h:
  #   -DLUA_USE_POSIX   (luaconf.h:54) mkstemp, popen, ...
  #   -DLUA_USE_DLOPEN  (luaconf.h:700) loadlib() through dlopen, needs -ldl
  # The executable must also export liblua's symbols so that a C module loaded
  # with require() resolves lua_* against it: -Wl,-E on ELF (src/Makefile:90),
  # nothing on Mach-O, where the linker exports them already for executables
  # that dlopen.
  #
  # luaconf.h:97 hard-codes LUA_ROOT "/usr/local/": the DEFAULT package.path
  # and package.cpath point there, whatever INSTALL_TOP is. Not patched; neovim
  # sets its own package paths.
  script = [
    "if [ \"$(uname -s)\" = Darwin ]; then LDX=\"\"; else LDX=\"-Wl,-E\"; fi",
    "make --jobs {{ hw.concurrency }} posix MYCFLAGS=\"-DLUA_USE_POSIX -DLUA_USE_DLOPEN\" MYLIBS=\"$LDX -ldl\"",
    "make install INSTALL_TOP={{prefix}}",

    # etc/lua.pc ships with prefix= /usr/local; rewrite that one line. It is
    # installed under both names pkg-config users ask for (`lua` and `lua5.1`).
    "mkdir -p {{prefix}}/lib/pkgconfig",
    "sed -e 's|^prefix=.*|prefix={{prefix}}|' etc/lua.pc > {{prefix}}/lib/pkgconfig/lua.pc",
    "cp {{prefix}}/lib/pkgconfig/lua.pc {{prefix}}/lib/pkgconfig/lua5.1.pc",
  ]
}

provides = [
  "bin/lua",
  "bin/luac",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  script = [
    "test -f {{prefix}}/include/lua.h",
    "test -f {{prefix}}/lib/liblua.a",
    "pkg-config --exists lua5.1",
    "test \"$(pkg-config --modversion lua5.1)\" = {{version.raw}}",
    "test \"$(lua -e 'io.write(_VERSION)')\" = 'Lua 5.1'",
    "luac -v > /dev/null",
  ]
}

provenance {
  read = [
    "Makefile",         # :8 PLAT none; :12-16 INSTALL_*; :44-47 what installs; :50-51 V 5.1, R 5.1.5
    "src/Makefile",     # :11 CFLAGS; :98-102 linux/macosx pull in readline; :112-113 posix; :116 solaris
    "src/luaconf.h",    # :39 LUA_USE_READLINE; :54 LUA_USE_POSIX; :97 LUA_ROOT; :273 readline; :700 LUA_USE_DLOPEN
    "etc/lua.pc",       # prefix= /usr/local; Libs: -llua -lm
    "COPYRIGHT",        # :12 Copyright 1994-2012 Lua.org, PUC-Rio; MIT text
  ]

  consulted = [
    "https://www.lua.org/ftp/",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the test block has not been
run on either platform.

  checksum   lua.org/ftp/ publishes lua-5.1.5.tar.gz sha256 2640fc56...695333
  published  2012-02-13, last release of the 5.1 series
EOT
}
