import packet, mysql_const, reader
import db_common

type
  ColumnDefinition41* = object
    catalog*: string
    schema*: string
    table*: string
    org_table*: string
    name*: string
    org_name*: string
    character_set*: uint16
    column_length*: uint32
    column_type*: FIELD_TYPES
    flags*: uint16
    decimals*: uint8

type
  OKData* = object
    affected_rows*: uint64
    last_insert_id*: uint64
    server_status_flags*: uint16
    num_of_warnings*: uint16

type
  ERRData* = object
    error_code*: uint16
    sql_state_marker*: string
    sql_state*: string
    error_message*: string

type
  EOFData* = object
    server_status_flags*: uint16
    num_of_warnings*: uint16

func is_ok_packet*(packet: Packet): bool =
  return packet[0] == 0x00 and packet.len >= 7

func read_ok_data*(packet: Packet): OKData =
  var reader = new_reader(packet)
  reader.read_skip(1)
  result.affected_rows = reader.read_length_encoded_integer()[0]
  result.last_insert_id = reader.read_length_encoded_integer()[0]
  result.server_status_flags = reader.read_int_2()
  result.num_of_warnings = reader.read_int_2()
  return result

func is_err_packet*(packet: Packet): bool =
  return packet[0] == 0xFF

func read_err_data*(packet: Packet): ERRData =
  var reader = new_reader(packet)
  reader.read_skip(1)
  result.error_code = reader.read_int_2()
  result.sql_state_marker = reader.read_fixed_length_string(1)
  result.sql_state = reader.read_fixed_length_string(5)
  result.error_message = reader.read_eof_string()
  return result

func is_eof_packet*(packet: Packet): bool =
  return packet[0] == 0xFE and packet.len < 9

func read_eof_data*(packet: Packet): EOFData =
  var reader = new_reader(packet)
  reader.read_skip(1)
  result.num_of_warnings = reader.read_int_2()
  result.server_status_flags = reader.read_int_2()
  return result

func read_column_count*(packet: Packet): uint64 =
  var reader = new_reader(packet)
  return reader.read_length_encoded_integer()[0]

func read_column_definition*(packet: Packet): ColumnDefinition41  =
  var reader = new_reader(packet)

  result.catalog = reader.read_length_encoded_string()[0]
  result.schema = reader.read_length_encoded_string()[0]
  result.table = reader.read_length_encoded_string()[0]
  result.org_table= reader.read_length_encoded_string()[0]
  result.name = reader.read_length_encoded_string()[0]
  result.org_name = reader.read_length_encoded_string()[0]

  let (fields_length, _) = reader.read_length_encoded_integer()
  if fields_length != 0x0C:
    dbError("length of fixed length fields is invalid")
  
  result.character_set = reader.read_int_2()
  result.column_length = reader.read_int_4()
  result.column_type = FIELD_TYPES(reader.read_int_1())
  result.flags = reader.read_int_2()
  result.decimals = reader.read_int_1()

  return result

type
  Row* = seq[string]

func read_text_resultset_row*(row_packet: Packet, column_count: uint64): Row =
  result.setlen(column_count)
  var reader = new_reader(row_packet)
  for i in 0..<column_count:
    let (str, _) = reader.read_length_encoded_string()
    result[i] = str
  return
