# Install

```bash
nimble install https://github.com/tauplus/pure_db_mysql.git
```

# Note

This library supports `mysql_native_password` only.

# Example

```nim
import pure_db_mysql

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