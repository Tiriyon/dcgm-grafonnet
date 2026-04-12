// Node & Device Inventory Dashboard
// Mirrors Run:AI node/resource visibility + inventory tables
// Variable-driven deep-dive into individual nodes
// Answers: "What hardware do I have? What's running where? What's the resource state per node?"
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    // --- Row 1: Device Inventory ---
    row.new('Device Inventory')
    + row.withGridPos(0),

    // Device Inventory & Status — repeated per node
    table.new('Device Inventory & Status — $hostname')
    + table.panelOptions.withDescription('Per-node GPU device inventory. Sorted by compute utilization.')
    + table.panelOptions.withGridPos(12, 12, 0, 1)
    + table.panelOptions.withRepeat('hostname')
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.inventoryComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.inventoryMemoryPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.inventoryUsedGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      prometheus.new(ds, q.inventoryTotalGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),

      prometheus.new(ds, q.inventoryPower)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('E'),

      prometheus.new(ds, q.inventoryTemp)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('F'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Compute %' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgCompute)
      ),
      table.standardOptions.override.byName.new('Memory %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgMemory)
      ),
      table.standardOptions.override.byName.new('VRAM Used (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(1)
      ),
      table.standardOptions.override.byName.new('VRAM Total (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(1)
      ),
      table.standardOptions.override.byName.new('Power (W)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('watt')
        + table.standardOptions.withDecimals(0)
      ),
      table.standardOptions.override.byName.new('Temp (C)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('celsius')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps(t.tableBgTemperature)
      ),
      table.standardOptions.override.byName.new('Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(130)
      ),
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
              Hostname: 0,
              gpu: 1,
              GPU_I_ID: 2,
              GPU_I_PROFILE: 3,
              modelName: 4,
              'Value #A': 5,
              'Value #B': 6,
              'Value #C': 7,
              'Value #D': 8,
              'Value #E': 9,
              'Value #F': 10,
            },
            renameByName: {
              Hostname: 'Host',
              gpu: 'GPU',
              GPU_I_ID: 'MIG ID',
              GPU_I_PROFILE: 'Profile',
              modelName: 'Model',
              'Value #A': 'Compute %',
              'Value #B': 'Memory %',
              'Value #C': 'VRAM Used (GB)',
              'Value #D': 'VRAM Total (GB)',
              'Value #E': 'Power (W)',
              'Value #F': 'Temp (C)',
            },
          },
        },
      ],
    },

    // --- Row 2: Node Resources ---
    row.new('Node Resources')
    + row.withGridPos(13),

    // Node Resources — repeated per node
    table.new('Node Resources — $hostname')
    + table.panelOptions.withDescription('Node CPU and RAM from kube-state-metrics / cAdvisor. Node label must match $hostname.')
    + table.panelOptions.withGridPos(5, 12, 0, 14)
    + table.panelOptions.withRepeat('hostname')
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.nodeCpuUsedCores)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.nodeCpuAllocatable)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.nodeRamUsedMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      prometheus.new(ds, q.nodeRamTotalMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),
    ])
    + table.options.withShowHeader(true)
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('CPU Used (cores)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withDecimals(2)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('CPU Total (cores)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node RAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node RAM Total (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node')
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
            excludeByName: {
              Time: true,
              __name__: true,
              container: true,
              endpoint: true,
              job: true,
              namespace: true,
              prometheus: true,
              resource: true,
              service: true,
              unit: true,
            },
            indexByName: {
              node: 0,
              'Value #A': 1,
              'Value #B': 2,
              'Value #C': 3,
              'Value #D': 4,
            },
            renameByName: {
              node: 'Node',
              'Value #A': 'CPU Used (cores)',
              'Value #B': 'CPU Total (cores)',
              'Value #C': 'Node RAM Used (MiB)',
              'Value #D': 'Node RAM Total (MiB)',
            },
          },
        },
      ],
    },

    // --- Row 3: Deployments per Node ---
    row.new('Deployments per Node')
    + row.withGridPos(19),

    // Deployments on Node — repeated per node
    table.new('Deployments on Node — $hostname')
    + table.panelOptions.withDescription('Active deployments per node (kube-state-metrics ReplicaSet owner join)')
    + table.panelOptions.withGridPos(8, 12, 0, 20)
    + table.panelOptions.withRepeat('hostname')
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.deploymentsPerNode)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Namespace' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Deployment')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(260)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
    ])
    + {
      transformations: [
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, 'Value #A': true },
            indexByName: {
              node: 0,
              namespace: 1,
              deployment: 2,
            },
            renameByName: {
              node: 'Node',
              namespace: 'Namespace',
              deployment: 'Deployment',
            },
          },
        },
      ],
    },
  ],
}