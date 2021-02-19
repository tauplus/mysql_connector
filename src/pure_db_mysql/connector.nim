import net, db_common
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

    echo "recv sequence_id:", uint8(header[3])
    if uint8(header[3]) != db_conn.sequence_id: dbError("packet sequence is wrong")
    db_conn.sequence_id.inc(1)

    let payload_length = 
      uint32(header[0]) or
      uint32(header[1]).shl(8) or
      uint32(header[2]).shl(16)
    echo "payload_length:", payload_length
    if payload_length == 0: break
    var payload = new_packet(payload_length)
    var payload_read_size = recv(db_conn.socket, payload[0].addr, int(payload_length))
    if payload_read_size != int(payload_length): dbError("read packet payload error")

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

    echo "send sequence_id:", db_conn.sequence_id
    echo "send length:",payload_length

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
  echo initial_handshake.repr

  var handshake_response = make_handshake_response_41(initial_handshake, user, password, database)
  send_packet(db_conn, handshake_response)

  let response = recv_packet(db_conn)
  if response.is_ok_packet():
    let ok_data = read_ok_data(response)
    discard ok_data
  return db_conn

proc disconnect*(db_conn:var DbConn) =

  var packet = new_packet(5)

  packet[4] = COM_QUIT.byte
  
  db_conn.sequence_id = 1
  send_packet(db_conn, packet)

  db_conn.socket.close()
  
  return