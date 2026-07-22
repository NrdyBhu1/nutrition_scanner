# syntax=docker/dockerfile:1

# ---- Configurable build args ----
ARG FLUTTER_VERSION=3.41.6
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_PLATFORM=android-35
ARG ANDROID_BUILD_TOOLS=35.0.0
ARG ANDROID_NDK_VERSION=28.0.13004108

FROM ubuntu:22.04

ARG FLUTTER_VERSION
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION
ARG ANDROID_PLATFORM
ARG ANDROID_BUILD_TOOLS
ARG ANDROID_NDK_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# ---- System dependencies ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    ca-certificates \
    openjdk-17-jdk-headless \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# ---- Android SDK setup ----
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    curl -sSL -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_CMDLINE_TOOLS_VERSION}_latest.zip" && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null && \
    sdkmanager \
      "platform-tools" \
      "platforms;${ANDROID_PLATFORM}" \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "ndk;${ANDROID_NDK_VERSION}"

ENV ANDROID_NDK_HOME=${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}

# ---- Flutter SDK (pinned version) ----
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=${PATH}:${FLUTTER_HOME}/bin

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    || (echo "Tag ${FLUTTER_VERSION} not found directly, trying with 'v' prefix" && \
        rm -rf ${FLUTTER_HOME} && \
        git clone --depth 1 --branch v${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME})

# Mark the flutter repo as safe (needed since it's cloned as a different user context sometimes)
RUN git config --global --add safe.directory ${FLUTTER_HOME}

RUN flutter config --no-analytics && \
    flutter config --android-sdk ${ANDROID_SDK_ROOT} && \
    yes | flutter doctor --android-licenses || true && \
    flutter precache --android && \
    flutter doctor -v

# ---- App build ----
WORKDIR /app

# Copy pubspec first to leverage Docker layer caching for dependencies
COPY pubspec.* ./
RUN flutter pub get || true

# Copy the rest of the project
COPY . .

RUN flutter pub get

# Entry point script copies the built APK(s) into the mounted /output volume
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

VOLUME ["/output"]

ENTRYPOINT ["/entrypoint.sh"]
