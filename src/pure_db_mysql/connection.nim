import net
import auth, packet, mysql_const

type Initial_handshake_v10* = object
  protocol_version*: uint8
  server_version*: string
  thread_id*: uint32
  auth_plugin_data*: Packet
  filler*: uint8
  capability_flags*: uint32
  character_set*: uint8
  status_flags*: uint16
  auth_plugin_data_len*: uint8
  reserved*: Packet
  auth_plugin_name*: string

proc read_initial_handshake_v10*(payload: Packet): Initial_handshake_v10 =
  result = Initial_handshake_v10()
  var next_start = 0

  result.protocol_version = uint8(payload[0])
  next_start += 1
  #TODO: if protocol_version != 10, raise exception

  var server_version_len: int
  for i, c in payload[1..<payload.len]:
    if c == 0x00:
      server_version_len = i
      break
  result.server_version = payload[1..server_version_len].to_string()
  next_start += server_version_len + 1

  result.thread_id = 
    uint32(payload[next_start]) or 
    uint32(payload[next_start+1]).shl(8) or 
    uint32(payload[next_start+2]).shl(16) or
    uint32(payload[next_start+3]).shl(24)
  next_start += 4

  let auth_plugin_data_part_1 = payload[next_start..<next_start+8]
  next_start += 8

  result.filler = uint8(payload[next_start])
  next_start += 1

  let capability_flags_1 = 
    uint32(payload[next_start]) or 
    uint32(payload[next_start+1]).shl(8)
  next_start += 2

  result.character_set = uint8(payload[next_start])
  next_start += 1

  result.status_flags = uint16(payload[next_start]) or uint16(
      payload[next_start+1]).shl(8)
  next_start += 2

  let capability_flags_2 = uint32(payload[next_start]).shl(16) or cast[
      uint32](payload[next_start+1]).shl(24)
  result.capability_flags = capability_flags_1 + capability_flags_2
  next_start += 2

  result.auth_plugin_data_len = uint8(payload[next_start])
  next_start += 1

  result.reserved = payload[next_start..<next_start+10]
  next_start += 10

  let auth_plugin_data_part_2_len = max(13, int(result.auth_plugin_data_len) - 8)
  var auth_plugin_data_part_2 = payload[
      next_start..<next_start+auth_plugin_data_part_2_len]
  if auth_plugin_data_part_2[^1] == 0x00:
    discard auth_plugin_data_part_2.pop()
  result.auth_plugin_data = auth_plugin_data_part_1 & auth_plugin_data_part_2
  next_start += auth_plugin_data_part_2_len

  if (result.capability_flags and CLIENT_PLUGIN_AUTH) == 0:
    return result

  var auth_plugin_name_len: int
  for i, c in payload[next_start..<payload.len]:
    if c == 0x00:
      auth_plugin_name_len = i
      break
  result.auth_plugin_name = payload[next_start..<next_start+auth_plugin_name_len].to_string()
  next_start += auth_plugin_name_len + 1

  return result

proc make_handshake_response_41*(hand_shake: Initial_handshake_v10, user, password: string): Packet =

  var pos: int

  var client_flag: uint32
  client_flag = CLIENT_PROTOCOL_41 or
                CLIENT_TRANSACTIONS or
                CLIENT_PLUGIN_AUTH or
                CLIENT_MULTI_RESULTS

  let packet_init_size = 4 + 4 + 4 + 1 + 23
  result.setLen(packet_init_size)

  result[3] = 0x01

  pos = 8

  result[pos] = 0x00
  result[pos+1] = 0x00
  result[pos+2] = 0x00
  result[pos+3] = 0x00
  pos += 4

  result[pos] = 0xFF
  pos += 1

  # filler
  pos += 23

  result.setLen(result.len + user.len + 1)
  for i, x in user:
    result[pos+i] = byte(x)
  pos += user.len + 1

  let auth_response = 
    if password == "":
      new_packet()
    else:
      auth_mysql_native_password(password, hand_shake.auth_plugin_data.to_string())
  let auth_response_length = auth_response.len
  result.add(byte(auth_response_length))
  result.add(auth_response)
  pos += 1 + auth_response_length

  for i, x in hand_shake.auth_plugin_name:
    result.add(byte(x))
  result.add(0x00)
  pos += hand_shake.auth_plugin_name.len + 1

  result[4] = byte(client_flag)
  result[5] = byte(client_flag shr 8)
  result[6] = byte(client_flag shr 16)
  result[7] = byte(client_flag shr 24)
  
  return result

