import 'cpu.dart';

/// Class to handle instruction implementation, instructions run on top of the CPU object.
///
/// This class is just an abstraction to make the CPU structure cleaner.
class Instructions
{
  static int NOP(CPU cpu){}

  static int CALL_cc_nn(CPU cpu, int op)
  {
    int jmp = (nextUByte()) | (nextUByte() << 8);

    if(getConditionalFlag(0b100 | ((op >> 3) & 0x7)))
    {
      pushWord(cpu.pc);
      cpu.pc = jmp;
      cpu.clocks += 4;
    }
  }

  static int CALL_nn(CPU cpu)
  {
    int jmp = (nextUByte()) | (nextUByte() << 8);
    pushWord(cpu.pc);
    cpu.pc = jmp;
    cpu.clocks += 4;
  }

  static int LD_dd_nn(CPU cpu, int op)
  {
    setRegisterPair(RegisterPair.byValue[(op >> 4) & 0x3], nextUByte() | (nextUByte() << 8));
  }

  static int LD_r_n(CPU cpu, int op)
  {
    int to = (op >> 3) & 0x7;
    int n = nextUByte();
    setRegister(to, n);
  }

  static int LD_A_BC(CPU cpu)
  {
    cpu.registers.a = getUByte(cpu.registers.bc);
  }

  static int LD_A_DE(CPU cpu)
  {
    cpu.registers.a = getUByte(cpu.registers.de);
  }

  static int LD_BC_A(CPU cpu)
  {
    setByte(cpu.registers.bc, A);
  }

  static int LD_DE_A(CPU cpu)
  {
    setByte(cpu.registers.de, A);
  }

  static int LD_A_C(CPU cpu)
  {
    cpu.registers.a = getUByte(0xFF00 | C);
  }

  static int ADD_SP_n(CPU cpu)
  {
    int offset = nextByte();
    int nsp = (cpu.sp + offset);

    cpu.registers.f = 0;
    int carry = nsp ^ cpu.sp ^ offset;
    
    if((carry & 0x100) != 0) cpu.registers.f |= F_C;
    if((carry & 0x10) != 0) cpu.registers.f |= F_H;

    nsp &= 0xffff;

    cpu.sp = nsp;
    cpu.clocks += 4;
}

  static int SCF(CPU cpu)
  {
    cpu.registers.f &= F_Z;
    cpu.registers.f |= F_C;
  }

  static int CCF(CPU cpu)
  {
    cpu.registers.f = (cpu.registers.f & F_C) != 0 ? (cpu.registers.f & F_Z) : ((cpu.registers.f & F_Z) | F_C);
  }

  static int LD_A_n(CPU cpu)
  {
    cpu.registers.a = getUByte(cpu.registers.hl & 0xffff);

    cpu.registers.hl = (cpu.registers.hl - 1) & 0xFFFF;
  }

  static int LD_nn_A(CPU cpu)
  {
    setByte(nextUByte() | (nextUByte() << 8), A);
  }

  static int LDHL_SP_n(CPU cpu)
  {
    int offset = nextByte();
    int nsp = (cpu.sp + offset);

    cpu.registers.f = 0; // (short) (cpu.registers.f & F_Z);
    int carry = nsp ^ cpu.sp ^ offset;
    if((carry & 0x100) != 0) cpu.registers.f |= F_C;
    if((carry & 0x10) != 0) cpu.registers.f |= F_H;
    nsp &= 0xffff;

    cpu.registers.hl =  nsp;
  }

  static int CPL(CPU cpu)
  {
    cpu.registers.a = (~A) & 0xFF;
    cpu.registers.f = (cpu.registers.f & (F_cpu.registers.c | F_Z)) | F_cpu.registers.h | F_N;
  }

  static int LD_FFn_A(CPU cpu)
  {
    setByte(0xff00 | nextUByte(), A);
  }

