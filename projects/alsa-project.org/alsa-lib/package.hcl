# alsa-lib — the ALSA userspace library (libasound, alsa/asoundlib.h).
#
# ⛔ WRITTEN FROM ALSA-LIB'S OWN FILES at 1.2.16 (go-zpkg/packages#440 step 1).
# The `alsa-sys` crate that sniffnet.net links needs it through pkg-config
# (it panics when the module is missing) and no recipe existed.

summary = "ALSA userspace library: libasound and alsa/asoundlib.h"

# COPYING is the GNU Lesser General Public License, "Version 2.1, February
# 1999". (The aserver and utils programs carry their own licences, which this
# recipe does not ship as `provides`.)
license = "LGPL-2.1-or-later"

# ALSA is the Linux sound subsystem.
platforms = ["linux"]

versions {
  github = "alsa-project/alsa-lib"
}

distributable {
  # The STORED release archive on alsa-project.org.
  #
  # 1.2.16.1: 1130309 bytes, fetched with `zpkb sourcepin`, which also verified
  # alsa-lib-1.2.16.1.tar.bz2.sig against
  # https://www.alsa-project.org/files/pub/gpg-release-key-v1.txt: good
  # signature by "ALSA Release Team (Package Signing Key v1)
  # <release@alsa-project.org>", made 2026-06-12. The configure.ac line numbers
  # cited below were read at 1.2.16 and re-checked identical at 1.2.16.1.
  #
  # THE FINGERPRINT COMES FROM A DIFFERENT PLACE THAN THE KEY: the project's
  # Download page (https://www.alsa-project.org/wiki/Download) prints "GPG
  # signing key fingerprint: F04D F507 37AC 1A88 4C4B 3D71 8380 596D A6E5 9C91"
  # and the key block is a separate file; both agree. No keyserver was asked.
  url              = "https://www.alsa-project.org/files/pub/lib/alsa-lib-{{version.raw}}.tar.bz2"
  strip-components = 1

  sha256 = {
    "1.2.16.1" = "f740db7f488255944ffd4428416ee3390a96742856916433df468c281436480e"
  }
}

dependencies = {}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # ⛔ THE OPTIONAL PARTS ARE NAMED. `--disable-python` (configure.ac:435) is the
  # one that is auto-detected: without it the build looks for a host Python and
  # builds the Python bindings against whatever it finds. `--disable-resmgr`
  # (:354) names a default-off feature explicitly. The configuration and plugin
  # directories are written out (:87, :106) so they are the prefix's and not a
  # guess; the components (mixer, pcm, rawmidi, hwdep, seq, ucm, topology,
  # :401-:419) stay at their default of enabled, because libasound's callers
  # (alsa-sys, cpal) use the PCM and mixer APIs and the rest is part of the
  # library.
  script = [
    "./configure --prefix={{prefix}} --with-configdir={{prefix}}/share/alsa --with-plugindir={{prefix}}/lib/alsa-lib --disable-python --disable-resmgr",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⚠ NO `provides`: the library installs headers, libasound and alsa.pc. The
# aserver program (aserver/Makefile.am:1) is built only with the shm PCM plugin
# (Makefile.am:13) and is not asserted here because the build was not run.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/alsa/asoundlib.h",
    "pkg-config --exists alsa",
    "test \"$(pkg-config --modversion alsa)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libasound.* > /dev/null",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <alsa/asoundlib.h>

int main(void) {
  const char *v = snd_asoundlib_version();
  if (v == NULL || strlen(v) == 0) {
    puts("no library version");
    return 1;
  }
  printf("libasound %s\n", v);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o probe $(pkg-config --cflags --libs alsa)"
    },
    "./probe",
  ]
}

provenance {
  read = [
    "configure.ac",      # :3 AC_INIT 1.2.16.1; :87 configdir; :106 plugindir; :354 resmgr; :401-:419 components; :435 python
    "Makefile.am",       # :13 aserver only with the shm PCM plugin
    "aserver/Makefile.am", # :1 bin_PROGRAMS = aserver
    "COPYING",           # GNU Lesser General Public License, Version 2.1
    "configure --help",
  ]

  consulted = [
    "https://www.alsa-project.org/wiki/Download",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

  signature   https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2.sig
  key         https://www.alsa-project.org/files/pub/gpg-release-key-v1.txt
  identity    ALSA Release Team (Package Signing Key v1) <release@alsa-project.org>
  fingerprint F04DF50737AC1A884C4B3D718380596DA6E59C91, printed on the Download page
  signed at   2026-06-12

The licence is read from COPYING (LGPL, Version 2.1) and written as
"or-later" because the library sources carry the usual "either version 2.1 of
the License, or (at your option) any later version" notice; that notice was not
re-read file by file.

⛔ THE BUILD AND THE TEST BLOCK WERE NOT RUN: NOT BUILT (this host is not
Linux). Stated rather than implied.
EOT
}
