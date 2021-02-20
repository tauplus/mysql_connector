import net, db_common
import auth, packet, mysql_const, reader, writer

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
  if result.protocol_version != 10:
    dbError("This library supports protocol_version 10 only")
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
  if result.auth_plugin_name != "mysql_native_password":
    dbError("this library supports mysql_native_password only")

  return result

proc make_handshake_response_41*(hand_shake: Initial_handshake_v10, user, password: string, database = ""): Packet =

  var writer = new_writer()

  var client_flag: uint32
  client_flag = CLIENT_PROTOCOL_41 or
                CLIENT_TRANSACTIONS or
                CLIENT_PLUGIN_AUTH or
                CLIENT_MULTI_RESULTS or
                CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA 

  if database.len != 0:
    client_flag = client_flag or CLIENT_CONNECT_WITH_DB 

  # result[3] = 0x01
  writer.write_zero(4)
  writer.write_int_4(client_flag)
  writer.write_zero(4)

  writer.write_int_1(0xFF)

  # filler
  writer.write_zero(23)

  writer.write_null_terminated_string(user)

  let auth_response = 
    if password == "":
      new_packet()
    else:
      auth_mysql_native_password(password, hand_shake.auth_plugin_data.to_string())
  writer.write_length_encoded_integer(auth_response.len.uint64)
  writer.add(auth_response)

  if database.len != 0:
    writer.write_null_terminated_string(database)

  writer.write_null_terminated_string(hand_shake.auth_plugin_name)
  
  return writer

