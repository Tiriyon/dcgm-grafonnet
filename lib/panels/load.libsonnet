// Row 3: Device Load Analysis
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
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
    row.new('Device Load Analysis')
    + row.withGridPos(18),

    // Device Composite Load (bar gauge)
    barGauge.new('Device Composite Load')
    + barGauge.panelOptions.withDescription('Composite load (60% compute + 40% memory) per GPU/MIG device')
    + barGauge.panelOptions.withGridPos(6, 24, 0, 19)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.deviceCompositeLoad)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-{{GPU_I_PROFILE}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.compute)
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true)
    + barGauge.options.withMinVizHeight(10)
    + barGauge.options.withMinVizWidth(0),

    // Top 10 Devices by Load (timeseries)
    timeSeries.new('Top 10 Devices by Load')
    + timeSeries.panelOptions.withDescription('Top 10 devices by composite load over time')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 25)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.top10DeviceLoad)
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

    // Compute % by Device (timeseries)
    timeSeries.new('Compute % by Device')
    + timeSeries.panelOptions.withDescription('Graphics engine activity (compute) per device')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 25)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.computeByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-MIG{{GPU_I_ID}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
