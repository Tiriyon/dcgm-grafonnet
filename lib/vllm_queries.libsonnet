// PromQL queries for vLLM monitoring dashboard.
// Metric names match vLLM as observed on this cluster (no _total suffix on counters,
// kv_cache_usage_perc instead of gpu_cache_usage_perc, etc.).
// Primary selectors: namespace, model_name (per-deployment), pod (per-replica).
// Histogram metrics use _bucket suffix for histogram_quantile patterns.
// All rate/histogram windows use $__rate_interval (Grafana auto-sets based on scrape
// interval + time range) to avoid NaN on sparse traffic.
// Latency mapping:
//   TTFT  → vllm:request_prefill_time_seconds  (prefill latency; excludes queue wait)
//   TPOT  → vllm:inter_token_latency_seconds   (inter-token / decode latency)
//   E2E   → vllm:e2e_request_latency_seconds   (full request duration)
{
  // --- Service health KPIs ---

  requestsRunning:
    'sum(vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name"})',

  requestsWaiting:
    'sum(vllm:num_requests_waiting{namespace="$namespace", model_name=~"$model_name"})',

  requestsSwapped:
    'sum(vllm:num_requests_swapped{namespace="$namespace", model_name=~"$model_name"})',

  requestThroughput: |||
    sum(
      rate(vllm:request_success{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  tokenGenRate: |||
    sum(
      rate(vllm:generation_tokens{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  totalTokenRate: |||
    sum(
      rate(vllm:prompt_tokens{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
      + rate(vllm:generation_tokens{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  ttftP99Snapshot: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  // --- KV cache ---

  gpuCacheUsage:
    'avg(vllm:kv_cache_usage_perc{namespace="$namespace", model_name=~"$model_name"})',

  // Peak GPU KV cache over the last 15 minutes — shows pressure even if current value dropped.
  // Replaces cpu_cache_usage_perc which is not exposed when CPU offloading is disabled.
  gpuCachePeak:
    'max(max_over_time(vllm:kv_cache_usage_perc{namespace="$namespace", model_name=~"$model_name"}[15m]))',

  cacheHitRate: |||
    sum(
      rate(vllm:prefix_cache_hits{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
    /
    (
      sum(
        rate(vllm:prefix_cache_queries{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
      ) > 0
    )
  |||,

  gpuCacheOverTime: |||
    vllm:kv_cache_usage_perc{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,

  // --- Request latency (histogram_quantile over rate) ---

  ttftP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  ttftP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  ttftP99: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  tpotP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:inter_token_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  tpotP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:inter_token_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  tpotP99: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:inter_token_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  e2eP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:e2e_request_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  e2eP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:e2e_request_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  e2eP99: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:e2e_request_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le)
    )
  |||,

  // Timeseries variants — grouped by model_name for multi-series panels
  ttftP50OverTime: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  ttftP95OverTime: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  ttftP99OverTime: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:request_prefill_time_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  e2eP50OverTime: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:e2e_request_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  e2eP95OverTime: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:e2e_request_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  e2eP99OverTime: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:e2e_request_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  tpotP50OverTime: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:inter_token_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  tpotP99OverTime: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:inter_token_latency_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  // --- Token throughput ---

  promptTokenRateOverTime: |||
    sum by (model_name) (
      rate(vllm:prompt_tokens{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  genTokenRateOverTime: |||
    sum by (model_name) (
      rate(vllm:generation_tokens{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  requestThroughputOverTime: |||
    sum by (model_name) (
      rate(vllm:request_success{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  promptLenP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_prompt_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  promptLenP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_prompt_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  outputLenP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_generation_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  outputLenP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_generation_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[$__rate_interval])
      ) by (le, model_name)
    )
  |||,

  // --- Queue & scheduler ---

  queueRunningOverTime: |||
    sum by (model_name) (
      vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name"}
    )
  |||,

  queueWaitingOverTime: |||
    sum by (model_name) (
      vllm:num_requests_waiting{namespace="$namespace", model_name=~"$model_name"}
    )
  |||,

  queueSwappedOverTime: |||
    sum by (model_name) (
      vllm:num_requests_swapped{namespace="$namespace", model_name=~"$model_name"}
    )
  |||,

  preemptionRate: |||
    sum by (model_name) (
      rate(vllm:num_preemptions{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  finishReasonRate: |||
    sum by (model_name, finished_reason) (
      rate(vllm:request_success{namespace="$namespace", model_name=~"$model_name"}[$__rate_interval])
    )
  |||,

  runningByPod: |||
    vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,

  waitingByPod: |||
    vllm:num_requests_waiting{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,
}
