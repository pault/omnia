CREATE TABLE nodelet (
  nodelet_id INTEGER PRIMARY KEY NOT NULL,
  nltext text,
  nlcode text,
  parent_container integer(20),
  lastupdate integer(20) NOT NULL DEFAULT '0',
  updateinterval integer(20) NOT NULL DEFAULT '0',
  mini_nodelet integer(20) NOT NULL DEFAULT '0'
)