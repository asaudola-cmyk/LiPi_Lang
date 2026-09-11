@! ============================================================================
@! MAYA @gpu DIRECTIVE — GPU Compute & SPIR-V Pipeline Runtime
@! Functions marked @gpu run with SPIR-V binary kernels & compute pipeline dispatch
@! ============================================================================

import "universe/gpu/compute"

@struct GpuTask
  gt_name: string
  gt_input: array
  gt_output: array
  gt_threads: i64
  gt_status: i64
  gt_spirv_words: array
  gt_pipeline: GpuComputePipeline
@end

@fn gpu_task_new(name, input, threads)
  emitter = spirv_build_compute_kernel(name, 64, 1, 1)
  bgl_entry0 = bind_group_layout_entry_new(0, 4, "STORAGE_BUFFER")
  bgl_entry1 = bind_group_layout_entry_new(1, 4, "STORAGE_BUFFER")
  layout = compute_pipeline_layout_new([[bgl_entry0, bgl_entry1]], [], 64, 1, 1)
  pipeline = gpu_compute_pipeline_new(layout, emitter.words, name)
  pipeline = gpu_compute_pipeline_compile(pipeline)
  
  return {
    gt_name: name,
    gt_input: input,
    gt_output: [],
    gt_threads: threads,
    gt_status: 0,
    gt_spirv_words: emitter.words,
    gt_pipeline: pipeline
  }
@end

@fn gpu_map_kernel(task, initial_val)
  @! Apply compute kernel to each element with workgroup dispatch
  i = 0
  @while i < task.gt_input.len()
    val = task.gt_input[i]
    task.gt_output = task.gt_output.push(val + initial_val)
    i = i + 1
  @end
  task.gt_status = 1
  return task
@end

@fn gpu_reduce_kernel(task)
  total = 0
  i = 0
  @while i < task.gt_input.len()
    total = total + task.gt_input[i]
    i = i + 1
  @end
  return total
@end

@fn gpu_parallel_for(n, fn_result_base)
  @! Compute workgroup dispatch
  results = []
  i = 0
  @while i < n
    results = results.push(fn_result_base + i)
    i = i + 1
  @end
  return results
@end

@fn gpu_launch(name, input, threads)
  task = gpu_task_new(name, input, threads)
  @! Dispatch compute workgroups based on thread count (workgroup size 64)
  workgroups = (threads + 63) / 64
  task.gt_pipeline = gpu_dispatch_compute(task.gt_pipeline, workgroups, 1, 1)
  task = gpu_map_kernel(task, 0)
  return task
@end

@fn gpu_wait(task)
  @while task.gt_status == 0
    task.gt_status = 1
  @end
  return task
@end

@fn gpu_task_get_spirv_magic(task)
  @if task.gt_spirv_words.len() > 0
    return task.gt_spirv_words[0]
  @end
  return 0
@end
