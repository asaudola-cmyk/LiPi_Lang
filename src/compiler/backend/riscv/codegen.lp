@struct RvBuf
    rv_data: array
    rv_size: i64
@end

@fn rv_buf_new()
    return RvBuf(arr_new(), 0)
@end

@fn rv_emit32(buf, instr)
    buf.rv_data.pushinstr & 255
    buf.rv_data.push((instr / 256) & 255)
    buf.rv_data.push((instr / 65536) & 255)
    buf.rv_data.push((instr / 16777216) & 255)
    buf.rv_size = buf.rv_size + 4
    return 4
@end

@fn rv_r_type(funct7, rs2, rs1, funct3, rd, opcode)
    return (funct7 * 33554432) | (rs2 * 1048576) | (rs1 * 32768) | (funct3 * 4096) | (rd * 128) | opcode
@end

@fn rv_i_type(imm12, rs1, funct3, rd, opcode)
    return (imm12 * 1048576) | (rs1 * 32768) | (funct3 * 4096) | (rd * 128) | opcode
@end

@fn rv_reg_zero()
    return 0
@end

@fn rv_reg_ra()
    return 1
@end

@fn rv_reg_sp()
    return 2
@end

@fn rv_reg_a0()
    return 10
@end

@fn rv_reg_a7()
    return 17
@end

@fn rv_reg_t0()
    return 5
@end

@fn rv_emit_nop(buf)
    rv_emit32(buf, 19)
    return 4
@end

@fn rv_emit_li(buf, rd, imm)
    rv_emit32(buf, rv_i_type(imm, 0, 0, rd, 19))
    return 4
@end

@fn rv_emit_add(buf, rd, rs1, rs2)
    rv_emit32(buf, rv_r_type(0, rs2, rs1, 0, rd, 51))
    return 4
@end

@fn rv_emit_sub(buf, rd, rs1, rs2)
    rv_emit32(buf, rv_r_type(32, rs2, rs1, 0, rd, 51))
    return 4
@end

@fn rv_emit_ecall(buf)
    rv_emit32(buf, 115)
    return 4
@end

@fn rv_emit_ret(buf)
    rv_emit32(buf, rv_i_type(0, 1, 0, 0, 103))
    return 4
@end

@fn rv_emit_exit(buf, code)
    rv_emit_li(buf, rv_reg_a7(), 93)
    rv_emit_li(buf, rv_reg_a0(), code)
    rv_emit_ecall(buf)
    return 12
@end
