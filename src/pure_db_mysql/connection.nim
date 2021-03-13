import net, db_common
import auth, packet, mysql_const, reader, writer, rsa_encrypt

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

  return result

proc make_handshake_response_41*(hand_shake: Initial_handshake_v10, user, password: string, database = ""): Packet =

  result = new_writer(4)

  var client_flag: uint32
  client_flag = CLIENT_PROTOCOL_41 or
                CLIENT_TRANSACTIONS or
                CLIENT_PLUGIN_AUTH or
                CLIENT_MULTI_RESULTS or
                CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA 

  if database.len != 0:
    client_flag = client_flag or CLIENT_CONNECT_WITH_DB 

  result.write_int_4(client_flag)
  result.write_zero(4)

  result.write_int_1(0xFF)

  # filler
  result.write_zero(23)

  result.write_null_terminated_string(user)

  let auth_response = 
    if password == "":
      new_packet()
    elif hand_shake.auth_plugin_name == "mysql_native_password":
      auth_mysql_native_password(password, hand_shake.auth_plugin_data.to_string())
    elif hand_shake.auth_plugin_name == "caching_sha2_password":
      auth_caching_sha2_password(password, hand_shake.auth_plugin_data.to_string())
    else: 
      dbError("Unsupported auth_plugin")
  result.write_length_encoded_integer(auth_response.len.uint64)
  result.add(auth_response)

  if database.len != 0:
    result.write_null_terminated_string(database)

  result.write_null_terminated_string(hand_shake.auth_plugin_name)

  return result
  
func make_encypted_password_packet*(password: string, auth_plugin_data: Packet, publickey_packet: Packet): Packet =
  let pem_str = publickey_packet[1..^1].to_string()
  let encrypted_password = rsa_publickey_encrypt(password, auth_plugin_data.to_string(), pem_str)
  result = new_writer(4)
  result.write_fixed_length_string(encrypted_password, encrypted_password.len)
  return result

proc read_auth_switch_request*(payload: Packet): (string, Packet) =
  # https://dev.mysql.com/doc/dev/mysql-server/8.0.23/page_protocol_connection_phase_packets_protocol_auth_switch_request.html
  var reader = new_reader(payload)
  reader.read_skip(1)
  let plugin_name = reader.read_null_terminated_string()
  var plugin_data = reader.read_eof_string().to_packet()
  if plugin_data[^1] == 0x00:
    discard plugin_data.pop()
  return (plugin_name, plugin_data)

proc make_auth_switch_response*(password, plugin_name: string, plugin_data: Packet): Packet =
  let auth_response = 
    if password == "":
      new_packet()
    elif plugin_name == "mysql_native_password":
      auth_mysql_native_password(password, plugin_data.to_string())
    elif plugin_name == "caching_sha2_password":
      auth_caching_sha2_password(password, plugin_data.to_string())
    else: 
      dbError("Unsupported auth_plugin")

  result = new_writer(4)
  result.write_fixed_length_string(auth_response.to_string, auth_response.len)