build {
  dependencies = {
    "facebook.com/zstd" = "*"
    linux = {
      "savannah.nongnu.org/acl" = "^2.3.1"
    }
    "lz4.org"     = "*"
    "openssl.org" = "^3"
    "python.org"  = "^3.10"
  }
  script = [
    "zpkvenv stage {{prefix}} {{version}}",
    "$${{prefix}}/venv/bin/pip install -r requirements.d/development.txt",
    "$${{prefix}}/venv/bin/pip install .",
    "zpkvenv seal {{prefix}} borg borgfs",
  ]

  env {
    BORG_LIBACL_PREFIX    = "{{deps.savannah.nongnu.org/acl.prefix}}"
    BORG_LIBLZ4_PREFIX    = "{{deps.lz4.org.prefix}}"
    BORG_LIBXXHASH_PREFIX = "{{deps.github.com/Cyan4973/xxHash.prefix}}"
    BORG_LIBZSTD_PREFIX   = "{{deps.facebook.com/zstd.prefix}}"
    BORG_OPENSSL_PREFIX   = "{{deps.openssl.org.prefix}}"
    TMPDIR                = "$(mktemp -d)"
  }
}
