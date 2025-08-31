# For a demo container:
# docker build --tag=flux .
# To run tests:
# docker build --target=test .

# NOTE: liquid-fixpoint version not pinned,
# watch out for breaking changes

# ARG BASE_IMAGE requirements:
# - cargo is available
ARG BASE_IMAGE="docker.io/library/rust:1-bookworm"

FROM $BASE_IMAGE AS with-deps

# Important for handling unicode in files
ENV LANG="C.UTF-8" 

RUN \
  if [ "x86_64" != "$(uname -m)" ]; then echo "Invalid architecture - this image only supports x86_64" && exit 1; fi \
  # fetch liquid-fixpoint
  && FIXPOINT_ARCH_COMPONENT="x86_64" \
  && FIXPOINT_RELEASE_NAME="fixpoint-${FIXPOINT_ARCH_COMPONENT}-linux-gnu.tar.gz" \
  && FIXPOINT_URL="https://github.com/ucsd-progsys/liquid-fixpoint/releases/download/nightly/${FIXPOINT_RELEASE_NAME}" \
  && curl -fsSL --retry 3 -o fixpoint.tar.gz "$FIXPOINT_URL" \
  && tar xzf fixpoint.tar.gz \
  && rm fixpoint.tar.gz \
  && mv fixpoint /usr/local/bin/ \
  && fixpoint --version \
  # fetch z3
  && Z3_VERSION="4.12.1" \
  && Z3_ARCH_COMPONENT="x64" \
  && Z3_GLIBC_COMPONENT="2.35" \
  && Z3_URL="https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-${Z3_ARCH_COMPONENT}-glibc-${Z3_GLIBC_COMPONENT}.zip" \
  && curl -fsSL --retry 3 -o z3.zip "$Z3_URL" \
  && unzip z3.zip -d ./ \
  && rm z3.zip \
  && mv ./z3*/bin/z3 /usr/local/bin/ \
  && rm -rf ./z3*/ \
  && z3 --version

FROM with-deps AS flux-builder

COPY . /flux

WORKDIR /flux
RUN cargo xtask install

FROM flux-builder AS test

WORKDIR /flux
RUN cargo xtask test

FROM with-deps AS final

COPY --from=flux-builder \
  /usr/local/cargo/bin/flux \
  /usr/local/cargo/bin/cargo-flux \
  /usr/local/cargo/bin/
COPY --from=flux-builder /root/.flux /root/.flux

LABEL org.opencontainers.image.title="Flux - Liquid Types for Rust"
LABEL org.opencontainers.image.description="Docker image to build and test Flux"
LABEL org.opencontainers.image.vendor="ucsd-progsys"
LABEL org.opencontainers.image.source="https://github.com/flux-rs/flux"
LABEL org.opencontainers.image.licenses="MIT"