BASE := oraclelinux:7-slim
REPO := aptplatforms/oraclelinux-python
PYTHON_VERSION := 3.7.6
PYTHON_PIP_VERSION := 20.0.2
ORA_VERSION := 19.5
VERSION := 7-slim-py${PYTHON_VERSION}-oic${ORA_VERSION}

export DOCKER_BUILDKIT := 1

.PHONY: base
base:
	@docker pull ${BASE}
ifneq ($(NOCACHE),)
	docker build \
		--pull \
		--no-cache \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--tag ${REPO}:$@ --target $@ .
else
	@docker image inspect ${REPO}:$@ &>/dev/null || docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$@ \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--tag ${REPO}:$@ --target $@ .
endif

.PHONY: oracle-base
oracle-base: base
ifneq ($(NOCACHE),)
	docker build \
		--pull \
		--no-cache \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg ORA_VERSION=${ORA_VERSION} \
		--tag ${REPO}:$@ --target $@ .
else
	@docker image inspect ${REPO}:$@ &>/dev/null || docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$< \
		--cache-from ${REPO}:$@ \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg ORA_VERSION=${ORA_VERSION} \
		--tag ${REPO}:$@ --target $@ .
endif

.PHONY: builder
builder: base
ifneq ($(NOCACHE),)
	docker build \
		--pull \
		--no-cache \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg PYTHON_VERSION=${PYTHON_VERSION} \
		--build-arg PYTHON_PIP_VERSION=${PYTHON_PIP_VERSION} \
		--tag ${REPO}:$@ --target $@ .
else
	@docker image inspect ${REPO}:$@ &>/dev/null || docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$< \
		--cache-from ${REPO}:$@ \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg PYTHON_VERSION=${PYTHON_VERSION} \
		--build-arg PYTHON_PIP_VERSION=${PYTHON_PIP_VERSION} \
		--tag ${REPO}:$@ --target $@ .
endif

.PHONY: python-oracle
python-oracle: base oracle-base builder
ifneq ($(NOCACHE),)
	docker build \
		--pull \
		--no-cache \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg ORA_VERSION=${ORA_VERSION} \
		--tag ${REPO}:${VERSION} --target $@ .
else
	@docker image inspect ${REPO}:$@ &>/dev/null || docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		$(addprefix --cache-from ${REPO}:,$^) \
		--cache-from ${REPO}:latest \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg ORA_VERSION=${ORA_VERSION} \
		--tag ${REPO}:${VERSION} --target $@ .
endif
	docker tag ${REPO}:${VERSION} ${REPO}:latest

.PHONY: image
image: python-oracle

.PHONY: push
push: image
	docker push ${REPO}
