// GPU Overview Dashboard (real-time "what's happening now")
// Mirrors Run:AI GPU/CPU Overview Dashboard
// Answers: "What's happening right now? Which devices are busy, which are idle?"
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    // --- Row 1: Cluster Snapshot ---
    row.new('Cluster Snapshot')
    + row.withGridPos(0),

    stat.new('Total VRAM Capacity')
    + stat.panelOptions.withDescription('Total GPU memory capacity across selected nodes')
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

    stat.new('VRAM In Use')
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

    gauge.new('Avg VRAM Utilization')
    + gauge.panelOptions.withDescription('Average VRAM utilization across selected devices')
    + gauge.panelOptions.withGridPos(4, 4, 8, 1)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.avgMemoryUtilByHost)
      + prometheus.withLegendFormat('Avg VRAM %'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.memory)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Avg Temperature')
    + stat.panelOptions.withDescription('Average temperature across selected GPUs')
    + stat.panelOptions.withGridPos(4, 4, 12, 1)
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
    + stat.panelOptions.withGridPos(4, 4, 16, 1)
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

    stat.new('OOM Risk %')
    + stat.panelOptions.withDescription('Percentage of devices at risk of OOM (>85% VRAM)')
    + stat.panelOptions.withGridPos(4, 4, 20, 1)
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

    // --- Row 2: Device Workload Map ---
    row.new('Device Workload Map')
    + row.withGridPos(5),

    table.new('Device Workload Map')
    + table.panelOptions.withDescription('At-a-glance device status: blue = idle, green = has active workload')
    + table.panelOptions.withGridPos(8, 24, 0, 6)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.deviceWorkloadMap)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Host' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Status')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(1)
        + table.standardOptions.color.withMode('thresholds')
        + table.standardOptions.thresholds.withSteps(t.deviceStatus)
        + table.fieldConfig.defaults.custom.withWidth(50)
      )
      + {
        properties+: [{
          id: 'mappings',
          value: [{
            type: 'value',
            options: {
              '0': { text: '■', index: 0 },
              '1': { text: '■', index: 1 },
            },
          }],
        }],
      },
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(220)
      ),
      table.standardOptions.override.byName.new('Host')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
      table.standardOptions.override.byName.new('Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(120)
      ),
    ])
    + {
      transformations: [
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, UUID: true, GPU_I_ID: true },
            indexByName: {
              Hostname: 0,
              modelName: 1,
              GPU_I_PROFILE: 2,
              gpu: 3,
              'Value #A': 4,
              exported_pod: 5,
            },
            renameByName: {
              Hostname: 'Host',
              modelName: 'Model',
              GPU_I_PROFILE: 'Profile',
              gpu: 'GPU',
              'Value #A': 'Status',
              exported_pod: 'Workload',
            },
          },
        },
      ],
    },

    // --- Row 3: Workload Status ---
    row.new('Workload Status')
    + row.withGridPos(14),

    // Pods by Status (kube_pod_status_phase) — key Run:AI concept
    table.new('Pods by Status & Namespace')
    + table.panelOptions.withDescription('Pod counts broken down by phase (Running/Pending/Failed/Succeeded) per namespace. Source: kube-state-metrics.')
    + table.panelOptions.withGridPos(8, 12, 0, 15)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.podCountByPhase)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Running' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Running')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps([{ color: 'rgba(50, 172, 45, 0.2)', value: null }])
        + table.fieldConfig.defaults.custom.withWidth(100)
      ),
      table.standardOptions.override.byName.new('Pending')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps([
          { color: 'rgba(50, 172, 45, 0.2)', value: null },
          { color: 'rgba(237, 129, 40, 0.2)', value: 1 },
        ])
        + table.fieldConfig.defaults.custom.withWidth(100)
      ),
      table.standardOptions.override.byName.new('Failed')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps([
          { color: 'rgba(50, 172, 45, 0.2)', value: null },
          { color: 'rgba(245, 54, 54, 0.2)', value: 1 },
        ])
        + table.fieldConfig.defaults.custom.withWidth(100)
      ),
      table.standardOptions.override.byName.new('Succeeded')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(100)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(200)
      ),
    ])
    + {
      transformations: [
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true },
            indexByName: {
              namespace: 0,
              'Running': 1,
              'Pending': 2,
              'Failed': 3,
              'Succeeded': 4,
            },
            renameByName: {
              namespace: 'Namespace',
            },
          },
        },
      ],
    },

    // Pending/Failed pods detail
    table.new('Pending & Failed Pods')
    + table.panelOptions.withDescription('Individual pods in Pending or Failed state. Investigate these for scheduling or resource issues.')
    + table.panelOptions.withGridPos(8, 12, 12, 15)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.pendingFailedPods)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Phase' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Phase')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps([
          { color: 'rgba(237, 129, 40, 0.2)', value: null },
        ])
        + table.fieldConfig.defaults.custom.withWidth(100)
      ),
      table.standardOptions.override.byName.new('Pod')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(300)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
      table.standardOptions.override.byName.new('Node')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
    ])
    + {
      transformations: [
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, 'Value #A': true, uid: true },
            indexByName: {
              namespace: 0,
              pod: 1,
              phase: 2,
              node: 3,
            },
            renameByName: {
              namespace: 'Namespace',
              pod: 'Pod',
              phase: 'Phase',
              node: 'Node',
            },
          },
        },
      ],
    },

    // --- Row 4: Workload GPU Usage ---
    row.new('Workload GPU Usage')
    + row.withGridPos(23),

    table.new('Workload GPU Usage')
    + table.panelOptions.withDescription('Per-workload GPU usage. VRAM shown as Used/Total (MiB).')
    + table.panelOptions.withGridPos(10, 24, 0, 24)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.workloadComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.workloadVramUsed)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.workloadVramTotal)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Compute %' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.compute)
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      table.standardOptions.override.byName.new('VRAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('VRAM Total (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(260)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
      table.standardOptions.override.byName.new('Node')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
      table.standardOptions.override.byName.new('GPU Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(100)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, gpu: true },
            indexByName: {
              exported_pod: 1,
              exported_namespace: 2,
              Hostname: 3,
              modelName: 4,
              GPU_I_ID: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
            },
            renameByName: {
              exported_pod: 'Workload',
              exported_namespace: 'Namespace',
              Hostname: 'Node',
              modelName: 'GPU Model',
              GPU_I_ID: 'MIG ID',
              'Value #A': 'Compute %',
              'Value #B': 'VRAM Used (MiB)',
              'Value #C': 'VRAM Total (MiB)',
            },
          },
        },
      ],
    },
  ],
}
