# -*- mode: dockerfile -*-
# vi: set ft=dockerfile fdm=marker :


###################################################################################################
# This is a multi-stage build with what looks like a lot of builds. It results
# in a very clean runtime image that has as few unintended extras as possible.
ARG PYPI_BUILD_DEPS="gcc gcc-c++"
ARG PYPI_DEPS=""


# {{{ base
# base has the bare minimum operating system plus security updates and our custom python.
# This image needs to be squeaky clean when done, thus all of the rolling back and the way-too-much
# work of removing everything in a big long shell command.
FROM oraclelinux:7-slim AS base

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# These are base needs. They are good to have and don't appreciably increase the image size.
ARG SYSTEM_DEPS="bzip2 gnupg2 gzip tar tzdata which xz"

# These are required by python at runtime. Preinstall to keep from automatic removal.
# Run this after python build if it ever looks "broken". I don't like making a static
# list here, but I'm learning to deal with it. yum doesn't make this easy without a
# bunch of output parsing. You will probably get these for free with the base system,
# but allow my paranoia.
# rpmKeep="$(find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' + \
#            | awk '/=>/ && NF==4 {print $3}' \
#            | sort -u \
#            | xargs -r rpm -qf --qf='%{name}\n' \
#            | grep -v 'is not owned by any package' \
#            | sort -u)"
ARG PYTHON_DEPS="bzip2-libs expat gdbm glibc keyutils-libs krb5-libs libcom_err libffi libselinux \
                 libuuid ncurses-libs nss-softokn-freebl openssl-libs pcre readline sqlite \
                 xz-libs zlib"
ARG SQLITE_DEPS="tcl"