  static int LDH_FFC_A(CPU cpu)
  {
    setByte(0xFF00 | (cpu.registers.c & 0xFF), A);
  }

  static int LD_A_nn(CPU cpu)
  {
    int nn = nextUByte() | (nextUByte() << 8);
    cpu.registers.a = getUByte(nn);
  }

  static int LD_A_HLI(CPU cpu)
  {
    cpu.registers.a = getUByte(cpu.registers.hl & 0xffff);
    cpu.registers.hl =  (cpu.registers.hl + 1) & 0xffff;
  }

  static int LD_HLI_A(CPU cpu)
  {
    setByte(cpu.registers.hl & 0xFFFF, A);
    cpu.registers.hl =  (cpu.registers.hl + 1) & 0xffff;
  }

  static int LD_HLD_A(CPU cpu)
  {
    int hl = cpu.registers.hl;
    setByte(hl, A);
    cpu.registers.hl = (hl - 1) & 0xFFFF;

  }

  static int STOP(CPU cpu)
  {
    return NOP(cpu);
  }

  static void LD_r_r(CPU cpu, int op)
  {
    int from = op & 0x7;
    int to = (op >> 3) & 0x7;

    // important note: getIO(6) fetches (HL)
    setRegister(to, getRegister(from) & 0xFF);
  }

  static void CBPrefix(CPU cpu)
  {
    int x = cpu.pc++;
    int cbop = getUByte(x);
    int r = cbop & 0x7;
    int d = getRegister(r) & 0xff;

    switch(cbop & 0b11000000)
    {
      case 0x80:
        {
          // RES b, r
          // 1 0 b b b r r r
          setRegister(r, d & ~(0x1 << (cbop >> 3 & 0x7)));
          return;
        }
      case 0xc0:
        {
          // SET b, r
          // 1 1 b b b r r r
          setRegister(r, d | (0x1 << (cbop >> 3 & 0x7)));
          return;
        }
      case 0x40:
        {
          // BIT b, r
          // 0 1 b b b r r r
          cpu.registers.f &= F_C;
          cpu.registers.f |= F_H;
          if((d & (0x1 << (cbop >> 3 & 0x7))) == 0) cpu.registers.f |= F_Z;
          return;
        }
      case 0x0:
        {
          switch(cbop & 0xf8)
          {
            case 0x00: // RLcpu.registers.c m
              {
                cpu.registers.f = 0;
                if((d & 0x80) != 0) cpu.registers.f |= F_C;
                d <<= 1;

                // we're shifting circular left, add back bit 7
                if((cpu.registers.f & F_C) != 0) d |= 0x01;
                d &= 0xff;
                if(d == 0) cpu.registers.f |= F_Z;
                setRegister(r, d);
                return;
              }
            case 0x08: // RRcpu.registers.c m
              {
                cpu.registers.f = 0;
                if((d & 0b1) != 0) cpu.registers.f |= F_C;
                d >>= 1;

                // we're shifting circular right, add back bit 7
                if((cpu.registers.f & F_C) != 0) d |= 0x80;
                d &= 0xff;
                if(d == 0) cpu.registers.f |= F_Z;
                setRegister(r, d);
                return;
              }
            case 0x10: // Rcpu.registers.l m
              {
                bool carryflag = (cpu.registers.f & F_C) != 0;
                cpu.registers.f = 0;

                // we'll be shifting left, so if bit 7 is set we set carry
                if((d & 0x80) == 0x80) cpu.registers.f |= F_C;
                d <<= 1;
                d &= 0xff;

                // move old cpu.registers.c into bit 0
                if(carryflag) d |= 0b1;
                if(d == 0) cpu.registers.f |= F_Z;
                setRegister(r, d);
                return;
              }
            case 0x18: // RR m
              {
                bool carryflag = (cpu.registers.f & F_C) != 0;
                cpu.registers.f = 0;

                // we'll be shifting right, so if bit 1 is set we set carry
                if((d & 0x1) == 0x1) cpu.registers.f |= F_C;
                d >>= 1;

                // move old cpu.registers.c into bit 7
                if(carryflag) d |= 0b10000000;

                if(d == 0) cpu.registers.f |= F_Z;
                
                setRegister(r, d);
                
                return;
              }
            case 0x38: // SRcpu.registers.l m
              {
                cpu.registers.f = 0;

                // we'll be shifting right, so if bit 1 is set we set carry
                if((d & 0x1) != 0) cpu.registers.f |= F_C;
                d >>= 1;
                if(d == 0) cpu.registers.f |= F_Z;
                setRegister(r, d);
                return;
              }
            case 0x20: // SLcpu.registers.a m
              {
                cpu.registers.f = 0;

                // we'll be shifting right, so if bit 1 is set we set carry
                if((d & 0x80) != 0) cpu.registers.f |= F_C;
                d <<= 1;
                d &= 0xff;
                if(d == 0) cpu.registers.f |= F_Z;
                setRegister(r, d);
                return;
              }
            case 0x28: // SRcpu.registers.a m
              {
                bool bit7 = (d & 0x80) != 0;
                cpu.registers.f = 0;
                if((d & 0b1) != 0) cpu.registers.f |= F_C;
                d >>= 1;
                if(bit7) d |= 0x80;
                if(d == 0) cpu.registers.f |= F_Z;
                setRegister(r, d);
                return;
              }
            case 0x30: // SWAP m
              {
                d = ((d & 0xF0) >> 4) | ((d & 0x0F) << 4);
                cpu.registers.f = d == 0 ? F_Z : 0;
                setRegister(r, d);
                return;
              }
            default:
              throw new UnsupportedOperationException("cb-&f8-" + Integer.toHexString(cbop));
          }
        }
      default:
        throw new UnsupportedOperationException("cb-" + Integer.toHexString(cbop));
    }
  }

