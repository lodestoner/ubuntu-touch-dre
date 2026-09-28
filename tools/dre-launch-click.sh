#!/bin/sh
set -eu

profile=$1
shift
[ "$1" = -- ] || exit 2
shift

case "$profile" in
    terminal.ubports_terminal_2.0.6)
        package=terminal.ubports
        ;;
    openstore.openstore-team_openstore_4.2.0-20.04)
        package=openstore.openstore-team
        ;;
    *)
        echo "DRE launcher does not allow $profile" >&2
        exit 1
        ;;
esac

directory=$(click pkgdir "$package")
[ -d "$directory" ] || exit 1
libraries="$directory/lib/aarch64-linux-gnu"

export APP_ID="$profile"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_DATA_DIRS="$directory:${XDG_DATA_DIRS:-/usr/share}"
export PATH="$libraries/bin:$directory:$PATH"
export LD_LIBRARY_PATH="$libraries:$directory/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QML2_IMPORT_PATH="${QML2_IMPORT_PATH:+$QML2_IMPORT_PATH:}$libraries"
export UBUNTU_APPLICATION_ISOLATION=1
export TMPDIR="$XDG_RUNTIME_DIR/confined/$package"
export __GL_SHADER_DISK_CACHE_PATH="$XDG_CACHE_HOME/$package"
mkdir -p "$TMPDIR"

exec "$@"
