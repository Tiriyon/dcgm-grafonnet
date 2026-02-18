// Row 2: Memory Capacity Planning
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local timeSeries = g.panel.timeSeries;
local pieChart = g.panel.pieChart;
local row = g.panel.row;

local ds = '${datasource}';

// Common timeseries field config
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
    row.new('Memory Capacity Planning')
    + row.withGridPos(5),

    // Total Memory Capacity
    stat.new('Total Memory Capacity')
    + stat.panelOptions.withDescription('Total GPU memory capacity across all devices')
    + stat.panelOptions.withGridPos(4, 4, 0, 6)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.totalMemoryCapacity)
      + prometheus.withLegendFormat('Total Capacity'),
    ])
    + stat.standardOptions.withUnit('decgbytes')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Memory In Use
    stat.new('Memory In Use')
    + stat.panelOptions.withDescription('Total GPU memory currently in use')
    + stat.panelOptions.withGridPos(4, 4, 4, 6)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.memoryInUse)
      + prometheus.withLegendFormat('Used'),
    ])
    + stat.standardOptions.withUnit('decgbytes')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Avg Memory Utilization (gauge)
    gauge.new('Avg Memory Utilization')
    + gauge.panelOptions.withDescription('Average memory utilization percentage across all devices')
    + gauge.panelOptions.withGridPos(4, 4, 8, 6)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.avgMemoryUtil)
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

    // OOM Risk %
    stat.new('OOM Risk %')
    + stat.panelOptions.withDescription('Percentage of devices at risk of OOM (>85% memory)')
    + stat.panelOptions.withGridPos(4, 4, 12, 6)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.oomRiskPct)
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

    // Avg Temperature
    stat.new('Avg Temperature')
    + stat.panelOptions.withDescription('Average temperature across all GPUs')
    + stat.panelOptions.withGridPos(4, 4, 16, 6)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgTemperature)
      + prometheus.withLegendFormat('Avg Temp'),
    ])
    + stat.standardOptions.withUnit('celsius')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.temperature)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Avg Power per Device
    stat.new('Avg Power per Device')
    + stat.panelOptions.withDescription('Average power usage per device')
    + stat.panelOptions.withGridPos(4, 4, 20, 6)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgPower)
      + prometheus.withLegendFormat('Avg Power'),
    ])
    + stat.standardOptions.withUnit('watt')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('orange'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Memory Utilization % by Device (timeseries)
    timeSeries.new('Memory Utilization % by Device')
    + timeSeries.panelOptions.withDescription('Memory utilization per device over time')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 10)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.memoryUtilByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-MIG{{GPU_I_ID}}'),
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

    // Memory by Namespace (pie chart)
    pieChart.new('Memory by Namespace')
    + pieChart.panelOptions.withDescription('GPU memory distribution by namespace')
    + pieChart.panelOptions.withGridPos(8, 6, 12, 10)
    + pieChart.queryOptions.withTargets([
      prometheus.new(ds, q.memoryByNamespace)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + pieChart.standardOptions.withUnit('decmbytes')
    + pieChart.standardOptions.color.withMode('palette-classic')
    + pieChart.options.withPieType('donut')
    + pieChart.options.withDisplayLabels(['name', 'percent'])
    + pieChart.options.legend.withDisplayMode('table')
    + pieChart.options.legend.withPlacement('right')
    + pieChart.options.legend.withShowLegend(true)
    + pieChart.options.legend.withValues(['value', 'percent'])
    + pieChart.options.tooltip.withMode('single'),

    // Workload Memory Over Time (timeseries)
    timeSeries.new('Workload Memory Over Time')
    + timeSeries.panelOptions.withDescription('Memory used by workloads over time')
    + timeSeries.panelOptions.withGridPos(8, 6, 18, 10)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.workloadMemoryOverTime)
      + prometheus.withLegendFormat('{{exported_namespace}}/{{exported_pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('decmbytes')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('bottom')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max'])
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
