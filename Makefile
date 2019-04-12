.PHONY: base python-build image push

BASE := oraclelinux:7-slim
REPO := aptplatforms/oraclelinux-python
PYTHON_VERSION := 3.7.3
PYTHON_PIP_VERSION := 19.0.3
PYTHON_GPG_KEY := 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ORA_VERSION := 18.5
VERSION := 7-slim-py${PYTHON_VERSION}-oic${ORA_VERSION}

base:
	@docker pull ${BASE}
	@docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$@ \
		--tag ${REPO}:$@ --target $@ .

python-build: base
	@docker pull ${REPO}:$@ || true
	docker build \
		--cache-from ${BASE} \
		--cache-from ${REPO}:$< \
		--cache-from ${REPO}:$@ \
		--build-arg PYTHON_VERSION=${PYTHON_VERSION} \
		--build-arg PYTHON_GPG_KEY=${PYTHON_GPG_KEY} \
		--build-arg PYTHON_PIP_VERSION=${PYTHON_PIP_VERSION} \
		--tag ${REPO}:$@ --target $@ .

image: base python-build
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
