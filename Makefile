# Copyright (c) 2024, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VERSION ?nIMAGE_REGISTRY ?= nvcr.io/nvidia/cloud-native
MAGE_NAME ?= gpu_TAG ?= $(VERSION)
IMAGE = $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# Go settings
GO ?= go
GOFLAGS ?= -mod= linux
md64

# Directories
ROOT_DIR := $(shell dirname $(realpath $())))
BIN_DIR := $(ROOT_DIR)/bin
COVER_DIR := $(ROOT_DIR)/coverage

.PHONY: all
all: build

## Build the GPU operator binary
.PHONY: build
build:
	@echo "Building gpu-operator..."
	GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build $(GOFLAGS) -o $(BIN_DIR)/gpu-operator ./cmd/gpu-operator/

## Run unit tests
.PHONY: test
test:
	@echo "Running unit tests..."
	mkdir -p $(COVER_DIR)
	$(GO) test $(GOFLAGS) -coverprofile=$(COVER_DIR)/coverage.out ./...

## Run unit tests with verbose output
.PHONY: test-verbose
test-verbose:
	@echo "Running unit tests (verbose)..."
	mkdir -p $(COVER_DIR)
	$(GO) test $(GOFLAGS) -v -coverprofile=$(COVER_DIR)/coverage.out ./...

## Generate test coverage report
.PHONY: coverage
coverage: test
	$(GO) tool cover -html=$(COVER_DIR)/coverage.out -o $(COVER_DIR)/coverage.html
	@echo "Coverage report generated at $(COVER_DIR)/coverage.html"

## Run linter
.PHONY: lint
lint:
	@echo "Running linter..."
	golangci-lint run ./...

## Format Go source files
.PHONY: fmt
fmt:
	$(GO) fmt ./...

## Tidy Go modules
.PHONY: tidy
tidy:
	$(GO) mod tidy

## Build the Docker image
.PHONY: docker-build
docker-build:
	@echo "Building Docker image $(IMAGE)..."
	docker build \
		--build-arg VERSION=$(VERSION) \
		-t $(IMAGE) \
		-f docker/Dockerfile .

## Push the Docker image
.PHONY: docker-push
docker-push:
	@echo "Pushing Docker image $(IMAGE)..."
	docker push $(IMAGE)

## Generate CRD manifests and deepcopy functions
.PHONY: generate
generate:
	@echo "Generating code..."
	controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."

## Generate CRD YAML manifests
.PHONY: manifests
manifests:
	@echo "Generating CRD manifests..."
	controller-gen crd:trivialVersions=true rbac:roleName=gpu-operator-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

## Install CRDs into the cluster
.PHONY: install
install: manifests
	kustomize build config/crd | kubectl apply -f -

## Uninstall CRDs from the cluster
.PHONY: uninstall
uninstall: manifests
	kustomize build config/crd | kubectl delete -f -

## Deploy the operator to the clus
