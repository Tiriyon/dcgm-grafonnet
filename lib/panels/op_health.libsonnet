// Operational Health / Analytics Dashboard
// Time-series trends: power, temperature, clock, compute, tensor, disk.
// Answers: "How are things trending? Are there thermal, power, or clock anomalies?"
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
local row = g.panel.row;

local ds = '${datasource}';

local tsDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

local legendTable =
  timeSeries.options.legend.withDisplayMode('table')
  + timeSeries.options.legend.withPlacement('right')
  + timeSeries.options.legend.withShowLegend(true)
  + timeSeries.options.legend.withCalcs(['mean', 'max'])
  + timeSeries.options.tooltip.withMode('multi')
  + timeSeries.options.tooltip.withSort('desc');

{
  panels: [
    // --- Row 1: Thermal & Power ---
    row.new('Thermal & Power')
    + row.withGridPos(0),

    // Power Usage by Device
    timeSeries.new('Power Usage by Device')
    + timeSeries.panelOptions.withDescription('Power usage over time per device (filtered by selected nodes)')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 1)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.powerByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-MIG{{GPU_I_ID}}'),
    ])
    + timeSeries.standardOptions.withUnit('watt')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + legendTable,

    // Temperature by Device
    timeSeries.new('Temperature by Device')
    + timeSeries.panelOptions.withDescription('Temperature over time per device (filtered by selected nodes)')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 1)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.temperatureByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-MIG{{GPU_I_ID}}'),
    ])
    + timeSeries.standardOptions.withUnit('celsius')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.temperature)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + legendTable,

    // --- Row 2: Compute & Clock ---
    row.new('Compute & Clock')
    + row.withGridPos(9),

    // Top 10 Devices by Compute %
    timeSeries.new('Top 10 Devices by Compute %')
    + timeSeries.panelOptions.withDescription('Top 10 GPU/MIG devices by GR engine active % (pure compute, no composite formula)')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 10)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.top10DeviceCompute)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-{{GPU_I_PROFILE}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.compute)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // SM Clock by GPU Model
    timeSeries.new('SM Clock by GPU Model')
    + timeSeries.panelOptions.withDescription('SM Clock frequency by GPU model')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 18)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.smClockByModel)
      + prometheus.withLegendFormat('{{modelName}}'),
    ])
    + timeSeries.standardOptions.withUnit('none')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + legendTable,

    // Tensor Utilization by Workload
    timeSeries.new('Tensor Utilization by Workload')
    + timeSeries.panelOptions.withDescription('Tensor core utilization per workload')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 18)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.tensorUtilByWorkloadByHost)
      + prometheus.withLegendFormat('{{exported_pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + legendTable,

    // --- Row 3: Disk ---
    row.new('Node Disk')
    + row.withGridPos(26),

    // Node Disk Usage — repeated per node
    timeSeries.new('Node Disk Usage — $hostname')
    + timeSeries.panelOptions.withDescription('Local disk utilization over time for this node. Source: node-exporter. Mountpoint: /.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 27)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.nodeDiskUsagePct)
      + prometheus.withLegendFormat('Disk Used %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('thresholds')
    + timeSeries.standardOptions.thresholds.withSteps(t.diskUsage)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withPlacement('bottom')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
