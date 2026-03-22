JSONNET_BIN ?= jsonnet
JSONNETFMT_BIN ?= jsonnetfmt
JSONNET_ARGS ?= -J vendor

OUTPUT_DIR ?= output

.PHONY: build fmt lint test clean

build: $(OUTPUT_DIR)/gpu-capacity-planning-dashboard.json $(OUTPUT_DIR)/gpu-weekly-report-dashboard.json $(OUTPUT_DIR)/gpu-util-intelligence-dashboard.json $(OUTPUT_DIR)/vllm-monitoring-dashboard.json $(OUTPUT_DIR)/vllm-capacity-dashboard.json

$(OUTPUT_DIR)/gpu-capacity-planning-dashboard.json: dashboards/gpu-capacity-planning.jsonnet $(wildcard lib/*.libsonnet lib/**/*.libsonnet)
	@mkdir -p $(OUTPUT_DIR)
	$(JSONNET_BIN) $(JSONNET_ARGS) $< > $@
	@echo "Built $@"

$(OUTPUT_DIR)/gpu-util-intelligence-dashboard.json: dashboards/gpu-util-intelligence.jsonnet $(wildcard lib/*.libsonnet lib/**/*.libsonnet)
	@mkdir -p $(OUTPUT_DIR)
	$(JSONNET_BIN) $(JSONNET_ARGS) $< > $@
	@echo "Built $@"

$(OUTPUT_DIR)/vllm-monitoring-dashboard.json: dashboards/vllm-monitoring.jsonnet $(wildcard lib/*.libsonnet lib/**/*.libsonnet)
	@mkdir -p $(OUTPUT_DIR)
	$(JSONNET_BIN) $(JSONNET_ARGS) $< > $@
	@echo "Built $@"

$(OUTPUT_DIR)/gpu-weekly-report-dashboard.json: dashboards/gpu-weekly-report.jsonnet $(wildcard lib/*.libsonnet lib/**/*.libsonnet)
	@mkdir -p $(OUTPUT_DIR)
	$(JSONNET_BIN) $(JSONNET_ARGS) $< > $@
	@echo "Built $@"

$(OUTPUT_DIR)/vllm-capacity-dashboard.json: dashboards/vllm-capacity.jsonnet $(wildcard lib/*.libsonnet lib/**/*.libsonnet)
	@mkdir -p $(OUTPUT_DIR)
	$(JSONNET_BIN) $(JSONNET_ARGS) $< > $@
	@echo "Built $@"

test: build
	python3 scripts/check_dashboards.py $(OUTPUT_DIR)/*.json

fmt:
	find . -name '*.jsonnet' -o -name '*.libsonnet' | grep -v vendor | xargs $(JSONNETFMT_BIN) -i

lint:
	find . -name '*.jsonnet' -o -name '*.libsonnet' | grep -v vendor | xargs $(JSONNETFMT_BIN) --test

clean:
	rm -rf $(OUTPUT_DIR)
