@! ============================================================================
@! MAYA UNIVERSE AI: MODEL SERIALIZATION & DESERIALIZATION (.mayamodel)
@! Module: universe/ai/model_io
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"

@struct ModelMetadata
  model_name: string
  architecture: string
  num_parameters: i64
  creation_date: string
  tokenizer_path: string
  training_step: i64
@end

@struct Checkpoint
  model_name: string
  step: i64
@end

@struct TensorMeta
  name: string
  dtype: i64
  ndim: i64
  shape: array
  data_offset: i64
  data_len: i64
  compressed: i64
@end

@fn get_dtype_code(dtype_str: string) -> i64
  @if dtype_str == "f32" return 0 @end
  @if dtype_str == "f64" return 1 @end
  @if dtype_str == "i32" return 2 @end
  @if dtype_str == "i64" return 3 @end
  @if dtype_str == "f16" return 4 @end
  @if dtype_str == "bf16" return 5 @end
  return 0
@end

@fn get_dtype_from_code(code: i64) -> string
  @if code == 0 return "f32" @end
  @if code == 1 return "f64" @end
  @if code == 2 return "i32" @end
  @if code == 3 return "i64" @end
  @if code == 4 return "f16" @end
  @if code == 5 return "bf16" @end
  return "f32"
@end

@fn save_checkpoint(model_name: string, step: i64, path: string) -> i64
  content = "MAYAMDL\nmodel=" + model_name + "\nstep=" + step.to_str() + "\n"
  file_write(path, content)
  return 1
@end

@fn load_checkpoint(path: string) -> Checkpoint
  @if file_exists(path) == 0
    return { model_name: "none", step: 0 }
  @end
  content = file_read(path)
  lines = string_split(content, "\n")
  model_name = "unknown"
  step = 0
  i = 0
  num_items = lines.len()
  @while i < num_items
    line = lines[i]
    @if string_starts_with(line, "model=")
      model_name = str_substr(line, 6, str_len(line))
    @elif string_starts_with(line, "step=")
      step = str_to_int(str_substr(line, 5, str_len(line)))
    @end
    i = i + 1
  @end
  return { model_name: model_name, step: step }
@end
