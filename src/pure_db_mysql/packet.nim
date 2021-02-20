import net

type
  Packet* = seq[byte]

proc new_packet*(len = 0.Natural): Packet =
  return Packet(newSeq[byte](len))

proc to_string*(packet: Packet): string =
  result = newString(len(packet))
  for i, b in packet:
    result[i] = char(b)

proc read_length_encoded_integer*(packet: Packet): (uint64, bool, int) =

  # https://github.com/go-sql-driver/mysql/pull/349
  if packet.len == 0:
    return (0'u64, true, 0)

  case packet[0]:
    of 0xFB: # NULL
      return (0'u64, true, 1)
    of 0xFC: # 251..<2^16
      let value =
        uint64(packet[1]) or
        uint64(packet[2]).shl(8)
      return (value, false, 3)
    of 0xFD: # 2^16..<2^24
      let value =
        uint64(packet[1]) or
        uint64(packet[2]).shl(8) or
        uint64(packet[3]).shl(16)
      return (value, false, 4)
    of 0xFE: # 2^24..<2^64
      let value =
        uint64(packet[1]) or
        uint64(packet[2]).shl(8) or
        uint64(packet[3]).shl(16) or
        uint64(packet[4]).shl(24) or
        uint64(packet[5]).shl(32) or
        uint64(packet[6]).shl(40) or
        uint64(packet[7]).shl(48) or
        uint64(packet[8]).shl(56)
      return (value, false, 9)
    else: # 0..250
      return (uint64(packet[0]), false, 1)

proc read_length_encoded_string*(packet: Packet): (string, bool, int) =
  let (str_length, is_null, read_size) = read_length_encoded_integer(packet[0..^1])
  result[0] = packet[read_size..<read_size+str_length.int].to_string()
  result[1] = isNull
  result[2] = read_size + str_length.int
  return result
