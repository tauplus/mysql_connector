import net, db_common
when defined(logging_mysql_connector):
  import logging
import mysql_const, connection, packet, data

type DbConn* = object
  socket*: Socket
  sequence_id*: uint8
  server_status_flags*: uint16

proc connect_mysql_socket(db_conn:var DbConn, host: string, port: Port) =
  let socket = newSocket()
  socket.connect(host, port)
  db_conn.socket = socket
  db_conn.sequence_id = 0
  return

proc recv_packet*(db_conn:var DbConn): Packet =

  result = new_packet()

  while true:
    var header = new_packet(HEADER_SIZE)
    let header_read_size = recv(db_conn.socket, header[0].addr, HEADER_SIZE)
    if header_read_size != HEADER_SIZE: dbError("read packet header error")

    when defined(logging_mysql_connector):
      log(lvlDebug, "recv packet sequence_id:", uint8(header[3]))
    if uint8(header[3]) != db_conn.sequence_id: dbError("packet sequence is wrong")
    db_conn.sequence_id.inc(1)

    let payload_length = 
      uint32(header[0]) or
      uint32(header[1]).shl(8) or
      uint32(header[2]).shl(16)
    when defined(logging_mysql_connector):
      log(lvlDebug, "recv packet payload_length:", payload_length)
    if payload_length == 0: break
    var payload = new_packet(payload_length)
    var payload_read_size = recv(db_conn.socket, payload[0].addr, int(payload_length))
    if payload_read_size != int(payload_length): dbError("read packet payload error")
    when defined(logging_mysql_connector) and defined(logging_mysql_packet):
      log(lvlDebug, "recv packet payload:", payload)

    result.add(payload)
    if payload_length != MAX_PACKET_SIZE: break

  return result

proc send_packet*(db_conn:var DbConn, packet:var Packet) =

  var packet_length = packet.len - HEADER_SIZE
  var payload_length: int

  while true:
    if packet_length >= MAX_PACKET_SIZE.int:
      payload_length = MAX_PACKET_SIZE.int
      packet[0] = 0xFF
      packet[1] = 0xFF
      packet[2] = 0xFF
    else:
      payload_length = packet_length
      packet[0] = byte(payload_length)
      packet[1] = byte(payload_length shr 8)
      packet[2] = byte(payload_length shr 16)

    packet[3] = byte(db_conn.sequence_id)

    when defined(logging_mysql_connector):
      log(lvlDebug, "send packet sequence_id:", db_conn.sequence_id)
      log(lvlDebug, "send packet payload_length:", payload_length)
      when defined(logging_mysql_packet):
        log(lvlDebug, "send packet:", packet)

    discard send(db_conn.socket, packet[0].addr, payload_length + HEADER_SIZE)
    db_conn.sequence_id.inc(1)

    if payload_length != MAX_PACKET_SIZE.int:
      return

    packet_length -= payload_length
    packet = packet[payload_length..^1]

  return

proc connect*(host: string, port: Port, user, password: string, database = ""): DbConn =
  var db_conn = DBConn()
  db_conn.connect_mysql_socket(host, port)
  let payload = recv_packet(db_conn)
  let initial_handshake = read_initial_handshake_v10(payload)
  when defined(logging_mysql_connector):
    log(lvlDebug, "initial_handshake:", initial_handshake)

  var handshake_response = make_handshake_response_41(initial_handshake, user, password, database)
  send_packet(db_conn, handshake_response)

  var response = recv_packet(db_conn)
  if response.is_ok_packet():
    let ok_data = read_ok_data(response)
    db_conn.server_status_flags = ok_data.server_status_flags
    return db_conn
  
  var plugin_name = initial_handshake.auth_plugin_name
  var plugin_data = initial_handshake.auth_plugin_data
  if response.len > 0 and response[0] == 0xFE:
    (plugin_name, plugin_data) = read_auth_switch_request(response)
    var auth_switch_response = make_auth_switch_response(password, plugin_name, plugin_data)
    send_packet(db_conn, auth_switch_response)
    response = recv_packet(db_conn)
    if response.is_ok_packet():
      let ok_data = read_ok_data(response)
      db_conn.server_status_flags = ok_data.server_status_flags
      return db_conn

  if plugin_name == "caching_sha2_password":
    if response.len != 2:
      dbError("unexpected respose")
    elif response[0] == 0x01:
      # https://insidemysql.com/preparing-your-community-connector-for-mysql-8-part-2-sha256/
      case response[1]:
        of CACHING_SHA2_FAST_AUTH_SUCCESS.byte:
          let more_response = recv_packet(db_conn)
          if more_response.is_ok_packet():
            let ok_data = read_ok_data(more_response)
            db_conn.server_status_flags = ok_data.server_status_flags
            return db_conn
          else:
            dbError("unexpected respose")
        of CACHING_SHA2_PERFORM_FULL_AUTHENTICATION.byte:
          var pubkey_req_packet = new_packet(5)
          pubkey_req_packet[4] = CACHING_SHA2_REQUEST_PUBLIC_KEY.byte
          send_packet(db_conn, pubkey_req_packet)
          let pubkey_respose = recv_packet(db_conn)
          var encrypted_password_packet = make_encypted_password_packet(password, plugin_data, pubkey_respose)
          send_packet(db_conn, encrypted_password_packet)
          let pubkey_respose2 = recv_packet(db_conn)
          if pubkey_respose2.is_ok_packet():
            let ok_data = read_ok_data(pubkey_respose2)
            db_conn.server_status_flags = ok_data.server_status_flags
            return db_conn
          elif pubkey_respose2.is_err_packet():
            let err_data = read_err_data(pubkey_respose2)
            dbError(err_data.error_message)
          else:
            dbError("unexpected respose")
        else:
          dbError("unexpected respose")
  dbError("unexpected respose")

proc disconnect*(db_conn:var DbConn) =

  var packet = new_packet(5)

  packet[4] = COM_QUIT.byte
  
  db_conn.sequence_id = 1
  send_packet(db_conn, packet)

  db_conn.socket.close()
  
  return