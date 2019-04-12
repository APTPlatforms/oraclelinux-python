.PHONY: base builder image push

BASE := oraclelinux:7-slim
REPO := aptplatforms/oraclelinux-python
PYTHON_VERSION := 3.7.3
PYTHON_PIP_VERSION := 19.0.3
ORA_VERSION := 18.5
VERSION := 7-slim-py${PYTHON_VERSION}-oic${ORA_VERSION}

base:
	@docker pull ${BASE}
	@docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$@ \
		--tag ${REPO}:$@ --target $@ .

builder: base
	@docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$< \
		--cache-from ${REPO}:$@ \
		--build-arg PYTHON_VERSION=${PYTHON_VERSION} \
		--build-arg PYTHON_PIP_VERSION=${PYTHON_PIP_VERSION} \
		--tag ${REPO}:$@ --target $@ .

image: base builder
	@docker pull ${REPO}:latest || true
	docker build \
		--cache-from ${BASE} \
		$(addprefix --cache-from ${REPO}:,$^) \
		--cache-from ${REPO}:latest \
		--build-arg ORA_VERSION=${ORA_VERSION} \
		--tag ${REPO}:${VERSION} --target python-oracle .
	docker tag ${REPO}:${VERSION} ${REPO}:latest

push: image
	docker push ${REPO}
