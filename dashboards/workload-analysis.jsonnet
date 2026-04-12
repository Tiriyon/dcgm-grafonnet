// Workload Analysis Dashboard — v0.1.0
// Mirrors Run:AI per-project/workload breakdown
// Build: jsonnet -J vendor dashboards/workload-analysis.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local workloadAnalysis = import '../lib/panels/workload_analysis.libsonnet';

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

local workloadVar =
  var.query.new('workload')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('exported_pod', 'DCGM_FI_DEV_FB_USED{exported_pod!=""}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// --- Dashboard ---
g.dashboard.new('Workload Analysis')
+ g.dashboard.withUid('workload-analysis')
+ g.dashboard.withDescription('Per-deployment and per-workload GPU, CPU, and RAM breakdown. Mirrors Run:AI per-project/workload view.')
+ g.dashboard.withTags(['gpu', 'workload', 'deployment', 'dcgm', 'runai'])
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
  workloadVar,
])
+ g.dashboard.withPanels(
  workloadAnalysis.panels
)