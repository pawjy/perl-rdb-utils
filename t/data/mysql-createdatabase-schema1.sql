CREATE TABLE hoge1 (
  key1 INT UNSIGNED NOT NULL,
  PRIMARY KEY (key1)
);

CREATE TABLE hoge2 (
  key2 INT UNSIGNED NOT NULL,
  PRIMARY KEY (key2)
);

DROP TABLE hoge1;

INSERT INTO hoge1 (key1) VALUES (12345);
