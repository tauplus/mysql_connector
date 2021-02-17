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
    server_status_flags*: uint16
    num_of_warnings*: uint16

type
  EOFData* = object
    server_status_flags*: uint16
    num_of_warnings*: uint16

func is_eof*(packet: Packet): bool =
  return packet[0] == 0xFE and packet.len < 9

proc read_eof_data*(packet: Packet): EOFData =

  var reader = new_reader(packet)

  result.server_status_flags = reader.read_int_2()

  # TODO: handle warnings
  result.num_of_warnings = reader.read_int_2()

proc read_column_definition*(packet: Packet): ColumnDefinition41  =
  var reader = new_reader(packet)
  var is_null: bool

  (result.catalog, is_null) = reader.read_length_encoded_string()
  (result.schema, is_null) = reader.read_length_encoded_string()
  (result.table, is_null) = reader.read_length_encoded_string()
  (result.org_table, is_null)= reader.read_length_encoded_string()
  (result.name, is_null) = reader.read_length_encoded_string()
  (result.org_name, is_null) = reader.read_length_encoded_string()

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

proc read_text_resultset_row*(row_packet: Packet, column_count: uint64): Row =
  result.setlen(column_count)
  var reader = new_reader(row_packet)
  for i in 0..<column_count:
    let (str, _) = reader.read_length_encoded_string()
    result[i] = str
  return
