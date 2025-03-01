# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

ARG base
FROM ${base}

RUN apk add --no-cache bash build-base bzip2-dev dpkg dpkg-dev g++ git libffi-dev libnsl-dev libtirpc-dev \
    linux-headers ncurses-dev openssl-dev pkgconf tzdata zlib-dev

RUN wget https://github.com/python/cpython/archive/refs/tags/v3.13.2.tar.gz && \
    tar -xzf v3.13.2.tar.gz && \
    rm v3.13.2.tar.gz && \
    cd cpython-3.13.2/ && \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" && \
    ./configure --build="$gnuArch" --disable-gil --with-ensurepip && \
    make -j && \
    make install && \
    cd ../ && \
    rm -rf cpython-3.13.2/

RUN for src in idle3 pip3 pydoc3 python3 python3-config; do \
        dst="$(echo "$src" | tr -d 3)"; \
        [ -s "/usr/local/bin/$src" ]; \
        [ ! -e "/usr/local/bin/$dst" ]; \
        ln -svT "$src" "/usr/local/bin/$dst"; \
    done

ENV ARROW_PYTHON_VENV /arrow-dev
RUN python3.13t -m venv ${ARROW_PYTHON_VENV}

ENV PYTHON_GIL 0
ENV PATH "${ARROW_PYTHON_VENV}/bin:${PATH}"

ENV TZDIR=/usr/share/zoneinfo
RUN cp /usr/share/zoneinfo/Etc/UTC /etc/localtime

# pandas doesn't provide wheels for aarch64 yet, so we have to install nightly Cython
# along with the rest of pandas' build dependencies and disable build isolation
COPY python/requirements-wheel-test.txt /arrow/python/
RUN python -m pip install \
    --pre \
    --prefer-binary \
    --extra-index-url "https://pypi.anaconda.org/scientific-python-nightly-wheels/simple" \
    Cython numpy
RUN python -m pip install "meson-python==0.13.1" "meson==1.2.1" wheel "versioneer[toml]" ninja
RUN python -m pip install --no-build-isolation -r /arrow/python/requirements-wheel-test.txt
