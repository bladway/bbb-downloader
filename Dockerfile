FROM elgalu/selenium:latest

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG FIREFOX_VERSION=158.0.1
ARG GECKODRIVER_VERSION=0.37.1

ENV FIREFOX_VERSION=${FIREFOX_VERSION}

# =================================
# Install Firefox
# =================================

RUN set -eux; \
    cd /tmp; \
    wget -4 --timeout=30 --tries=5 --waitretry=3 --show-progress \
        "https://archive.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.tar.xz" \
        -O firefox.tar.xz; \
    rm -rf /opt/firefox; \
    tar -xJf firefox.tar.xz -C /opt; \
    test -x /opt/firefox/firefox; \
    ln -sfn /opt/firefox/firefox /usr/bin/firefox; \
    chown -R seluser:seluser /opt/firefox; \
    chmod -R a+rX /opt/firefox; \
    rm -f firefox.tar.xz

# =================================
# Install GeckoDriver
# =================================

RUN set -eux; \
    cd /tmp; \
    wget -4 --timeout=30 --tries=5 --waitretry=3 --show-progress \
        "https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz" \
        -O geckodriver.tar.gz; \
    tar -xzf geckodriver.tar.gz; \
    install -o root -g root -m 0755 geckodriver /usr/bin/geckodriver; \
    install -o root -g root -m 0755 geckodriver /opt/geckodriver; \
    rm -f geckodriver geckodriver.tar.gz

LABEL selenium_firefox_version="${FIREFOX_VERSION}"
LABEL selenium_geckodriver_version="${GECKODRIVER_VERSION}"

USER seluser
