# ⛔⛔ SECURITY: THIS RECIPE WAS CAPPED AT curl 8.17.0 BY AN `ignore` BLOCK
# WHOSE STATED REASON THIS VERY FRAGMENT ALREADY SATISFIES.
#
# Upstream's versions block reads:
#
#   # 8.18 requires opensslv3
#   # TODO: make another package for curl with openssl3
#   ignore:
#     - /8\.1[8-9]\..*/
#     - /8\.2\d\..*/
#     - /9\.\d+\.\d+/
#
# The reason is correct and was verified in curl's own files, not taken from the
# comment: `m4/curl-openssl.m4:286` tests
#
#   #if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
#
# and `:293` is `AC_MSG_ERROR([OpenSSL 3.0.0 or greater required.])`.
#
# ⭐ But `openssl.org = "^3"` below — which this fragment has carried since it
# corrected upstream's `^1.1` — resolves to the newest 3.x, i.e. ≥ 3.0.0. The
# condition the cap exists for is met. The cap is not.
#
# ⛔⛔ AND THE COST IS NOT STALENESS, IT IS CVEs. curl's newest release is
# **8.23.0** (99 releases read from the GitHub API), so the recipe is SIX
# minors behind on a package whose whole job is to fetch things off the
# network. curl.se/docs/vuln-8.17.0.html lists 61 advisories that affect
# 8.17.0 and are first fixed in 8.18.0 or later.
#
# ⚠ The 61 is a COUNT FROM A LISTING, derived by reading the page's "Last
# affected" column, which is not the same as a stated "fixed in". One was
# verified on its own advisory page instead of trusting the derivation, and it
# is the worst of them:
#
#   CVE-2026-92392  HTTP/2 upload Use-After-Free
#   Severity: High (CWE-416)
#   "Affected versions: curl 8.12.0 to and including 8.22.0"
#   "Not affected versions: curl < 8.12.0 and >= 8.23.0"
#
# So 8.17.0 is inside the affected range and 8.23.0 is where it stops, stated
# by the page in the negative. ⛔ That page's own `Fixed-in:` field is a COMMIT
# URL, not a version — which is why the other 60 are reported here as derived
# rather than as read.

dependencies = {
  "curl.se/ca-certs" = "*"
  "nghttp2.org"      = "*"

  # ⛔ NOT WIDENED TO `^4`, DELIBERATELY. openssl.org resolves to 4.1.0 as its
  # newest, and curl states only a ≥ 3.0.0 floor, so `^4` would satisfy curl's
  # configure. But gnu.org/wget 1.25.0 FAILS to compile against OpenSSL 4.1.0
  # (measured in go-zpkg/recipes#120: `src/openssl.c:230` calls
  # `SSLv3_client_method`, which OpenSSL 4 removed), so "the floor is met" is
  # not evidence that a major works. curl against OpenSSL 4 has not been
  # measured here, and an unmeasured widening in a TLS dependency is the last
  # place to guess. `^3` is what the cap removal needs and all it needs.
  "openssl.org" = "^3"

  "zlib.net" = "^1.2.11"
}

# ⚠ CARRIED IN FULL, because an overlay list REPLACES rather than merges
# (recipefile/overridden_test.go: "a list must replace"). `github` and `strip`
# are upstream's, unchanged; only the ignore list differs, and the difference
# is the two patterns that are gone.
versions {
  github = "curl/curl/releases"
  strip  = "/^curl /"

  ignore = [
    # ⛔ `/8\.1[8-9]\..*/` and `/8\.2\d\..*/` ARE REMOVED. They are what capped
    # the recipe at 8.17.0 for an OpenSSL 3 requirement that `openssl.org ^3`
    # above already satisfies. Measured A/B: 91 versions resolving with them,
    # newest 8.17.0; without them, the newest is 8.23.0.
    #
    # ⭐ `/9\.\d+\.\d+/` IS KEPT, and that is a decision rather than an
    # oversight. No curl 9 exists yet — the newest of 99 releases is 8.23.0 —
    # so the pattern guards a major version bump that nobody has read. Removing
    # it would let a future curl 9.0.0 resolve the day it ships, into a recipe
    # whose flags and dependencies were written for 8.x. A major deserves its
    # own reading; the 8.x line needed only its reason checked.
    #
    # ⛔ And upstream's "TODO: make another package for curl with openssl3" is
    # now moot rather than pending: the second package it proposes is what this
    # fragment already is.
    "/9\\.\\d+\\.\\d+/",
  ]
}
