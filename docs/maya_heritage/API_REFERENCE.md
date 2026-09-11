# Maya API Reference

Maya features a comprehensive standard library known as the "Universe", structured into 15 domains.

## 1. Core (`universe/core/`)
Essential language utilities.
- `@fn print(s: string)`
- `@fn println(s: string)`
- `@fn panic(msg: string)`

## 2. Crypto (`universe/crypto/`)
Cryptographic primitives.
- `@fn hash_sha256(data: string) -> string`
- `@fn encrypt_aes(key: string, data: string) -> string`

## 3. Net (`universe/net/`)
Networking and sockets.
- `@fn tcp_listen(address: string) -> Result<TcpListener>`
- `@fn tcp_connect(address: string) -> Result<TcpStream>`

## 4. DB (`universe/db/`)
Database interactions.
- `@fn connect_postgres(url: string) -> Result<DbConnection>`
- `@fn execute_query(conn: DbConnection, query: string) -> Result<ResultSet>`

## 5. AI (`universe/ai/`)
Artificial Intelligence and ML tools.
- `@fn load_model(path: string) -> Result<Model>`
- `@fn infer(model: Model, input: Tensor) -> Result<Tensor>`

## 6. GPU (`universe/gpu/`)
Hardware acceleration.
- `@fn gpu_init() -> Result<GpuContext>`
- `@fn launch_kernel(kernel_name: string, grid: Grid, block: Block, args: [any])`

## 7. OS (`universe/os/`)
Operating system bindings.
- `@fn read_file(path: string) -> Result<string>`
- `@fn write_file(path: string, content: string) -> Result<bool>`

## 8. Kernel (`universe/kernel/`)
Low-level system access.
- `@fn syscall(id: i64, ...args: any) -> i64`
- `@fn alloc_pages(num: i64) -> ptr`

## 9. Web (`universe/web/`)
Web and HTTP utilities.
- `@fn http_get(url: string) -> Result<HttpResponse>`
- `@fn start_server(port: i64) -> Result<HttpServer>`

## 10. Tools (`universe/tools/`)
Utility commands and parsing.
- `@fn parse_json(data: string) -> Result<map>`

## 11. Security (`universe/security/`)
Permissions and sandboxing.
- `@fn drop_privileges()`
- `@fn create_sandbox() -> Result<Sandbox>`

## 12. Assimilator (`universe/assimilator/`)
Foreign Function Interface (FFI) and interoperability.
- `@fn call_c(lib: string, func: string, ...args: any) -> any`

## 13. Registry (`universe/registry/`)
Package and module management.
- `@fn install_package(pkg: string)`

*(Additional domains expanding the Universe functionality...)*
