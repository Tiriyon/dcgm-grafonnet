// Workload — Per-Pod Detail
// Per-pod KV cache, request queue depth, and token throughput.
// Used by vllm-capacity.jsonnet; panels start at y=0 so the dashboard
// can apply an offset to place them after the model-level section.
//
// Variables: $namespace, $model_name, $pod (all support multi-select)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
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

local tsLegend =
  timeSeries.options.legend.withDisplayMode('table')
  + timeSeries.options.legend.withShowLegend(true)
  + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
  + timeSeries.options.legend.withPlacement('right')
  + timeSeries.options.legend.withSortBy('Last')
  + timeSeries.options.legend.withSortDesc(true)
  + timeSeries.options.tooltip.withMode('multi')
  + timeSeries.options.tooltip.withSort('desc');

// Inline queries — namespace + model_name + pod filtered
local kvCachePerPod = |||
  vllm:kv_cache_usage_perc{
    namespace=~"$namespace",
    model_name=~"$model_name",
    pod=~"$pod"
  } * 100
|||;

local runningPerPod = |||
  vllm:num_requests_running{
    namespace=~"$namespace",
    model_name=~"$model_name",
    pod=~"$pod"
  }
|||;

local waitingPerPod = |||
  vllm:num_requests_waiting{
    namespace=~"$namespace",
    model_name=~"$model_name",
    pod=~"$pod"
  }
|||;

local genTokensPerPod = |||
  rate(vllm:generation_tokens{
    namespace=~"$namespace",
    model_name=~"$model_name",
    pod=~"$pod"
  }[5m])
|||;

local promptTokensPerPod = |||
  rate(vllm:prompt_tokens{
    namespace=~"$namespace",
    model_name=~"$model_name",
    pod=~"$pod"
  }[5m])
|||;

{
  panels: [
    row.new('Workload — Per-Pod Detail')
    + row.withCollapsed(false)
    + row.withGridPos(0),

    // KV cache per pod — preemption risk visible before it hits the model-level average
    timeSeries.new('KV Cache % per Pod')
    + timeSeries.panelOptions.withDescription('GPU KV cache utilization per pod. A single pod at >85% will start preempting requests even if the model-level average looks healthy.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 1)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, kvCachePerPod)
      + prometheus.withLegendFormat('{{pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.memory)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + tsLegend,

    // Running + waiting per pod — load-balancer skew diagnostic
    timeSeries.new('Requests per Pod')
    + timeSeries.panelOptions.withDescription('Running and waiting requests per pod. A pod with a persistent waiting queue while peers are idle = load-balancer skew or readiness issue on that replica.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 1)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, runningPerPod)
      + prometheus.withLegendFormat('Running — {{pod}}'),
      prometheus.new(ds, waitingPerPod)
      + prometheus.withLegendFormat('Waiting — {{pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + tsLegend,

    // Token throughput per pod — generation + prompt rates side by side
    timeSeries.new('Token Throughput per Pod')
    + timeSeries.panelOptions.withDescription('Generation and prompt token rates per pod. Uneven generation rates across pods = uneven work distribution. Prompt rate >> gen rate = long-prompt / short-answer workload.')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 10)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, genTokensPerPod)
      + prometheus.withLegendFormat('Gen — {{pod}}'),
      prometheus.new(ds, promptTokensPerPod)
      + prometheus.withLegendFormat('Prompt — {{pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + tsLegend,
  ],
}
