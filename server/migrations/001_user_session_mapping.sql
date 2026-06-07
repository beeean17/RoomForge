CREATE TABLE users (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  firebase_uid VARCHAR2(128) NOT NULL,
  email VARCHAR2(320),
  display_name VARCHAR2(255),
  role VARCHAR2(32) DEFAULT 'user' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT uq_users_firebase_uid UNIQUE (firebase_uid),
  CONSTRAINT ck_users_role CHECK (role IN ('user', 'admin'))
);

CREATE INDEX idx_users_email ON users (email);
