.PHONY: help lint package index clean install uninstall test all-images clean-images

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

clean-images:
	@echo "Cleaning cloned repositories..."
	rm -rf $(BUILD_DIR)

