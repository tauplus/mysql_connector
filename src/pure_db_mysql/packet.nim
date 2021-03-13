import net

type
  Packet* = seq[byte]

proc new_packet*(len = 0.Natural): Packet =
  return Packet(newSeq[byte](len))

proc to_string*(packet: Packet): string =
  result = newString(len(packet))
  for i, b in packet:
    result[i] = char(b)

proc to_packet*(str: string): Packet =
  result = new_packet(str.len)
  for i in 0..<str.len:
    result[i] = str[i].byte
