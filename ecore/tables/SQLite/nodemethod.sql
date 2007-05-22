CREATE TABLE nodemethod (
  nodemethod_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  supports_nodetype integer(20) NOT NULL DEFAULT '0',
  code text NOT NULL DEFAULT ''
)