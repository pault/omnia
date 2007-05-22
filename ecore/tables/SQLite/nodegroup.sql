CREATE TABLE nodegroup (
  nodegroup_id integer NOT NULL,
  rank integer(20) NOT NULL DEFAULT '0',
  node_id integer(20) NOT NULL DEFAULT '0',
  orderby integer(20),
  PRIMARY KEY (nodegroup_id, rank)
)