// PromQL queries for GPU capacity planning dashboard.
// All expressions are strings, referenced by panel definitions.
{
  // --- Device counts ---
  totalDevices:
    'count(count by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED))',

  wholeGPUs:
    'count(count by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED{GPU_I_ID=""}))',

  migInstances:
    'count(DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})',

  activeWorkloads:
    'count(count by (exported_pod, exported_namespace) (DCGM_FI_DEV_FB_USED{exported_pod!=""}))',

  // --- Composite load (60% compute + 40% memory) ---
  avgDeviceLoad: |||
    avg(
      sum by (gpu, GPU_I_ID, UUID) (
        (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100 * 0.60)
        +
        ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100) * 0.40)
      )
    )
  |||,

  memorySaturated:
    'count(((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100) > 85) or vector(0)',

  underutilized: |||
    count(
      sum by (gpu, GPU_I_ID, UUID) (
        (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100 * 0.60)
        +
        ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100) * 0.40)
      ) < 20
    ) or vector(0)
  |||,

  // --- Memory ---
  totalMemoryCapacity:
    'sum(DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) / 1024',

  memoryInUse:
    'sum(DCGM_FI_DEV_FB_USED) / 1024',

  avgMemoryUtil:
    'avg((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100)',

  oomRiskPct: |||
    (
      count((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) > 0.85)
      /
      count(DCGM_FI_DEV_FB_USED)
    ) * 100 or vector(0)
  |||,

  avgTemperature:
    'avg(DCGM_FI_DEV_GPU_TEMP)',

  avgPower:
    'avg(DCGM_FI_DEV_POWER_USAGE)',

  memoryUtilByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100
    )
  |||,

  memoryByNamespace:
    'sum by (exported_namespace) (DCGM_FI_DEV_FB_USED{exported_pod!=""})',

  workloadMemoryOverTime:
    'sum by (exported_pod, exported_namespace) (DCGM_FI_DEV_FB_USED{exported_pod!=""})',

  // --- Device load ---
  deviceCompositeLoad: |||
    sum by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
      (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100 * 0.60)
      +
      ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100) * 0.40)
    )
  |||,

  top10DeviceLoad: |||
    topk(10,
      sum by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
        (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100 * 0.60)
        +
        ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100) * 0.40)
      )
    )
  |||,

  computeByDevice:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)',

  // --- Workload analysis ---
  workloadComputePct:
    'avg by (exported_pod, exported_namespace, gpu, GPU_I_ID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100)',

  workloadMemoryPct: |||
    avg by (exported_pod, exported_namespace, gpu, GPU_I_ID) (
      DCGM_FI_DEV_FB_USED{exported_pod!=""} / (DCGM_FI_DEV_FB_USED{exported_pod!=""} + DCGM_FI_DEV_FB_FREE{exported_pod!=""}) * 100
    )
  |||,

  workloadMemoryGB:
    'avg by (exported_pod, exported_namespace, gpu, GPU_I_ID) (DCGM_FI_DEV_FB_USED{exported_pod!=""} / 1024)',

  workloadLoadOverTime: |||
    sum by (exported_pod, exported_namespace, gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, UUID) (
      (DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100 * 0.60)
      +
      ((DCGM_FI_DEV_FB_USED{exported_pod!=""} / (DCGM_FI_DEV_FB_USED{exported_pod!=""} + DCGM_FI_DEV_FB_FREE{exported_pod!=""}) * 100) * 0.40)
    )
  |||,

  // --- Deployment-level (kube-state-metrics join) ---
  local kubeOwnerJoin = |||
    * on(exported_pod, exported_namespace) group_left(deployment)
    label_replace(
      label_replace(
        label_replace(
          kube_pod_owner{owner_kind="ReplicaSet"},
          "deployment", "$1", "owner_name", "(.+)-[^-]+"
        ),
        "exported_pod", "$1", "pod", "(.+)"
      ),
      "exported_namespace", "$1", "namespace", "(.+)"
    )
  |||,

  deploymentComputePct: |||
    sum by (deployment, exported_namespace) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
  ||| + kubeOwnerJoin + ')',

  deploymentMemoryPct: |||
    sum by (deployment, exported_namespace) (
      (DCGM_FI_DEV_FB_USED{exported_pod!=""} / (DCGM_FI_DEV_FB_USED{exported_pod!=""} + DCGM_FI_DEV_FB_FREE{exported_pod!=""}) * 100)
  ||| + kubeOwnerJoin + ')',

  // --- Device inventory ---
  inventoryLoad: |||
    sum by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
      (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100 * 0.60)
      +
      ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100) * 0.40)
    )
  |||,

  inventoryComputePct:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)',

  inventoryMemoryPct: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100
    )
  |||,

  inventoryUsedGB:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_DEV_FB_USED / 1024)',

  inventoryTotalGB:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) ((DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) / 1024)',

  inventoryPower:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_DEV_POWER_USAGE)',

  inventoryTemp:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_DEV_GPU_TEMP)',

  // --- Operational health ---
  powerByDevice:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_DEV_POWER_USAGE)',

  temperatureByDevice:
    'avg by (gpu, GPU_I_ID, Hostname, UUID) (DCGM_FI_DEV_GPU_TEMP)',

  tensorUtilByWorkload:
    'avg by (exported_pod) (DCGM_FI_PROF_PIPE_TENSOR_ACTIVE{exported_pod!=""} * 100)',

  smClockByModel:
    'avg by (modelName) (DCGM_FI_DEV_SM_CLOCK{exported_namespace!=""})',
}
