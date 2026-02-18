// Row 4: Workload Analysis
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
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
    row.new('Workload Analysis')
    + row.withGridPos(33),

    // Workload GPU Usage (table)
    table.new('Workload GPU Usage')
    + table.panelOptions.withDescription('Detailed workload GPU usage table')
    + table.panelOptions.withGridPos(10, 24, 0, 34)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.workloadComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.workloadMemoryPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.workloadMemoryGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Memory %' }])
    + table.standardOptions.withOverrides([
      // Compute % column
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.compute)
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // Memory % column
      table.standardOptions.override.byName.new('Memory %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.memory)
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // Memory (GB) column
      table.standardOptions.override.byName.new('Memory (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(2)
      ),
      // Workload column width
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(280)
      ),
      // Namespace column width
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true },
            indexByName: {
              GPU_I_ID: 4,
              Time: 0,
              'Value #A': 5,
              'Value #B': 6,
              'Value #C': 7,
              exported_namespace: 2,
              exported_pod: 1,
              gpu: 3,
            },
            renameByName: {
              GPU_I_ID: 'MIG ID',
              'Value #A': 'Compute %',
              'Value #B': 'Memory %',
              'Value #C': 'Memory (GB)',
              exported_namespace: 'Namespace',
              exported_pod: 'Workload',
              gpu: 'GPU',
            },
          },
        },
      ],
    },

    // Workload GPU Load Over Time (timeseries)
    timeSeries.new('Workload GPU Load Over Time')
    + timeSeries.panelOptions.withDescription('GPU load over time per workload')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 44)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.workloadLoadOverTime)
      + prometheus.withLegendFormat('{{exported_namespace}}/{{exported_pod}}'),
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
