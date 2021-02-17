import packet

type
  Reader* = object
    packet: Packet
    len: int
    next_read_pos: int

func new_reader*(packet: Packet): Reader =
  result.packet = packet
  result.len = packet.len()
  result.next_read_pos = 0
  return result

proc read_bytes*(reader: var Reader, len: int): Packet =
  result = reader.packet[reader.next_read_pos..<reader.next_read_pos+len]
  reader.next_read_pos += len
  return result

proc read_int_1*(reader: var Reader): uint8 =
  result = uint8(reader.packet[reader.next_read_pos])
  reader.next_read_pos += 1
  return result

proc read_int_2*(reader: var Reader): uint16 =
  result =
    uint16(reader.packet[reader.next_read_pos]) or
    uint16(reader.packet[reader.next_read_pos+1]).shl(8)
  reader.next_read_pos += 2
  return result

proc read_int_3*(reader: var Reader): uint32 =
  result =
    uint32(reader.packet[reader.next_read_pos]) or
    uint32(reader.packet[reader.next_read_pos+1]).shl(8) or
    uint32(reader.packet[reader.next_read_pos+2]).shl(16)
  reader.next_read_pos += 3
  return result

proc read_int_4*(reader: var Reader): uint32 =
  result =
    uint32(reader.packet[reader.next_read_pos]) or
    uint32(reader.packet[reader.next_read_pos+1]).shl(8) or
    uint32(reader.packet[reader.next_read_pos+2]).shl(16) or
    uint32(reader.packet[reader.next_read_pos+3]).shl(24)
  reader.next_read_pos += 4
  return result

proc read_int_6*(reader: var Reader): uint64 =
  result =
    uint64(reader.packet[reader.next_read_pos]) or
    uint64(reader.packet[reader.next_read_pos+1]).shl(8) or
    uint64(reader.packet[reader.next_read_pos+2]).shl(16) or
    uint64(reader.packet[reader.next_read_pos+3]).shl(24) or
    uint64(reader.packet[reader.next_read_pos+4]).shl(32) or
    uint64(reader.packet[reader.next_read_pos+5]).shl(40)
  reader.next_read_pos += 6
  return result

proc read_int_8*(reader: var Reader): uint64 =
  result =
    uint64(reader.packet[reader.next_read_pos]) or
    uint64(reader.packet[reader.next_read_pos+1]).shl(8) or
    uint64(reader.packet[reader.next_read_pos+2]).shl(16) or
    uint64(reader.packet[reader.next_read_pos+3]).shl(24) or
    uint64(reader.packet[reader.next_read_pos+4]).shl(32) or
    uint64(reader.packet[reader.next_read_pos+5]).shl(40) or
    uint64(reader.packet[reader.next_read_pos+6]).shl(48) or
    uint64(reader.packet[reader.next_read_pos+7]).shl(56)
  reader.next_read_pos += 8
  return result

proc read_length_encoded_integer*(reader: var Reader): (uint64, bool) =
  # https://github.com/go-sql-driver/mysql/pull/349
  if reader.len == reader.next_read_pos:
    return (0'u64, true)

  let pos = reader.next_read_pos

  case reader.packet[pos]:
    of 0xFB: # NULL
      reader.next_read_pos += 1
      return (0'u64, true)
    of 0xFC: # 251..<2^16
      reader.next_read_pos += 1
      let value = reader.read_int_2().uint64
      return (value, false)
    of 0xFD: # 2^16..<2^24
      reader.next_read_pos += 1
      let value = reader.read_int_3().uint64
      return (value, false)
    of 0xFE: # 2^24..<2^64
      reader.next_read_pos += 1
      let value = reader.read_int_8()
      return (value, false)
    else: # 0..250
      return (reader.read_int_1().uint64, false)

proc read_fixed_length_string*(reader: var Reader, len: int): string =
  result = newString(len)
  let pos = reader.next_read_pos
  for i in 0..<len:
    result[i] = reader.packet[pos+i].char()
  reader.next_read_pos += len

proc read_length_encoded_string*(reader: var Reader): (string, bool) =
  let (str_length, is_null) = read_length_encoded_integer(reader)
  result[0] = reader.read_fixed_length_string(str_length.int)
  result[1] = isNull
  return result

proc read_null_terminated_string*(reader: var Reader): string =
  var str_len: int
  for i in reader.next_read_pos..<reader.packet.len:
    if reader.packet[i] == 0x00:
      str_len = i - reader.next_read_pos
      break
  result = reader.read_fixed_length_string(str_len)
  reader.next_read_pos += 1
  return result