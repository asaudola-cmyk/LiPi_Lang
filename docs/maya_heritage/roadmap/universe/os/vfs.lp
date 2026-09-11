@! ============================================================================
@! MAYA OS KERNEL — VIRTUAL FILE SYSTEM & INODE LAYER (vfs.my)
@! 100% Written in Pure Maya Language — RamFS & Inode File Operations
@! ============================================================================

@! Inode Types: 1 = FILE, 2 = DIRECTORY, 3 = DEVICE_NODE
@fn create_inode(inode_id, name, inode_type, content)
  return {
    id: inode_id,
    name: name,
    kind: inode_type,
    size: content.len(),
    content: content,
    children: []
  }
@end

@fn vfs_init_root()
  root_node = create_inode(1, "/", 2, "")
  dev_node = create_inode(2, "dev", 2, "")
  bin_node = create_inode(3, "bin", 2, "")
  home_node = create_inode(4, "home", 2, "")
  
  root_node.children = root_node.children.push(dev_node)
  root_node.children = root_node.children.push(bin_node)
  root_node.children = root_node.children.push(home_node)
  
  return {
    root: root_node,
    next_inode_id: 5
  }
@end

@fn vfs_create_file(vfs, path, content)
  new_id = vfs.next_inode_id
  file_node = create_inode(new_id, path, 1, content)
  
  new_root_children = vfs.root.children.push(file_node)
  vfs.root.children = new_root_children
  
  return {
    root: vfs.root,
    next_inode_id: new_id + 1,
    created_inode_id: new_id
  }
@end

@fn vfs_read_file(vfs, filename)
  @for node in vfs.root.children
    @if node.name == filename && node.kind == 1
      return node.content
    @end
  @end
  return ""
@end
