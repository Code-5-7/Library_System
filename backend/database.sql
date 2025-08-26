-- =========================================
-- 1. DROP TABLES IF THEY EXIST (for reseeding)
-- =========================================
DROP TABLE IF EXISTS library_entries;
DROP TABLE IF EXISTS memberships;
DROP TABLE IF EXISTS payments;

-- =========================================
-- 2. CREATE TABLES
-- =========================================

-- Detailed log of each person’s entry
CREATE TABLE library_entries (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    entry_time TIMESTAMP NOT NULL,
    amount DECIMAL NOT NULL
);

-- Active memberships (one row per unique member)
CREATE TABLE memberships (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    amount DECIMAL NOT NULL,
    duration_days INTEGER NOT NULL
);

-- Payment summary (one row per M-Pesa transaction)
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    payer_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    bill_ref_number TEXT NOT NULL,
    trans_amount DECIMAL NOT NULL,
    group_size INTEGER NOT NULL,
    per_person_amount DECIMAL NOT NULL,
    trans_time TIMESTAMP NOT NULL
);

-- Daily revenue summary from the payments table
SELECT 
    DATE(trans_time) AS payment_date,
    SUM(trans_amount) AS total_revenue,
    COUNT(*) AS total_transactions
FROM payments
GROUP BY DATE(trans_time)
ORDER BY payment_date;


-- =========================================
-- 3. SEED SAMPLE DATA
-- =========================================

-- === payments ===
INSERT INTO payments (payer_name, phone, bill_ref_number, trans_amount, group_size, per_person_amount, trans_time) VALUES
-- GROUP_5 payment: KSh 100 total → 5 people × KSh 20 each
('John Mwangi', '0712345600', 'GROUP_5', 100.00, 5, 20.00, '2025-08-26 09:15:00'),

-- SINGLE payment: KSh 100 → 1 person, 7-day membership
('Mary Atieno', '0798765432', 'SINGLE', 100.00, 1, 100.00, '2025-08-25 14:30:00'),

-- GROUP_3 payment: KSh 60 total → 3 people × KSh 20 each
('Peter Kamau', '0700111222', 'GROUP_3', 60.00, 3, 20.00, '2025-08-26 10:05:00');

-- === library_entries ===
INSERT INTO library_entries (full_name, phone, entry_time, amount) VALUES
-- GROUP_5
('John Mwangi', '0712345600_0', '2025-08-26 09:15:00', 20.00),
('John Mwangi', '0712345600_1', '2025-08-26 09:15:00', 20.00),
('John Mwangi', '0712345600_2', '2025-08-26 09:15:00', 20.00),
('John Mwangi', '0712345600_3', '2025-08-26 09:15:00', 20.00),
('John Mwangi', '0712345600_4', '2025-08-26 09:15:00', 20.00),

-- SINGLE
('Mary Atieno', '0798765432', '2025-08-25 14:30:00', 100.00),

-- GROUP_3
('Peter Kamau', '0700111222_0', '2025-08-26 10:05:00', 20.00),
('Peter Kamau', '0700111222_1', '2025-08-26 10:05:00', 20.00),
('Peter Kamau', '0700111222_2', '2025-08-26 10:05:00', 20.00);

-- === memberships ===
INSERT INTO memberships (full_name, phone, start_time, end_time, amount, duration_days) VALUES
-- GROUP_5 daily passes
('John Mwangi', '0712345600_0', '2025-08-26 09:15:00', '2025-08-27 09:15:00', 20.00, 1),
('John Mwangi', '0712345600_1', '2025-08-26 09:15:00', '2025-08-27 09:15:00', 20.00, 1),
('John Mwangi', '0712345600_2', '2025-08-26 09:15:00', '2025-08-27 09:15:00', 20.00, 1),
('John Mwangi', '0712345600_3', '2025-08-26 09:15:00', '2025-08-27 09:15:00', 20.00, 1),
('John Mwangi', '0712345600_4', '2025-08-26 09:15:00', '2025-08-27 09:15:00', 20.00, 1),

-- SINGLE weekly membership
('Mary Atieno', '0798765432', '2025-08-25 14:30:00', '2025-09-01 14:30:00', 100.00, 7),

-- GROUP_3 daily passes
('Peter Kamau', '0700111222_0', '2025-08-26 10:05:00', '2025-08-27 10:05:00', 20.00, 1),
('Peter Kamau', '0700111222_1', '2025-08-26 10:05:00', '2025-08-27 10:05:00', 20.00, 1),
('Peter Kamau', '0700111222_2', '2025-08-26 10:05:00', '2025-08-27 10:05:00', 20.00, 1);
