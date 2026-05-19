CREATE TABLE room_projects (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id NUMBER NOT NULL,
  name VARCHAR2(120) NOT NULL,
  description VARCHAR2(1000),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE,
  CONSTRAINT fk_room_projects_user
    FOREIGN KEY (user_id)
    REFERENCES users (id),
  CONSTRAINT ck_room_projects_name_not_blank
    CHECK (LENGTH(TRIM(name)) > 0)
);

CREATE INDEX idx_room_projects_user_id ON room_projects (user_id);
CREATE INDEX idx_room_projects_user_updated ON room_projects (user_id, updated_at);
