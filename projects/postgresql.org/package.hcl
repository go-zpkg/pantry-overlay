dependencies = {
  "gnome.org/libxml2" = "~2.13"
  # No "gnome.org/libxslt" here, on purpose: it inherits the pantry's. A copy of
  # `"*"` in this fragment shadowed pkgxdev/pantry 3af085f (2026-11-19,
  # pantry#15143), which pins =1.1.43 because 1.1.45 links libxml2.so.16 (2.14+)
  # while declaring libxml2 '*', so configure's test program cannot load it with
  # libxml2 held at ~2.13 above. A pin copied here would drift the same way.
  "gnu.org/readline" = "*"
  "lz4.org"          = "*"
  "openssl.org"      = "^3"
  "unicode.org"      = "^73"
  "zlib.net"         = "*"
}
