# palletsprojects.com/markupsafe — MarkupSafe: the HTML-safe string type Jinja2
# needs, with its optional C speedups built.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#431, #440), as a
# dependency of Jinja2, which systemd's meson.build:1735 requires.

summary = "MarkupSafe: safe HTML string escaping for Python, with C speedups"

# pyproject.toml:6 `license = "BSD-3-Clause"`, :7 license-files LICENSE.txt.
license = "BSD-3-Clause"

versions {
  github = "pallets/markupsafe/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/m/markupsafe/markupsafe-{{version.raw}}.tar.gz"
  strip-components = 1

  # 153777 bytes, fetched with `zpkb sourcepin`, and byte-identical to the
  # sha256 PyPI's JSON API (pypi.org/pypi/markupsafe/3.0.4/json) records for the
  # sdist.
  sha256 = {
    "3.0.4" = "2e9ad7dd851bf45fab9f75cbff4cb493fee9979e8d8c7c9c3ee119022518edd6"
  }
}

build {
  dependencies = {
    "gnu.org/gcc"        = "*"
    "pypa.io/setuptools" = "*"
  }

  script = [
    {
      # pyproject.toml:59-61 requires setuptools>=77, backend
      # setuptools.build_meta. The speedups are a C extension built here with the
      # declared compiler; MARKUPSAFE is not told to skip it (setup.py: the
      # extension is optional and falls back to pure Python if it fails).
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
import markupsafe
from markupsafe import Markup, escape
assert markupsafe.__version__ == "{{version.raw}}", markupsafe.__version__
assert str(escape("<a & b>")) == "&lt;a &amp; b&gt;"
assert str(Markup("<b>%s</b>") % "<i>") == "<b>&lt;i&gt;</b>"
print(markupsafe.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "markupsafe was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :3 version 3.0.4; :6-7 license BSD-3-Clause; :19 requires-python >=3.9; :59-61 setuptools>=77 and setuptools.build_meta
    "LICENSE.txt",    # "Copyright 2010 Pallets", BSD-3-Clause text
  ]

  consulted = [
    "pypi.org/pypi/markupsafe/3.0.4/json", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform. The install command is the one
pypa.io/setuptools and mesonbuild.com use.

⛔ NOT SIGNED. The digest is witnessed by PyPI's JSON API and by the bytes
`zpkb sourcepin` fetched, which agree.
EOT
}
