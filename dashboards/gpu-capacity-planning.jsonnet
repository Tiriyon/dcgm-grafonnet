// GPU Capacity Planning Dashboard
// Build: jsonnet -J vendor dashboards/gpu-capacity-planning.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// Panel sections (each exports { panels: [...] })
local overview = import '../lib/panels/overview.libsonnet';
local memory = import '../lib/panels/memory.libsonnet';
local load = import '../lib/panels/load.libsonnet';
local workload = import '../lib/panels/workload.libsonnet';
local deployment = import '../lib/panels/deployment.libsonnet';
local inventory = import '../lib/panels/inventory.libsonnet';
local health = import '../lib/panels/health.libsonnet';

// --- Variables ---
local var = g.dashboard.variable;

local datasourceVar =
  var.datasource.new('datasource', 'prometheus');

local namespaceVar =
  var.query.new('namespace')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('exported_namespace', 'DCGM_FI_DEV_FB_USED{exported_namespace!=""}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local hostnameVar =
  var.query.new('hostname')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('Hostname', 'DCGM_FI_DEV_FB_USED')
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
g.dashboard.new('GPU Capacity Planning Dashboard')
+ g.dashboard.withUid('gpu-capacity-planning')
+ g.dashboard.withDescription('AI Workload Capacity Planning Dashboard - Comprehensive GPU/MIG monitoring with memory, compute, and workload analysis')
+ g.dashboard.withTags(['gpu', 'capacity-planning', 'mig', 'dcgm', 'ai-workloads', 'memory'])
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
  namespaceVar,
  hostnameVar,
  gpuModelVar,
])
+ g.dashboard.withPanels(
  overview.panels
  + memory.panels
  + load.panels
  + workload.panels
  + deployment.panels
  + inventory.panels
  + health.panels
)
