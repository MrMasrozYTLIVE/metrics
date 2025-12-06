# syntax=docker/dockerfile:1.16

# Base image
FROM node:22

# Install latest chrome dev package, fonts to support major charsets and skip chromium download on puppeteer install
# Based on https://github.com/puppeteer/puppeteer/blob/main/docs/troubleshooting.md#running-puppeteer-in-docker
RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends wget ca-certificates xz-utils build-essential zlib1g-dev \
  && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && apt-get install -y --no-install-recommends ./google-chrome-stable_current_amd64.deb fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 libxml2 libxml2-dev \
  && rm -rf ./google-chrome-stable_current_amd64.deb \
  && wget https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz \
  && tar -xf libxml2-2.12.7.tar.xz \
  && cd libxml2-2.12.7 \
  && ./configure --prefix=/usr/local --without-python \
  && make -j$(nproc) \
  && make install \
  && cd .. \
  && rm -rf libxml2-2.12.7* \
  && wget https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.39.tar.xz \
  && tar -xf libxslt-1.1.39.tar.xz \
  && cd libxslt-1.1.39 \
  && ./configure --prefix=/usr/local --with-libxml-prefix=/usr/local \
  && make -j$(nproc) \
  && make install \
  && cd .. \
  && rm -rf libxslt-1.1.39* \
  && ldconfig \
  && rm -rf /var/lib/apt/lists/*

# Install deno for miscellaneous scripts
# TODO: pin major deno version
COPY --from=denoland/deno:bin /deno /usr/local/bin/deno

# Install licensed through pkgx
# TODO: pin major pkgx version
COPY --from=pkgxdev/pkgx:busybox /usr/local/bin/pkgx /usr/local/bin/pkgx
COPY --chmod=+x <<EOF /usr/local/bin/licensed
#!/usr/bin/env -S pkgx --shebang --quiet +github.com/licensee/licensed@5 -- licensed
EOF
RUN licensed --version

# Environment variables
ENV PUPPETEER_SKIP_DOWNLOAD="true"
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/google-chrome-stable"

# Copy repository
WORKDIR /metrics
COPY . .

# Install node modules and rebuild indexes
RUN set -x \
  && which "${PUPPETEER_EXECUTABLE_PATH}" \
  && npm ci \
  && npm run build \
  && npm prune --omit=dev

# Execute GitHub action
ENTRYPOINT ["node", "/metrics/source/app/action/index.mjs"]