# Update the system and install runtime dependencies
RUN : \
 && set -ex \
 && yum clean all \
 && yum -y upgrade \
 && yum -y install $SYSTEM_DEPS $PYTHON_DEPS $SQLITE_DEPS \
 && yum clean all \
 && rm -rf /var/cache/yum/ /var/lib/yum/repos/*
# base }}}


# {{{ builder
# Here we build python and its dependencies. This makes a really dirty build
# environment, so we make it its own stage to avoid cleanup as much as
# possible. `COPY /usr/local` from this image to get python into the runtime
# image. This stage is not intended for runtime consumption - it's a cache
# staged only.  NOTE: Don't forget to `ldconfig` in the COPY destination later.
FROM base AS builder

ARG PYTHON_PIP_VERSION=19.0.3
ARG PYTHON_VERSION=3.7.3
ARG pybasever=3.7
ARG pyshortver=37
ARG _bindir=/usr/local/bin
ARG _libdir=/usr/local/lib
ARG pylibdir=${_libdir}/python${pybasever}
ARG dynload_dir=${pylibdir}/lib-dynload
ARG ABIFLAGS_optimized=m
ARG _arch=x86_64
ARG _gnu=-gnu
ARG bytecode_suffixes=.cpython-${pyshortver}*.pyc
ARG SOABI_optimized=cpython-${pyshortver}${ABIFLAGS_optimized}-${_arch}-linux${_gnu}
ARG PYTHON_BUILD_DEPS="gcc gcc-c++ bzip2-devel glibc-devel expat-devel libffi-devel gdbm-devel \
                       xz-devel ncurses-devel readline-devel sqlite-devel openssl-devel make \
                       tk-devel libuuid-devel zlib-devel"
ARG SQLITE_BUILD_DEPS="autoconf file pkgconfig ncurses-devel readline-devel glibc-devel tcl-devel"
ARG SQLITE_VERSION=3270200

ENV PATH=$_bindir:$PATH

WORKDIR /usr/src

# Install build dependencies
RUN : \
 && set -ex \
 && yum clean all \
 && yum -y install $PYTHON_BUILD_DEPS $SQLITE_BUILD_DEPS

# Install SQLite
RUN : \
 && set -ex \
 && curl -sSLo sqlite.tar.gz "https://www.sqlite.org/2019/sqlite-autoconf-${SQLITE_VERSION}.tar.gz" \
 && mkdir -p /usr/src/sqlite \
 && tar -xzC /usr/src/sqlite --strip-components=1 -f sqlite.tar.gz \
 && rm sqlite.tar.gz

# Build and install SQLite
RUN : \
 && set -ex \
 && cd /usr/src/sqlite \
 && sh ./configure \
         --disable-static \
         --enable-silent-rules \
 && make -j $(nproc) \
 && make install

# Extract python source
RUN : \
 && set -ex \
 && curl -sSLo python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
 && mkdir -p /usr/src/python \
 && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
 && rm python.tar.xz

# Build and install python. Run ldconfig to get the libraries in LD_LIBRARY_PATH
# NOTE: Don't forget to `ldconfig` in the COPY destination later.
RUN : \
 && set -ex \
 && cd /usr/src/python \
 && CXX="/usr/bin/g++" sh ./configure \
         --enable-ipv6 \
         --enable-shared \
         --with-dbmliborder=gdbm:ndbm:bdb \
         --with-system-expat \
         --enable-loadable-sqlite-extensions \
         --without-ensurepip \
         --enable-optimizations \
         --with-lto \
 && make -j "$(nproc)" \
 && make install

# Make sure python3 runs. If anything fails silently, this should catch it by throwing a runtime error
# NOTE: This ldconfig is only for this stage - it doesn't carryover.
RUN : \
 && set -ex \
 && echo ${_libdir} >/etc/ld.so.conf.d/usr-local.conf \
 && ldconfig \
 && python3 --version

# make some useful symlinks that are expected to exist
RUN : \
 && set -ex \
 && cd ${_bindir} \
 && ln -s pydoc3 pydoc \
 && ln -s python3 python \
 && ln -s python3-config python-config

# Get and install pip
# Make sure pip runs. If anything fails silently, this should catch it by throwing a runtime error
RUN : \
 && set -ex \
 && curl -sSLo get-pip.py 'https://bootstrap.pypa.io/get-pip.py' \
 && python get-pip.py \
      --disable-pip-version-check \
      --no-cache-dir \
      "pip==$PYTHON_PIP_VERSION" \
 && pip --version \
 && rm -f get-pip.py

# Cleanup files that we don't want to have in the final image
RUN : \
 && set -ex \
# %files libs
 && rm -rf \
      ${pylibdir}/distutils/command/wininst-*.exe \
      ${pylibdir}/turtle.py \
      ${pylibdir}/__pycache__/turtle*${bytecode_suffixes} \
# %files idle
      ${_bindir}/idle* \
      ${pylibdir}/idlelib \
# %files tkinter
      ${pylibdir}/tkinter \
      ${dynload_dir}/_tkinter.${SOABI_optimized}.so \
      ${pylibdir}/turtledemo \
# %files test
      ${pylibdir}/ctypes/test \
      ${pylibdir}/distutils/tests \
      ${pylibdir}/lib2to3/tests \
      ${pylibdir}/sqlite3/test \
      ${pylibdir}/test \
      ${dynload_dir}/_ctypes_test.${SOABI_optimized}.so \
      ${dynload_dir}/_testbuffer.${SOABI_optimized}.so \
      ${dynload_dir}/_testcapi.${SOABI_optimized}.so \
      ${dynload_dir}/_testimportmultiple.${SOABI_optimized}.so \
      ${pylibdir}/tkinter/test \
      ${pylibdir}/unittest/test \
# Python bytecode
 && find ${pylibdir} -type d -name __pycache__ -exec rm -rf '{}' +
# }}}


# {{{ python-oracle
# This image has the real, ready-to-run python installed in /usr/local. It copies the results of
# the builder stage and makes it ready for action.
# NOTE: We didn't forget to `ldconfig` like we were told.
FROM base AS python-oracle
LABEL vendor="Apt Platform Technologies, Inc." \
      maintainer="Chris Cosby <chris.cosby@aptplatforms.com>"

ARG ORA_VERSION=18.5

ENV PATH=${_bin}:$PATH:/usr/lib/oracle/${ORA_VERSION}/client64/bin

COPY --from=builder /etc/ld.so.conf.d/usr-local.conf /etc/ld.so.conf.d/usr-local.conf
COPY --from=builder /usr/local/ /usr/local/

# Run ldconfig to get /usr/local/lib into the system LD_LIBRARY_PATH
# Install the Oracle Instant Client Libraries
RUN : \
 && set -ex \
 && yum clean all \
 && curl -sSLo /etc/yum.repos.d/public-yum-ol7.repo https://yum.oracle.com/public-yum-ol7.repo \
 && yum-config-manager --enable ol7_oracle_instantclient \
 && yum -y install oracle-instantclient${ORA_VERSION}-basic oracle-instantclient${ORA_VERSION}-sqlplus \
 && echo /usr/lib/oracle/${ORA_VERSION}/client64/lib >/etc/ld.so.conf.d/oracle-instantclient${ORA_VERSION}.conf \
 && ldconfig \
 && yum clean all \
 && rm -rf /var/cache/yum/ /var/lib/yum/repos/*

ENTRYPOINT []
CMD ["python3"]
# }}}
