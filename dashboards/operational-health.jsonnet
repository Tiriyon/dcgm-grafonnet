// Operational Health / Analytics Dashboard — v0.1.0
// Mirrors Run:AI Analytics Dashboard
// Time-series trends: power, temperature, clock, compute, tensor, disk
// Build: jsonnet -J vendor dashboards/operational-health.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local opHealth = import '../lib/panels/op_health.libsonnet';

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

local gpuModelVar =
  var.query.new('gpu_model')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('modelName', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// --- Dashboard ---
g.dashboard.new('Operational Health / Analytics')
+ g.dashboard.withUid('operational-health')
+ g.dashboard.withDescription('GPU operational health trends — power, temperature, clock, compute, tensor utilization, and disk usage. Mirrors Run:AI Analytics.')
+ g.dashboard.withTags(['gpu', 'operational-health', 'analytics', 'dcgm', 'runai'])
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
  gpuModelVar,
])
+ g.dashboard.withPanels(
  opHealth.panels
)
