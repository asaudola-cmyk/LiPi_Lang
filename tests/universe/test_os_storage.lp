@! ============================================================================
@! TEST SUITE: AHCI SATA DISK DRIVER & STORAGE SUBSYSTEM
@! File: tests/universe/test_os_storage.maya
@! ============================================================================

import "universe/os/drivers/disk"
import "universe/os/storage"
import "universe/core/collections"

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] " + msg)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("▶ [TEST] AHCI SATA Disk Driver & Block Storage Subsystem")
  println("=================================================================")

  total = 0
  passed = 0

  @! 1. Disk Initialization & Parameters
  total = total + 1
  disk = disk_init()
  ok1 = assert_eq_int(disk.sector_size, 512, "Sector size is 512 bytes")
  ok2 = assert_eq_int(disk.total_sectors, 2097152, "Total sectors is 2097152 (1GB)")
  ok3 = assert_eq_int(disk.command_slots, 32, "32 NCQ command slots")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed = passed + 1
    println("  [PASS] TC-DISK-01: AHCI SATA Disk Controller Initialization")
  @end

  @! 2. Default MBR Sector 0 Generation & Parsing
  total = total + 1
  mbr_sec = disk_read_sector(disk, 0)
  ok_sig1 = assert_eq_int(mbr_sec[510], 0x55, "MBR signature byte 510 is 0x55")
  ok_sig2 = assert_eq_int(mbr_sec[511], 0xAA, "MBR signature byte 511 is 0xAA")
  parts = mbr_parse_partitions(mbr_sec)
  ok_p_count = assert_eq_int(parts.len(), 4, "4 MBR partition table records parsed")
  p1 = parts[0]
  ok_p1_type = assert_eq_int(p1.partition_type, 0x83, "Partition 1 type is Linux Native (0x83)")
  ok_p1_start = assert_eq_int(p1.lba_start, 2048, "Partition 1 start LBA is 2048")
  ok_p1_sec = assert_eq_int(p1.sector_count, 1048576, "Partition 1 size is 1048576 sectors (512MB)")
  @if ok_sig1 == 1 && ok_sig2 == 1 && ok_p_count == 1 && ok_p1_type == 1 && ok_p1_start == 1 && ok_p1_sec == 1
    passed = passed + 1
    println("  [PASS] TC-DISK-02: MBR Partition Table Parsing (0x55AA signature & Linux partition)")
  @end

  @! 3. Default GPT Header Sector 1 Parsing
  total = total + 1
  gpt_sec = disk_read_sector(disk, 1)
  gpt_hdr = gpt_validate_header(gpt_sec)
  ok_gpt_val = assert_eq_int(gpt_hdr.is_valid, 1, "GPT Header 'EFI PART' signature valid")
  ok_gpt_rev = assert_eq_int(gpt_hdr.revision, 0x00010000, "GPT Header revision 1.0")
  ok_gpt_lba = assert_eq_int(gpt_hdr.current_lba, 1, "GPT current LBA is 1")
  @if ok_gpt_val == 1 && ok_gpt_rev == 1 && ok_gpt_lba == 1
    passed = passed + 1
    println("  [PASS] TC-DISK-03: GPT Header Validation & LBA Verification")
  @end

  @! 4. Sector Write & Read-Back Persistence
  total = total + 1
  custom_data = []
  i = 0
  @while i < 512
    custom_data = custom_data.push((i * 7 + 13) % 256)
    i = i + 1
  @end
  w_res = disk_write_sector(disk, 42, custom_data)
  ok_w = assert_eq_int(w_res, 1, "disk_write_sector returned success")
  read_back = disk_read_sector(disk, 42)
  ok_rb_len = assert_eq_int(read_back.len(), 512, "Read-back sector is 512 bytes")
  mismatches = 0
  j = 0
  @while j < 512
    @if read_back[j] != custom_data[j]
      mismatches = mismatches + 1
    @end
    j = j + 1
  @end
  ok_match = assert_eq_int(mismatches, 0, "All 512 bytes match written data exactly")
  @if ok_w == 1 && ok_rb_len == 1 && ok_match == 1
    passed = passed + 1
    println("  [PASS] TC-DISK-04: Bit-Exact Read/Write Persistence on LBA 42")
  @end

  @! 5. LBA48 Command FIS & PRDT Construction
  total = total + 1
  cmd_table = ahci_build_command_table(0x12345678, 16, 1)
  cfis = cmd_table.cfis
  ok_fis_type = assert_eq_int(cfis[0], 0x27, "FIS Type 0x27 (Register H2D)")
  ok_fis_cmd = assert_eq_int(cfis[2], 0x61, "Command 0x61 (WRITE FPDMA QUEUED)")
  ok_lba0 = assert_eq_int(cfis[4], 0x78, "LBA0 is 0x78")
  ok_lba1 = assert_eq_int(cfis[5], 0x56, "LBA1 is 0x56")
  ok_lba2 = assert_eq_int(cfis[6], 0x34, "LBA2 is 0x34")
  ok_lba3 = assert_eq_int(cfis[8], 0x12, "LBA3 is 0x12")
  ok_count = assert_eq_int(cfis[12], 16, "Count is 16 sectors")
  ok_prdt = assert_eq_int(cmd_table.prdt.len(), 1, "PRDT table contains 1 entry")
  @if ok_fis_type == 1 && ok_fis_cmd == 1 && ok_lba0 == 1 && ok_lba1 == 1 && ok_lba2 == 1 && ok_lba3 == 1 && ok_count == 1 && ok_prdt == 1
    passed = passed + 1
    println("  [PASS] TC-DISK-05: LBA48 FIS & PRDT Command Descriptor Table Builder")
  @end

  @! 6. High-Level Block Storage Interface
  total = total + 1
  bdev = storage_create_block_device("sda", disk)
  ok_bdev_name = assert_true(bdev.name == "sda", "BlockDevice name is 'sda'")
  ok_bdev_sec = assert_eq_int(bdev.sector_size, 512, "BlockDevice sector size is 512")
  stats = storage_get_stats(bdev)
  ok_stats_total = assert_eq_int(stats.total_sectors, 2097152, "StorageStats total sectors is 2097152")
  mbr_from_storage = storage_get_mbr_partitions(bdev)
  ok_mbr_s = assert_eq_int(mbr_from_storage.len(), 4, "storage_get_mbr_partitions returned 4 partitions")
  flush_res = storage_flush(bdev)
  ok_flush = assert_eq_int(flush_res, 1, "storage_flush succeeded")
  @if ok_bdev_name == 1 && ok_bdev_sec == 1 && ok_stats_total == 1 && ok_mbr_s == 1 && ok_flush == 1
    passed = passed + 1
    println("  [PASS] TC-DISK-06: High-Level Storage Block Device & Partition Queries")
  @end

  println("-----------------------------------------------------------------")
  println("Disk Storage Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if passed == total
    println("✓ AHCI SATA Disk Driver & Storage Subsystem PASSED")
    return 0
  @else
    println("❌ Some disk tests failed")
    return 1
  @end
@end
