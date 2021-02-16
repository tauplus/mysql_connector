import unittest

import pure_db_mysql
import pure_db_mysql/packet
import pure_db_mysql/reader

test "connect":
  var db = db_open("localhost", 3306, "no_password_user", "")
  defer: db.db_close()

  echo db.get_all_rows(sql"SELECT * FROM test.user")

test "reader":
  var packet = new_packet(40000)
  packet[0] = 1
  echo packet[0].addr.repr
  var reader = new_reader(packet)
  packet[0] = 2
  echo reader.packet[0].addr.repr

