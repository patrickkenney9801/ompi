SHELL := /bin/bash

IMAGE_NAME ?= ompi-dev
IMAGE_VERSION ?= latest
RELEASE_IMAGE_NAME ?= ompi
RELEASE_IMAGE_VERSION ?= 5.0.2
SRC_DIR ?= $(shell pwd)

PROFILE ?= observability

CONTAINER_TOOL ?= docker
CONTAINER_CONTEXT ?= default
CONTAINER_OPTS ?=
CONTAINER_CMD ?= bash -l
CONTAINER_SRC_DIR ?= ${SRC_DIR}
CONTAINER_BUILD_DIR ?= ${CONTAINER_SRC_DIR}/build
CONTAINER_WORK_DIR ?= ${CONTAINER_SRC_DIR}
INTERACTIVE ?= i
UNAME ?= $(shell whoami)
UID ?= $(shell id -u)
GID ?= $(shell id -g)

# Developer variables that should be set as env vars in startup files like .profile
OMPI_PARALLELISM ?= 16
OMPI_CONTAINER_MOUNTS ?=
OMPI_CONTAINER_ENV ?=
OMPI_PREFIX_PATH ?= ${CONTAINER_BUILD_DIR}
OMPI_OUTPUT_FILE ?= ${CONTAINER_BUILD_DIR}/config.out

build-image:
	@${CONTAINER_TOOL} --context ${CONTAINER_CONTEXT} build \
	--build-arg UNAME=${UNAME} \
  --build-arg UID=${UID} \
  --build-arg GID=${GID} \
	-t ${IMAGE_NAME}:${IMAGE_VERSION} \
	--file Containerfile \
	--target build .

run-image:
	@${CONTAINER_TOOL} --context ${CONTAINER_CONTEXT} run --rm \
	-v ${SRC_DIR}/:${CONTAINER_SRC_DIR} \
	${OMPI_CONTAINER_MOUNTS} \
	${OMPI_CONTAINER_ENV} \
	--privileged \
	--network host \
	--workdir=${CONTAINER_WORK_DIR} ${CONTAINER_OPTS} -${INTERACTIVE}t \
	${IMAGE_NAME}:${IMAGE_VERSION} ${CONTAINER_CMD}

.PHONY: setup
setup:
	@AUTOMAKE_JOBS=${OMPI_PARALLELISM} ${CONTAINER_SRC_DIR}/autogen.pl

.PHONY: configure
configure:
	@mkdir -p ${CONTAINER_BUILD_DIR}
	@cd ${CONTAINER_BUILD_DIR} && ${CONTAINER_SRC_DIR}/configure --prefix=${OMPI_PREFIX_PATH} 2>&1 | tee ${OMPI_OUTPUT_FILE}

.PHONY: build
build:
	@make -C ${CONTAINER_BUILD_DIR} -j ${OMPI_PARALLELISM} all
	@make -C ${CONTAINER_BUILD_DIR} -j ${OMPI_PARALLELISM} install

deploy-image:
	@${CONTAINER_TOOL} --context ${CONTAINER_CONTEXT} build \
  --build-arg OMPI_PREFIX_PATH=${OMPI_PREFIX_PATH} \
	-t ${RELEASE_IMAGE_NAME}:${RELEASE_IMAGE_VERSION} \
	--file Containerfile \
	--target release .
	@minikube -p ${PROFILE} image load ${RELEASE_IMAGE_NAME}:${RELEASE_IMAGE_VERSION}

run-deploy:
	@${CONTAINER_TOOL} --context ${CONTAINER_CONTEXT} run --rm \
	-${INTERACTIVE}t \
	${RELEASE_IMAGE_NAME}:${RELEASE_IMAGE_VERSION} ${CONTAINER_CMD}
