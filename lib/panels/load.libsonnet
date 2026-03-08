// Row 3 (new order): Device Load Analysis
// Composite load removed. Top 10 and per-node compute panels use GR engine active only.
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

{
  panels: [
    row.new('Device Load Analysis')
    + row.withGridPos(57),

    // Top 10 Devices by Compute % — cluster-wide, pure GR engine active
    timeSeries.new('Top 10 Devices by Compute %')
    + timeSeries.panelOptions.withDescription('Top 10 GPU/MIG devices by GR engine active % (pure compute, no composite formula)')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 58)
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

    // Compute % by Device — repeated per node
    timeSeries.new('Compute % by Device — $hostname')
    + timeSeries.panelOptions.withDescription('GR engine active % per GPU/MIG device on this node')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 67)
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
  ],
}
