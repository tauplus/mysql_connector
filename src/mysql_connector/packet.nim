import net

type
  Packet* = seq[byte]

func new_packet*(len = 0.Natural): Packet =
  return Packet(newSeq[byte](len))

func to_string*(packet: Packet): string =
  result = newString(len(packet))
  for i, b in packet:
    result[i] = char(b)

func to_packet*(str: string): Packet =
  result = new_packet(str.len)
  for i in 0..<str.len:
    result[i] = str[i].byte
