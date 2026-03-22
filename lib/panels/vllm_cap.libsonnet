// vLLM Inference Capacity Panels — v2.0
// Platform → Model → Pod drill-down across capacity, efficiency, utilization and health.
//
// Sections (all y coordinates are absolute, dashboard does no rebasing):
//   1. Fleet Capacity Overview  y=0   — 6 KPI stats
//   2. Saturation Signals       y=6   — queue depth + KV cache by model
//   3. Throughput               y=16  — token and request rate by model
//   4. Request Latency          y=26  — 6 snapshot stats + 3 timeseries (E2E / TTFT / TPOT)
//   5. Cache & Efficiency       y=40  — prefix cache hit rate + preemption rate
//   6. Per-Pod Detail           y=50  — KV cache, queue, token rate per replica
//
// Metric names (vLLM v0.10+, confirmed on this cluster):
//   vllm:kv_cache_usage_perc         — GPU KV-cache utilisation (0–1 gauge)
//   vllm:num_requests_running/waiting — scheduler queue gauges
//   vllm:generation_tokens            — output token counter
//   vllm:prompt_tokens                — input token counter
//   vllm:request_success              — completed request counter (label: finished_reason)
//   vllm:num_preemptions              — KV-cache eviction counter
//   vllm:prefix_cache_hits/queries    — prefix cache block counters (V1)
//   vllm:request_prefill_time_seconds — prefill phase histogram (TTFT proxy)
//   vllm:inter_token_latency_seconds  — per-token decode histogram (TPOT)
//   vllm:e2e_request_latency_seconds  — full request latency histogram
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../vllm_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat       = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local row        = g.panel.row;

local ds  = '${datasource}';
local ns  = 'namespace="$namespace"';
local mod = 'model_name=~"$model_name"';
local pod = 'pod=~"$pod"';

local sel    = ns + ', ' + mod;
local selPod = ns + ', ' + mod + ', ' + pod;

local kvcMetric = 'vllm:kv_cache_usage_perc';

// ── Shared visual defaults ─────────────────────────────────────────────────────

local tsBase =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

local tsLegend =
  timeSeries.options.legend.withDisplayMode('table')
  + timeSeries.options.legend.withShowLegend(true)
  + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
  + timeSeries.options.legend.withPlacement('right')
  + timeSeries.options.legend.withSortBy('Last')
  + timeSeries.options.legend.withSortDesc(true)
  + timeSeries.options.tooltip.withMode('multi')
  + timeSeries.options.tooltip.withSort('desc');

// stat panel helper — unit + graph area + last-not-null reduce
local mkStat(title, desc, h, w, x, y, targets, unit, thresholds, colorMode) =
  stat.new(title)
  + stat.panelOptions.withDescription(desc)
  + stat.panelOptions.withGridPos(h, w, x, y)
  + stat.queryOptions.withTargets(targets)
  + stat.standardOptions.withUnit(unit)
  + stat.standardOptions.color.withMode('thresholds')
  + stat.standardOptions.thresholds.withSteps(thresholds)
  + stat.options.withColorMode(colorMode)
  + stat.options.withGraphMode('area')
  + stat.options.reduceOptions.withCalcs(['lastNotNull']);

// timeseries panel helper
local mkTs(title, desc, h, w, x, y, targets, unit, thresholds, thresholdMode) =
  timeSeries.new(title)
  + timeSeries.panelOptions.withDescription(desc)
  + timeSeries.panelOptions.withGridPos(h, w, x, y)
  + timeSeries.queryOptions.withTargets(targets)
  + timeSeries.standardOptions.withUnit(unit)
  + timeSeries.standardOptions.withMin(0)
  + timeSeries.standardOptions.color.withMode('palette-classic')
  + timeSeries.standardOptions.thresholds.withSteps(thresholds)
  + tsBase
  + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode(thresholdMode)
  + tsLegend;

// ── Threshold presets ──────────────────────────────────────────────────────────

