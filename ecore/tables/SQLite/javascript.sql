CREATE TABLE javascript (
  javascript_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  code text NOT NULL DEFAULT '',
  comment text DEFAULT '',
  dynamic integer(20) NOT NULL DEFAULT '0'
)