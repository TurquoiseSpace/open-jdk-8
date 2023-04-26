
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

FROM alpine:3.17.3

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apk -vv info | sort
RUN apk add --no-cache tzdata --virtual .build-deps curl zstd
# fontconfig and ttf-dejavu added to support serverside image generation by Java programs
RUN apk add --no-cache fontconfig libretls musl-locales musl-locales-lang ttf-dejavu zlib

RUN apk -vv info | sort
RUN apk -U upgrade -f
RUN apk -vv info | sort

ENV GLIBC_VER="2.35-r1"
ENV ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download"
ENV GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-12.2.1-4-x86_64.pkg.tar.zst"
ENV GCC_LIBS_SHA256="9f6ed8f56d753071cfd0ece95c09ff7b6eb9131182ed5b5b1bd435feb7a00c31"
ENV SGERRAND_RSA_SHA256="823b54589c93b02497f1ba4dc622eaef9c813e6b0f0ebbb2f771e32adf9f4ef2"

RUN curl -LfsS https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub
RUN echo "${SGERRAND_RSA_SHA256} */etc/apk/keys/sgerrand.rsa.pub" | sha256sum -c -

RUN curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/glibc-${GLIBC_VER}.apk
RUN apk add --force-overwrite /tmp/glibc-${GLIBC_VER}.apk
RUN curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk > /tmp/glibc-bin-${GLIBC_VER}.apk
RUN apk add --force-overwrite /tmp/glibc-bin-${GLIBC_VER}.apk
RUN curl -Ls ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-i18n-${GLIBC_VER}.apk > /tmp/glibc-i18n-${GLIBC_VER}.apk
RUN apk add --force-overwrite /tmp/glibc-i18n-${GLIBC_VER}.apk

RUN /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true
RUN echo "export LANG=$LANG" > /etc/profile.d/locale.sh
RUN curl -LfsS ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.zst
RUN echo "${GCC_LIBS_SHA256} */tmp/gcc-libs.tar.zst" | sha256sum -c -
RUN mkdir /tmp/gcc
RUN zstd -d /tmp/gcc-libs.tar.zst --output-dir-flat /tmp
RUN tar -xf /tmp/gcc-libs.tar -C /tmp/gcc
RUN mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib
RUN apk del --purge .build-deps glibc-i18n
RUN rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar* /var/cache/apk/*

RUN set -eux
RUN apk add --no-cache --virtual .fetch-deps curl

RUN echo "Identified Architecture : $(apk --print-arch)"
RUN case "$(apk --print-arch)" in \
       amd64|x86_64) \
         echo "Architecture Supported"; \
         ;; \
       *) \
         echo "Architecture Not Unsupported"; \
         exit 1; \
         ;; \
    esac;

ENV JAVA_VERSION jdk8u372-b07
ENV JAVA_HOME=/opt/java/openjdk
ENV ESUM="95d8cb8b5375ec00a064ed728eb60d925d44c1a79fe92f6ca7385b5863d4f78c"
ENV BINARY_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u372-b07/OpenJDK8U-jre_x64_alpine-linux_hotspot_8u372b07.tar.gz"

RUN curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}
RUN echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -;
RUN mkdir -p "$JAVA_HOME"
RUN cd /opt/java/openjdk
RUN tar --extract --file /tmp/openjdk.tar.gz --directory "$JAVA_HOME" --strip-components 1 --no-same-owner
RUN apk del --purge .fetch-deps
RUN rm -rf /var/cache/apk/*
RUN rm -rf /tmp/openjdk.tar.gz
RUN rm -f ${JAVA_HOME}/src.zip

ENV PATH="$JAVA_HOME/bin:$PATH"

RUN apk -vv info | sort

RUN echo "Verifying OpenJDK installation ..."
RUN java -version

RUN whoami
