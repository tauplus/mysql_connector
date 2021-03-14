# About mysql_connector

This library is MySQL Connector written in ~~pure~~(OpenSSL is required) Nim.  
(Nim standard library [`db_mysql`](https://nim-lang.org/docs/db_mysql.html) is impure and needs installation of MySQL client library.)

# Install

```bash
nimble install https://github.com/tauplus/mysql_connector.git
```

# Note

Supported auth plugins
- caching_sha2_password
- mysql_native_password

# Example

```nim
import mysql_connector

proc main()=
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

  let insert_args = 
    @[
      @["1","Tom"],
      @["2","Jay"],
      @["3","Ann"]
    ]

  for insert_arg in insert_args:
    db.exec(sql"INSERT INTO user VALUES (?, ?)", insert_arg)
  let rows = db.get_all_rows(sql"SELECT * FROM user WHERE id >= ? ORDER BY id", 2)

  echo rows

main()
```

## result

```bash
@[@["2", "Jay"], @["3", "Ann"]]
```