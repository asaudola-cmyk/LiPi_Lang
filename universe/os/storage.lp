@! ============================================================================
@! MAYA UNIVERSE OS — HIGH-LEVEL BLOCK STORAGE INTERFACE (universe/os/storage)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! ============================================================================

import "universe/os/drivers/disk"
import "universe/core/collections"

@struct BlockDevice
  name: string
  sector_size: i64
  total_sectors: i64
  driver_disk: AHCIDisk
@end

@struct StorageStats
  total_bytes: i64
  free_bytes: i64
  sector_size: i64
  total_sectors: i64
  dirty_count: i64
@end

@! Creates a new block device wrapping an underlying AHCI disk
@fn storage_create_block_device(name, disk)
  return {
    name: name,
    sector_size: disk.sector_size,
    total_sectors: disk.total_sectors,
    driver_disk: disk
  }
@end

@! Reads count sectors starting at LBA from block device
@fn storage_read_sectors(bdev, lba, count)
  all_data = []
  i = 0
  @while i < count
    sec = disk_read_sector(bdev.driver_disk, lba + i)
    j = 0
    s_len = sec.len()
    @while j < s_len
      all_data = all_data.push(sec[j])
      j = j + 1
    @end
    i = i + 1
  @end
  return all_data
@end

@! Writes count sectors starting at LBA to block device
@fn storage_write_sectors(bdev, lba, data, count)
  i = 0
  sec_size = bdev.sector_size
  @while i < count
    sec_data = []
    j = 0
    base_off = i * sec_size
    @while j < sec_size
      data_idx = base_off + j
      @if data_idx < data.len()
        sec_data = sec_data.push(data[data_idx])
      @else
        sec_data = sec_data.push(0)
      @end
      j = j + 1
    @end
    disk_write_sector(bdev.driver_disk, lba + i, sec_data)
    i = i + 1
  @end
  return count
@end

@! Flushes all pending writes to disk
@fn storage_flush(bdev)
  return disk_flush_cache(bdev.driver_disk)
@end

@! Parses MBR partitions from LBA 0
@fn storage_get_mbr_partitions(bdev)
  sec0 = disk_read_sector(bdev.driver_disk, 0)
  return mbr_parse_partitions(sec0)
@end

@! Validates GPT header from LBA 1
@fn storage_get_gpt_header(bdev)
  sec1 = disk_read_sector(bdev.driver_disk, 1)
  return gpt_validate_header(sec1)
@end

@! Returns device storage statistics
@fn storage_get_stats(bdev)
  return {
    total_bytes: bdev.total_sectors * bdev.sector_size,
    free_bytes: (bdev.total_sectors - bdev.driver_disk.sectors_lba.len()) * bdev.sector_size,
    sector_size: bdev.sector_size,
    total_sectors: bdev.total_sectors,
    dirty_count: bdev.driver_disk.dirty_sectors.len()
  }
@end
