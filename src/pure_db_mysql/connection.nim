import net
import auth, packet, mysql_const, reader

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
  var reader = new_reader(payload)

  result.protocol_version = reader.read_int_1()
  #TODO: if protocol_version != 10, raise exception
  result.server_version = reader.read_null_terminated_string()
  result.thread_id = reader.read_int_4()
  let auth_plugin_data_part_1 = reader.read_bytes(8)
  result.filler = reader.read_int_1()
  let capability_flags_1 = reader.read_int_2().uint32
  result.character_set = reader.read_int_1()
  result.status_flags = reader.read_int_2()
  let capability_flags_2 = reader.read_int_2().uint32
  result.capability_flags = capability_flags_1 + capability_flags_2.shl(16)
  result.auth_plugin_data_len = reader.read_int_1()
  result.reserved = reader.read_bytes(10)
  let auth_plugin_data_part_2_len = max(13, int(result.auth_plugin_data_len) - 8)
  var auth_plugin_data_part_2 = reader.read_bytes(auth_plugin_data_part_2_len)
  if auth_plugin_data_part_2[^1] == 0x00:
    discard auth_plugin_data_part_2.pop()
  result.auth_plugin_data = auth_plugin_data_part_1 & auth_plugin_data_part_2

  if (result.capability_flags and CLIENT_PLUGIN_AUTH) == 0:
    return result

  result.auth_plugin_name = reader.read_null_terminated_string()

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

