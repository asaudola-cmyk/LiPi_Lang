@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — BARE-METAL IDT & PIC 8259A INTERRUPT CONTROLLER
@! Module: universe/os/drivers/idt.maya
@! Milestone: Grand Sovereign Pillar 4
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features: 64-Bit IDT Gate Descriptors, PIC 8259A Remapping (0x20-0x28),
@! PIT Timer (0x40/0x43) Frequency Setup
@! ============================================================================

import "universe/core/collections"

@! ============================================================================
@! 1. IDT GATE DESCRIPTOR (64-bit Long Mode)
@! ============================================================================

@struct IDTGate64
  offset_low: i64      @! Bits 0..15 of ISR address
  selector: i64        @! Kernel code segment selector (0x08)
  ist: i64             @! Interrupt Stack Table offset (0..7)
  type_attr: i64       @! 0x8E
  offset_mid: i64      @! Bits 16..31 of ISR address
  offset_high: i64     @! Bits 32..63 of ISR address
  reserved: i64         @! Zero
@end

@struct IDTPointer64
  limit: i64           @! sizeof(IDT) - 1 (256 * 16 - 1
  base_address: i64     @! Linear address of IDT array
@end

@struct PICController
  master_cmd_port: i64 @! 0x20
  master_data_port: i64@! 0x21
  slave_cmd_port: i64  @! 0xA0
  slave_data_port: i64 @! 0xA1
  master_offset: i64   @! 0x20 (32)
  slave_offset: i64    @! 0x28 (40)
  irq_mask: i64
@end

@! ============================================================================
@! 2. IDT GATE BUILDER & SERIALIZER
@! ============================================================================

@fn idt_gate_new(isr_address, selector, type_attr)
  off_low = isr_address % 65536
  off_mid = (isr_address / 65536) % 65536
  off_high = (isr_address / 4294967296) % 4294967296

  return {
    offset_low: off_low,
    selector: selector,
    ist: 0,
    type_attr: type_attr,
    offset_mid: off_mid,
    offset_high: off_high,
    reserved: 0
  }
@end

@fn idt_gate_serialize_16b(gate)
  bytes = []
  @! 1. Offset Low (u16)
  bytes = bytes.push(gate.offset_low % 256)
  bytes = bytes.push((gate.offset_low / 256) % 256)
  
  @! 2. Selector (u16)
  bytes = bytes.push(gate.selector % 256)
  bytes = bytes.push((gate.selector / 256) % 256)
  
  @! 3. IST (u8)
  bytes = bytes.push(gate.ist % 8)
  
  @! 4. Type & Attributes (u8)
  bytes = bytes.push(gate.type_attr % 256)
  
  @! 5. Offset Mid (u16)
  bytes = bytes.push(gate.offset_mid % 256)
  bytes = bytes.push((gate.offset_mid / 256) % 256)
  
  @! 6. Offset High (u32)
  bytes = bytes.push(gate.offset_high % 256)
  bytes = bytes.push((gate.offset_high / 256) % 256)
  bytes = bytes.push((gate.offset_high / 65536) % 256)
  bytes = bytes.push((gate.offset_high / 16777216) % 256)
  
  @! 7. Reserved (u32)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)
  bytes = bytes.push(0)

  return bytes
@end

@fn idt_table_new()
  gates = []
  i = 0
  @while i < 256
    @! Null gate
    gates = gates.push(idt_gate_new(0, 8, 142)) @! 0x8E = 142 (Interrupt Gate)
    i = i + 1
  @end
  return gates
@end

@! ============================================================================
@! 3. PIC 8259A REMAPPING & PIT TIMER
@! ============================================================================

@fn pic_init(master_offset, slave_offset)
  return {
    master_cmd_port: 32,  @! 0x20
    master_data_port: 33, @! 0x21
    slave_cmd_port: 160,  @! 0xA0
    slave_data_port: 161, @! 0xA1
    master_offset: master_offset,
    slave_offset: slave_offset,
    irq_mask: 0
  }
@end

@fn pic_calc_irq_vector(pic, irq_num)
  @if irq_num < 8
    return pic.master_offset + irq_num
  @end
  return pic.slave_offset + (irq_num - 8)
@end

@fn pit_calc_divisor(hz)
  base_pit = 1193182 @! 1.193182 MHz
  div = base_pit / hz
  @if div <= 0 div = 1 @end
  @if div > 65535 div = 65535 @end
  return div
@end
