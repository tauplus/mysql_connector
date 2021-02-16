import net
import pure_db_mysql/[
  connector,
  data,
  packet,
  mysql_const
]

import db_common
export db_common


proc db_open*(host: string, port = DEFAULT_MYSQL_PORT, user,
    password: string): DbConn =
  return connect(host, Port(port), user, password)

proc db_close*(db_conn: var DbConn) =
  db_conn.disconnect()

  return

proc get_all_rows*(db_conn: var DbConn, sql: SqlQuery): seq[Row] =
  var query: Packet
  query.setLen(HEADER_SIZE)

  query.add(COM_QUERY.byte)
  for c in sql.string:
    query.add(byte(c))


  let query_len = query.len - HEADER_SIZE
  query[0] = byte(query_len)

  db_conn.sequence_id = 0'u8
  send_packet(db_conn, query)

  let column_count = db_conn.recv_packet().read_length_encoded_integer()[0]
  echo "column_count:", column_count

  var column_definitions = newSeq[ColumnDefinition41](column_count)
  for i in 0..<column_count:
    let column_def_packet = db_conn.recv_packet()
    column_definitions[i] = read_column_definition(column_def_packet)

  echo column_definitions

  let response = db_conn.recv_packet()
  if not response.is_eof():
    dbError("read connection ok error")

  while true:
    var row_packet = db_conn.recv_packet()
    if row_packet.is_eof():
      let eof_data = read_eof_data(row_packet)
      db_conn.server_status_flags = eof_data.server_status_flags
      break
    let row = read_text_resltset_row(row_packet, column_count)
    result.add(row)

