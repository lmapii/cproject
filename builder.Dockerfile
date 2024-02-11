# update the base_tag to the version of the base image
# e.g., "bullseye" is currently (2024-02) still the latest version for vscode devcontainers:
# https://hub.docker.com/_/microsoft-vscode-devcontainers

ARG base_tag=bullseye
ARG base_img=mcr.microsoft.com/vscode/devcontainers/base:dev-${base_tag}
# ARG base_img=debian:${base_tag}

FROM --platform=linux/amd64 ${base_img} AS builder-install

# the following shows how to install the latest version of a package.
# you can determine the installed version with `apt-cache policy <list of packages>` and fix
# the version to install with <package>=<version> in the list below.

# notice that ruby is being installed for ceedling and would otherwise most likely not be needed
# https://www.throwtheswitch.org/ceedling

RUN apt-get update --fix-missing && apt-get -y upgrade
RUN apt-get install -y --no-install-recommends \
    apt-utils \
    curl \
    cmake \
    build-essential \
    gcc \
    g++-multilib \
    locales \
    make \
    ruby \
    gcovr \
    wget \
    && rm -rf /var/lib/apt/lists/*

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && /usr/sbin/locale-gen
RUN echo "alias ll='ls -laGFh'" >> /root/.bashrc

VOLUME ["/builder/mnt"]
WORKDIR /builder/mnt

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# install clang tools

ARG base_tag=bullseye
ARG llvm_version=16
RUN apt-get update --fix-missing && apt-get -y upgrade
RUN apt-get install -y --no-install-recommends \
    gnupg2 \
    gnupg-agent \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl --fail --silent --show-error --location https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN echo "deb http://apt.llvm.org/$base_tag/ llvm-toolchain-$base_tag-$llvm_version main" >> /etc/apt/sources.list.d/llvm.list

RUN apt-get update --fix-missing && apt-get -y upgrade
RUN apt-get install -y --no-install-recommends \
    clang-format-${llvm_version} \
    clang-tidy-${llvm_version} \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/clang-format-${llvm_version} /usr/local/bin/clang-format
RUN ln -s /usr/bin/clang-tidy-${llvm_version} /usr/local/bin/clang-tidy

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# option A: install rust and install clang wrappers via cargo
# this option installs rust and cargo, and then compiles the clang wrappers from scratch.
# this can take a significant amount of time (e.g., several minutes just to compile one tool),
# and also increases the image size significantly. therefore, we go for option B below.

# RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
# ENV PATH=/root/.cargo/bin:$PATH

# Each takes around 280 s to build on an M2 macbook air
# RUN cargo install run-clang-format
# RUN cargo install run-clang-tidy

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# option B: install pre-built clang wrappers

RUN mkdir -p /usr/local/run-clang-format
RUN wget -O clang-utils.tgz "https://github.com/lmapii/run-clang-format/releases/download/v1.4.14/run-clang-format-v1.4.14-i686-unknown-linux-gnu.tar.gz" && \
    tar -C /usr/local/run-clang-format -xzf clang-utils.tgz --strip-components 1 && \
    rm clang-utils.tgz
ENV PATH /usr/local/run-clang-format:$PATH
RUN run-clang-format --version

RUN mkdir -p /usr/local/run-clang-tidy
RUN wget -O clang-utils.tgz "https://github.com/lmapii/run-clang-tidy/releases/download/v0.2.5/run-clang-tidy-v0.2.5-i686-unknown-linux-gnu.tar.gz" && \
    tar -C /usr/local/run-clang-tidy -xzf clang-utils.tgz --strip-components 1 && \
    rm clang-utils.tgz
ENV PATH /usr/local/run-clang-tidy:$PATH
RUN run-clang-tidy --version

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# install unity and ceedling

# install unity cmock and ceedling (unit test environment)
RUN gem install ceedling
# set standard encoding to UTF-8 for ruby (and thus ceedling)
ENV RUBYOPT "-KU -E utf-8:utf-8"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# cleanup and vulnerability fixes

# check all installed packages with "apt list", maybe remove packages.
RUN apt remove -y \
    wget

# FIXME: remove more packages ...
# RUN apt remove -y \
#     python3-yaml \
#     curl \
#     unzip \
#     cpp \
#     cpp-10 \
#     nano \
#     vim
