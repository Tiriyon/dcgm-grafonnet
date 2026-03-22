// vLLM Inference Capacity Dashboard — v2.0
// Platform → Model → Pod drill-down covering capacity, efficiency, utilisation and health.
//
// Sections:
//   1. Fleet Capacity Overview  — KPIs: throughput, queue depth, KV cache, preemptions
//   2. Saturation Signals       — queue depth + KV cache pressure per model over time
//   3. Throughput               — token and request rate per model
//   4. Request Latency          — E2E / TTFT / TPOT snapshots and timeseries
//   5. Cache Efficiency         — prefix cache hit rate and preemption rate
//   6. Per-Pod Detail           — KV cache, queue and token rate per replica
//
// Variable hierarchy: datasource → namespace → model_name → pod
// namespace + model_name scope all aggregated queries. pod scopes Section 6 only.
//
// Default time range: 1h (operational). Switch to 6h–24h for trend / capacity analysis.
// Build: jsonnet -J vendor dashboards/vllm-capacity.jsonnet
local g   = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local cap = import '../lib/panels/vllm_cap.libsonnet';

local var = g.dashboard.variable;

// ── Variables ──────────────────────────────────────────────────────────────────

local datasourceVar =
  var.datasource.new('datasource', 'prometheus')
  + var.datasource.withRegex('');

// Kubernetes namespace where vLLM pods run.
// Single-select so pod variable resolves to a clean list.
local namespaceVar =
  var.query.new('namespace')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('namespace', 'vllm:num_requests_running')
  + var.query.selectionOptions.withMulti(false)
  + var.query.selectionOptions.withIncludeAll(false)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// AI model(s) served by vLLM — multi-select for cross-model comparison.
local modelNameVar =
  var.query.new('model_name')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('model_name', 'vllm:num_requests_running{namespace="$namespace"}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// Pod (replica) selector — scopes Section 6 per-pod panels only.
local podVar =
  var.query.new('pod')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('pod', 'vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name"}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// ── Dashboard ──────────────────────────────────────────────────────────────────

g.dashboard.new('vLLM Inference Capacity')
+ g.dashboard.withUid('vllm-capacity')
+ g.dashboard.withDescription(
  'vLLM capacity drill-down: platform KPIs → per-model saturation signals and latency SLOs → per-replica load balance. Filter: namespace → model → pod.'
)
+ g.dashboard.withTags(['vllm', 'llm', 'inference', 'capacity', 'kv-cache', 'latency', 'gpu'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(false)
+ g.dashboard.time.withFrom('now-1h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['30s', '1m', '5m', '15m', '1h'])
+ g.dashboard.withVariables([
  datasourceVar,
  namespaceVar,
  modelNameVar,
  podVar,
])
+ g.dashboard.withPanels(cap.panels)
