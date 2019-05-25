import '../../emulator/cartridge/cartridge.dart';
import '../../emulator/memory/memory.dart';

/// The MMU (memory management unit) is used to access memory.
///
/// Depending on the cartridge type it may select different data sources and switch memory banks as required.
///
/// This is the base implementation that considers only a single ROM bank in the cartridge and a access to the system memory.
///
/// Interrupt Enable Register FF80 - FFFF
/// Internal RAM FF4C - FF80
/// Empty but unusable for I/O FF4C - FF80
/// I/O ports FEA0 - FF00 - FF4C
/// Empty but unusable for I/O FEA0 - FF00
/// Sprite Attrib Memory (OAM) FE00 - FEA0
/// Echo of 8kB Internal RAM E000 - FE00
/// 8kB Internal RAM C000 - E000
/// 8kB switchable RAM bank A000 - C000
/// 8kB Video RAM 8000 - A000
/// 16kB switchable ROM bank 4000 - 8000 (32kB Cartridge)
/// 16kB ROM bank #0 0000 - 4000
///
/// From address 0x0000 to index 0x00FF is the bootstrap code.
///
/// Address 0x100 until index 0x3FFF include the contents of the cartridge (depending on the cartridge size this memory bank can change totally)
class MMU
{
  /// Total memory addressable size
  static const ADDRESS_SIZE = 65536;

  /// Cartridge end address
  static const CARTRIDGE_ROM_END = 0x8000;

  /// Cartridge memory (contains booth RAM and ROM memory)
  Cartridge cartridge;

  /// On board game boy memory
  Memory memory;

  MMU(Cartridge cartridge)
  {
    this.cartridge = cartridge;

    this.memory = new Memory(ADDRESS_SIZE - CARTRIDGE_ROM_END);
  }

  /// Write a byte into memory
  void writeByte(int address, int value)
  {
    if(address < CARTRIDGE_ROM_END)
    {
      //throw 'Cannot write data into ROM memory.';
      return;
    }
    else
    {
      this.memory.writeByte(address - CARTRIDGE_ROM_END, value);
    }
  }

  /// Read a byte from memory
  int readByte(int address)
  {
    if(address < CARTRIDGE_ROM_END)
    {
      return this.cartridge.readByte(address);
    }
    else
    {
      return this.memory.readByte(address - CARTRIDGE_ROM_END);
    }
  }

  /// Read a register value, register values are mapped between FF00 to FFFF
  int readRegisterByte(int address)
  {
    return this.readByte(0xFF00 + address);
  }

  /// Read a register value, register values are mapped between FF00 to FFFF
  void writeRegisterByte(int address, int value)
  {
    this.writeByte(0xFF00 + address, value);
  }

  /// Reset the memory to default boot values.
  ///
  /// (Check page 17 and 18 of the GB CPU manual)
  void reset()
  {
    this.writeByte(0xFF04, 0xAB);
    this.writeByte(0xFF05, 0x00);
    this.writeByte(0xFF06, 0x00);
    this.writeByte(0xFF07, 0x00);
    this.writeByte(0xFF10, 0x80);
    this.writeByte(0xFF11, 0xBF);
    this.writeByte(0xFF12, 0xF3);
    this.writeByte(0xFF14, 0xBF);
    this.writeByte(0xFF16, 0x3F);
    this.writeByte(0xFF17, 0x00);
    this.writeByte(0xFF19, 0xBF);
    this.writeByte(0xFF1A, 0x7F);
    this.writeByte(0xFF1B, 0xFF);
    this.writeByte(0xFF1C, 0x9F);
    this.writeByte(0xFF1E, 0xBF);
    this.writeByte(0xFF20, 0xFF);
    this.writeByte(0xFF21, 0x00);
    this.writeByte(0xFF22, 0x00);
    this.writeByte(0xFF23, 0xBF);
    this.writeByte(0xFF24, 0x77);
    this.writeByte(0xFF25, 0xF3);
    this.writeByte(0xFF26, this.cartridge.superGameboy ? 0xF0 : 0xF1);
    this.writeByte(0xFF40, 0x91);
    this.writeByte(0xFF42, 0x00);
    this.writeByte(0xFF43, 0x00);
    this.writeByte(0xFF45, 0x00);
    this.writeByte(0xFF47, 0xFC);
    this.writeByte(0xFF48, 0xFF);
    this.writeByte(0xFF49, 0xFF);
    this.writeByte(0xFF4A, 0x00);
    this.writeByte(0xFF4B, 0x00);
    this.writeByte(0xFFFF, 0x00);
  }
}