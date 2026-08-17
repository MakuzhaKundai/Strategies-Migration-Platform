-- ============================================================
-- SMSSA / Strategies Migration Services
-- Prototype PostgreSQL Database
-- ============================================================
-- Purpose:
--   Documentation + prototype phase database for the proposed
--   Intelligent Case Management Platform.
--
-- IMPORTANT:
--   This is NOT a production migration script.
--   It contains no real client/company data.
--   Review naming, business rules, retention requirements and
--   existing-company data mappings with the client before use.
--
-- Target: PostgreSQL 15+
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Extensions
-- ------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------
-- 2. ENUM TYPES
-- ------------------------------------------------------------

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('ADMIN', 'CONSULTANT', 'CLIENT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE user_status AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE lead_status AS ENUM (
        'NEW',
        'QUALIFIED',
        'UNQUALIFIED',
        'NEEDS_REVIEW',
        'CONVERTED',
        'ARCHIVED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE lead_source AS ENUM (
        'WEBSITE',
        'REFERRAL',
        'EMAIL',
        'PHONE',
        'SOCIAL_MEDIA',
        'OTHER'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE case_status AS ENUM (
        'ACTIVE',
        'ON_HOLD',
        'CLOSED',
        'ARCHIVED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE case_stage AS ENUM (
        'INITIAL_INTAKE',
        'DOCUMENT_GATHERING',
        'UNDER_REVIEW',
        'SUBMITTED_TO_AUTHORITY',
        'FINAL_DECISION'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE priority_level AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'URGENT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE document_status AS ENUM (
        'PENDING',
        'UPLOADED',
        'UNDER_REVIEW',
        'APPROVED',
        'REJECTED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE agent_type AS ENUM (
        'INTAKE_TRIAGE',
        'DOCUMENT_CHECKLIST',
        'CASE_SUMMARISATION'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE agent_run_status AS ENUM (
        'SUCCESS',
        'FAILED',
        'FALLBACK'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE message_sender_type AS ENUM ('CLIENT', 'CONSULTANT', 'ADMIN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM (
        'CASE_UPDATE',
        'DOCUMENT_UPDATE',
        'MESSAGE',
        'PAYMENT',
        'SYSTEM'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------
-- 3. COMMON UPDATED-AT FUNCTION
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- 4. USERS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(50),
    password_hash TEXT,
    role user_role NOT NULL,
    status user_status NOT NULL DEFAULT 'ACTIVE',
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 5. CLIENTS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    client_reference VARCHAR(50) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    date_of_birth DATE,
    nationality VARCHAR(100),
    immigration_status VARCHAR(150),
    passport_number VARCHAR(100),
    id_number VARCHAR(100),
    address_line_1 VARCHAR(255),
    address_line_2 VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_clients_user_id ON clients(user_id);
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_reference ON clients(client_reference);

DROP TRIGGER IF EXISTS trg_clients_updated_at ON clients;
CREATE TRIGGER trg_clients_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 6. CORPORATE CLIENTS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS corporate_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(255) NOT NULL,
    registration_number VARCHAR(100),
    tax_number VARCHAR(100),
    contact_name VARCHAR(200),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_corporate_clients_company
ON corporate_clients(company_name);

DROP TRIGGER IF EXISTS trg_corporate_clients_updated_at
ON corporate_clients;
CREATE TRIGGER trg_corporate_clients_updated_at
BEFORE UPDATE ON corporate_clients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 7. VISA CATEGORIES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS visa_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS trg_visa_categories_updated_at
ON visa_categories;
CREATE TRIGGER trg_visa_categories_updated_at
BEFORE UPDATE ON visa_categories
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 8. DOCUMENT TYPES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS document_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    is_sensitive BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS trg_document_types_updated_at
ON document_types;
CREATE TRIGGER trg_document_types_updated_at
BEFORE UPDATE ON document_types
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 9. CHECKLIST TEMPLATES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS checklist_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visa_category_id UUID NOT NULL
        REFERENCES visa_categories(id) ON DELETE CASCADE,
    document_type_id UUID NOT NULL
        REFERENCES document_types(id) ON DELETE RESTRICT,
    is_mandatory BOOLEAN NOT NULL DEFAULT TRUE,
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (visa_category_id, document_type_id)
);

CREATE INDEX IF NOT EXISTS idx_checklist_visa_category
ON checklist_templates(visa_category_id);

-- ------------------------------------------------------------
-- 10. LEADS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_reference VARCHAR(50) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),

    current_immigration_status TEXT,
    target_visa_category_id UUID
        REFERENCES visa_categories(id) ON DELETE SET NULL,
    assistance_level VARCHAR(100),
    intended_start_date DATE,

    source lead_source NOT NULL DEFAULT 'WEBSITE',
    status lead_status NOT NULL DEFAULT 'NEW',

    ai_confidence NUMERIC(5,2),
    ai_reason TEXT,

    assigned_consultant_id UUID
        REFERENCES users(id) ON DELETE SET NULL,

    converted_client_id UUID
        REFERENCES clients(id) ON DELETE SET NULL,

    converted_case_id UUID,

    raw_submission JSONB,

    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_lead_ai_confidence
        CHECK (ai_confidence IS NULL OR
               (ai_confidence >= 0 AND ai_confidence <= 100))
);

CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_email ON leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_consultant
ON leads(assigned_consultant_id);
CREATE INDEX IF NOT EXISTS idx_leads_created_at
ON leads(created_at);

DROP TRIGGER IF EXISTS trg_leads_updated_at ON leads;
CREATE TRIGGER trg_leads_updated_at
BEFORE UPDATE ON leads
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 11. LEAD NOTES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lead_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL
        REFERENCES leads(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    note TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lead_notes_lead
ON lead_notes(lead_id);

-- ------------------------------------------------------------
-- 12. LEGAL / IMMIGRATION CASES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_reference VARCHAR(50) NOT NULL UNIQUE,

    client_id UUID NOT NULL
        REFERENCES clients(id) ON DELETE RESTRICT,

    corporate_client_id UUID
        REFERENCES corporate_clients(id) ON DELETE SET NULL,

    lead_id UUID UNIQUE
        REFERENCES leads(id) ON DELETE SET NULL,

    visa_category_id UUID
        REFERENCES visa_categories(id) ON DELETE SET NULL,

    assigned_consultant_id UUID
        REFERENCES users(id) ON DELETE SET NULL,

    case_type VARCHAR(150),
    title VARCHAR(255),

    status case_status NOT NULL DEFAULT 'ACTIVE',
    current_stage case_stage NOT NULL DEFAULT 'INITIAL_INTAKE',
    priority priority_level NOT NULL DEFAULT 'MEDIUM',

    opened_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deadline DATE,
    closed_at TIMESTAMPTZ,

    description TEXT,
    notes TEXT,

    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cases_client
ON cases(client_id);

CREATE INDEX IF NOT EXISTS idx_cases_consultant
ON cases(assigned_consultant_id);

CREATE INDEX IF NOT EXISTS idx_cases_status
ON cases(status);

CREATE INDEX IF NOT EXISTS idx_cases_stage
ON cases(current_stage);

CREATE INDEX IF NOT EXISTS idx_cases_deadline
ON cases(deadline);

DROP TRIGGER IF EXISTS trg_cases_updated_at ON cases;
CREATE TRIGGER trg_cases_updated_at
BEFORE UPDATE ON cases
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Add the circular lead -> case relationship safely.
ALTER TABLE leads
    DROP CONSTRAINT IF EXISTS fk_leads_converted_case;

ALTER TABLE leads
    ADD CONSTRAINT fk_leads_converted_case
    FOREIGN KEY (converted_case_id)
    REFERENCES cases(id)
    ON DELETE SET NULL;

-- ------------------------------------------------------------
-- 13. CASE STAGE HISTORY
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS case_stage_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL
        REFERENCES cases(id) ON DELETE CASCADE,
    from_stage case_stage,
    to_stage case_stage NOT NULL,
    changed_by UUID
        REFERENCES users(id) ON DELETE SET NULL,
    reason TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_case_stage_history_case
ON case_stage_history(case_id);

CREATE INDEX IF NOT EXISTS idx_case_stage_history_date
ON case_stage_history(changed_at);

-- ------------------------------------------------------------
-- 14. CASE DOCUMENT CHECKLIST
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS case_document_checklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL
        REFERENCES cases(id) ON DELETE CASCADE,
    document_type_id UUID NOT NULL
        REFERENCES document_types(id) ON DELETE RESTRICT,
    is_mandatory BOOLEAN NOT NULL DEFAULT TRUE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    instructions TEXT,
    due_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(case_id, document_type_id)
);

CREATE INDEX IF NOT EXISTS idx_case_checklist_case
ON case_document_checklist(case_id);

DROP TRIGGER IF EXISTS trg_case_checklist_updated_at
ON case_document_checklist;
CREATE TRIGGER trg_case_checklist_updated_at
BEFORE UPDATE ON case_document_checklist
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 15. DOCUMENTS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL
        REFERENCES cases(id) ON DELETE CASCADE,
    client_id UUID
        REFERENCES clients(id) ON DELETE SET NULL,
    document_type_id UUID
        REFERENCES document_types(id) ON DELETE SET NULL,

    file_name VARCHAR(255) NOT NULL,
    storage_key TEXT NOT NULL UNIQUE,
    mime_type VARCHAR(100),
    file_size_bytes BIGINT,

    status document_status NOT NULL DEFAULT 'PENDING',
    review_comment TEXT,
    uploaded_by UUID
        REFERENCES users(id) ON DELETE SET NULL,
    reviewed_by UUID
        REFERENCES users(id) ON DELETE SET NULL,

    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMPTZ,

    is_archived BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT chk_document_file_size
        CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0)
);

