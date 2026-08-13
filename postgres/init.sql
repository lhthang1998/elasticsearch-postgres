CREATE TABLE IF NOT EXISTS book (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    year        INTEGER
);

ALTER TABLE book REPLICA IDENTITY FULL;


CREATE TABLE IF NOT EXISTS author (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    biography   TEXT,
    country     TEXT
);

ALTER TABLE book REPLICA IDENTITY FULL;


-- Sample
INSERT INTO book (name, description, year) VALUES
('Tôi thấy hoa vàng trên cỏ xanh', 'Tiểu thuyết của Nguyễn Nhật Ánh về tuổi thơ miền quê', 2010),
('Nhà giả kim', 'Hành trình tìm kiếm kho báu và ý nghĩa cuộc đời của Santiago', 1988),
('Đắc nhân tâm', 'Cuốn sách kinh điển về nghệ thuật giao tiếp và ứng xử', 1936)
('Sapiens: Lược sử loài người', 'Khám phá lịch sử tiến hóa và xã hội loài người', 2011),
('Clean code', 'A handbook of agile software craftmanship by Rober C.Martin', 2008);

INSERT INTO author (name, biography, country) VALUES
('Nguyễn Nhật Ánh', 'Nhà văn Việt Nam nổi tiếng với các tác phẩm về tuổi thơ và tuổi mới lớn', 'Việt Nam'),
('Paulo Coelho', 'Nhà văn Brazil, tác giả của Nhà giả kim', 'Brazil'),
('Dale Carnegie', 'Tác giả người Mỹ về phát triển bản thân và nghệ thuật giao tiếp', 'Hoa Kỳ')
('Yaval Noah Harari', 'Sử gia người Israel, tác giả của Sapiens ', 'Israel'),
('Robert C.Martin', 'Software engineer and author known as Uncle Bob', 'United States');