  static void DEC_rr(CPU cpu, int op)
  {
    RegisterPair p = RegisterPair.byValue[(op >> 4) & 0x3];
    int o = getRegisterPair(p);
    setRegisterPair(p, o - 1);
  }

  static void RLA(CPU cpu)
  {
    bool carryflag = (cpu.registers.f & F_C) != 0;
    cpu.registers.f = 0; // &= F_Z;?

    // we'll be shifting left, so if bit 7 is set we set carry
    if((cpu.registers.a & 0x80) == 0x80) cpu.registers.f |= F_C;
    cpu.registers.a <<= 1;
    cpu.registers.a &= 0xff;

    // move old cpu.registers.c into bit 0
    if(carryflag) cpu.registers.a |= 1;
  }

  static void RRA(CPU cpu)
  {
    bool carryflag = (cpu.registers.f & F_C) != 0;
    cpu.registers.f = 0;

    // we'll be shifting right, so if bit 1 is set we set carry
    if((cpu.registers.a & 0x1) == 0x1) cpu.registers.f |= F_C;
    cpu.registers.a >>= 1;

    // move old cpu.registers.c into bit 7
    if(carryflag) cpu.registers.a |= 0x80;
  }

  static void RRCA(CPU cpu)
  {
    cpu.registers.f = 0;//F_Z;
    if((cpu.registers.a & 0x1) == 0x1) cpu.registers.f |= F_C;
    cpu.registers.a >>= 1;

    // we're shifting circular right, add back bit 7
    if((cpu.registers.f & F_C) != 0) cpu.registers.a |= 0x80;
  }

