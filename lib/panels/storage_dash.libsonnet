// Storage Dashboard (Node Disk + PVC)
// Answers: "Are nodes running out of disk? Which PVCs are filling up?"
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local table = g.panel.table;
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
    // --- Row 1: Disk & PVC Summary ---
    row.new('Disk & PVC Summary')
    + row.withGridPos(0),

    // Avg Node Disk Used %
    stat.new('Avg Node Disk Used %')
    + stat.panelOptions.withDescription('Average local disk utilization across selected nodes. Source: node-exporter (node_filesystem_*). High values risk DiskPressure and pod eviction.')
    + stat.panelOptions.withGridPos(4, 8, 0, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgNodeDiskUsedPct)
      + prometheus.withLegendFormat('Avg Disk %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.diskUsage)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Total PVCs
    stat.new('Total PVCs')
    + stat.panelOptions.withDescription('Number of Persistent Volume Claims in selected namespaces. Source: kubelet (kubelet_volume_stats_*).')
    + stat.panelOptions.withGridPos(4, 8, 8, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.totalPvcs)
      + prometheus.withLegendFormat('PVCs'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // PVCs > 80%
    stat.new('PVCs > 80%')
    + stat.panelOptions.withDescription('PVCs with storage utilization above 80%. These are at risk of running out of space — investigate or expand.')
    + stat.panelOptions.withGridPos(4, 8, 16, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.pvcsAbove80Pct)
      + prometheus.withLegendFormat('Critical'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.countWarning)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // --- Row 2: Node Disk Usage Over Time ---
    row.new('Node Disk Usage Over Time')
    + row.withGridPos(5),

    // Node Disk Usage — repeated per node
    timeSeries.new('Node Disk Usage — $hostname')
    + timeSeries.panelOptions.withDescription('Local disk utilization over time for this node. Source: node-exporter. Mountpoint: /.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 6)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.nodeDiskUsagePct)
      + prometheus.withLegendFormat('Disk Used %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('thresholds')
    + timeSeries.standardOptions.thresholds.withSteps(t.diskUsage)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withPlacement('bottom')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // --- Row 3: PVC Details ---
    row.new('PVC Details')
    + row.withGridPos(14),

    // PVC Usage by Namespace — table
    table.new('PVC Usage by Namespace')
    + table.panelOptions.withDescription('Persistent Volume Claim utilization per namespace. Source: kubelet (kubelet_volume_stats_*). Sorted by Used % descending to surface full PVCs.')
    + table.panelOptions.withGridPos(10, 24, 0, 15)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.pvcUsedPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      prometheus.new(ds, q.pvcUsedBytes)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      prometheus.new(ds, q.pvcCapacityBytes)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Used %' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Used %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withUnit('percent')
        + table.standardOptions.withDecimals(1)
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgDisk)
        + table.fieldConfig.defaults.custom.withWidth(120)
      ),
      table.standardOptions.override.byName.new('Used')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decbytes')
        + table.standardOptions.withDecimals(1)
        + table.fieldConfig.defaults.custom.withWidth(120)
      ),
      table.standardOptions.override.byName.new('Capacity')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decbytes')
        + table.standardOptions.withDecimals(1)
        + table.fieldConfig.defaults.custom.withWidth(120)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(200)
      ),
      table.standardOptions.override.byName.new('PVC')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(300)
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
              endpoint: true,
              instance: true,
              job: true,
              metrics_path: true,
              node: true,
              service: true,
            },
            indexByName: {
              namespace: 0,
              persistentvolumeclaim: 1,
              'Value #A': 2,
              'Value #B': 3,
              'Value #C': 4,
            },
            renameByName: {
              namespace: 'Namespace',
              persistentvolumeclaim: 'PVC',
              'Value #A': 'Used %',
              'Value #B': 'Used',
              'Value #C': 'Capacity',
            },
          },
        },
      ],
    },

    // --- Row 4: PVC Usage Over Time ---
    row.new('PVC Usage Over Time')
    + row.withGridPos(25),

    // PVC Usage Over Time — timeseries
    timeSeries.new('PVC Usage Over Time')
    + timeSeries.panelOptions.withDescription('PVC utilization % over time per volume. Source: kubelet (kubelet_volume_stats_*).')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 26)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.pvcUsedPctOverTime)
      + prometheus.withLegendFormat('{{namespace}}/{{persistentvolumeclaim}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.diskUsage)
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
