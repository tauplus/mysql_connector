import net, strutils
import pure_db_mysql/[
  connector,
  data,
  packet,
  mysql_const
]

import db_common
export db_common
export connector.DbConn

proc db_open*(host: string, user, password: string, database = ""): DbConn =

  var host_address: string
  var host_port = Port(DEFAULT_MYSQL_PORT)

  let colon_pos = host.find(':') 
  if colon_pos == -1:
    host_address = host
  else:
    host_address = host[0..<colon_pos]
    host_port = Port(host[colon_pos+1..^1].parse_uint)

  return connect(host_address, host_port, user, password, database)

proc db_close*(db_conn: var DbConn) =
  db_conn.disconnect()
  return

proc escape_string*(str: string): string =
  # https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
  # https://github.com/mysql/mysql-server/blob/8.0/mysys/charset.cc#L758
  result = newStringOfCap(str.len+2)
  result.add('\'')
  for c in str:
    case c:
      of '\0':
        result.add("\\0")
      of '\'':
        result.add("\\'")
      of '\"':
        result.add("\\\"")
      of '\n':
        result.add("\\n")
      of '\r':
        result.add("\\r")
      of '\26':
        result.add("\\Z")
      of '\\':
        result.add("\\\\")
      else:
        result.add(c)
  result.add('\'')
  return

proc quote_string*(str: string): string =
  # https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html#sqlmode_no_backslash_escapes
  result = newStringOfCap(str.len+2)
  result.add('\'')
  for c in str:
    if c == '\'':
      result.add("''")
    else:
      result.add(c)
  result.add('\'')
  return

proc query_exec(db_conn: var DbConn, sql: SqlQuery, args: varargs[string, `$`]) =
  var query_packet: Packet
  query_packet.setLen(HEADER_SIZE)
  query_packet.add(COM_QUERY.byte)

  var arg_idx = 0
  for c in sql.string:
    if c == '?':
      let replacing_str = 
        if (db_conn.server_status_flags and SERVER_STATUS_NO_BACKSLASH_ESCAPES) == 0:
          args[arg_idx].escape_string()
        else:
          args[arg_idx].quote_string()
      for rc in replacing_str:
        query_packet.add(byte(rc))
      arg_idx += 1
    else:
      query_packet.add(byte(c))

  db_conn.sequence_id = 0'u8
  send_packet(db_conn, query_packet)
  return

proc exec*(db_conn: var DbConn, sql: SqlQuery, args: varargs[string, `$`]) =
  query_exec(db_conn, sql, args)

  let response = db_conn.recv_packet()
  if response.is_err_packet():
    let err_data = read_err_data(response)
    dbError(err_data.error_message)

  if response.is_ok_packet():
    let ok_data = response.read_ok_data()
    echo ok_data
  else:
    dbError("exec error")


proc get_all_rows*(db_conn: var DbConn, sql: SqlQuery, args: varargs[string, `$`]): seq[Row] =

  query_exec(db_conn, sql, args)

  let column_count_packet = db_conn.recv_packet()
  if column_count_packet.is_err_packet():
    let err_data = read_err_data(column_count_packet)
    dbError(err_data.error_message)
  let column_count = column_count_packet.read_length_encoded_integer()[0]
  echo "column_count:", column_count

  var column_definitions = newSeq[ColumnDefinition41](column_count)
  for i in 0..<column_count:
    let column_def_packet = db_conn.recv_packet()
    column_definitions[i] = read_column_definition(column_def_packet)

  echo column_definitions

  let response = db_conn.recv_packet()
  if not response.is_eof_packet():
    dbError("read result error")

  while true:
    var row_packet = db_conn.recv_packet()
    if row_packet.is_eof_packet():
      let eof_data = read_eof_data(row_packet)
      db_conn.server_status_flags = eof_data.server_status_flags
      break
    let row = read_text_resultset_row(row_packet, column_count)
    result.add(row)