CREATE INDEX IF NOT EXISTS idx_documents_case
ON documents(case_id);

CREATE INDEX IF NOT EXISTS idx_documents_status
ON documents(status);

CREATE INDEX IF NOT EXISTS idx_documents_type
ON documents(document_type_id);

-- ------------------------------------------------------------
-- 16. DOCUMENT VERSIONS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL
        REFERENCES documents(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    storage_key TEXT NOT NULL UNIQUE,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100),
    file_size_bytes BIGINT,
    uploaded_by UUID
        REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(document_id, version_number),

    CONSTRAINT chk_version_number
        CHECK (version_number > 0)
);

CREATE INDEX IF NOT EXISTS idx_document_versions_document
ON document_versions(document_id);

-- ------------------------------------------------------------
-- 17. DOCUMENT SHARING
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS document_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL
        REFERENCES documents(id) ON DELETE CASCADE,
    shared_with_user_id UUID
        REFERENCES users(id) ON DELETE CASCADE,
    shared_by_user_id UUID
        REFERENCES users(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_document_shares_document
ON document_shares(document_id);

-- ------------------------------------------------------------
-- 18. CASE MESSAGES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL
        REFERENCES cases(id) ON DELETE CASCADE,

    sender_user_id UUID
        REFERENCES users(id) ON DELETE SET NULL,

    sender_type message_sender_type NOT NULL,

    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_messages_case
ON messages(case_id);

CREATE INDEX IF NOT EXISTS idx_messages_created
ON messages(created_at);

-- ------------------------------------------------------------
-- 19. AI AGENT RUNS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS agent_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    agent_type agent_type NOT NULL,

    lead_id UUID
        REFERENCES leads(id) ON DELETE SET NULL,

    case_id UUID
        REFERENCES cases(id) ON DELETE SET NULL,

    model_name VARCHAR(150),

    input_tokens INTEGER,
    output_tokens INTEGER,

    status agent_run_status NOT NULL,

    input_data JSONB,
    output_data JSONB,
    error_message TEXT,

    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,

    CONSTRAINT chk_agent_tokens
        CHECK (
            (input_tokens IS NULL OR input_tokens >= 0)
            AND
            (output_tokens IS NULL OR output_tokens >= 0)
        )
);

