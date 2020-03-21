#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Ncurses from sources.

NCURSES_TAR=ncurses-6.1.tar.gz
NCURSES_DIR=ncurses-6.1
PKG_NAME=ncurses

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

if [[ -e "$INSTX_PACKAGE_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-termcap.sh
then
    echo "Failed to build Termcap"
    exit 1
fi

###############################################################################

echo
echo "********** ncurses **********"
echo

if ! "$WGET" -O "$NCURSES_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR"
then
    echo "Failed to download Ncurses"
    exit 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
gzip -d < "$NCURSES_TAR" | tar xf -
cd "$NCURSES_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS+=("--build=$AUTOCONF_BUILD")
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--disable-leaks")
CONFIG_OPTS+=("--with-shared")
CONFIG_OPTS+=("--with-cxx-shared")
CONFIG_OPTS+=("--without-ada")
CONFIG_OPTS+=("--enable-pc-files")
CONFIG_OPTS+=("--with-termlib")
CONFIG_OPTS+=("--disable-root-environ")
CONFIG_OPTS+=("--with-build-cc=$CC")
CONFIG_OPTS+=("--with-build-cxx=$CXX")
CONFIG_OPTS+=("--with-build-cpp=${BUILD_CPPFLAGS[*]}")
CONFIG_OPTS+=("--with-build-cflags=${BUILD_CFLAGS[*]}")
CONFIG_OPTS+=("--with-build-cxxflags=${BUILD_CXXFLAGS[*]}")
CONFIG_OPTS+=("--with-build-ldflags=${BUILD_LDFLAGS[*]}")
CONFIG_OPTS+=("--with-build-libs=${BUILD_LIBS[*]}")
CONFIG_OPTS+=("--with-pkg-config-libdir=${BUILD_PKGCONFIG[*]}")

# Ncurses can be built narrow or wide. There's no real way to
# know for sure, so we attempt to see what the distro is doing.
COUNT=$(find /usr/lib/ /usr/lib64/ -name 'ncurses*w.*' 2>/dev/null | wc -l)
if [[ "$COUNT" -ne 0 ]]; then
    echo "Enabling wide character version"
    echo ""
    CONFIG_OPTS+=("--enable-widec")
else
    echo "Enabling narrow character version"
    echo ""
fi

    # Ncurses use PKG_CONFIG_LIBDIR, not PKG_CONFIG_PATH???
    PKG_CONFIG_LIBDIR="${BUILD_PKGCONFIG[*]}" \
    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure ncurses"
    exit 1
fi

# Remove unneeded warning
echo "Patching Makefiles..."
(IFS="" find "$PWD" -name 'Makefile' -print | while read -r file
do
    cp -p "$file" "$file.fixed"
    sed 's| --param max-inline-insns-single=1200||g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to build ncurses"
    echo "**********************"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test ncurses"
    echo "**********************"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | grep -v -E 'doc/|man/' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test ncurses"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PACKAGE_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$NCURSES_TAR" "$NCURSES_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ncurses.sh 2>&1 | tee build-ncurses.log
    if [[ -e build-ncurses.log ]]; then
        rm -f build-ncurses.log
    fi
fi

exit 0
