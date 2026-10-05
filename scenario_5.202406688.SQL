-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 5: Engineering Workshop Tool Loans
-- Student number: STUDENTNO

DROP TABLE IF EXISTS tool_loans;
DROP TABLE IF EXISTS tools;

-- 1. Tables and sample data
CREATE TABLE tools (
    tool_id            SERIAL PRIMARY KEY,
    tool_name          VARCHAR(80) NOT NULL,
    available_quantity INT NOT NULL CHECK (available_quantity >= 0)
);

CREATE TABLE tool_loans (
    loan_id        SERIAL PRIMARY KEY,
    tool_id        INT NOT NULL REFERENCES tools(tool_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    status         VARCHAR(10) NOT NULL DEFAULT 'ISSUED'
                   CHECK (status IN ('ISSUED','RETURNED'))
);

INSERT INTO tools (tool_name, available_quantity) VALUES
 ('Digital Multimeter', 12),
 ('Soldering Iron', 3),
 ('Vernier Caliper', 0);

-- 2. IF / ELSIF / ELSE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT tool_name, available_quantity FROM tools ORDER BY tool_id LOOP
        IF r.available_quantity = 0 THEN
            RAISE NOTICE '%: UNAVAILABLE', r.tool_name;
        ELSIF r.available_quantity <= 3 THEN
            RAISE NOTICE '%: LOW on stock (%)', r.tool_name, r.available_quantity;
        ELSE
            RAISE NOTICE '%: readily available (%)', r.tool_name, r.available_quantity;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    n INT := 1;
BEGIN
    WHILE n <= 3 LOOP
        RAISE NOTICE 'Workshop safety reminder %', n;
        n := n + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Tool inspection %', i;
    END LOOP;
END $$;

-- 4. issue_tool procedure
CREATE OR REPLACE PROCEDURE issue_tool(p_tool_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: % (must be greater than zero)', p_qty;
    END IF;

    SELECT available_quantity INTO v_stock
    FROM tools WHERE tool_id = p_tool_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Tool % does not exist.', p_tool_id;
        RETURN;
    END IF;

    IF v_stock < p_qty THEN
        RAISE NOTICE 'Loan REJECTED for %: requested %, only % available.', p_student, p_qty, v_stock;
        RETURN;
    END IF;

    UPDATE tools SET available_quantity = available_quantity - p_qty WHERE tool_id = p_tool_id;
    INSERT INTO tool_loans (tool_id, student_number, quantity) VALUES (p_tool_id, p_student, p_qty);
    RAISE NOTICE 'Issued % of tool % to %.', p_qty, p_tool_id, p_student;
END $$;

-- 5. Two valid loans and one exceeding stock
CALL issue_tool(1, '2024001', 4);   -- valid
CALL issue_tool(2, '2024002', 1);   -- valid
CALL issue_tool(2, '2024003', 5);   -- exceeds stock

SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;

-- 6. return_tool procedure
CREATE OR REPLACE PROCEDURE return_tool(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tool   INT;
    v_qty    INT;
    v_status VARCHAR;
BEGIN
    SELECT tool_id, quantity, status INTO v_tool, v_qty, v_status
    FROM tool_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan % not found.', p_loan_id;
        RETURN;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % already returned. No stock added.', p_loan_id;
        RETURN;
    END IF;

    UPDATE tool_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
    UPDATE tools SET available_quantity = available_quantity + v_qty WHERE tool_id = v_tool;
    RAISE NOTICE 'Loan % returned. % tool(s) added back to stock.', p_loan_id, v_qty;
END $$;

CALL return_tool(1);   -- restores stock
CALL return_tool(1);   -- second call: no stock added

SELECT * FROM tools ORDER BY tool_id;

-- 7. Explicit cursor: tools with low availability
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT tool_name, available_quantity FROM tools
        WHERE available_quantity <= 3 ORDER BY available_quantity;
    v_name  tools.tool_name%TYPE;
    v_stock tools.available_quantity%TYPE;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO v_name, v_stock;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low availability: % (% left)', v_name, v_stock;
    END LOOP;
    CLOSE cur_low;
END $$;

-- 8. Zero tools: handled with EXCEPTION block
DO $$
BEGIN
    CALL issue_tool(1, '2024004', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- 9. Final results
SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;
