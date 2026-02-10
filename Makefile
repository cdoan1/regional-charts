.PHONY: help lint package index clean install uninstall test all-images push-images bundle-helm clean-images

.DEFAULT_GOAL := help

CHART_NAME := hyperfleet-api
CHART_DIR := charts/$(CHART_NAME)
CHART_VERSION := $(shell grep '^version:' $(CHART_DIR)/Chart.yaml | awk '{print $$2}')
NAMESPACE := default

# Image build configuration
BUILD_DIR := /tmp/hyperfleet-build
DOCKER := docker
REPOS := hyperfleet-api hyperfleet-adapter hyperfleet-sentinel
REPO_BASE := https://github.com/openshift-hyperfleet

IMAGE_USER ?= quay.io/hyperfleet
IMAGE_TAG ?= latest

help:
	@echo "Available targets:"
	@echo "  lint         - Lint the Helm chart"
	@echo "  package      - Package the Helm chart"
	@echo "  index        - Update the Helm repository index"
	@echo "  all          - Lint, package, and update index"
	@echo "  install      - Install the chart to Kubernetes"
	@echo "  uninstall    - Uninstall the chart from Kubernetes"
	@echo "  test         - Run chart tests"
	@echo "  all-images   - Clone and build images for all HyperFleet components"
	@echo "  push-images  - Push all HyperFleet component images to registry"
	@echo "  bundle-helm  - Package Helm charts from all HyperFleet repos and update index"
	@echo "  clean        - Remove packaged charts"
	@echo "  clean-images - Remove cloned repositories"

lint:
	@echo "Linting $(CHART_NAME) chart..."
	helm lint $(CHART_DIR)

package: lint
	@echo "Packaging $(CHART_NAME) chart..."
	helm package $(CHART_DIR)

index: package
	@echo "Updating Helm repository index..."
	helm repo index . --url https://cdoan1.github.io/regional-charts

all: lint package index
	@echo "Build complete!"

install:
	@echo "Installing $(CHART_NAME) chart..."
	helm install $(CHART_NAME) $(CHART_DIR) -n $(NAMESPACE)

uninstall:
	@echo "Uninstalling $(CHART_NAME) chart..."
	helm uninstall $(CHART_NAME) -n $(NAMESPACE)

test:
	@echo "Testing $(CHART_NAME) chart..."
	helm template $(CHART_NAME) $(CHART_DIR) > /dev/null
	@echo "Template test passed!"

clean:
	@echo "Cleaning packaged charts..."
	rm -f *.tgz

all-images:
	@echo "Building all HyperFleet component images..."
	@mkdir -p $(BUILD_DIR)
	@for repo in $(REPOS); do \
		echo "Processing $$repo..."; \
		if [ -d "$(BUILD_DIR)/$$repo" ]; then \
			echo "  Repository already exists, pulling latest..."; \
			cd $(BUILD_DIR)/$$repo && git pull && cd ../..; \
		else \
			echo "  Cloning $$repo..."; \
			git clone $(REPO_BASE)/$$repo.git $(BUILD_DIR)/$$repo; \
		fi; \
		echo "  Building image for $$repo using its Makefile (target: image)..."; \
		cd $(BUILD_DIR)/$$repo && make image IMAGE_REGISTRY=$(IMAGE_USER) IMAGE_TAG=$(IMAGE_TAG) && cd ../..; \
		echo "  ✓ $$repo image built successfully"; \
		echo ""; \
	done
	@echo "All images built successfully!"

push-images:
	@echo "Pushing all HyperFleet component images..."
	@if [ ! -d "$(BUILD_DIR)" ]; then \
		echo "Error: Build directory $(BUILD_DIR) does not exist. Run 'make all-images' first."; \
		exit 1; \
	fi
	@for repo in $(REPOS); do \
		echo "Pushing $$repo..."; \
		if [ ! -d "$(BUILD_DIR)/$$repo" ]; then \
			echo "  Error: Repository $$repo not found. Run 'make all-images' first."; \
			exit 1; \
		fi; \
		echo "  Pushing image for $$repo using its Makefile (target: image-push)..."; \
		cd $(BUILD_DIR)/$$repo && make image-push IMAGE_REGISTRY=$(IMAGE_USER) IMAGE_TAG=$(IMAGE_TAG) && cd ../..; \
		echo "  ✓ $$repo image pushed successfully"; \
		echo ""; \
	done
	@echo "All images pushed successfully!"

bundle-helm:
	@echo "Bundling Helm charts from all HyperFleet repositories..."
	@mkdir -p $(BUILD_DIR)
	@mkdir -p charts
	@for repo in $(REPOS); do \
		echo "Processing $$repo..."; \
		if [ ! -d "$(BUILD_DIR)/$$repo" ]; then \
			echo "  Cloning $$repo..."; \
			git clone $(REPO_BASE)/$$repo.git $(BUILD_DIR)/$$repo; \
		else \
			echo "  Repository already exists, pulling latest..."; \
			git -C $(BUILD_DIR)/$$repo pull; \
		fi; \
		echo "  Finding Helm chart in $$repo..."; \
		CHART_PATH=$$(find $(BUILD_DIR)/$$repo -name "Chart.yaml" -type f | head -1); \
		if [ -z "$$CHART_PATH" ]; then \
			echo "  ⚠ No Chart.yaml found in $$repo, skipping..."; \
			continue; \
		fi; \
		CHART_DIR=$$(dirname $$CHART_PATH); \
		CHART_NAME=$$(grep '^name:' $$CHART_PATH | awk '{print $$2}'); \
		echo "  Found chart '$$CHART_NAME' at $$CHART_DIR"; \
		echo "  Syncing chart to ./charts/$$CHART_NAME..."; \
		rm -rf ./charts/$$CHART_NAME; \
		cp -r $$CHART_DIR ./charts/$$CHART_NAME; \
		echo "  Packaging chart..."; \
		helm package ./charts/$$CHART_NAME -d .; \
		echo "  ✓ $$repo chart synced and packaged successfully"; \
		echo ""; \
	done
	@echo "Updating Helm repository index..."
	@helm repo index . --url https://cdoan1.github.io/regional-charts --merge index.yaml
	@echo "✓ All Helm charts bundled and index updated!"

clean-images:
	@echo "Cleaning cloned repositories..."
	rm -rf $(BUILD_DIR)