local thWaiting    = [{ color: 'green', value: null }, { color: '#EAB839', value: 1 }, { color: 'red', value: 10 }];
local thCache      = [{ color: 'green', value: null }, { color: '#EAB839', value: 70 }, { color: 'red', value: 85 }];
local thPreempt    = [{ color: 'green', value: null }, { color: '#EAB839', value: 0.01 }, { color: 'red', value: 1 }];
local thE2e        = [{ color: 'green', value: null }, { color: '#EAB839', value: 10 }, { color: 'red', value: 30 }];
local thTtft       = [{ color: 'green', value: null }, { color: '#EAB839', value: 1 }, { color: 'red', value: 5 }];
local thTpot       = [{ color: 'green', value: null }, { color: '#EAB839', value: 0.05 }, { color: 'red', value: 0.1 }];
local thHitRate    = [{ color: '#EAB839', value: null }, { color: 'green', value: 0.5 }];
local thGreen      = t.singleColor('green');
local thBlue       = t.singleColor('blue');

// ── Inline queries not in vllm_queries.libsonnet ───────────────────────────────

local kvByModel = 'avg by (model_name) (' + kvcMetric + '{' + sel + '}) * 100';

local prefixHitByModel = |||
  sum by (model_name) (
    rate(vllm:prefix_cache_hits{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
  )
  / (
    sum by (model_name) (
      rate(vllm:prefix_cache_queries{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    ) > 0
  )
|||;

{
  panels: [

    // ── Section 1: Fleet Capacity Overview ─────────────────────────────────────

    row.new('Fleet Capacity Overview')
    + row.withCollapsed(false)
    + row.withGridPos(0),

    mkStat(
      title='Gen Tokens/s',
      desc='Total generation token throughput across all selected models. Primary output capacity metric — size the fleet to sustain this at SLO latency.',
      h=4, w=4, x=0, y=1,
      targets=[
        prometheus.new(ds, 'sum(rate(vllm:generation_tokens{' + sel + '}[$__rate_interval]))')
        + prometheus.withLegendFormat('tok/s'),
      ],
      unit='short', thresholds=thGreen, colorMode='value'
    ),

    mkStat(
      title='Requests Running',
      desc='Requests currently being decoded on GPU. Stable value = healthy concurrency. Sudden drop = possible engine crash or restart.',
      h=4, w=4, x=4, y=1,
      targets=[
        prometheus.new(ds, 'sum(vllm:num_requests_running{' + sel + '})')
        + prometheus.withLegendFormat('running'),
      ],
      unit='short', thresholds=thBlue, colorMode='value'
    ),

    mkStat(
      title='Requests Waiting',
      desc='Requests queued waiting for a GPU slot (KV-cache block availability). Any sustained non-zero value = capacity exhausted. Waiting > 0 with low GPU utilisation = KV-cache bottleneck, not compute.',
      h=4, w=4, x=8, y=1,
      targets=[
        prometheus.new(ds, 'sum(vllm:num_requests_waiting{' + sel + '})')
        + prometheus.withLegendFormat('waiting'),
      ],
      unit='short', thresholds=thWaiting, colorMode='background'
    ),

    mkStat(
      title='KV Cache %',
      desc='Average GPU KV-cache utilisation across pods. Above 85% = preemption risk. The primary memory capacity constraint — when this saturates the engine queues or drops requests.',
      h=4, w=4, x=12, y=1,
      targets=[
        prometheus.new(ds, 'avg(' + kvcMetric + '{' + sel + '}) * 100')
        + prometheus.withLegendFormat('cache %'),
      ],
      unit='percent', thresholds=thCache, colorMode='background'
    ) + stat.standardOptions.withMin(0) + stat.standardOptions.withMax(100),

    mkStat(
      title='Preemptions/min',
      desc='Rate of KV-cache evictions. Non-zero = GPU memory was full and the scheduler evicted requests. Any sustained value here means you are running over memory capacity.',
      h=4, w=4, x=16, y=1,
      targets=[
        prometheus.new(ds, 'sum(rate(vllm:num_preemptions{' + sel + '}[$__rate_interval])) * 60')
        + prometheus.withLegendFormat('preempt/min'),
      ],
      unit='short', thresholds=thPreempt, colorMode='background'
    ),

    mkStat(
      title='Request Rate',
      desc='Successfully completed requests per second. Divide Gen Tokens/s by Request Rate to get average output length. Dropping rate with stable running count = longer responses.',
      h=4, w=4, x=20, y=1,
      targets=[
        prometheus.new(ds, 'sum(rate(vllm:request_success{' + sel + '}[$__rate_interval]))')
        + prometheus.withLegendFormat('req/s'),
      ],
      unit='reqps', thresholds=thGreen, colorMode='value'
    ),

    // ── Section 2: Saturation Signals ──────────────────────────────────────────

    row.new('Saturation Signals — Queue Depth & KV Cache Pressure')
    + row.withCollapsed(false)
    + row.withGridPos(6),

    // Diagnosis: running steady + waiting growing → KV-cache exhausted
    //            running low + GPU also low → idle / compute idle
    //            running at max + waiting=0 → healthy saturation
    mkTs(
      title='Request Queue Depth by Model',
      desc='Running (actively using GPU) and waiting (blocked on KV-cache) request counts per model. Waiting > 0 sustained = capacity exhausted. Healthy: running high, waiting zero. KV-cache bound: KV cache at 85%+ while waiting grows. Compute bound: GPU at 100%, waiting near zero.',
      h=8, w=12, x=0, y=7,
      targets=[
        prometheus.new(ds, q.queueRunningOverTime) + prometheus.withLegendFormat('Running — {{model_name}}'),
        prometheus.new(ds, q.queueWaitingOverTime) + prometheus.withLegendFormat('Waiting — {{model_name}}'),
      ],
      unit='short', thresholds=thGreen, thresholdMode='off'
    ),

    mkTs(
      title='GPU KV Cache % by Model',
      desc='Average GPU KV-cache utilisation per model. 85% threshold line marks the preemption boundary — crossing it means the engine must evict requests. Sustained proximity = need more GPU VRAM per pod, or reduce max concurrent context length.',
      h=8, w=12, x=12, y=7,
      targets=[
        prometheus.new(ds, kvByModel) + prometheus.withLegendFormat('{{model_name}}'),
      ],
      unit='percent', thresholds=thCache, thresholdMode='line'
    ) + timeSeries.standardOptions.withMax(100),

    // ── Section 3: Throughput ───────────────────────────────────────────────────

    row.new('Throughput — Token & Request Rate')
    + row.withCollapsed(false)
    + row.withGridPos(16),

    mkTs(
      title='Token Rate by Model',
      desc='Generation and prompt token throughput per model. Gen tok/s is the primary output capacity metric. Prompt rate >> gen rate = short-answer workload with expensive prefill. Watch for divergence between models to spot hot spots.',
      h=8, w=12, x=0, y=17,
      targets=[
        prometheus.new(ds, q.genTokenRateOverTime)    + prometheus.withLegendFormat('Gen — {{model_name}}'),
        prometheus.new(ds, q.promptTokenRateOverTime) + prometheus.withLegendFormat('Prompt — {{model_name}}'),
      ],
      unit='short', thresholds=thGreen, thresholdMode='off'
    ),

    mkTs(
      title='Request Throughput by Model',
      desc='Successfully completed requests per second per model. Divide gen tok/s by req/s to get average output length. A falling req/s with stable gen tok/s means responses are getting longer.',
      h=8, w=12, x=12, y=17,
      targets=[
        prometheus.new(ds, q.requestThroughputOverTime) + prometheus.withLegendFormat('{{model_name}}'),
      ],
      unit='reqps', thresholds=thBlue, thresholdMode='off'
    ),

    // ── Section 4: Request Latency ──────────────────────────────────────────────

    row.new('Request Latency — SLO Budget')
    + row.withCollapsed(false)
    + row.withGridPos(26),

    // Snapshot stats — current window
    mkStat(
      title='E2E P50',
      desc='Median end-to-end request latency (queue + prefill + decode). Typical user experience baseline.',
      h=4, w=4, x=0, y=27,
      targets=[prometheus.new(ds, q.e2eP50) + prometheus.withLegendFormat('P50')],
      unit='s', thresholds=thE2e, colorMode='value'
    ),

    mkStat(
      title='E2E P99',
      desc='99th percentile end-to-end latency — worst-case user experience. Should stay under your SLO ceiling.',
      h=4, w=4, x=4, y=27,
      targets=[prometheus.new(ds, q.e2eP99) + prometheus.withLegendFormat('P99')],
      unit='s', thresholds=thE2e, colorMode='background'
    ),

    mkStat(
      title='TTFT P50',
      desc='Median time to first token (prefill phase latency). User perceives this as the delay before the response starts appearing.',
      h=4, w=4, x=8, y=27,
      targets=[prometheus.new(ds, q.ttftP50) + prometheus.withLegendFormat('P50')],
      unit='s', thresholds=thTtft, colorMode='value'
    ),

    mkStat(
      title='TTFT P99',
      desc='99th percentile TTFT. Spikes indicate compute saturation during prefill: very long prompts, high concurrency, or GPU at capacity.',
      h=4, w=4, x=12, y=27,
      targets=[prometheus.new(ds, q.ttftP99) + prometheus.withLegendFormat('P99')],
      unit='s', thresholds=thTtft, colorMode='background'
    ),

    mkStat(
      title='TPOT P50',
      desc='Median time per output token (inter-token decode latency). Determines streaming speed perceived by users. Lower = faster streaming.',
      h=4, w=4, x=16, y=27,
      targets=[prometheus.new(ds, q.tpotP50) + prometheus.withLegendFormat('P50')],
      unit='s', thresholds=thTpot, colorMode='value'
    ),

    mkStat(
      title='TPOT P99',
      desc='99th percentile TPOT. Rising P99 = decode is becoming a bottleneck; fewer parallel sequences can be sustained. Correlate with Requests Running.',
      h=4, w=4, x=20, y=27,
      targets=[prometheus.new(ds, q.tpotP99) + prometheus.withLegendFormat('P99')],
      unit='s', thresholds=thTpot, colorMode='background'
    ),

    // Latency timeseries — P50 + P99 per metric for trend visibility
    mkTs(
      title='E2E Request Latency',
      desc='End-to-end latency P50 and P99 by model over time. Growing P99 with stable TTFT = decode bottleneck. Both growing together = prefill/compute saturation or queue build-up.',
      h=8, w=8, x=0, y=31,
      targets=[
        prometheus.new(ds, q.e2eP50OverTime) + prometheus.withLegendFormat('P50 {{model_name}}'),
        prometheus.new(ds, q.e2eP99OverTime) + prometheus.withLegendFormat('P99 {{model_name}}'),
      ],
      unit='s', thresholds=thE2e, thresholdMode='line'
    ),

    mkTs(
      title='Time to First Token (TTFT)',
      desc='TTFT P50 and P99 by model — prefill phase latency. Spikes = heavy prompts or GPU compute saturation during prefill. Sustained elevation = need more compute or shorter context limits.',
      h=8, w=8, x=8, y=31,
      targets=[
        prometheus.new(ds, q.ttftP50OverTime) + prometheus.withLegendFormat('P50 {{model_name}}'),
        prometheus.new(ds, q.ttftP99OverTime) + prometheus.withLegendFormat('P99 {{model_name}}'),
      ],
      unit='s', thresholds=thTtft, thresholdMode='line'
    ),

    mkTs(
      title='Time per Output Token (TPOT)',
      desc='TPOT P50 and P99 by model — decode phase latency per token. Rising TPOT = more concurrent sequences or longer sequences → higher memory pressure per decode step. Correlate with KV cache %.',
      h=8, w=8, x=16, y=31,
      targets=[
        prometheus.new(ds, q.tpotP50OverTime) + prometheus.withLegendFormat('P50 {{model_name}}'),
        prometheus.new(ds, q.tpotP99OverTime) + prometheus.withLegendFormat('P99 {{model_name}}'),
      ],
      unit='s', thresholds=thTpot, thresholdMode='line'
    ),

    // ── Section 5: Cache Efficiency & Preemptions ───────────────────────────────

    row.new('Cache Efficiency & Preemptions')
    + row.withCollapsed(false)
    + row.withGridPos(40),

    mkTs(
      title='Prefix Cache Hit Rate by Model',
      desc='Fraction of KV-cache block lookups served from the prefix cache per model. High rate = significant compute savings on repeated prefixes (system prompts, few-shot examples). Zero = no prefix reuse — consider whether workloads have shared prompt prefixes. Requires prefix caching enabled in vLLM config.',
      h=8, w=12, x=0, y=41,
      targets=[
        prometheus.new(ds, prefixHitByModel) + prometheus.withLegendFormat('{{model_name}}'),
      ],
      unit='percentunit', thresholds=thHitRate, thresholdMode='off'
    ) + timeSeries.standardOptions.withMax(1),

    mkTs(
      title='Preemption Rate by Model',
      desc='KV-cache eviction rate per second per model. Non-zero = GPU memory was full and the scheduler had to pause requests. Sustained preemptions = reduce concurrent context length, lower max model concurrency, or add GPU memory.',
      h=8, w=12, x=12, y=41,
      targets=[
        prometheus.new(ds, q.preemptionRate) + prometheus.withLegendFormat('{{model_name}}'),
      ],
      unit='short', thresholds=thPreempt, thresholdMode='line'
    ),

    // ── Section 6: Per-Pod Detail ───────────────────────────────────────────────

    row.new('Per-Pod Detail — Replica Health & Load Balance')
    + row.withCollapsed(false)
    + row.withGridPos(50),

    mkTs(
      title='KV Cache % per Pod',
      desc='GPU KV-cache utilisation per replica. A single pod above 85% will preempt requests even if the model-level average looks fine. Skew between pods = uneven load distribution or a replica-specific memory leak.',
      h=8, w=8, x=0, y=51,
      targets=[
        prometheus.new(ds, kvcMetric + '{' + selPod + '} * 100') + prometheus.withLegendFormat('{{pod}}'),
      ],
      unit='percent', thresholds=thCache, thresholdMode='line'
    ) + timeSeries.standardOptions.withMax(100),

    mkTs(
      title='Requests per Pod',
      desc='Running and waiting request counts per replica. A pod with persistent waiting while peers are idle = load-balancer skew or readiness issue on that replica. All pods waiting together = global capacity exhaustion.',
      h=8, w=8, x=8, y=51,
      targets=[
        prometheus.new(ds, 'vllm:num_requests_running{' + selPod + '}') + prometheus.withLegendFormat('Running — {{pod}}'),
        prometheus.new(ds, 'vllm:num_requests_waiting{' + selPod + '}') + prometheus.withLegendFormat('Waiting — {{pod}}'),
      ],
      unit='short', thresholds=thGreen, thresholdMode='off'
    ),

    mkTs(
      title='Generation Token Rate per Pod',
      desc='Output token throughput per replica. Uneven rates = uneven work distribution (check load-balancer routing). All pods low with users active = upstream throttling or the model is producing very short outputs.',
      h=8, w=8, x=16, y=51,
      targets=[
        prometheus.new(ds, 'rate(vllm:generation_tokens{' + selPod + '}[$__rate_interval])') + prometheus.withLegendFormat('{{pod}}'),
      ],
      unit='short', thresholds=thGreen, thresholdMode='off'
    ),

  ],
}
