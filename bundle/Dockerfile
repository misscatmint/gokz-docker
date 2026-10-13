# Builds the add-on zips (see tools/bundle.sh). Run from the repo root with
# `make bundle`, which copies the updated state back into bundle/.
FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS bundle
# GNU and Info-ZIP tools in place of BusyBox's, which build.sh wasn't written for.
RUN apk add --no-cache bash coreutils curl diffutils findutils grep sed tar unzip zip
# Defaults live in build.sh.
ARG GOKZ GOKZ_SHA256 STEAMWORKS STEAMWORKS_SHA256 GLOBALAPI GLOBALAPI_SHA256
RUN --mount=type=bind,source=build.sh,target=/build.sh \
    --mount=type=bind,source=overlay,target=/overlay \
    --mount=type=bind,source=tools,target=/tools \
    --mount=type=bind,source=bundle,target=/state \
    /build.sh /build && mkdir /out && cp /state/files.txt /state/removed.txt /out/ && \
    /tools/bundle.sh /build /out /out

FROM scratch
COPY --from=bundle /out /
