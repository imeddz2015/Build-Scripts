
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuPG and its dependencies from sources.

GNUPG_TAR=gnupg-2.2.20.tar.bz2
GNUPG_DIR=gnupg-2.2.20
PKG_NAME=gnupg

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-tasn1.sh
then
    echo "Failed to build libtasn1"
    exit 1
fi

###############################################################################

if ! ./build-gpgerror.sh
then
    echo "Failed to build Libgpg-error"
    exit 1
fi

###############################################################################

if ! ./build-libksba.sh
then
    echo "Failed to build Libksba"
    exit 1
fi

###############################################################################

if ! ./build-libassuan.sh
then
    echo "Failed to build Libassuan"
    exit 1
fi

###############################################################################

if ! ./build-libgcrypt.sh
then
    echo "Failed to build Libgcrypt"
    exit 1
fi

###############################################################################

if ! ./build-ntbTLS.sh
then
    echo "Failed to build ntbTLS"
    exit 1
fi

###############################################################################

if ! ./build-nPth.sh
then
    echo "Failed to build nPth"
    exit 1
fi

###############################################################################

echo
echo "********** GnuPG **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$GNUPG_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://gnupg.org/ftp/gcrypt/gnupg/$GNUPG_TAR"
then
    echo "Failed to download GnuPG"
    exit 1
fi

rm -rf "$GNUPG_DIR" &>/dev/null
tar xjf "$GNUPG_TAR"
cd "$GNUPG_DIR"

if [[ -e ../patch/gnupg.patch ]]; then
    patch -u -p0 < ../patch/gnupg.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    INSTX_STD="-std=c99"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]} $INSTX_STD" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --disable-scdaemon \
    --disable-dirmngr \
    --disable-wks-tools \
    --disable-doc \
    --with-zlib="$INSTX_PREFIX" \
    --with-bzip2="$INSTX_PREFIX" \
    --with-libgpg-error-prefix="$INSTX_PREFIX" \
    --with-libgcrypt-prefix="$INSTX_PREFIX" \
    --with-libassuan-prefix="$INSTX_PREFIX" \
    --with-ksba-prefix="$INSTX_PREFIX" \
    --with-npth-prefix="$INSTX_PREFIX" \
    --with-ntbtls-prefix="$INSTX_PREFIX" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GnuPG"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuPG"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GnuPG"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GNUPG_TAR" "$GNUPG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnupg.sh 2>&1 | tee build-gnupg.log
    if [[ -e build-gnupg.log ]]; then
        rm -f build-gnupg.log
    fi
fi

exit 0
