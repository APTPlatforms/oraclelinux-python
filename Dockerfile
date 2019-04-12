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

# Update the system and install runtime dependencies
RUN : \
 && set -ex \
 && yum clean all \
 && yum -y upgrade \
 && yum -y install $SYSTEM_DEPS $PYTHON_DEPS \
 && yum clean all \
 && rm -rf /var/cache/yum/ /var/lib/yum/repos/*
# base }}}


# {{{ python-build
# Here we build python. This makes a really dirty build environment, so we make it its own stage
# to avoid cleanup as much as possible. `COPY /usr/local` from this image to get python into the
# runtime image. This stage is not intended for runtime consumption - it's a cache staged only.
# NOTE: Don't forget to `ldconfig` in the COPY destination later.
FROM base AS python-build

ARG PYTHON_VERSION=3.7.3
ARG PYTHON_GPG_KEY=0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ARG PYTHON_PIP_VERSION=19.0.3
ARG PYTHON_BUILD_DEPS="gcc gcc-c++ bzip2-devel glibc-devel expat-devel libffi-devel gdbm-devel \
                       xz-devel ncurses-devel readline-devel sqlite-devel openssl-devel make \
                       tk-devel libuuid-devel zlib-devel"

ENV PATH=/usr/local/bin:$PATH

# Install python build dependencies
RUN : \
 && set -ex \
 && yum clean all \
 && yum -y install $PYTHON_BUILD_DEPS

# Download python source
RUN : \
 && set -ex \
 && curl -sSLo python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
 && curl -sSLo python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"

# Validate GPG signature of download
RUN : \
 && set -ex \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$PYTHON_GPG_KEY" \
 && gpg --batch --verify python.tar.xz.asc python.tar.xz \
 && { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
 && rm -rf "$GNUPGHOME" python.tar.xz.asc

# Extract python source
RUN : \
 && set -ex \
 && mkdir -p /usr/src/python \
 && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
 && rm python.tar.xz

# Build and install python. , run ldconfig to get the libraries in LD_LIBRARY_PATH
# NOTE: Don't forget to `ldconfig` in the COPY destination later.
RUN : \
 && set -ex \
 && cd /usr/src/python \
 && ./configure \
      --quiet \
      --enable-shared \
      --enable-loadable-sqlite-extensions \
# TODO: Enable this when ready for production and caching is a real thing
#     --enable-optimizations \
# TODO: Does LTO work with PGO? We'll try later.
      --with-lto \
      --with-system-expat \
      --without-ensurepip \
 && make --quiet -j "$(nproc)" \
 && make install

# Make sure python3 runs. If anything fails silently, this should catch it by throwing a runtime error
# NOTE: This ldconfig is only for this stage - it doesn't carryover.
RUN : \
 && set -ex \
 && echo /usr/local/lib >/etc/ld.so.conf.d/usr-local.conf \
 && ldconfig \
 && python3 --version

# make some useful symlinks that are expected to exist
RUN : \
 && set -ex \
 && cd /usr/local/bin \
 && ln -s idle3 idle \
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

# Nuke test directories and precompiled object code
RUN : \
 && set -ex \
 && find /usr/local -depth \
      \( \
        \( -type d -a \( -name test -o -name tests \) \) \
        -o \
        \( -type f -a \( -name '*.py[co]' \) \) \
       \) -exec rm -rf '{}' +
# }}}


# {{{ python-oracle
# This image has the real, ready-to-run python installed in /usr/local. It copies the results of
# the python-build stage and makes it ready for action.
# NOTE: We didn't forget to `ldconfig` like we were told.
FROM base AS python-oracle

ARG ORA_VERSION=18.5

ENV PATH=/usr/local/bin:$PATH:/usr/lib/oracle/${ORA_VERSION}/client64/bin

COPY --from=python-build /etc/ld.so.conf.d/usr-local.conf /etc/ld.so.conf.d/usr-local.conf
COPY --from=python-build /usr/local/ /usr/local/

# Run ldconfig to get /usr/local/lib into the system LD_LIBRARY_PATH
# Install the Oracle Instant Client Libraries
RUN : \
 && set -ex \
 && ldconfig \
 && yum clean all \
 && curl -sSLo /etc/yum.repos.d/public-yum-ol7.repo https://yum.oracle.com/public-yum-ol7.repo \
 && yum-config-manager --enable ol7_oracle_instantclient \
 && yum -y install "oracle-instantclient${ORA_VERSION}-basiclite" \
 && echo /usr/lib/oracle/${ORA_VERSION}/client64/lib >/etc/ld.so.conf.d/oracle-instantclient${ORA_VERSION}.conf \
 && ldconfig \
 && yum clean all \
 && rm -rf /var/cache/yum/ /var/lib/yum/repos/*

ENTRYPOINT []
CMD ["python3"]
# }}}