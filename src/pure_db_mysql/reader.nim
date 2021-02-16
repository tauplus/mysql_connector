import packet

type
  Reader* = object
    packet*: ref Packet
    next_read_pos: int

proc new_reader*(packet:var Packet, start_pos = 0): Reader =
  new(result.packet)
  echo packet[0].addr.repr
  result.packet[] = packet
  echo result.packet[0].addr.repr

  result.next_read_pos = start_pos