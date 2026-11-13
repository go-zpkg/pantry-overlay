# This overlay exists for ONE line: upstream pins `openssl.org: ^1.1`, and
# this registry publishes no openssl 1.x — all 48 artifacts are 3.x or 4.x —
# so the recipe would die in the resolver before a compiler ran. openssl
# 1.1.1 has been end-of-life since September 2023.
#
# ⛔ EVERYTHING ELSE HERE MUST TRACK THE PANTRY, and did not. Copying the
# other pins to hold the file's shape froze them: upstream moved abseil to
# ^20260526 for grpc 1.85 (Mutex::lock, MutexLock(Mutex&)) and this said
# ^20250512 until 2026-10-26, when overlaycheck caught the drift — on a
# run of an UNCHANGED commit, because it compares against the pantry as it
# is today, not as it was at merge.
#
# ⛔ AND THEY MOVE TOGETHER. Upstream's own comment: re2 and protobuf must
# be built against the same abseil LTS line, and protobuf 36.2.0 is the
# build against 20260526 — earlier artifacts use 20250512 or 20250127 and
# mangle differently. Bumping abseil alone would have satisfied the check
# and broken the invariant it exists to protect.
dependencies = {
  "abseil.io"             = "^20260526"
  "c-ares.org"            = "*"
  "github.com/google/re2" = "*"
  linux = {
    "gnu.org/gcc/libstdcxx" = 14
    "protobuf.dev"          = "36.2.0"
  }
  "openssl.org" = "^3"
  "zlib.net"    = "*"
}
