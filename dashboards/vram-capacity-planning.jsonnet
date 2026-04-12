// VRAM Capacity Planning Dashboard — v0.1.0
// Mirrors Run:AI GPU Allocation + Utilization tracking
// Build: jsonnet -J vendor dashboards/vram-capacity-planning.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local vramCapacity = import '../lib/panels/vram_capacity.libsonnet';

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
g.dashboard.new('VRAM Capacity Planning')
+ g.dashboard.withUid('vram-capacity-planning')
+ g.dashboard.withDescription('GPU VRAM allocation and utilization tracking — per-node, per-namespace, per-workload. Mirrors Run:AI GPU Allocation.')
+ g.dashboard.withTags(['gpu', 'vram', 'capacity-planning', 'dcgm', 'runai'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(true)
+ g.dashboard.time.withFrom('now-6h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['10s', '30s', '1m', '5m', '15m', '30m', '1h'])
+ g.dashboard.withVariables([
  datasourceVar,
  hostnameVar,
  namespaceVar,
  gpuModelVar,
])
+ g.dashboard.withPanels(
  vramCapacity.panels
)
