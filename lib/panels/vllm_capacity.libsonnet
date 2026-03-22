// Row 7: Inference Capacity
// Cross-layer correlation between vLLM engine metrics and DCGM GPU hardware metrics.
// Designed for the GPU Capacity Planning dashboard — surfaces saturation mode,
// KV cache OOM risk, and GPU efficiency that neither the DCGM nor vLLM dashboard shows alone.
//
// The four saturation modes visible here:
//   GPU high  + queue growing → compute saturation → add GPUs / reduce batch
//   GPU low   + queue growing → KV cache or scheduling bottleneck, not compute
//   GPU high  + queue empty   → single large request dominating → MIG / replica
//   GPU low   + queue empty   → healthy idle or cold deployment
//
// Variables used: $datasource, $model_name
// $namespace is intentionally NOT used in vLLM queries here: the capacity planning
// $namespace is sourced from DCGM exported_namespace, which may differ from the
// Kubernetes namespace where vLLM pods actually run. Filtering only by $model_name
// keeps queries cluster-wide and consistent with the DCGM aggregate queries above.
//
// DCGM queries reused from queries.libsonnet:
//   q.avgGrEngineActivePct  — cluster-wide GPU compute %
//   q.avgVramUtil           — cluster-wide VRAM utilization %
// vLLM queries defined in queries.libsonnet under the vLLM Inference Capacity section:
//   q.vllmGenTokenRate, q.vllmRequestsRunning, q.vllmRequestsWaiting,
//   q.vllmRequestsSwapped, q.vllmKvCachePct, q.vllmPrefixCacheHitRate,
//   q.vllmTokensPerGpu
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local row = g.panel.row;

local ds = '${datasource}';

// --- Shared timeseries style ---
local tsDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

local tsLegend =
  timeSeries.options.legend.withDisplayMode('table')
  + timeSeries.options.legend.withShowLegend(true)
  + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
  + timeSeries.options.tooltip.withMode('multi')
  + timeSeries.options.tooltip.withSort('desc');

