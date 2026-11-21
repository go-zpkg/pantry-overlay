# lpeg — parsing expression grammars for Lua (Roberto Ierusalimschy, PUC-Rio).
#
# ⛔ WRITTEN FROM LPEG'S OWN FILES at 1.1.0 (go-zpkg/packages#440 step 1), for
# neovim.io, which links it. Built against the Lua 5.1 of `lua.org`:
# lptypes.h:28 handles LUA_VERSION_NUM == 501.

summary = "Parsing expression grammars for Lua"

# lpeg.html:1391 "Copyright © 2007-2023 Lua.org, PUC-Rio." followed by the MIT
# permission text.
license = "MIT"

versions {
  # The project page links its newest release only (lpeg.html:1378), which is
  # all the "newest it resolves" needs.
  url   = "https://www.inf.puc-rio.br/~roberto/lpeg/"
  match = "/lpeg-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^lpeg-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://www.inf.puc-rio.br/~roberto/lpeg/lpeg-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.1.0: 78042 bytes, fetched with `curl` and hashed with `shasum -a 256`.
  # The project publishes NO checksum and NO signature, so the second witness is
  # a second, independent FETCH: NetBSD's pkgsrc distfiles mirror
  # (ftp.netbsd.org/pub/pkgsrc/distfiles/lpeg-1.1.0.tar.gz, another host) served
  # the same 78042 bytes with the same digest.
  sha256 = {
    "1.1.0" = "4b155d67d2246c1ffa7ad7bc466c1ea899bbc40fef0257cc9c03cecbaed4352a"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gcc"  = "*"
    "lua.org"      = "^5.1"
  }

  # makefile:2 LUADIR is where lua.h is looked for (-I$(LUADIR), :28). The
  # makefile has two targets and NO install: linux (:34-35, -shared) and macosx
  # (:38-39, -bundle). neovim's cmake/FindLpeg.cmake:2-9 searches lpeg.so under
  # lua/5.1 and REFUSES, on Darwin, a library built as a bundle rather than a
  # dylib, so on Darwin the link line is overridden to `-dynamiclib`, which
  # Lua's dlopen-based require loads just as well.
  #
  # re.lua (the `re` module) is installed beside it: it is LPeg's own regular-
  # expression front end and a plain Lua file.
  script = [
    "if [ \"$(uname -s)\" = Darwin ]; then DLL=\"-dynamiclib -undefined dynamic_lookup\"; else DLL=\"-shared -fPIC\"; fi",
    "make --jobs {{ hw.concurrency }} lpeg.so LUADIR={{deps.lua.org.prefix}}/include \"DLLFLAGS=$DLL\"",
    "mkdir -p {{prefix}}/lib/lua/5.1 {{prefix}}/share/lua/5.1",
    "cp lpeg.so {{prefix}}/lib/lua/5.1/lpeg.so",
    "cp re.lua {{prefix}}/share/lua/5.1/re.lua",
  ]
}

# ⚠ NO `provides`: the install is two Lua modules, no program.

test {
  dependencies = {
    "lua.org" = "^5.1"
  }

  script = [
    "test -f {{prefix}}/lib/lua/5.1/lpeg.so",
    "test -f {{prefix}}/share/lua/5.1/re.lua",
    "LUA_CPATH=\"{{prefix}}/lib/lua/5.1/?.so\" LUA_PATH=\"{{prefix}}/share/lua/5.1/?.lua\" lua -e 'local l = require \"lpeg\"; assert(l.version == \"LPeg {{version.raw}}\"); assert(l.match(l.P\"a\" ^ 1, \"aaab\") == 4); local re = require \"re\"; assert(re.match(\"abc\", \"[a-c]+\") == 4)'",
  ]
}

provenance {
  read = [
    "makefile",     # :2 LUADIR; :28 CFLAGS -std=c99 -I$(LUADIR) -fPIC; :34-39 linux/macosx targets; :41-42 lpeg.so; no install target
    "lptypes.h",    # :18 VERSION "1.1.0"; :28 LUA_VERSION_NUM == 501 branch
    "lptree.c",     # :1394 version() returns "LPeg " VERSION
    "lpeg.html",    # :1378 download link; :1391 Copyright 2007-2023 Lua.org, PUC-Rio; MIT text
    "README.md",
  ]

  consulted = [
    "https://www.inf.puc-rio.br/~roberto/lpeg/",
    "https://github.com/neovim/neovim/blob/v0.12.6/cmake/FindLpeg.cmake",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; the test block has not been
run on either platform. One point is worth a reviewer's attention: the Darwin
link line replaces the makefile's -bundle with -dynamiclib, a choice taken from
neovim's FindLpeg.cmake, not from LPeg.

  checksum   no published checksum or signature; NetBSD pkgsrc distfile mirror
             served the same 78042 bytes, sha256 4b155d67...4352a
EOT
}
