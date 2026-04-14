// VRAM Capacity Planning Dashboard
// Mirrors Run:AI GPU Allocation + Utilization tracking
// Answers: "Do we have enough VRAM? Who's consuming it? Do we need to scale?"
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local timeSeries = g.panel.timeSeries;
local barGauge = g.panel.barGauge;
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

{
  panels: [
    // --- Row 1: Cluster VRAM Summary ---
    row.new('Cluster VRAM Summary')
    + row.withGridPos(0),

    stat.new('Total Memory Capacity')
    + stat.panelOptions.withDescription('Total GPU memory capacity across all devices')
    + stat.panelOptions.withGridPos(4, 4, 0, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.totalMemoryCapacityByHost)
      + prometheus.withLegendFormat('Total Capacity'),
    ])
    + stat.standardOptions.withUnit('decgbytes')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Memory In Use')
    + stat.panelOptions.withDescription('Total GPU memory currently in use')
    + stat.panelOptions.withGridPos(4, 4, 4, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.memoryInUseByHost)
      + prometheus.withLegendFormat('Used'),
    ])
    + stat.standardOptions.withUnit('decgbytes')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    gauge.new('Avg Memory Utilization')
    + gauge.panelOptions.withDescription('Average VRAM utilization across all devices')
    + gauge.panelOptions.withGridPos(4, 4, 8, 1)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.avgMemoryUtilByHost)
      + prometheus.withLegendFormat('Avg Memory %'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.memory)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('OOM Risk %')
    + stat.panelOptions.withDescription('Percentage of devices at risk of OOM (>85% VRAM)')
    + stat.panelOptions.withGridPos(4, 4, 12, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.oomRiskPctByHost)
      + prometheus.withLegendFormat('OOM Risk %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.riskPct)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Avg Temperature')
    + stat.panelOptions.withDescription('Average temperature across all GPUs')
    + stat.panelOptions.withGridPos(4, 4, 16, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgTemperatureByHost)
      + prometheus.withLegendFormat('Avg Temp'),
    ])
    + stat.standardOptions.withUnit('celsius')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.temperature)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Avg Power per Device')
    + stat.panelOptions.withDescription('Average power usage per device')
    + stat.panelOptions.withGridPos(4, 4, 20, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgPowerByHost)
      + prometheus.withLegendFormat('Avg Power'),
    ])
    + stat.standardOptions.withUnit('watt')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('orange'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // --- Row 2: Per-Node VRAM Utilization ---
    row.new('Per-Node VRAM Utilization')
    + row.withGridPos(5),

    // VRAM Utilization % — repeated per node (whole GPU + MIG split)
    timeSeries.new('Memory Utilization % — $hostname')
    + timeSeries.panelOptions.withDescription('VRAM utilization per device on this node. Whole GPUs and MIG instances shown separately.')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 6)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.memoryUtilWholeGPU)
      + prometheus.withLegendFormat('{{modelName}} GPU{{gpu}}'),
      prometheus.new(ds, q.memoryUtilMIG)
      + prometheus.withLegendFormat('{{modelName}} GPU{{gpu}} MIG{{GPU_I_ID}} ({{GPU_I_PROFILE}})'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.memory)
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

    // --- Row 3: Namespace VRAM & Compute ---
    row.new('Namespace VRAM & Compute')
    + row.withGridPos(15),

    // VRAM by Namespace — repeated per node
    barGauge.new('VRAM by Namespace — $hostname')
    + barGauge.panelOptions.withDescription('VRAM used per namespace on this node')
    + barGauge.panelOptions.withGridPos(8, 24, 0, 16)
    + barGauge.panelOptions.withRepeat('hostname')
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.memoryByNamespacePerNode)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + barGauge.standardOptions.withUnit('decmbytes')
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // Compute % by Device — repeated per node
    timeSeries.new('Compute % by Device — $hostname')
    + timeSeries.panelOptions.withDescription('GR engine active % per GPU/MIG device on this node')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 25)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.computeByDevice)
      + prometheus.withLegendFormat('{{modelName}} GPU{{gpu}} {{GPU_I_PROFILE}}'),
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

    // --- Row 4: Workload VRAM Over Time ---
    row.new('Workload VRAM Over Time')
    + row.withGridPos(34),

    timeSeries.new('Workload Memory Over Time')
    + timeSeries.panelOptions.withDescription('VRAM used by workloads over time')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 35)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.workloadMemoryOverTimeByHost)
      + prometheus.withLegendFormat('{{Hostname}} / {{modelName}} / {{exported_pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('decmbytes')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max'])
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
