// Storage Dashboard (Node Disk + PVC) — v0.1.0
// No direct Run:AI equivalent — covers node disk and PVC health
// Build: jsonnet -J vendor dashboards/storage.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local storageDash = import '../lib/panels/storage_dash.libsonnet';

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

// --- Dashboard ---
g.dashboard.new('Storage (Node Disk + PVC)')
+ g.dashboard.withUid('storage-dashboard')
+ g.dashboard.withDescription('Node disk and Persistent Volume Claim health — utilization, capacity, and trends.')
+ g.dashboard.withTags(['storage', 'disk', 'pvc', 'node-exporter', 'kubelet', 'runai'])
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
])
+ g.dashboard.withPanels(
  storageDash.panels
)
