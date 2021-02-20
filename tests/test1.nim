import unittest

import pure_db_mysql

test "get all rows":
  var db = db_open("localhost:3306", "nim", "nim", "test")
  defer: db.db_close()

  echo db.get_all_rows(sql"SELECT * FROM user WHERE `name` = ?", "42")

test "escape string":
  let str =  "\0\'\"\n\r\26\\"
  check(str.escape_string() == "\'\\0\\'\\\"\\n\\r\\Z\\\\\'")
  check(str.quote_string() == "\'\0''\"\n\r\26\\\'")