// Row 6: Device Inventory & Health
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Device Inventory & Health')
    + row.withGridPos(63),

    // Device Inventory & Status (table with 7 queries)
    table.new('Device Inventory & Status')
    + table.panelOptions.withDescription('Comprehensive device status table')
    + table.panelOptions.withGridPos(12, 24, 0, 64)
    + table.queryOptions.withTargets([
      // A: Composite load
      prometheus.new(ds, q.inventoryLoad)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: Compute %
      prometheus.new(ds, q.inventoryComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: Memory %
      prometheus.new(ds, q.inventoryMemoryPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      // D: Used memory (GB)
      prometheus.new(ds, q.inventoryUsedGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),

      // E: Total memory (GB)
      prometheus.new(ds, q.inventoryTotalGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('E'),

      // F: Power usage
      prometheus.new(ds, q.inventoryPower)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('F'),

      // G: Temperature
      prometheus.new(ds, q.inventoryTemp)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('G'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Load %' }])
    + table.standardOptions.withOverrides([
      // Load % - gradient gauge
      table.standardOptions.override.byName.new('Load %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.compute)
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // Compute % - color background
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgCompute)
      ),
      // Memory % - color background
      table.standardOptions.override.byName.new('Memory %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgMemory)
      ),
      // Used (GB)
      table.standardOptions.override.byName.new('Used (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(1)
      ),
      // Total (GB)
      table.standardOptions.override.byName.new('Total (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(1)
      ),
      // Power (W)
      table.standardOptions.override.byName.new('Power (W)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('watt')
        + table.standardOptions.withDecimals(0)
      ),
      // Temp (C) - with color background
      table.standardOptions.override.byName.new('Temp (C)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('celsius')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps(t.tableBgTemperature)
      ),
      // Model column width
      table.standardOptions.override.byName.new('Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // Host column width
      table.standardOptions.override.byName.new('Host')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(150)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, UUID: true },
            indexByName: {
              GPU_I_ID: 2,
              GPU_I_PROFILE: 3,
              Hostname: 0,
              UUID: 13,
              'Value #A': 5,
              'Value #B': 6,
              'Value #C': 7,
              'Value #D': 8,
              'Value #E': 9,
              'Value #F': 10,
              'Value #G': 11,
              gpu: 1,
              modelName: 4,
            },
            renameByName: {
              GPU_I_ID: 'MIG ID',
              GPU_I_PROFILE: 'Profile',
              Hostname: 'Host',
              UUID: '',
              'Value #A': 'Load %',
              'Value #B': 'Compute %',
              'Value #C': 'Memory %',
              'Value #D': 'Used (GB)',
              'Value #E': 'Total (GB)',
              'Value #F': 'Power (W)',
              'Value #G': 'Temp (C)',
              gpu: 'GPU',
              modelName: 'Model',
            },
          },
        },
      ],
    },
  ],
}