  static void SBC_r(CPU cpu, int op)
  {
    int carry = (cpu.registers.f & F_C) != 0 ? 1 : 0;
    int reg = getRegister(op & 0b111) & 0xff;

    cpu.registers.f = F_N;
    if((cpu.registers.a & 0x0f) - (reg & 0x0f) - carry < 0) cpu.registers.f |= F_H;
    cpu.registers.a -= reg + carry;
    if(cpu.registers.a < 0)
    {
      cpu.registers.f |= F_C;
      cpu.registers.a &= 0xFF;
    }
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void ADC_n(CPU cpu)
  {
    int val = nextUByte();
    int carry = ((cpu.registers.f & F_C) != 0 ? 1 : 0);
    int n = val + carry;

    cpu.registers.f = 0;
    if((((cpu.registers.a & 0xf) + (val & 0xf)) + carry & 0xF0) != 0) cpu.registers.f |= F_H;
    cpu.registers.a += n;
    if(cpu.registers.a > 0xFF)
    {
      cpu.registers.f |= F_C;
      cpu.registers.a &= 0xFF;
    }
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static int RET(CPU cpu)
  {
    cpu.pc = (getUByte(cpu.sp + 1) << 8) | getUByte(cpu.sp);
    cpu.sp += 2;
    cpu.clocks += 4;
}

  static void XOR_n(CPU cpu)
  {
    cpu.registers.a ^= nextUByte();
    cpu.registers.f = 0;
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void AND_n(CPU cpu)
  {
    cpu.registers.a &= nextUByte();
    cpu.registers.f = F_H;
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static int EI(CPU cpu)
  {
    cpu.interruptsEnabled = true;

    // Note that during the execution of this instruction and the following instruction, maskable interrupts are disabled. we still need to increment div etc
    cpu.tick(4);

    return _exec();
  }

  static void DI(CPU cpu)
  {
    cpu.interruptsEnabled = false;
  }

  static int RST_p(CPU cpu, int op)
  {
    pushWord(cpu.pc);
    cpu.pc = op & 0b00111000;
    cpu.clocks += 4;
}

  static int RET_c(CPU cpu, int op)
  {
    if(getConditionalFlag(0b100 | ((op >> 3) & 0x7)))
    {
      cpu.pc = (getUByte(cpu.sp + 1) << 8) | getUByte(cpu.sp);
      cpu.sp += 2;
    }
    cpu.clocks += 4;
}

  static int HALT(CPU cpu)
  {
    cpu.halted = true;
  }

  static void LDH_FFnn(CPU cpu)
  {
    cpu.registers.a = getUByte(0xFF00 | nextUByte());
  }

  static int JR_c_e(CPU cpu, int op)
  {
    int e = nextByte();
    if(getConditionalFlag((op >> 3) & 0b111))
    {
      cpu.pc += e;
      cpu.clocks += 4;
      return;
    }
  }

  static int JP_c_nn(CPU cpu, int op)
  {
    int npc = nextUByte() | (nextUByte() << 8);

    if(getConditionalFlag(0b100 | ((op >> 3) & 0x7)))
    {
      cpu.pc = npc;
      cpu.clocks += 4;
      return;
    }
  }

  static void DAA(CPU cpu)
  {
    // TODO warning: this might be implemented wrong!
    /**
     * <code><pre>tmp := a,
     * if nf then
     *      if hf or [a ANcpu.registers.d 0x0f > 9] then tmp -= 0x06
     *      if cf or [a > 0x99] then tmp -= 0x60
     * else
     *      if hf or [a ANcpu.registers.d 0x0f > 9] then tmp += 0x06
     *      if cf or [a > 0x99] then tmp += 0x60
     * endif,
     * tmp => flags, cf := cf OR [a > 0x99],
     * hf := a.4 XOR tmp.4, a := tmp
     * </pre>
     * </code>
     * @see http://wikiti.brandonw.net/?title=Z80_Instruction_Set
     */
    
    int tmp = cpu.registers.a;

    if((cpu.registers.f & F_N) == 0)
    {
      if((cpu.registers.f & F_H) != 0 || ((tmp & 0x0f) > 9)) tmp += 0x06;
      if((cpu.registers.f & F_C) != 0 || ((tmp > 0x9f))) tmp += 0x60;
    } else
    {
      if((cpu.registers.f & F_H) != 0) tmp = ((tmp - 6) & 0xff);
      if((cpu.registers.f & F_C) != 0) tmp -= 0x60;
    }
    cpu.registers.f &= F_N | F_C;

    if(tmp > 0xff)
    {
      cpu.registers.f |= F_C;
      tmp &= 0xff;
    }

    if(tmp == 0) cpu.registers.f |= F_Z;

    cpu.registers.a = tmp;
  }

  static int JR_e(CPU cpu)
  {
    int e = nextByte();
    cpu.pc += e;
    cpu.clocks += 4;
}

  static void OR(CPU cpu, int n)
  {
    cpu.registers.a |= n;
    cpu.registers.f = 0;
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void OR_r(CPU cpu, int op)
  {
    OR(getRegister(op & 0b111) & 0xff);
  }

  static void OR_n(CPU cpu)
  {
    int n = nextUByte();
    OR(n);
  }

  static void XOR_r(CPU cpu, int op)
  {
    cpu.registers.a = (cpu.registers.a ^ getRegister(op & 0b111)) & 0xff;
    cpu.registers.f = 0;
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void AND_r(CPU cpu, int op)
  {
    cpu.registers.a = (cpu.registers.a & getRegister(op & 0b111)) & 0xff;
    cpu.registers.f = F_H;
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void ADC_r(CPU cpu, int op)
  {
    int carry = ((cpu.registers.f & F_C) != 0 ? 1 : 0);
    int reg = (getRegister(op & 0b111) & 0xff);

    int d = carry + reg;
    cpu.registers.f = 0;
    if((((cpu.registers.a & 0xf) + (reg & 0xf) + carry) & 0xF0) != 0) cpu.registers.f |= F_H;

    cpu.registers.a += d;
    if(cpu.registers.a > 0xFF)
    {
      cpu.registers.f |= F_C;
      cpu.registers.a &= 0xFF;
    }
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void ADD(CPU cpu, int n)
  {
    cpu.registers.f = 0;
    if((((cpu.registers.a & 0xf) + (n & 0xf)) & 0xF0) != 0) cpu.registers.f |= F_H;
    cpu.registers.a += n;
    if(cpu.registers.a > 0xFF)
    {
      cpu.registers.f |= F_C;
      cpu.registers.a &= 0xFF;
    }
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void ADD_r(CPU cpu, int op)
  {
    int n = getRegister(op & 0b111) & 0xff;
    ADD(n);
  }

  static void ADD_n(CPU cpu)
  {
    int n = nextUByte();
    ADD(n);
  }

  static void SUB(CPU cpu, int n)
  {
    cpu.registers.f = F_N;
    if((cpu.registers.a & 0xf) - (n & 0xf) < 0) cpu.registers.f |= F_H;
    cpu.registers.a -= n;
    if((cpu.registers.a & 0xFF00) != 0) cpu.registers.f |= F_C;
    cpu.registers.a &= 0xFF;
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void SUB_r(CPU cpu, int op)
  {
    int n = getRegister(op & 0b111) & 0xff;
    SUB(n);
  }

  static void SUB_n(CPU cpu)
  {
    int n = nextUByte();
    SUB(n);
  }

  static void SBC_n(CPU cpu)
  {
    int val = nextUByte();
    int carry = ((cpu.registers.f & F_C) != 0 ? 1 : 0);
    int n = val + carry;

    cpu.registers.f = F_N;
    if((cpu.registers.a & 0xf) - (val & 0xf) - carry < 0) cpu.registers.f |= F_H;
    cpu.registers.a -= n;
    if(cpu.registers.a < 0)
    {
      cpu.registers.f |= F_C;
      cpu.registers.a &= 0xff;
    }
    if(cpu.registers.a == 0) cpu.registers.f |= F_Z;
  }

  static void JP_HL(CPU cpu)
  {
    cpu.pc = cpu.registers.hl & 0xFFFF;
  }

  static void ADD_HL_rr(CPU cpu, int op)
  {
    /**
     * Z is not affected
     * cpu.registers.h is set if carry out of bit 11; reset otherwise
     * N is reset
     * cpu.registers.c is set if carry from bit 15; reset otherwise
     */
    int ss = getRegisterPair(RegisterPair.byValue[(op >> 4) & 0x3]);
    int hl = cpu.registers.hl;

    cpu.registers.f &= F_Z;

    if(((hl & 0xFFF) + (ss & 0xFFF)) > 0xFFF)
    {
      cpu.registers.f |= F_H;
    }

    hl += ss;

    if(hl > 0xFFFF)
    {
      cpu.registers.f |= F_C;
      hl &= 0xFFFF;
    }

    cpu.registers.hl =  hl;
  }

  static void CP(CPU cpu, int n)
  {
    cpu.registers.f = F_N;
    if(cpu.registers.a < n) cpu.registers.f |= F_C;
    if(cpu.registers.a == n) cpu.registers.f |= F_Z;
    if((cpu.registers.a & 0xf) < ((cpu.registers.a - n) & 0xf)) cpu.registers.f |= F_H;
  }

  static void CP_n(CPU cpu)
  {
    int n = nextUByte();
    CP(n);
  }

  static void CP_rr(CPU cpu, int op)
  {
    int n = getRegister(op & 0x7) & 0xFF;
    CP(n);
  }

  static void INC_rr(CPU cpu, int op)
  {
    RegisterPair pair = RegisterPair.byValue[(op >> 4) & 0x3];
    int o = getRegisterPair(pair) & 0xffff;
    setRegisterPair(pair, o + 1);
  }

  static void DEC_r(CPU cpu, int op)
  {
    int reg = (op >> 3) & 0x7;
    int a = getRegister(reg) & 0xff;

    cpu.registers.f = (cpu.registers.f & F_C) | Tables.DEC[a];

    a = (a - 1) & 0xff;

    setRegister(reg, a);
  }

  static void INC_r(CPU cpu, int op)
  {
    int reg = (op >> 3) & 0x7;
    int a = getRegister(reg) & 0xff;

    cpu.registers.f = (cpu.registers.f & F_C) | Tables.INC[a];

    a = (a + 1) & 0xff;

    setRegister(reg, a);
  }

  static void RLCA(CPU cpu)
  {
    bool carry = (cpu.registers.a & 0x80) != 0;
    cpu.registers.a <<= 1;
    cpu.registers.f = 0; // &= F_Z?

    if(carry)
    {
      cpu.registers.f |= F_C;
      cpu.registers.a |= 1;
    } else cpu.registers.f = 0;

    cpu.registers.a &= 0xff;
  }

  static int JP_nn(CPU cpu)
  {
    cpu.pc = (nextUByte()) | (nextUByte() << 8);
    cpu.clocks += 4;
  }

  static int RETI(CPU cpu)
  {
    cpu.interruptsEnabled = true;
    cpu.pc = (getUByte(cpu.sp + 1) << 8) | getUByte(cpu.sp);
    cpu.sp += 2;
    cpu.clocks += 4;
  }

  static int LD_a16_SP(CPU cpu)
  {
    int pos = ((nextUByte()) | (nextUByte() << 8));
    setByte(pos + 1, (cpu.sp & 0xFF00) >> 8);
    setByte(pos, (cpu.sp & 0x00FF));
  }

  static int POP_rr(CPU cpu, int op)
  {
    setRegisterPair2(RegisterPair.byValue[(op >> 4) & 0x3], getByte(cpu.sp + 1), getByte(cpu.sp));
    cpu.sp += 2;
  }

  static int PUSH_rr(CPU cpu, int op)
  {
    int val = cpu.registers.getRegisterPair((op >> 4) & 0x3);
    pushWord(val);
    cpu.clocks += 4;
  }
}