CREATE INDEX IF NOT EXISTS idx_agent_runs_type
ON agent_runs(agent_type);

CREATE INDEX IF NOT EXISTS idx_agent_runs_status
ON agent_runs(status);

CREATE INDEX IF NOT EXISTS idx_agent_runs_lead
ON agent_runs(lead_id);

CREATE INDEX IF NOT EXISTS idx_agent_runs_case
ON agent_runs(case_id);

-- ------------------------------------------------------------
-- 20. AI CASE SUMMARIES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS case_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    case_id UUID NOT NULL
        REFERENCES cases(id) ON DELETE CASCADE,

    agent_run_id UUID
        REFERENCES agent_runs(id) ON DELETE SET NULL,

    summary TEXT NOT NULL,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    reviewed_by UUID
        REFERENCES users(id) ON DELETE SET NULL,

    reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_case_summaries_case
ON case_summaries(case_id);

-- ------------------------------------------------------------
-- 21. PAYMENTS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    case_id UUID NOT NULL
        REFERENCES cases(id) ON DELETE CASCADE,

    client_id UUID
        REFERENCES clients(id) ON DELETE SET NULL,

    amount NUMERIC(12,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'ZAR',

    description TEXT,
    reference VARCHAR(100),

    payment_date DATE,
    paid BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_payment_amount
        CHECK (amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_payments_case
ON payments(case_id);

CREATE INDEX IF NOT EXISTS idx_payments_client
ON payments(client_id);

-- ------------------------------------------------------------
-- 22. NOTIFICATIONS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,

    case_id UUID
        REFERENCES cases(id) ON DELETE SET NULL,

    notification_type notification_type NOT NULL,

    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,

    is_read BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
ON notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
ON notifications(user_id, is_read);

-- ------------------------------------------------------------
-- 23. AUDIT LOGS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID
        REFERENCES users(id) ON DELETE SET NULL,

    entity_name VARCHAR(100) NOT NULL,
    entity_id UUID,

    action VARCHAR(50) NOT NULL,

    old_values JSONB,
    new_values JSONB,

    ip_address INET,
    user_agent TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
ON audit_logs(entity_name, entity_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user
ON audit_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
ON audit_logs(created_at);

-- ------------------------------------------------------------
-- 24. CASE / CLIENT REPORTING VIEWS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW vw_case_overview AS
SELECT
    c.id,
    c.case_reference,
    c.case_type,
    c.title,
    c.status,
    c.current_stage,
    c.priority,
    c.opened_at,
    c.deadline,

    cl.client_reference,
    cl.first_name || ' ' || cl.last_name AS client_name,
    cl.email AS client_email,

    vc.code AS visa_code,
    vc.name AS visa_category,

    u.first_name || ' ' || u.last_name AS consultant_name,

    (
        SELECT COUNT(*)
        FROM documents d
        WHERE d.case_id = c.id
          AND d.is_archived = FALSE
    ) AS document_count,

    (
        SELECT COUNT(*)
        FROM case_document_checklist cd
        WHERE cd.case_id = c.id
          AND cd.is_completed = FALSE
    ) AS outstanding_documents

FROM cases c
JOIN clients cl
    ON cl.id = c.client_id
LEFT JOIN visa_categories vc
    ON vc.id = c.visa_category_id
LEFT JOIN users u
    ON u.id = c.assigned_consultant_id
WHERE c.is_archived = FALSE;

CREATE OR REPLACE VIEW vw_lead_summary AS
SELECT
    l.id,
    l.lead_reference,
    l.first_name || ' ' || COALESCE(l.last_name, '') AS lead_name,
    l.email,
    l.status,
    l.source,
    vc.name AS target_visa_category,
    l.ai_confidence,
    l.created_at,
    u.first_name || ' ' || u.last_name AS assigned_consultant
FROM leads l
LEFT JOIN visa_categories vc
    ON vc.id = l.target_visa_category_id
LEFT JOIN users u
    ON u.id = l.assigned_consultant_id
WHERE l.is_archived = FALSE;

-- ------------------------------------------------------------
-- 25. PROTOTYPE SEED DATA
-- ------------------------------------------------------------
-- These records are fake examples only.
-- Remove them before any production deployment.

INSERT INTO users
    (id, first_name, last_name, email, role, email_verified)
VALUES
    ('00000000-0000-0000-0000-000000000001',
     'Prototype', 'Admin',
     'admin.prototype@example.com',
     'ADMIN', TRUE),

    ('00000000-0000-0000-0000-000000000002',
     'Prototype', 'Consultant',
     'consultant.prototype@example.com',
     'CONSULTANT', TRUE),

    ('00000000-0000-0000-0000-000000000003',
     'Prototype', 'Client',
     'client.prototype@example.com',
     'CLIENT', TRUE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO visa_categories
    (code, name, description)
VALUES
    ('GEN-VISA', 'General Visa / Immigration Matter',
     'Prototype visa category for system demonstration.'),
    ('WORK-VISA', 'Work Visa',
     'Prototype work-related immigration category.'),
    ('STUDY-VISA', 'Study Visa',
     'Prototype study-related immigration category.'),
    ('FAMILY', 'Family / Dependant',
     'Prototype family or dependant category.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO document_types
    (name, description, is_sensitive)
VALUES
    ('Passport', 'Valid passport copy.', TRUE),
    ('Identity Document', 'South African identity document or equivalent.', TRUE),
    ('Proof of Funds', 'Evidence of available financial resources.', TRUE),
    ('Proof of Address', 'Recent proof of residential address.', TRUE),
    ('Photograph', 'Required identification photograph.', TRUE),
    ('Supporting Letter', 'Supporting letter relevant to the application.', FALSE)
ON CONFLICT (name) DO NOTHING;

-- Example checklist template
INSERT INTO checklist_templates
    (visa_category_id, document_type_id, is_mandatory)
SELECT
    v.id,
    d.id,
    TRUE
FROM visa_categories v
CROSS JOIN document_types d
WHERE v.code = 'WORK-VISA'
  AND d.name IN ('Passport', 'Proof of Funds', 'Proof of Address')
ON CONFLICT (visa_category_id, document_type_id) DO NOTHING;

-- Example client
INSERT INTO clients
    (
        id,
        client_reference,
        first_name,
        last_name,
        email,
        nationality,
        country
    )
VALUES
    (
        '00000000-0000-0000-0000-000000000010',
        'DEMO-CLIENT-001',
        'Demo',
        'Client',
        'demo.client@example.com',
        'Prototype',
        'South Africa'
    )
ON CONFLICT (client_reference) DO NOTHING;

-- Example lead
INSERT INTO leads
    (
        id,
        lead_reference,
        first_name,
        last_name,
        email,
        current_immigration_status,
        target_visa_category_id,
        assistance_level,
        intended_start_date,
        source,
        status,
        ai_confidence
    )
SELECT
    '00000000-0000-0000-0000-000000000020',
    'DEMO-LEAD-001',
    'Demo',
    'Prospect',
    'demo.lead@example.com',
    'Visitor',
    v.id,
    'Full assistance',
    CURRENT_DATE + INTERVAL '30 days',
    'WEBSITE',
    'QUALIFIED',
    92.50
FROM visa_categories v
WHERE v.code = 'WORK-VISA'
ON CONFLICT (lead_reference) DO NOTHING;

-- Example case
INSERT INTO cases
    (
        id,
        case_reference,
        client_id,
        lead_id,
        visa_category_id,
        assigned_consultant_id,
        case_type,
        title,
        current_stage,
        priority
    )
SELECT
    '00000000-0000-0000-0000-000000000030',
    'DEMO-CASE-001',
    cl.id,
    l.id,
    v.id,
    u.id,
    'Immigration Application',
    'Prototype Immigration Case',
    'INITIAL_INTAKE',
    'MEDIUM'
FROM clients cl
JOIN leads l
    ON l.lead_reference = 'DEMO-LEAD-001'
JOIN visa_categories v
    ON v.code = 'WORK-VISA'
JOIN users u
    ON u.email = 'consultant.prototype@example.com'
WHERE cl.client_reference = 'DEMO-CLIENT-001'
ON CONFLICT (case_reference) DO NOTHING;

-- Link the prototype lead to the prototype case.
UPDATE leads
SET
    converted_client_id = '00000000-0000-0000-0000-000000000010',
    converted_case_id = '00000000-0000-0000-0000-000000000030',
    status = 'CONVERTED'
WHERE lead_reference = 'DEMO-LEAD-001';

-- Create checklist entries for the demo case.
INSERT INTO case_document_checklist
    (case_id, document_type_id, is_mandatory, instructions)
SELECT
    c.id,
    d.id,
    TRUE,
    'Prototype document requirement.'
FROM cases c
CROSS JOIN document_types d
WHERE c.case_reference = 'DEMO-CASE-001'
  AND d.name IN ('Passport', 'Proof of Funds', 'Proof of Address')
ON CONFLICT (case_id, document_type_id) DO NOTHING;

-- ------------------------------------------------------------
-- 26. BASIC DATA-INTEGRITY CHECKS
-- ------------------------------------------------------------

ALTER TABLE documents
    DROP CONSTRAINT IF EXISTS chk_document_review_comment;

ALTER TABLE documents
    ADD CONSTRAINT chk_document_review_comment
    CHECK (
        status <> 'REJECTED'
        OR review_comment IS NOT NULL
        OR reviewed_by IS NULL
    );

-- ------------------------------------------------------------
-- 27. FINAL TRANSACTION
-- ------------------------------------------------------------

COMMIT;

-- ============================================================
-- END OF PROTOTYPE DATABASE
-- ============================================================
