import "universe/core/string"
import "universe/core/collections"

@! ============================================================================
@! MAYA VIRTUAL FILESYSTEM (VFS) — universe/os/vfs.maya
@! 100% Written in Pure Lipi Language — Complete Zero libc / Zero C Dependencies
@! Features: Inode RamFS, DevFS (/dev/null, /dev/zero, /dev/random, /dev/tty),
@! File Descriptors, Path Resolution, and Standard File System Operations
@! ============================================================================

@! ----------------------------------------------------------------------------
@! 1. VFS Constants & Inode Types
@! ----------------------------------------------------------------------------

@fn VFS_INODE_FILE() return 1 @end
@fn VFS_INODE_DIR() return 2 @end
@fn VFS_INODE_CHARDEV() return 3 @end
@fn VFS_INODE_BLOCKDEV() return 4 @end
@fn VFS_INODE_FIFO() return 5 @end
@fn VFS_INODE_SYMLINK() return 6 @end

@fn VFS_O_RDONLY() return 0 @end
@fn VFS_O_WRONLY() return 1 @end
@fn VFS_O_RDWR() return 2 @end
@fn VFS_O_CREAT() return 64 @end
@fn VFS_O_TRUNC() return 512 @end
@fn VFS_O_APPEND() return 1024 @end

@fn VFS_SEEK_SET() return 0 @end
@fn VFS_SEEK_CUR() return 1 @end
@fn VFS_SEEK_END() return 2 @end

@! ----------------------------------------------------------------------------
@! 2. Inode & File Descriptor Helpers
@! ----------------------------------------------------------------------------

