SHELLCHECK := koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d
HADOLINT := hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d
LINT := docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt

.PHONY: check lint build outdated

check: lint build

lint:
	$(LINT) $(SHELLCHECK) *.sh maps/*.sh tools/*.sh
	$(LINT) --entrypoint /bin/hadolint $(HADOLINT) Dockerfile maps/Dockerfile

build:
	docker build -t gokz-docker:check .
	docker build -t gokz-docker-maps:check maps

outdated:
	@tools/outdated.sh
