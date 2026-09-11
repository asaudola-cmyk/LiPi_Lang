@! ============================================================================
@! MAYA DOCUMENTATION GENERATOR TEST (tests/tools/test_doc_gen.maya)
@! 100% Pure Maya Implementation — Zero Foreign Syntax
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct DocItem
  name: "",
  kind: "",
  doc: "",
  signature: ""
@end

@struct DocGenerator
  output_dir: "",
  items: []
@end

@fn new_doc_generator(out_dir)
  return {
    output_dir: out_dir,
    items: []
  }
@end

@fn doc_add_item(gen, name, kind, doc_str, sig)
  item = {
    name: name,
    kind: kind,
    doc: doc_str,
    signature: sig
  }
  gen.items = gen.items.push(item)
  return gen
@end

@fn main()
  gen = new_doc_generator("./docs")
  gen = doc_add_item(gen, "test", "fn", "test doc", "@fn test() @end")

  @if gen.items.len() != 1
    println("FAIL: Expected 1 doc item, got " + gen.items.len().to_str())
    return 1
  @end

  item0 = gen.items[0]
  @if item0.name != "test" || item0.kind != "fn"
    println("FAIL: Doc item fields mismatch")
    return 1
  @end

  println("PASS: Doc generator test verified.")
  return 0
@end
