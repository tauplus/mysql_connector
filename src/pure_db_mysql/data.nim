import packet, mysql_const
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
  var pos = 1

  result.server_status_flags = uint16(packet[pos]) or uint16(packet[pos+1]).shl(8)
  pos += 2

  # TODO: handle warnings
  result.num_of_warnings = uint16(packet[pos]) or uint16(packet[pos+1]).shl(8)
  pos += 2
  if pos != packet.len:
    dbError("process eof error")

proc read_column_definition*(packet: Packet): ColumnDefinition41  =
  var packet_pos = 0

  let (catalog, _, catalog_size) = read_length_encoded_string(packet[packet_pos..^1])
  result.catalog = catalog
  packet_pos += catalog_size

  let (schema, _, schema_size) = read_length_encoded_string(packet[packet_pos..^1])
  result.schema = schema
  packet_pos += schema_size

  let (table, _, table_size) = read_length_encoded_string(packet[packet_pos..^1])
  result.table = table
  packet_pos += table_size

  let (org_table, _, org_tablesize) = read_length_encoded_string(packet[packet_pos..^1])
  result.org_table = org_table
  packet_pos += org_table_size

  let (name, _, name_size) = read_length_encoded_string(packet[packet_pos..^1])
  result.name = name
  packet_pos += name_size

  let (org_name, _, org_name_size) = read_length_encoded_string(packet[packet_pos..^1])
  result.org_name = org_name
  packet_pos += org_name_size

  let ( fields_length, _, _ ) = read_length_encoded_integer(packet[packet_pos..^1])
  if fields_length != 0x0C:
    dbError("length of fixed length fields is invalid")
  packet_pos += 1
  
  result.character_set = 
    uint16(packet[packet_pos]) or 
    uint16(packet[packet_pos+1]).shl(8)
  packet_pos += 2

  result.column_length = 
    uint32(packet[packet_pos]) or 
    uint32(packet[packet_pos+1]).shl(8) or 
    uint32(packet[packet_pos+2]).shl(16) or
    uint32(packet[packet_pos+3]).shl(24)
  packet_pos += 4

  result.column_type = FIELD_TYPES(packet[packet_pos])
  packet_pos += 1

  result.flags = 
    uint16(packet[packet_pos]) or 
    uint16(packet[packet_pos+1]).shl(8)
  packet_pos += 2

  result.decimals = uint8(packet[packet_pos])
  packet_pos += 1

  return result

type
  Row* = seq[string]

proc read_text_resltset_row*(row_packet: Packet, column_count: uint64): Row =
  result.setlen(column_count)
  var row_packet_pos = 0
  for i in 0..<column_count:
    let (str, _, read_size) = read_length_encoded_string(row_packet[row_packet_pos..^1])
    result[i] = str
    row_packet_pos += read_size
  return