// Row 5: Deployment-Level Metrics (kube-state-metrics)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Deployment-Level Metrics (kube-state-metrics)')
    + row.withGridPos(52),

    // GPU Usage by Deployment (table)
    table.new('GPU Usage by Deployment')
    + table.panelOptions.withDescription('Memory utilization by Kubernetes deployment')
    + table.panelOptions.withGridPos(10, 24, 0, 53)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.deploymentComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.deploymentMemoryPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Memory %' }])
    + table.standardOptions.withOverrides([
      // Memory % column
      table.standardOptions.override.byName.new('Memory %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.memory)
        + table.fieldConfig.defaults.custom.withWidth(200)
      ),
      // Compute % column
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.compute)
        + table.fieldConfig.defaults.custom.withWidth(200)
      ),
      // Deployment column width
      table.standardOptions.override.byName.new('Deployment')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(250)
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
              Time: 0,
              'Value #A': 3,
              'Value #B': 4,
              deployment: 1,
              exported_namespace: 2,
            },
            renameByName: {
              'Value #A': 'Compute %',
              'Value #B': 'Memory %',
              deployment: 'Deployment',
              exported_namespace: 'Namespace',
            },
          },
        },
      ],
    },
  ],
}
