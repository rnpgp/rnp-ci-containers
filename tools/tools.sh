#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset

: "${LOCAL_BUILDS:=/tmp/local_builds}"
: "${JSONC_VERSION:=0.12.1}"
: "${PYTHON_VERSION:=3.9.2}"
: "${AUTOMAKE_VERSION:=1.16.4}"
: "${LIBICONV_VERSION:=1.17}"
: "${CMAKE_VERSION:=3.20.6-2}"
: "${USE_STATIC_DEPENDENCIES:=false}"

: "${DEFAULT_BOTAN_VERSION:=2.18.2}"
: "${DEFAULT_GPG_VERSION:=stable}"

MAKE_PARALLEL="$(nproc --all)"

is_use_static_dependencies() {
  [[ -n "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ no    != "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ off   != "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ false != "${USE_STATIC_DEPENDENCIES}" ]] && \
  [[ 0     != "${USE_STATIC_DEPENDENCIES}" ]]
}

# If target does not exist, create symlink from source to target.
ensure_symlink_to_target() {
  local from="${1:?Missing source}"
  local to="${2:?Missing target}"

  if [[ -e "${from}" && ! -e "${to}" ]]; then
    if ! sudo ln -s "${from}" "${to}"
    then
      >&2 echo "Error: ${to} still not available after symlink.  Aborting."
      exit 1
    fi
  fi
}

install_cmake() {
  echo "Running install_cmake version ${CMAKE_VERSION} for ${ARCH}"
  local cmake_install=${LOCAL_BUILDS}/cmake
  mkdir -p ${cmake_install}
  pushd ${cmake_install}
  wget -nv https://github.com/xpack-dev-tools/cmake-xpack/releases/download/v${CMAKE_VERSION}/xpack-cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz
  tar -zxf xpack-cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz --directory /usr --strip-components=1 --skip-old-files
  popd
  rm -rf ${cmake_install}
}

build_and_install_python() {
  echo "Running build_and_install_python version ${PYTHON_VERSION}"
  local python_build=${LOCAL_BUILDS}/python
  mkdir -p "${python_build}"
  pushd "${python_build}"
  wget -O python.tar.xz https://www.python.org/ftp/python/"${PYTHON_VERSION}"/Python-"${PYTHON_VERSION}".tar.xz
  tar -xf python.tar.xz --strip 1
  ./configure --enable-optimizations --prefix=/usr/local
  make -j"${MAKE_PARALLEL}" && sudo make install
  popd
  rm -rf "${python_build}"
  ensure_symlink_to_target /usr/local/bin/python3 /usr/local/bin/python
}

build_and_install_automake() {
  echo "Running build_and_install_automake version ${AUTOMAKE_VERSION}"
  local automake_build=${LOCAL_BUILDS}/automake
  mkdir -p "${automake_build}"
  pushd "${automake_build}"
  wget -O automake.tar.xz "https://ftp.gnu.org/gnu/automake/automake-${AUTOMAKE_VERSION}.tar.xz"
  tar -xf automake.tar.xz --strip 1
  ./configure --enable-optimizations --prefix=/usr
  make -j"${MAKE_PARALLEL}"
  sudo make install
  popd
  rm -rf "${automake_build}"
}

build_and_install_libiconv() {
  echo "Running build_and_install_libiconv version ${LIBICONV_VERSION}"
  local libiconv_build=${LOCAL_BUILDS}/libiconv
  mkdir -p "${libiconv_build}"
  pushd "${libiconv_build}"
  wget -O libiconv.tar.xz "https://ftp.gnu.org/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz"
  tar -xf libiconv.tar.xz --strip 1
  ./configure --prefix=/usr/local
  make -j"${MAKE_PARALLEL}"
  sudo make install
  popd
  rm -rf "${libiconv_build}"
}

build_and_install_jsonc() {
  echo "Running build_and_install_jsonc version ${JSONC_VERSION}"
  local jsonc_build=${LOCAL_BUILDS}/json-c
  mkdir -p "${jsonc_build}"
  pushd "${jsonc_build}"
  wget https://s3.amazonaws.com/json-c_releases/releases/json-c-"${JSONC_VERSION}".tar.gz -O json-c.tar.gz
  tar xzf json-c.tar.gz --strip 1

  autoreconf -ivf
  local cpuparam=()
    [[ -z "$CPU" ]] || cpuparam=(--build="$CPU")
    local build_type_args=(
        "--enable-$(is_use_static_dependencies && echo 'static' || echo 'shared')"
        "--disable-$(is_use_static_dependencies && echo 'shared' || echo 'static')"
    )
    env CFLAGS="-fPIC -fno-omit-frame-pointer -Wno-implicit-fallthrough -g" ./configure ${cpuparam+"${cpuparam[@]}"} "${build_type_args[@]}" --prefix=/usr
    make -j"${MAKE_PARALLEL}"
    sudo make install
    popd
    rm -rf "${jsonc_build}"
}

botan_version_at_least() {
  # Check whether botan version >= 3.2.0.
  # Head would be always after any existing version
  if [ "$(printf "$2\n%s" "$1" | sort -V | head -n1)" = "$2" ]; then
      return 0
  else
      return 1
  fi  
}

build_and_install_botan() {
  BOTAN_VERSION="${1:-system}"

  case "${BOTAN_VERSION}" in
    system)
      BOTAN_VERSION="$DEFAULT_BOTAN_VERSION"
      BOTAN_INSTALL="/usr/local"
      ;;
    head)
      BOTAN_INSTALL="/opt/botan/$BOTAN_VERSION"
      BOTAN_VERSION="master"
      ;;
    *)
      BOTAN_INSTALL="/opt/botan/$BOTAN_VERSION"
      ;;
  esac

  echo "Running build_and_install_botan version ${BOTAN_VERSION} (installing to ${BOTAN_INSTALL})"

  local botan_build=${LOCAL_BUILDS}/botan

  git clone --depth 1 --branch "${BOTAN_VERSION}" https://github.com/randombit/botan "${botan_build}"
  pushd "${botan_build}"

  local osparam=()
  local cpuparam=()
  local osslparam=()
  local modules
  if ! botan_version_at_least "${BOTAN_VERSION}" "3.0.0"; then
      osslparam+=("--without-openssl")
      modules=$(tr '\n' ',' < "${DIR_TOOLS}/botan-modules")
  elif ! botan_version_at_least "${BOTAN_VERSION}" "3.2.0"; then
      modules=$(tr '\n' ',' < "${DIR_TOOLS}/botan3-modules")
  elif ! botan_version_at_least "${BOTAN_VERSION}" "3.5.0"; then
      modules=$(tr '\n' ',' < "${DIR_TOOLS}/botan3.2-modules")
  elif ! botan_version_at_least "${BOTAN_VERSION}" "3.7.0"; then
      modules=$(tr '\n' ',' < "${DIR_TOOLS}/botan3.5-modules")
  else
      modules=$(tr '\n' ',' < "${DIR_TOOLS}/botan3.7-modules")
  fi

  echo "Building botan with modules: ${modules}"

  [[ -z "$OS" ]] || osparam=(--os="$OS")
  [[ -z "$CPU" ]] || cpuparam=(--cpu="$CPU" --disable-cc-tests)

  local build_target="shared,cli"
  is_use_static_dependencies && build_target="static,cli"

  python ./configure.py --prefix="${BOTAN_INSTALL}" --with-debug-info --extra-cxxflags="-fno-omit-frame-pointer -fPIC" \
      ${osparam+"${osparam[@]}"} ${cpuparam+"${cpuparam[@]}"} --without-documentation ${osslparam+"${osslparam[@]}"} --build-targets="${build_target}" \
      --minimized-build --enable-modules="$modules"
  make -j"${MAKE_PARALLEL}"
  sudo make install
  popd
  rm -rf "${botan_build}"
}

