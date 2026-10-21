SHELLCHECK := koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d
HADOLINT := hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d
LINT := docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt
# build.sh's swappable components; a --build-arg without a value takes it from
# the environment (or make's command line) and is skipped when that's unset.
COMPONENTS := GOKZ GOKZ_SHA256 STEAMWORKS STEAMWORKS_SHA256 GLOBALAPI GLOBALAPI_SHA256

.PHONY: check lint build bundle clean outdated

check: lint build

lint:
	$(LINT) $(SHELLCHECK) *.sh maps/*.sh tools/*.sh
	$(LINT) --entrypoint /bin/hadolint $(HADOLINT) Dockerfile

# Downloads always rerun, since a cached layer would hide a dead link.
build:
	docker build --no-cache-filter build -t gokz-docker:check $(COMPONENTS:%=--build-arg %) .
	docker build --no-cache-filter maps --target maps -t gokz-docker-maps:check .

bundle:
	docker build --target bundle --output dist $(COMPONENTS:%=--build-arg %) .
	mv dist/files.txt dist/removed.txt bundle/

clean:
	rm -rf dist

outdated:
	@tools/outdated.sh
