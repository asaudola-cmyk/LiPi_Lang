@! ============================================================================
@! MAYA CLI: DOCUMENTATION GENERATOR
@! Module: cmd/doc/main
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct DocItem
  name: string,
  kind: string,
  doc: string,
  signature: string
@end

@struct DocGenerator
  output_dir: string,
  items: array
@end

@fn doc_generator_new(output_dir: string) -> DocGenerator
  return DocGenerator {
    output_dir: output_dir,
    items: []
  }
@end

@fn doc_generator_add_item(gen: DocGenerator, name: string, kind: string, doc: string, sig: string) -> DocGenerator
  gen.items = gen.items.push(DocItem {
    name: name,
    kind: kind,
    doc: doc,
    signature: sig
  })
  return gen
@end

@fn doc_generator_generate_html(gen: DocGenerator) -> i64
  index_html = "<html><head><title>Maya Docs</title></head><body><h1>Maya Documentation</h1><ul>"
  i = 0
  len = gen.items.len()
  @while i < len
    item = gen.items[i]
    index_html = index_html + "<li><a href='" + item.name + ".html'>" + item.name + " (" + item.kind + ")</a></li>"
    page = "<html><body><h2>" + item.kind + " " + item.name + "</h2><pre>" + item.signature + "</pre><p>" + item.doc + "</p></body></html>"
    file_write(gen.output_dir + "/" + item.name + ".html", page)
    i = i + 1
  @end
  index_html = index_html + "</ul></body></html>"
  file_write(gen.output_dir + "/index.html", index_html)
  return 1
@end

@fn main()
  gen = doc_generator_new("/tmp/maya_docs")
  gen = doc_generator_add_item(gen, "main", "fn", "Application entry point", "@fn main() -> i64")
  doc_generator_generate_html(gen)
  println("Generated HTML documentation in /tmp/maya_docs")
  return 0
@end
