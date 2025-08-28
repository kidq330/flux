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

ENV ARCH="x86_64"

RUN \
  if [ "$(uname -m)" != "$ARCH" ]; then echo "Invalid architecture - this image only supports x86_64" && exit 1; fi \
  # fetch liquid-fixpoint
  && NAME="fixpoint-${ARCH}-linux-gnu.tar.gz" \
  && URL="https://github.com/ucsd-progsys/liquid-fixpoint/releases/download/nightly/${NAME}" \
  && curl -fsSL --retry 3 -o "$NAME" "$URL" \
  && tar xzf "$NAME" \
  && rm "$NAME" \
  && mv fixpoint /usr/local/bin/ \
  && fixpoint --version \
  # fetch z3
  && Z3_VERSION="4.12.1" \
  && ARCH_COMPONENT="x64" \
  && GLIBC_COMPONENT="2.35" \

  && URL="https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-${ARCH_COMPONENT}-glibc-${GLIBC_COMPONENT}.zip" \
  && curl -fsSL --retry 3 -o z3.zip "$URL" \
  && unzip z3.zip -d ~/ \
  && rm z3.zip \
  && mv ~/z3*/bin/z3 /usr/local/bin/ \
  && z3 --version

FROM with-deps AS flux-builder

# Don't copy everything like docs etc unless they affect the build
COPY ./.cargo /flux/.cargo
COPY ./Cargo.lock /flux/Cargo.lock
COPY ./Cargo.toml /flux/Cargo.toml
COPY ./clippy.toml /flux/clippy.toml
COPY ./crates /flux/crates
COPY ./lib /flux/lib
COPY ./rust-toolchain.toml /flux/rust-toolchain.toml
COPY ./tools /flux/tools
COPY ./typos.toml /flux/typos.toml
COPY ./xtask /flux/xtask

# test
COPY ./tests /flux/tests

# dev
COPY ./backtracetk.toml /flux/backtracetk.toml 
COPY ./rustfmt.toml /flux/rustfmt.toml
# COPY . /flux

WORKDIR /flux
RUN \
  fixpoint --version \
  && z3 --version \
  && cargo xtask install

FROM flux-builder AS test

WORKDIR /flux
RUN \
  fixpoint --version \
  && z3 --version \
  && cargo xtask test

# To have flux source available from inside the container, one can substitute `with-deps` with `flux-builder`,
# but if you want the changes to persist across containers (which is what's usually desired),
# then a bound volume with the flux project is a better solution 
FROM with-deps AS final
LABEL org.opencontainers.image.title="Flux - Liquid Types for Rust"
LABEL org.opencontainers.image.description="Docker image to build and test Flux"
LABEL org.opencontainers.image.vendor="ucsd-progsys"
LABEL org.opencontainers.image.source="https://github.com/flux-rs/flux"
LABEL org.opencontainers.image.licenses="MIT"

COPY --from=flux-builder \
  /usr/local/cargo/bin/rustc-flux \
  /usr/local/cargo/bin/cargo-flux \
  /usr/local/cargo/bin/
COPY --from=flux-builder /root/.flux /root/.flux