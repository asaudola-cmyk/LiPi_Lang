// 👑 LIPI UNIVERSE AI: MODEL SERIALIZATION & DESERIALIZATION (.lipimodel)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero Python | Zero PyTorch
// Module: aati/lipi_ai/model_io.lp
// WHY: Native binary checkpointing and hyperparameter persistence for Lipi AI models.

import "utso/string"
import "utso/os/fs"

@struct ModelMeta
  model_name: string
  version: string
  arch: string
  num_layers: i64
  hidden_dim: i64
  vocab_size: i64
@end

@struct Checkpoint
  model_name: string
  step: i64
@end

@fn save_model_weights(model_name: string, step: i64, weights: array, path: string) -> i64
  w_str = ""
  i = 0
  n = weights.len()
  @while i < n
    @if i > 0
      w_str = str_concat(w_str, ",")
    @end
    w_str = str_concat(w_str, to_str(weights[i]))
    i = i + 1
  @end
  hdr = str_concat("LIPIMDL\nmodel=", str_concat(model_name, str_concat("\nstep=", str_concat(to_str(step), "\nweights="))))
  content = str_concat(hdr, str_concat(w_str, "\n"))
  file_write(path, content)
  return 1
@end

@fn load_model_weights(path: string) -> array
  @if file_exists(path) == 0
    return []
  @end
  content = file_read(path)
  lines = string_split(content, "\n")
  i = 0
  num_items = lines.len()
  @while i < num_items
    line = lines[i]
    @if string_starts_with(line, "weights=")
      raw_w = str_substr(line, 8, str_len(line))
      @if str_len(raw_w) == 0
        return []
      @end
      parts = string_split(raw_w, ",")
      out = []
      pi = 0
      pn = parts.len()
      @while pi < pn
        out = out.push(str_to_int(parts[pi]))
        pi = pi + 1
      @end
      return out
    @end
    i = i + 1
  @end
  return []
@end

@fn model_dtype_to_code(dtype: string) -> i64
  @if str_eq(dtype, "f32") return 1 @end
  @if str_eq(dtype, "f64") return 2 @end
  @if str_eq(dtype, "i32") return 3 @end
  @if str_eq(dtype, "f16") return 4 @end
  @if str_eq(dtype, "bf16") return 5 @end
  return 0
@end

@fn model_code_to_dtype(code: i64) -> string
  @if code == 1 return "f32" @end
  @if code == 2 return "f64" @end
  @if code == 3 return "i32" @end
  @if code == 4 return "f16" @end
  @if code == 5 return "bf16" @end
  return "f32"
@end

@fn save_checkpoint(model_name: string, step: i64, path: string) -> i64
  content = str_concat("LIPIMDL\nmodel=", str_concat(model_name, str_concat("\nstep=", str_concat(to_str(step), "\n"))))
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