_install_gpg() {
  local VERSION_SWITCH=$1
  local NPTH_VERSION=$2
  local LIBGPG_ERROR_VERSION=$3
  local LIBGCRYPT_VERSION=$4
  local LIBASSUAN_VERSION=$5
  local LIBKSBA_VERSION=$6
  local PINENTRY_VERSION=$7
  local GNUPG_VERSION=$8

  local gpg_build="$PWD"
  # shellcheck disable=SC2153
  local gpg_install="${GPG_INSTALL:-/usr/local}"
  git clone --depth 1 https://github.com/rnpgp/gpg-build-scripts
  pushd gpg-build-scripts

  local cpuparam=()
  [[ -z "$CPU" ]] || cpuparam=(--build="$CPU")

  local configure_opts=(
      "--prefix=${gpg_install}"
      "--with-libgpg-error-prefix=${gpg_install}"
      "--with-libassuan-prefix=${gpg_install}"
      "--with-libgcrypt-prefix=${gpg_install}"
      "--with-ksba-prefix=${gpg_install}"
      "--with-npth-prefix=${gpg_install}"
      "--disable-doc"
      "--enable-pinentry-curses"
      "--disable-pinentry-emacs"
      "--disable-pinentry-gtk2"
      "--disable-pinentry-gnome3"
      "--disable-pinentry-qt"
      "--disable-pinentry-qt4"
      "--disable-pinentry-qt5"
      "--disable-pinentry-tqt"
      "--disable-pinentry-fltk"
      "--enable-maintainer-mode"
      "--enable-install-gpg-error-config"
      ${cpuparam+"${cpuparam[@]}"}
    )

  local common_args=(
      --force-autogen
#      --verbose		commented out to speed up recurring CI builds
#      --trace                  uncomment if you are debugging CI
      --build-dir "${gpg_build}"
      --configure-opts "${configure_opts[*]}"
  )

  # Workaround to correctly build pinentry on the latest GHA on macOS. Most likely there is a better solution.
  export CFLAGS="-D_XOPEN_SOURCE_EXTENDED"
  export CXXFLAGS="-D_XOPEN_SOURCE_EXTENDED"

  # Always build GnuPG with gcc, even if we are testing clang
  # ref https://github.com/rnpgp/rnp/issues/1669

  for component in libgpg-error:$LIBGPG_ERROR_VERSION \
                   libgcrypt:$LIBGCRYPT_VERSION \
                   libassuan:$LIBASSUAN_VERSION \
                   libksba:$LIBKSBA_VERSION \
                   npth:$NPTH_VERSION \
                   pinentry:$PINENTRY_VERSION \
                   gnupg:$GNUPG_VERSION; do
    local name="${component%:*}"
    local version="${component#*:}"

    env CC="gcc" CXX="g++" ./install_gpg_component.sh         \
                              --component-name "$name"        \
                              --"$VERSION_SWITCH" "$version"  \
                              "${common_args[@]}"
  done
  popd
}

