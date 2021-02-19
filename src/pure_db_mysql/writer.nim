import db_common
import packet

type
  Writer* = Packet

func new_writer*(): Writer =
  return new_packet()

proc write_zero*(writer: var Writer, len: Natural) =
  writer.add( new_packet(len) )
  return

proc write_int_1*(writer: var Writer, val: uint8) =
  writer.add(byte(val))
  return

proc write_int_2*(writer: var Writer, val: uint16) =
  writer.add(byte(val))
  writer.add(byte(val shr 8))
  return

proc write_int_3*(writer: var Writer, val: uint32) =
  writer.add(byte(val))
  writer.add(byte(val shr 8))
  writer.add(byte(val shr 16))
  return

proc write_int_4*(writer: var Writer, val: uint32) =
  writer.add(byte(val))
  writer.add(byte(val shr 8))
  writer.add(byte(val shr 16))
  writer.add(byte(val shr 24))
  return

proc write_int_8*(writer: var Writer, val: uint64) =
  writer.add(byte(val))
  writer.add(byte(val shr 8))
  writer.add(byte(val shr 16))
  writer.add(byte(val shr 24))
  writer.add(byte(val shr 32))
  writer.add(byte(val shr 40))
  writer.add(byte(val shr 48))
  writer.add(byte(val shr 56))
  return

proc write_length_encoded_integer*(writer: var Writer, val: uint64) =
  if val < 251:
    writer.write_int_1(val.uint8)
  elif val < 1'u64.shl(16):
    writer.add(byte(0xFC))
    writer.write_int_2(val.uint16)
  elif val < 1'u64.shl(24):
    writer.add(byte(0xFD))
    writer.write_int_3(val.uint32)
  elif val < 1'u64.shl(64):
    writer.add(byte(0xFE))
    writer.write_int_8(val)
  else:
    dbError("Exceed uint64_max")

proc write_fixed_length_string*(writer: var Writer, str: string, len: Natural) =
  let writer_original_len = writer.len()
  if len != str.len():
    dbError("Fixed string length error")
  writer.setLen(writer_original_len + len)
  for i, c in str:
    writer[writer_original_len+i] = byte(c)
  return

proc write_null_terminated_string*(writer: var Writer, str: string) =
  let writer_original_len = writer.len()
  writer.setLen(writer_original_len + str.len() + 1)
  for i, c in str:
    writer[writer_original_len+i] = byte(c)
  writer[^1] = byte(0x00)
  return

proc write_length_encoded_string*(writer: var Writer, str: string) =
  writer.write_length_encoded_integer(str.len.uint64)
  writer.write_fixed_length_string(str, str.len())

