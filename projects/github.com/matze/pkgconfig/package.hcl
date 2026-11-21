# github.com/matze/pkgconfig — pkgconfig: a Python interface to pkg-config.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a build-time
# dependency of borgbackup.org (`pkgconfig` in its pyproject.toml:75).

summary = "pkgconfig: Python interface to the pkg-config command"

# pyproject.toml:8 `license = "MIT"`; the sdist's LICENSE is the MIT text
# ("Permission is hereby granted, free of charge, ...").
license = "MIT"

versions {
  github = "matze/pkgconfig/tags"
}

# The module only runs the `pkg-config` executable (src/pkgconfig/pkgconfig.py
# :108 and :123 take $PKG_CONFIG or `pkg-config`, :93 raises when it is
# missing), so the program is a run-time dependency. pyproject.toml:21 asks for
# Python ^3.9.0.
dependencies = {
  "python.org"                  = "^3.9"
  "freedesktop.org/pkg-config"  = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/p/pkgconfig/pkgconfig-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and the same as the sha256 PyPI's simple index
  # (pypi.org/simple/pkgconfig/) records for the sdist.
  sha256 = {
    "1.6.0" = "4a5a6631ce937fafac457104a40d558785a658bbdca5c49b6295bc3fd651907f"
  }
}

build {
  dependencies = {
    "github.com/python-poetry/poetry-core" = "*"
  }

  script = [
    {
      # pyproject.toml:2-3 requires ["poetry_core>=1.0.0"], backend
      # poetry.core.masonry.api; the version is static (:7).
      run = <<EOT
set -eu
python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
EOT
    },
  ]
}

runtime {
  env = {
    PYTHONPATH = "{{prefix}}/lib/python{{deps.python.org.version.major}}.{{deps.python.org.version.minor}}/site-packages:$PYTHONPATH"
  }
}

test {
  script = [
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
cat > probe.py <<'PYEOF'
import importlib.metadata, pkgconfig
assert importlib.metadata.version("pkgconfig") == "{{version.raw}}"
assert pkgconfig.exists("pkg-config")
print(pkgconfig.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "pkgconfig was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml",                # :2-3 build-system poetry_core, poetry.core.masonry.api; :7 version; :8 license MIT; :21 python ^3.9.0
    "src/pkgconfig/pkgconfig.py",    # :93, :108, :123 it runs the pkg-config executable
    "LICENSE",                       # the MIT text
  ]

  consulted = [
    "pypi.org/simple/pkgconfig/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The probe asserts that pkg-config can find a package called `pkg-config`, which
assumes the tree's freedesktop.org/pkg-config installs pkg-config.pc; that has
not been checked.
EOT
}
