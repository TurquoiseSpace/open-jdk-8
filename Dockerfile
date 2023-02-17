
# ------------------------------------------------------------------------------
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ------------------------------------------------------------------------------

FROM alpine:3.14

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apk add --no-cache tzdata --virtual .build-deps curl binutils zstd

ENV GLIBC_VER="2.33-r0"
ENV ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download"
ENV GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-10.1.0-2-x86_64.pkg.tar.zst"
ENV GCC_LIBS_SHA256="f80320a03ff73e82271064e4f684cd58d7dbdb07aa06a2c4eea8e0f3c507c45c"
ENV ZLIB_URL="https://archive.archlinux.org/packages/z/zlib/zlib-1%3A1.2.11-3-x86_64.pkg.tar.xz"
ENV ZLIB_SHA256="17aede0b9f8baa789c5aa3f358fbf8c68a5f1228c5e6cba1a5dd34102ef4d4e5"
ENV SGERRAND_RSA_SHA256="823b54589c93b02497f1ba4dc622eaef9c813e6b0f0ebbb2f771e32adf9f4ef2"

RUN curl -LfsS https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub
RUN echo "${SGERRAND_RSA_SHA256} */etc/apk/keys/sgerrand.rsa.pub" | sha256sum -c -

RUN curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/glibc-${GLIBC_VER}.apk
RUN apk add --no-cache /tmp/glibc-${GLIBC_VER}.apk
RUN curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk > /tmp/glibc-bin-${GLIBC_VER}.apk
RUN apk add --no-cache /tmp/glibc-bin-${GLIBC_VER}.apk
RUN curl -Ls ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-i18n-${GLIBC_VER}.apk > /tmp/glibc-i18n-${GLIBC_VER}.apk
RUN apk add --no-cache /tmp/glibc-i18n-${GLIBC_VER}.apk

RUN /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true
RUN echo "export LANG=$LANG" > /etc/profile.d/locale.sh
RUN curl -LfsS ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.zst
RUN echo "${GCC_LIBS_SHA256} */tmp/gcc-libs.tar.zst" | sha256sum -c -
RUN mkdir /tmp/gcc
RUN zstd -d /tmp/gcc-libs.tar.zst --output-dir-flat /tmp
RUN tar -xf /tmp/gcc-libs.tar -C /tmp/gcc
RUN mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib
RUN strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so*
RUN curl -LfsS ${ZLIB_URL} -o /tmp/libz.tar.xz
RUN echo "${ZLIB_SHA256} */tmp/libz.tar.xz" | sha256sum -c -
RUN mkdir /tmp/libz
RUN tar -xf /tmp/libz.tar.xz -C /tmp/libz
RUN mv /tmp/libz/usr/lib/libz.so* /usr/glibc-compat/lib
RUN apk del --purge .build-deps glibc-i18n
RUN rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar* /tmp/libz /tmp/libz.tar.xz /var/cache/apk/*

ENV JAVA_VERSION jdk8u292-b10

RUN set -eux;
RUN apk add --no-cache --virtual .fetch-deps curl;

ENV ARCH="$(apk --print-arch)";

RUN case "${ARCH}" in \
       amd64|x86_64) \
         ESUM='cad66f48f90167ed19030c71f8f0580702c43cce5ce5a0d76833f7a5ae7c402a'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u292-b10/OpenJDK8U-jre_x64_linux_hotspot_8u292b10.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac;

RUN curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL};
RUN echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -;
RUN mkdir -p /opt/java/openjdk;
RUN cd /opt/java/openjdk;
RUN tar -xf /tmp/openjdk.tar.gz --strip-components=1;
RUN apk del --purge .fetch-deps;
RUN rm -rf /var/cache/apk/*;
RUN rm -rf /tmp/openjdk.tar.gz;

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="/opt/java/openjdk/bin:$PATH"