{
  panels: [
    row.new('Inference Capacity')
    + row.withCollapsed(false)
    + row.withGridPos(141),

    // ── KPI stats ──────────────────────────────────────────────────────────

    stat.new('Gen Tokens/s')
    + stat.panelOptions.withDescription('Output tokens generated per second. Primary throughput signal for LLM inference capacity.')
    + stat.panelOptions.withGridPos(4, 4, 0, 142)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.vllmGenTokenRate)
      + prometheus.withLegendFormat('tok/s'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Requests Running')
    + stat.panelOptions.withDescription('Requests currently being decoded. Correlate with GPU Compute % to identify saturation mode.')
    + stat.panelOptions.withGridPos(4, 4, 4, 142)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.vllmRequestsRunning)
      + prometheus.withLegendFormat('Running'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Requests Waiting')
    + stat.panelOptions.withDescription('Requests queued in the vLLM scheduler. Growing = backpressure. Cross with GPU % to find root cause.')
    + stat.panelOptions.withGridPos(4, 4, 8, 142)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.vllmRequestsWaiting)
      + prometheus.withLegendFormat('Waiting'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: '#EAB839', value: 5 },
      { color: 'red', value: 20 },
    ])
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('KV Cache Pressure')
    + stat.panelOptions.withDescription('GPU KV cache utilization (vLLM). >85% → OOM risk, triggers CPU swapping and preemption.')
    + stat.panelOptions.withGridPos(4, 4, 12, 142)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.vllmKvCachePct)
      + prometheus.withLegendFormat('KV Cache %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.memory)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Total Load')
    + stat.panelOptions.withDescription('Total concurrent requests (running + waiting). Rising with GPU % high = compute saturation. Rising with GPU % low = KV cache or scheduling bottleneck.')
    + stat.panelOptions.withGridPos(4, 4, 16, 142)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.vllmTotalRequests)
      + prometheus.withLegendFormat('Total'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: '#EAB839', value: 10 },
      { color: 'red', value: 50 },
    ])
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Prefix Cache Hit Rate')
    + stat.panelOptions.withDescription('Fraction of prefix cache lookups that hit. Higher = less redundant prefill work. No-data = no prefix queries in window or vLLM <v0.14.')
    + stat.panelOptions.withGridPos(4, 4, 20, 142)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.vllmPrefixCacheHitRate)
      + prometheus.withLegendFormat('Hit Rate'),
    ])
    + stat.standardOptions.withUnit('percentunit')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(1)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps([
      { color: 'red', value: null },
      { color: '#EAB839', value: 0.3 },
      { color: 'green', value: 0.6 },
    ])
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // ── GPU Compute % vs Queue Depth ────────────────────────────────────────
    // Left axis: GPU compute % (0–100%). Right axis: queue depth (count).
    // Use raw JSON override for custom.axisPlacement — withPropertiesFromOptions
    // does not reliably extract custom field config properties in Grafonnet.

    timeSeries.new('GPU Compute % vs Queue Depth')
    + timeSeries.panelOptions.withDescription(
      'Saturation mode diagnostic — read the relationship between the two lines:\n' +
      '  GPU ↑ + Queue ↑  →  compute saturation: add capacity or reduce concurrency\n' +
      '  GPU ↓ + Queue ↑  →  KV cache / scheduling bottleneck, not compute\n' +
      '  GPU ↑ + Queue ↓  →  single large request dominating (consider MIG)\n' +
      '  GPU ↓ + Queue ↓  →  healthy idle'
    )
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 146)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.avgGrEngineActivePct)
      + prometheus.withLegendFormat('GPU Compute %'),
      prometheus.new(ds, q.vllmRequestsWaiting)
      + prometheus.withLegendFormat('Queue Depth'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.compute)
    + timeSeries.standardOptions.withOverrides([
      {
        matcher: { id: 'byName', options: 'Queue Depth' },
        properties: [
          { id: 'unit', value: 'short' },
          { id: 'custom.axisPlacement', value: 'right' },
          { id: 'custom.axisLabel', value: 'Queue Depth (requests)' },
          { id: 'min', value: 0 },
        ],
      },
    ])
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('bottom')
    + tsLegend,

    // ── VRAM Hardware % vs KV Cache Pressure ───────────────────────────────
    // Both series on the same 0–100% axis. The gap between them is constant
    // model weight + CUDA overhead. Watch for them converging toward 100%.

    timeSeries.new('VRAM % (hardware) vs KV Cache % (vLLM)')
    + timeSeries.panelOptions.withDescription(
      'Hardware VRAM utilization (DCGM) vs inference KV cache utilization (vLLM) on the same scale.\n' +
      '  Gap = model weights + CUDA context + activations (fixed per model)\n' +
      '  Both rising together  →  OOM risk: reduce max_num_seqs or context window\n' +
      '  KV high, VRAM steady  →  KV cache dominating: long sequences or large batches\n' +
      '  VRAM high, KV low     →  model weights fill VRAM with little room for context'
    )
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 146)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.avgVramUtil)
      + prometheus.withLegendFormat('VRAM % (hardware)'),
      prometheus.new(ds, q.vllmKvCachePct)
      + prometheus.withLegendFormat('KV Cache % (vLLM)'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.memory)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('bottom')
    + tsLegend,

    // ── Generation Tokens / Active GPU / s ─────────────────────────────────
    // The unit-economics metric: how much inference work each GPU is producing.
    // Declining = GPUs being underutilized. Flat + growing queue = true saturation.

    timeSeries.new('Generation Tokens / Active GPU / s')
    + timeSeries.panelOptions.withDescription(
      'Output token generation rate divided by active GPU count (DCGM). Unit-economics metric for LLM inference.\n' +
      '  Declining trend         →  GPUs underutilized (idle replicas, cold starts, scheduling gaps)\n' +
      '  Flat/rising + queue ↑  →  true compute saturation — fleet expansion needed\n' +
      '  Spiky pattern           →  bursty workload or model loading latency'
    )
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 154)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.vllmTokensPerGpu)
      + prometheus.withLegendFormat('tok/s/GPU'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + tsLegend,
  ],
}
