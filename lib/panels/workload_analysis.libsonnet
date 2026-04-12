// Workload Analysis Dashboard (deployment-level)
// Mirrors Run:AI per-project/workload breakdown
// Answers: "How are individual workloads performing? CPU/RAM/GPU per deployment?"
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
    // --- Row 1: CPU & RAM by Deployment ---
    row.new('CPU & RAM by Deployment')
    + row.withGridPos(0),

    table.new('CPU & RAM by Deployment')
    + table.panelOptions.withDescription('Node CPU (millicores) and RAM (MiB) usage per Kubernetes deployment. Source: kube-state-metrics + cAdvisor.')
    + table.panelOptions.withGridPos(10, 24, 0, 1)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.deploymentCpuMillicores)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.deploymentCpuRequested)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.deploymentRamMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      prometheus.new(ds, q.deploymentRamRequestedMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'RAM Used (MiB)' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('CPU Used (m)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('short')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(130)
      ),
      table.standardOptions.override.byName.new('CPU Requested (m)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('short')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(160)
      ),
      table.standardOptions.override.byName.new('RAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('RAM Requested (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(165)
      ),
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
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true },
            indexByName: {
              deployment: 1,
              namespace: 2,
              'Value #A': 3,
              'Value #B': 4,
              'Value #C': 5,
              'Value #D': 6,
            },
            renameByName: {
              deployment: 'Deployment',
              namespace: 'Namespace',
              'Value #A': 'CPU Used (m)',
              'Value #B': 'CPU Requested (m)',
              'Value #C': 'RAM Used (MiB)',
              'Value #D': 'RAM Requested (MiB)',
            },
          },
        },
      ],
    },

    // --- Row 2: Workload GPU Usage ---
    row.new('Workload GPU Usage')
    + row.withGridPos(11),

    table.new('Workload GPU Usage')
    + table.panelOptions.withDescription('Per-workload GPU usage. VRAM shown as Used/Total (MiB).')
    + table.panelOptions.withGridPos(10, 24, 0, 12)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.workloadComputePctByHost)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.workloadVramUsedByHost)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.workloadVramTotalByHost)
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

    // --- Row 3: Workload Compute Over Time ---
    row.new('Workload Compute % Over Time')
    + row.withGridPos(22),

    // Workload Compute % — repeated per node
    timeSeries.new('Workload Compute % — $hostname')
    + timeSeries.panelOptions.withDescription('GPU compute activity per workload on this node (GR engine active %)')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 23)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.workloadComputeOverTime)
      + prometheus.withLegendFormat('{{exported_namespace}}/{{exported_pod}} ({{GPU_I_PROFILE}})'),
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