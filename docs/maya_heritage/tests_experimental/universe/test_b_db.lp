import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/db"

@fn main()
  string_println("=== NATIVE MAYA DATABASE ===")
  
  db = db_init()
  
  string_println("Storing values...")
  db_set(db, "username", "admin")
  db_set(db, "password", "supersecret123")
  db_set(db, "version", "2.0 Native")
  
  string_println("Retrieving values...")
  
  user = db_get(db, "username")
  string_print("username: ")
  @if user != 0 string_println(user) @else string_println("NULL") @end
  
  pass = db_get(db, "password")
  string_print("password: ")
  @if pass != 0 string_println(pass) @else string_println("NULL") @end
  
  ver = db_get(db, "version")
  string_print("version: ")
  @if ver != 0 string_println(ver) @else string_println("NULL") @end
  
  missing = db_get(db, "email")
  string_print("email: ")
  @if missing != 0 string_println(missing) @else string_println("NULL") @end
  
  string_println("Updating password...")
  db_set(db, "password", "newpass456")
  
  pass2 = db_get(db, "password")
  string_print("password (updated): ")
  @if pass2 != 0 string_println(pass2) @else string_println("NULL") @end
  
  string_println("Database test successful!")
  sys_exit(0)
  return 0
@end

@fn sys_write_byte(fd, b)
  buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke8(buf, b)
  sys_syscall(1, fd, buf, 1, 0, 0, 0)
  return 0
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
  return 0
@end