@fn vfs_create_inode(id, name, kind, mode, parent_id)
  return {
    id: id,
    name: name,
    kind: kind,
    mode: mode,
    size: 0,
    parent_id: parent_id,
    children: [],
    content_bytes: [],
    dev_major: 0,
    dev_minor: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 3. VFS Initialization with RamFS Root and DevFS Devices
@! ----------------------------------------------------------------------------

@fn vfs_init()
  inodes = []
  
  @! Inode 1: / (Root directory)
  root = vfs_create_inode(1, "/", 2, 493, 1) @! 0755
  inodes = inodes.push(root)
  
  @! Inode 2: /dev (DevFS directory)
  dev_dir = vfs_create_inode(2, "dev", 2, 493, 1)
  inodes = inodes.push(dev_dir)
  inodes[0].children = inodes[0].children.push(2)
  
  @! Inode 3: /dev/null (Char device 1:3)
  dev_null = vfs_create_inode(3, "null", 3, 438, 2) @! 0666
  dev_null.dev_major = 1
  dev_null.dev_minor = 3
  inodes = inodes.push(dev_null)
  inodes[1].children = inodes[1].children.push(3)
  
  @! Inode 4: /dev/zero (Char device 1:5)
  dev_zero = vfs_create_inode(4, "zero", 3, 438, 2)
  dev_zero.dev_major = 1
  dev_zero.dev_minor = 5
  inodes = inodes.push(dev_zero)
  inodes[1].children = inodes[1].children.push(4)
  
  @! Inode 5: /dev/random (Char device 1:8)
  dev_rand = vfs_create_inode(5, "random", 3, 438, 2)
  dev_rand.dev_major = 1
  dev_rand.dev_minor = 8
  inodes = inodes.push(dev_rand)
  inodes[1].children = inodes[1].children.push(5)
  
  @! Inode 6: /dev/urandom (Char device 1:9)
  dev_urand = vfs_create_inode(6, "urandom", 3, 438, 2)
  dev_urand.dev_major = 1
  dev_urand.dev_minor = 9
  inodes = inodes.push(dev_urand)
  inodes[1].children = inodes[1].children.push(6)
  
  @! Inode 7: /dev/tty (Char device 5:0)
  dev_tty = vfs_create_inode(7, "tty", 3, 438, 2)
  dev_tty.dev_major = 5
  dev_tty.dev_minor = 0
  inodes = inodes.push(dev_tty)
  inodes[1].children = inodes[1].children.push(7)
  
  @! Inode 8: /bin
  bin_dir = vfs_create_inode(8, "bin", 2, 493, 1)
  inodes = inodes.push(bin_dir)
  inodes[0].children = inodes[0].children.push(8)
  
  @! Inode 9: /tmp
  tmp_dir = vfs_create_inode(9, "tmp", 2, 511, 1) @! 0777
  inodes = inodes.push(tmp_dir)
  inodes[0].children = inodes[0].children.push(9)
  
  @! Inode 10: /home
  home_dir = vfs_create_inode(10, "home", 2, 493, 1)
  inodes = inodes.push(home_dir)
  inodes[0].children = inodes[0].children.push(10)
  
  return {
    inodes: inodes,
    open_files: [],
    next_inode_id: 11,
    next_fd: 3, @! 0=stdin, 1=stdout, 2=stderr
    prng_state: 88172645463325252
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Path Splitting & Traversal Engine
@! ----------------------------------------------------------------------------

@fn vfs_split_path(path)
  segments = []
  num_items = path.len()
  i = 0
  cur = ""
  @while i < num_items
    c = str_char_at(path, i)
    @if c == 47 @! '/'
      @if cur.len() > 0
        segments = segments.push(cur)
        cur = ""
      @end
    @else
      cur = cur + str_substr(path, i, i + 1)
    @end
    i = i + 1
  @end
  @if cur.len() > 0
    segments = segments.push(cur)
  @end
  return segments
@end

@fn vfs_lookup_path(vfs, path)
  @if path == "" || path == "/"
    return vfs.inodes[0] @! Root directory
  @end
  
  segments = vfs_split_path(path)
  cur_node = vfs.inodes[0]
  
  s_idx = 0
  num_segs = segments.len()
  @while s_idx < num_segs
    target_name = segments[s_idx]
    found_child = 0
    
    c_idx = 0
    num_children = cur_node.children.len()
    @while c_idx < num_children
      child_id = cur_node.children[c_idx]
      
      @! Find inode by child_id
      in_idx = 0
      num_inodes = vfs.inodes.len()
      @while in_idx < num_inodes
        @if vfs.inodes[in_idx].id == child_id
          @if vfs.inodes[in_idx].name == target_name
            cur_node = vfs.inodes[in_idx]
            found_child = 1
            break
          @end
        @end
        in_idx = in_idx + 1
      @end
      
      @if found_child == 1 break @end
      c_idx = c_idx + 1
    @end
    
    @if found_child == 0
      return 0 @! Not found
    @end
    
    s_idx = s_idx + 1
  @end
  
  return cur_node
@end

@! ----------------------------------------------------------------------------
@! 5. PRNG Helper for /dev/random & /dev/urandom
@! ----------------------------------------------------------------------------

@fn vfs_next_random_byte(vfs)
  x = vfs.prng_state
  x = x ^ (x * 8192)
  x = x ^ (x / 2097152)
  x = x ^ (x * 134217728)
  @if x == 0 x = 88172645463325252 @end
  vfs.prng_state = x
  return x & 255
@end

@! ----------------------------------------------------------------------------
@! 6. Core Standard File Operations (Open, Read, Write, Lseek, Close)
@! ----------------------------------------------------------------------------

@fn vfs_open(vfs, path, flags, mode)
  target_node = vfs_lookup_path(vfs, path)
  
  @if target_node == 0
    @! File does not exist: Check if O_CREAT is set
    has_creat = flags & 64
    @if has_creat != 0
      segments = vfs_split_path(path)
      @if segments.len() == 0 return 0 - 2 @! ENOENT
      
      file_name = segments[segments.len() - 1]
      
      @! Find parent directory
      parent_node = vfs.inodes[0]
      @if segments.len() > 1
        parent_path = ""
        p = 0
        @while p < segments.len() - 1
          parent_path = parent_path + "/" + segments[p]
          p = p + 1
        @end
        parent_node = vfs_lookup_path(vfs, parent_path)
        @if parent_node == 0 return 0 - 2 @! ENOENT
      @end
      
      @! Create new file inode
      new_id = vfs.next_inode_id
      vfs.next_inode_id = new_id + 1
      
      new_node = vfs_create_inode(new_id, file_name, 1, mode, parent_node.id)
      vfs.inodes = vfs.inodes.push(new_node)
      
      @! Link into parent's children
      p_idx = 0
      @while p_idx < vfs.inodes.len()
        @if vfs.inodes[p_idx].id == parent_node.id
          vfs.inodes[p_idx].children = vfs.inodes[p_idx].children.push(new_id)
          break
        @end
        p_idx = p_idx + 1
      @end
      
      target_node = new_node
    @else
      return 0 - 2 @! ENOENT
    @end
  @end
  
  @! Truncate file if O_TRUNC is set and it is a regular file
  has_trunc = flags & 512
  @if has_trunc != 0
    @if target_node.kind == 1
      t_idx = 0
      @while t_idx < vfs.inodes.len()
        @if vfs.inodes[t_idx].id == target_node.id
          vfs.inodes[t_idx].content_bytes = []
          vfs.inodes[t_idx].size = 0
          break
        @end
        t_idx = t_idx + 1
      @end
    @end
  @end
  
  fd_num = vfs.next_fd
  vfs.next_fd = fd_num + 1
  
  init_offset = 0
  has_append = flags & 1024
  @if has_append != 0
    init_offset = target_node.size
  @end
  
  open_file = {
    fd: fd_num,
    inode_id: target_node.id,
    flags: flags,
    offset: init_offset,
    is_open: 1
  }
  
  vfs.open_files = vfs.open_files.push(open_file)
  return fd_num
@end

@fn vfs_read(vfs, fd, count)
  @if count <= 0 return [] @end
  
  @! Find open file
  f_idx = 0
  open_file = 0
  @while f_idx < vfs.open_files.len()
    @if vfs.open_files[f_idx].fd == fd && vfs.open_files[f_idx].is_open == 1
      open_file = vfs.open_files[f_idx]
      break
    @end
    f_idx = f_idx + 1
  @end
  
  @if open_file == 0 return [] @end
  
  @! Find associated inode
  in_idx = 0
  inode = 0
  @while in_idx < vfs.inodes.len()
    @if vfs.inodes[in_idx].id == open_file.inode_id
      inode = vfs.inodes[in_idx]
      break
    @end
    in_idx = in_idx + 1
  @end
  
  @if inode == 0 return [] @end
  
  @! Handle DevFS Character Devices
  @if inode.kind == 3 @! CHARDEV
    @if inode.name == "null"
      return [] @! EOF
    @elif inode.name == "zero"
      res_bytes = []
      z = 0
      @while z < count
        res_bytes = res_bytes.push(0)
        z = z + 1
      @end
      return res_bytes
    @elif inode.name == "random" || inode.name == "urandom"
      res_bytes = []
      r = 0
      @while r < count
        res_bytes = res_bytes.push(vfs_next_random_byte(vfs))
        r = r + 1
      @end
      return res_bytes
    @end
  @end
  
  @! Regular File Read
  avail = inode.size - open_file.offset
  @if avail <= 0 return [] @end
  
  read_count = count
  @if read_count > avail
    read_count = avail
  @end
  
  res = []
  i = 0
  @while i < read_count
    res = res.push(inode.content_bytes[open_file.offset + i])
    i = i + 1
  @end
  
  open_file.offset = open_file.offset + read_count
  return res
@end

@fn vfs_write(vfs, fd, data)
  data_len = data.len()
  @if data_len <= 0 return 0 @end
  
  f_idx = 0
  open_file = 0
  @while f_idx < vfs.open_files.len()
    @if vfs.open_files[f_idx].fd == fd && vfs.open_files[f_idx].is_open == 1
      open_file = vfs.open_files[f_idx]
      break
    @end
    f_idx = f_idx + 1
  @end
  
  @if open_file == 0 return 0 - 9 @! EBADF
  
  in_idx = 0
  inode = 0
  @while in_idx < vfs.inodes.len()
    @if vfs.inodes[in_idx].id == open_file.inode_id
      inode = vfs.inodes[in_idx]
      break
    @end
    in_idx = in_idx + 1
  @end
  
  @if inode == 0 return 0 - 9 @! EBADF
  
  @! Handle DevFS Discard Devices
  @if inode.kind == 3
    @if inode.name == "null" || inode.name == "zero"
      return data_len
    @elif inode.name == "random" || inode.name == "urandom"
      @if data_len >= 4
        b0 = data[0]
        b1 = data[1] * 256
        b2 = data[2] * 65536
        b3 = data[3] * 16777216
        p_st = b0 | b1
        p_st = p_st | b2
        p_st = p_st | b3
        vfs.prng_state = p_st
      @end
      return data_len
    @end
  @end
  
  @! Regular File Write
  i = 0
  write_offset = open_file.offset
  @while i < data_len
    target_pos = write_offset + i
    @if target_pos < inode.content_bytes.len()
      inode.content_bytes = list_set(inode.content_bytes, target_pos, data[i])
    @else
      inode.content_bytes = inode.content_bytes.push(data[i])
    @end
    i = i + 1
  @end
  
  open_file.offset = write_offset + data_len
  @if open_file.offset > inode.size
    inode.size = open_file.offset
  @end
  
  return data_len
@end

@fn vfs_lseek(vfs, fd, offset, whence)
  f_idx = 0
  open_file = 0
  @while f_idx < vfs.open_files.len()
    @if vfs.open_files[f_idx].fd == fd && vfs.open_files[f_idx].is_open == 1
      open_file = vfs.open_files[f_idx]
      break
    @end
    f_idx = f_idx + 1
  @end
  
  @if open_file == 0 return 0 - 9 @end
  
  in_idx = 0
  inode = 0
  @while in_idx < vfs.inodes.len()
    @if vfs.inodes[in_idx].id == open_file.inode_id
      inode = vfs.inodes[in_idx]
      break
    @end
    in_idx = in_idx + 1
  @end
  
  @if inode == 0 return 0 - 9 @end
  
  new_off = 0
  @if whence == 0 @! SEEK_SET
    new_off = offset
  @elif whence == 1 @! SEEK_CUR
    new_off = open_file.offset + offset
  @elif whence == 2 @! SEEK_END
    new_off = inode.size + offset
  @end
  
  @if new_off < 0 return 0 - 22 @! EINVAL
  open_file.offset = new_off
  return new_off
@end

@fn vfs_close(vfs, fd)
  f_idx = 0
  @while f_idx < vfs.open_files.len()
    @if vfs.open_files[f_idx].fd == fd && vfs.open_files[f_idx].is_open == 1
      vfs.open_files[f_idx].is_open = 0
      return 0
    @end
    f_idx = f_idx + 1
  @end
  return 0 - 9 @! EBADF
@end

@! ----------------------------------------------------------------------------
@! 7. Metadata, Directory Creation, Inspection & Unlink
@! ----------------------------------------------------------------------------

@fn vfs_stat(vfs, path)
  node = vfs_lookup_path(vfs, path)
  @if node == 0 return 0 @end
  
  is_d = 0
  is_f = 0
  is_c = 0
  @if node.kind == 2 is_d = 1 @end
  @if node.kind == 1 is_f = 1 @end
  @if node.kind == 3 is_c = 1 @end
  
  return {
    inode_id: node.id,
    name: node.name,
    kind: node.kind,
    size: node.size,
    mode: node.mode,
    is_dir: is_d,
    is_file: is_f,
    is_chardev: is_c
  }
@end

@fn vfs_mkdir(vfs, path, mode)
  existing = vfs_lookup_path(vfs, path)
  @if existing != 0 return 0 - 17 @! EEXIST
  
  segments = vfs_split_path(path)
  @if segments.len() == 0 return 0 - 22 @! EINVAL
  
  dir_name = segments[segments.len() - 1]
  
  parent_node = vfs.inodes[0]
  @if segments.len() > 1
    parent_path = ""
    p = 0
    @while p < segments.len() - 1
      parent_path = parent_path + "/" + segments[p]
      p = p + 1
    @end
    parent_node = vfs_lookup_path(vfs, parent_path)
    @if parent_node == 0 return 0 - 2 @! ENOENT
  @end
  
  new_id = vfs.next_inode_id
  vfs.next_inode_id = new_id + 1
  
  new_dir = vfs_create_inode(new_id, dir_name, 2, mode, parent_node.id)
  vfs.inodes = vfs.inodes.push(new_dir)
  
  p_idx = 0
  @while p_idx < vfs.inodes.len()
    @if vfs.inodes[p_idx].id == parent_node.id
      vfs.inodes[p_idx].children = vfs.inodes[p_idx].children.push(new_id)
      break
    @end
    p_idx = p_idx + 1
  @end
  
  return 0
@end

@fn vfs_read_dir(vfs, path)
  node = vfs_lookup_path(vfs, path)
  @if node == 0 return [] @end
  @if node.kind != 2 return [] @! ENOTDIR
  
  entries = []
  c = 0
  @while c < node.children.len()
    child_id = node.children[c]
    i = 0
    @while i < vfs.inodes.len()
      @if vfs.inodes[i].id == child_id
        child_node = vfs.inodes[i]
        entries = entries.push({
          inode_id: child_node.id,
          name: child_node.name,
          kind: child_node.kind
        })
        break
      @end
      i = i + 1
    @end
    c = c + 1
  @end
  
  return entries
@end

@fn vfs_unlink(vfs, path)
  node = vfs_lookup_path(vfs, path)
  @if node == 0 return 0 - 2 @! ENOENT
  @if node.kind == 2 return 0 - 21 @! EISDIR
  
  target_id = node.id
  parent_id = node.parent_id
  
  @! Remove from parent's children list
  p_idx = 0
  @while p_idx < vfs.inodes.len()
    @if vfs.inodes[p_idx].id == parent_id
      new_kids = []
      k = 0
      @while k < vfs.inodes[p_idx].children.len()
        @if vfs.inodes[p_idx].children[k] != target_id
          new_kids = new_kids.push(vfs.inodes[p_idx].children[k])
        @end
        k = k + 1
      @end
      vfs.inodes[p_idx].children = new_kids
      break
    @end
    p_idx = p_idx + 1
  @end
  
  @! Remove from master inodes list
  new_inodes = []
  n = 0
  @while n < vfs.inodes.len()
    @if vfs.inodes[n].id != target_id
      new_inodes = new_inodes.push(vfs.inodes[n])
    @end
    n = n + 1
  @end
  vfs.inodes = new_inodes
  
  return 0
@end
