// GPU Overview Dashboard — v0.1.0
// Mirrors Run:AI GPU/CPU Overview Dashboard
// Real-time "what's happening now" view
// Build: jsonnet -J vendor dashboards/gpu-overview.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local gpuOverview = import '../lib/panels/gpu_overview.libsonnet';

// --- Variables ---
local var = g.dashboard.variable;

local datasourceVar =
  var.datasource.new('datasource', 'prometheus');

local hostnameVar =
  var.query.new('hostname')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('Hostname', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(false)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local namespaceVar =
  var.query.new('namespace')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('exported_namespace', 'DCGM_FI_DEV_FB_USED{exported_namespace!=""}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local gpuModelVar =
  var.query.new('gpu_model')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('modelName', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// --- Dashboard ---
g.dashboard.new('GPU Overview')
+ g.dashboard.withUid('gpu-overview')
+ g.dashboard.withDescription('Real-time GPU cluster overview — device status, workload allocation, VRAM summary, and pod health. Mirrors Run:AI GPU/CPU Overview.')
+ g.dashboard.withTags(['gpu', 'overview', 'dcgm', 'runai', 'real-time'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(true)
+ g.dashboard.time.withFrom('now-1h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('10s')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['5s', '10s', '30s', '1m', '5m'])
+ g.dashboard.withVariables([
  datasourceVar,
  hostnameVar,
  namespaceVar,
  gpuModelVar,
])
+ g.dashboard.withPanels(
  gpuOverview.panels
)
