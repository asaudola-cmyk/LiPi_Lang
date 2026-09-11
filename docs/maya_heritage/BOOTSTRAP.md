# Maya Language Bootstrap Milestone

## Historic Milestone

Maya can now compile Maya!

The `mayac_compiler_v2` is a fully self-hosted compiler implemented purely in Maya. 

## Self-hosted Pipeline Architecture
1. **Frontend**: Lexing, parsing, and typechecking are handled entirely in Maya code (`compiler/frontend/*`).
2. **Backend**: IR generation and x86_64 ELF file generation are handled in Maya (`compiler/backend/*`).
3. **Maya Compiler v2**: The entrypoint that ties it all together into an executable (`compiler/maya_compiler_v2.maya`).

## Path Forward
- Full LLVM elimination: Replacing the remaining legacy LLVM-based C++ compiler (`bin/maya`).
- Language evolution: Developing and extending Maya using Maya itself.

> "Maya karo help ney na. Maya r help sobai ney."
