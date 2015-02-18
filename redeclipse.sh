#!/bin/sh
if [ "$_" != "$0" ]; then REDECLIPSE_EXITR="return"; else REDECLIPSE_EXITR="exit"; fi

redeclipse_path() {
    if [ -z "${REDECLIPSE_PATH+isset}" ]; then REDECLIPSE_PATH="$(cd "$(dirname "$0")" && pwd)"; fi
}

redeclipse_init() {
    if [ -z "${REDECLIPSE_BINARY+isset}" ]; then REDECLIPSE_BINARY="redeclipse"; fi
    REDECLIPSE_SCRIPT="$0"
    REDECLIPSE_SUFFIX=""
    REDECLIPSE_OPTIONS=""
    REDECLIPSE_MAKE="make"
}

redeclipse_setup() {
    if [ -z "${REDECLIPSE_TARGET+isset}" ]; then 
        REDECLIPSE_SYSTEM="$(uname -s)"
        REDECLIPSE_MACHINE="$(uname -m)"
        case "${REDECLIPSE_SYSTEM}" in
            Linux)
                REDECLIPSE_SUFFIX="_linux"
                REDECLIPSE_TARGET="linux"
                ;;
            FreeBSD)
                REDECLIPSE_SUFFIX="_freebsd"
                REDECLIPSE_TARGET="bsd"
                REDECLIPSE_BRANCH="source" # we don't have binaries for BSD yet sorry
                ;;
            MINGW*)
                REDECLIPSE_SUFFIX=".exe"
                REDECLIPSE_TARGET="windows"
                REDECLIPSE_MAKE="mingw32-make"
                if [ -n "${PROCESSOR_ARCHITEW6432+isset}" ]; then
                    REDECLIPSE_MACHINE="${PROCESSOR_ARCHITEW6432}"
                else
                    REDECLIPSE_MACHINE="${PROCESSOR_ARCHITECTURE}"
                fi
                ;;
            *)
                echo "Unsupported system: ${REDECLIPSE_SYSTEM}"
                return 1
                ;;
        esac
    fi
    if [ -z "${REDECLIPSE_ARCH+isset}" ]; then
        case "${REDECLIPSE_MACHINE}" in
            i486|i586|i686|x86)
                REDECLIPSE_ARCH="x86"
                ;;
            x86_64|[Aa][Mm][Dd]64)
                REDECLIPSE_ARCH="amd64"
                ;;
            *)
                echo "Unsupported architecture: ${REDECLIPSE_MACHINE}"
                return 1
                ;;
        esac
    fi
    if [ -z "${REDECLIPSE_BRANCH+isset}" ]; then
        REDECLIPSE_BRANCH="stable"
        if [ -a ".git" ]; then REDECLIPSE_BRANCH="devel"; fi
        if [ -a "${REDECLIPSE_PATH}/bin/branch.txt" ]; then REDECLIPSE_BRANCH=`cat "${REDECLIPSE_PATH}/bin/branch.txt"`; fi
    fi
    if [ "${REDECLIPSE_BRANCH}" != "stable" ] && [ "${REDECLIPSE_BRANCH}" != "devel" ] && [ "${REDECLIPSE_BRANCH}" != "source" ] && [ "${REDECLIPSE_BRANCH}" != "inplace" ]; then
        REDECLIPSE_BRANCH="inplace"
    fi
    if [ -z "${REDECLIPSE_HOME+isset}" ] && [ "${REDECLIPSE_BRANCH}" != "stable" ] && [ "${REDECLIPSE_BRANCH}" != "inplace" ]; then REDECLIPSE_HOME="home"; fi
    if [ -z "${REDECLIPSE_HOME+isset}" ]; then REDECLIPSE_OPTIONS="-h\"${REDECLIPSE_HOME}\" ${REDECLIPSE_OPTIONS}"; fi
    redeclipse_check
    return $?
}

redeclipse_check() {
    if [ "${REDECLIPSE_BRANCH}" = "stable" ] || [ "${REDECLIPSE_BRANCH}" = "devel" ]; then
        echo ""
        echo "Checking for updates to \"${REDECLIPSE_BRANCH}\". To disable set: REDECLIPSE_BRANCH=\"inplace\""
        echo ""
        redeclipse_begin
        return $?
    fi
    redeclipse_runit
    return $?
}

redeclipse_begin() {
    REDECLIPSE_RETRY="false"
    redeclipse_update
    return $?
}

redeclipse_retry() {
    if [ "${REDECLIPSE_RETRY}" != "true" ]; then
        REDECLIPSE_RETRY="true"
        echo "Retrying..."
        redeclipse_update
        return $?
    fi
    redeclipse_runit
    return $?
}

redeclipse_update() {
    REDECLIPSE_BINVER=`cat "${REDECLIPSE_PATH}/bin/version.txt"`
    chmod +x "${REDECLIPSE_PATH}/bin/update.sh"
    source "${REDECLIPSE_PATH}/bin/update.sh"
    if [ $? -eq 0 ]; then
        redeclipse_success
        return $?
    else
        redeclipse_retry
        return $?
    fi
    return 0
}

redeclipse_success() {
    if [ "${REDECLIPSE_BRANCH}" = "stable" ]; then
        REDECLIPSE_BINNEW=`cat "${REDECLIPSE_PATH}/bin/version.txt"`
        if [ "${REDECLIPSE_BINVER}" != "${REDECLIPSE_BINNEW}" ]; then
            redeclipse_update
            return $?
        fi
    fi
    redeclipse_runit
    return $?
}

redeclipse_runit() {
    if [ -a "${REDECLIPSE_PATH}/bin/${REDECLIPSE_ARCH}/${REDECLIPSE_BINARY}${REDECLIPSE_SUFFIX}" ]; then
        pushd "${REDECLIPSE_PATH}" 2>&1 > /dev/null || return 1
        exec "bin/${REDECLIPSE_ARCH}/${REDECLIPSE_BINARY}${REDECLIPSE_SUFFIX}" ${REDECLIPSE_OPTIONS} "$@" || (
            popd 2>&1 > /dev/null
            return 1
        )
        popd 2>&1 > /dev/null
        return 0
    else
        if [ "${REDECLIPSE_BRANCH}" = "source" ]; then
            ${REDECLIPSE_MAKE} -C src all install && ( redeclipse_runit; return $? )
            REDECLIPSE_BRANCH="devel"
        fi
        if [ "${REDECLIPSE_BRANCH}" != "inplace" ] && [ "${REDECLIPSE_TRYUPDATE}" != "true" ]; then
            REDECLIPSE_TRYUPDATE="true"
            redeclipse_begin
            return $?
        fi
        if [ "${REDECLIPSE_ARCH}" != "x86" ]; then
            REDECLIPSE_ARCH="x86"
            redeclipse_runit
            return $?
        fi
        echo "Unable to find a working binary."
    fi
    return 1
}

redeclipse_path
redeclipse_init 
redeclipse_setup

if [ $? -ne 0 ]; then
    echo ""
    echo "There was an error running Red Eclipse."
    ${REDECLIPSE_EXITR} 1
else
    ${REDECLIPSE_EXITR} 0
fi
