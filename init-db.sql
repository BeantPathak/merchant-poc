-- 1. Create role
DO
$$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'merchant') THEN
      CREATE ROLE merchant LOGIN PASSWORD 'merchant';
   END IF;
END
$$;

-- 2. Create database safely
SELECT 'CREATE DATABASE merchantdb OWNER merchant'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'merchantdb'
)\gexec

-- 3. Connect
\connect merchantdb

-- 4. Tables
CREATE TABLE IF NOT EXISTS merchants (
    merchant_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kyc (
    kyc_id SERIAL PRIMARY KEY,
    merchant_id INT REFERENCES merchants(merchant_id),
    status TEXT
);

CREATE TABLE IF NOT EXISTS risk (
    risk_id SERIAL PRIMARY KEY,
    merchant_id INT REFERENCES merchants(merchant_id),
    score INT
);

-- 5. Grants (THIS is what actually makes Lambdas work)
GRANT ALL PRIVILEGES ON TABLE merchants TO merchant;
GRANT ALL PRIVILEGES ON TABLE kyc TO merchant;
GRANT ALL PRIVILEGES ON TABLE risk TO merchant;

GRANT USAGE, SELECT ON SEQUENCE merchants_merchant_id_seq TO merchant;
GRANT USAGE, SELECT ON SEQUENCE kyc_kyc_id_seq TO merchant;
GRANT USAGE, SELECT ON SEQUENCE risk_risk_id_seq TO merchant;
