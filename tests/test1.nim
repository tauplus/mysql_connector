import unittest

import pure_db_mysql

test "connect":
  var db = db_open("localhost", 3306, "no_password_user", "")
  defer: db.db_close()

  echo db.get_all_rows(sql"SELECT * FROM test.user")