build_and_install_gpg() {
  GPG_VERSION="${1:-stable}"
  GPG_INSTALL="/opt/gpg/${GPG_VERSION}"
  echo "Running build_and_install_gpg version ${GPG_VERSION} (installing to ${GPG_INSTALL})"

  local gpg_build=${LOCAL_BUILDS}/gpg
  mkdir -p "${gpg_build}"
  pushd "${gpg_build}"

    # shellcheck disable=SC2153
  case "${GPG_VERSION}" in
    head)
      #                               npth      libgpg-error   libgcrypt  libassuan libksba pinentry gnupg
      _install_gpg component-git-ref npth-1.6     master         master    master   master   master  master

      ;;
    stable)
      #                              npth libgpg-error libgcrypt libassuan libksba pinentry gnupg
      _install_gpg component-version 1.7  1.48         1.10.3     2.5.7     1.6.6  1.3.0    2.4.5
      ;;
    lts)
      #                              npth libgpg-error libgcrypt libassuan libksba pinentry gnupg
      _install_gpg component-version 1.6  1.48         1.8.10     2.5.5     1.6.3   1.2.1   2.2.43
      ;;
    *)
      >&2 echo "\$GPG_VERSION is set to invalid value: ${GPG_VERSION}"
      exit 1
  esac
  popd
  rm -rf ${gpg_build}
}

select_crypto_backend_for_gha() {
  backend="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  echo CRYPTO_BACKEND="$backend" >> $GITHUB_ENV
}

select_gpg_version_for_gha() {
  GPG_VERSION=$(echo "${1:-system}" | tr '[:upper:]' '[:lower:]')

  if [[ "$GPG_VERSION" != 'system' ]]; then
    echo "/opt/gpg/$GPG_VERSION/bin" >> $GITHUB_PATH
  fi
}

select_botan_version_for_gha() {
  BOTAN_VERSION=$(echo "${1:-system}" | tr '[:upper:]' '[:lower:]')

  if [[ "$BOTAN_VERSION" != 'system' ]]; then
    echo "/opt/botan/$BOTAN_VERSION/bin" >> $GITHUB_PATH
    echo BOTAN_ROOT_DIR="/opt/botan/$BOTAN_VERSION" >> $GITHUB_ENV
    echo LD_LIBRARY_PATH="/opt/botan/$BOTAN_VERSION/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" >> $GITHUB_ENV
    echo PKG_CONFIG_PATH="/opt/botan/$BOTAN_VERSION/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" >> $GITHUB_ENV
    echo CPATH="/opt/botan/$BOTAN_VERSION/include${CPATH:+:${CPATH}}" >> $GITHUB_ENV
  fi
}

DIR0=$( dirname "$0" )
DIR_TOOLS=$( cd "$DIR0" && pwd )

echo "Running tools.sh with args: $@, DIR_TOOLS: ${DIR_TOOLS}"

"$@"
