CREATE TABLE blocks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    block_number INT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE assets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(10) NOT NULL
);

CREATE TABLE pairs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    asset1_id INT NOT NULL,
    asset2_id INT NOT NULL,
    FOREIGN KEY (asset1_id) REFERENCES assets(id),
    FOREIGN KEY (asset2_id) REFERENCES assets(id)
);

CREATE TABLE events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    block_id INT NOT NULL,
    asset_id INT NOT NULL,
    FOREIGN KEY (block_id) REFERENCES blocks(id),
    FOREIGN KEY (asset_id) REFERENCES assets(id)
);
