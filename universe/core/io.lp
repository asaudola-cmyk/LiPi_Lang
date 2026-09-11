@! Maya Core I/O Library — Real Implementation

@fn read_file(path)
  return file_read(path)
@end

@fn write_file(path, content)
  return file_write(path, content)
@end

@fn append_file(path, content)
  return file_append(path, content)
@end

@fn path_exists(path)
  return file_exists(path)
@end
