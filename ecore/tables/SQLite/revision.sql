CREATE TABLE revision (
  node_id integer(20) NOT NULL DEFAULT '0',
  inside_workspace integer(20) NOT NULL DEFAULT '0',
  revision_id integer(20) NOT NULL DEFAULT '0',
  xml text NOT NULL,
  tstamp timestamp,
  PRIMARY KEY (node_id, inside_workspace, revision_id)
)