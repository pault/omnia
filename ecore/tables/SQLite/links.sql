CREATE TABLE links (
  from_node integer(20) NOT NULL DEFAULT '0',
  to_node integer(20) NOT NULL DEFAULT '0',
  linktype integer(20) NOT NULL DEFAULT '0',
  hits integer(20) DEFAULT '0',
  food integer(20) DEFAULT '0',
  PRIMARY KEY (from_node, to_node, linktype)
)