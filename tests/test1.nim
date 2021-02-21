import unittest
import os

import pure_db_mysql

suite "db test":

  echo "suite setup: run once before the tests"
  
  setup:
    var db_setup: DB_conn
    var try_count = 0
    var success = false
    while true:
      try:
        db_setup = db_open("127.0.0.1:3306", "nim", "nim", "test")
        success = true
      except:
        try_count += 1
        sleep(1*1000)
        echo "retry", try_count
      if success:
        break
      elif try_count > 120:
        raise newException(IOError, "connect mysql error")
    defer: db_setup.db_close()
  
  test "get all rows":
    var db = db_open("127.0.0.1:3306", "nim", "nim", "test")
    defer: db.db_close()

    let drop_sql = 
      sql"""DROP TABLE IF EXISTS `user`"""
    let create_sql = sql"""
      CREATE TABLE IF NOT EXISTS `user` (
      `id` int NOT NULL,
      `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '',
      PRIMARY KEY (`id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"""

    db.exec(drop_sql)
    db.exec(create_sql)

    let insert_args = @[@["1","Tom"],@["2","Jay"]]

    for insert_arg in insert_args:
      db.exec(sql"INSERT INTO user VALUES (?, ?)", insert_arg)
    let rows = db.get_all_rows(sql"SELECT * FROM user ORDER BY id")
    check( rows == insert_args )

  test "escape string":
    let str =  "\0\'\"\n\r\26\\"
    check(str.escape_string() == "\'\\0\\'\\\"\\n\\r\\Z\\\\\'")
    check(str.quote_string() == "\'\0''\"\n\r\26\\\'")