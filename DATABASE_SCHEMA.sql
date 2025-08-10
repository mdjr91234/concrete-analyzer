-- Concrete Sales & Profit Analyzer Database Schema
-- PostgreSQL 15+ Compatible
-- Industry-specific design for concrete manufacturing and sales tracking

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'sales', 'analyst');
CREATE TYPE delivery_status_enum AS ENUM ('pending', 'in_transit', 'delivered', 'cancelled');
CREATE TYPE cost_category_enum AS ENUM ('manufacturing', 'labor', 'equipment', 'fuel', 'fixed', 'overhead', 'maintenance');
CREATE TYPE project_status_enum AS ENUM ('active', 'completed', 'cancelled', 'on_hold');
CREATE TYPE concrete_category_enum AS ENUM ('standard', 'high_strength', 'fiber_reinforced', 'self_consolidating', 'lightweight');

-- =============================================
-- CORE BUSINESS ENTITIES
-- =============================================

-- Users and Authentication
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  role user_role NOT NULL DEFAULT 'sales',
  phone VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMP,
  password_reset_token VARCHAR(255),
  password_reset_expires TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customers
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name VARCHAR(255) NOT NULL,
  contact_name VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(20),
  billing_address TEXT,
  shipping_address TEXT,
  payment_terms INTEGER DEFAULT 30, -- Days
  credit_limit DECIMAL(12,2),
  tax_id VARCHAR(50),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Concrete Types and Specifications
CREATE TABLE concrete_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  category concrete_category_enum NOT NULL DEFAULT 'standard',
  psi_strength INTEGER NOT NULL, -- Compressive strength
  slump_rating VARCHAR(20), -- e.g., "4-6 inches"
  air_content DECIMAL(4,2), -- Percentage
  max_aggregate_size DECIMAL(4,2), -- Inches
  cement_content DECIMAL(6,2), -- lbs per cubic yard
  water_cement_ratio DECIMAL(4,3),
  base_cost_per_yard DECIMAL(8,2) DEFAULT 70.00,
  standard_price_per_yard DECIMAL(8,2) DEFAULT 120.00,
  description TEXT,
  specifications JSONB, -- Additional technical specs
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Projects (Delivery Jobs)
CREATE TABLE projects (
  id VARCHAR(50) PRIMARY KEY, -- e.g., "PROJ-2024-001"
  customer_id UUID NOT NULL REFERENCES customers(id),
  project_name VARCHAR(255) NOT NULL,
  site_address TEXT NOT NULL,
  start_date DATE,
  estimated_completion_date DATE,
  actual_completion_date DATE,
  project_status project_status_enum DEFAULT 'active',
  estimated_total_yards DECIMAL(10,2),
  actual_total_yards DECIMAL(10,2),
  contract_amount DECIMAL(12,2),
  project_manager_id UUID REFERENCES users(id),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sales Transactions (Individual Deliveries)
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_number VARCHAR(50) UNIQUE NOT NULL, -- e.g., "INV-2024-001"
  project_id VARCHAR(50) NOT NULL REFERENCES projects(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  sale_date DATE NOT NULL,
  delivery_date DATE,
  concrete_type_id UUID NOT NULL REFERENCES concrete_types(id),
  concrete_yards DECIMAL(10,2) NOT NULL CHECK (concrete_yards > 0),
  unit_price DECIMAL(8,2) NOT NULL CHECK (unit_price > 0),
  total_revenue DECIMAL(10,2) GENERATED ALWAYS AS (concrete_yards * unit_price) STORED,
  
  -- Delivery details
  delivery_address TEXT NOT NULL,
  delivery_status delivery_status_enum DEFAULT 'pending',
  truck_number VARCHAR(20),
  driver_name VARCHAR(100),
  pour_time_start TIME,
  pour_time_end TIME,
  
  -- Additional charges
  fuel_surcharge DECIMAL(8,2) DEFAULT 0,
  overtime_charges DECIMAL(8,2) DEFAULT 0,
  additional_charges DECIMAL(8,2) DEFAULT 0,
  additional_charges_description TEXT,
  
  -- Sales team
  sales_rep_id UUID REFERENCES users(id),
  dispatcher_id UUID REFERENCES users(id),
  
  -- Financial
  profit_margin DECIMAL(5,2), -- Calculated percentage
  gross_profit DECIMAL(10,2), -- Calculated amount
  
  -- System fields
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- COST TRACKING SYSTEM
-- =============================================

-- Vendors and Suppliers
CREATE TABLE vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name VARCHAR(255) NOT NULL,
  contact_name VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(20),
  address TEXT,
  vendor_type VARCHAR(100), -- e.g., "Material Supplier", "Equipment Rental"
  payment_terms INTEGER DEFAULT 30,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Equipment and Assets
CREATE TABLE equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_number VARCHAR(50) UNIQUE NOT NULL,
  equipment_type VARCHAR(100) NOT NULL, -- e.g., "Mixer Truck", "Pump", "Loader"
  make VARCHAR(100),
  model VARCHAR(100),
  year INTEGER,
  acquisition_cost DECIMAL(12,2),
  current_value DECIMAL(12,2),
  hourly_rate DECIMAL(8,2), -- Cost per hour of operation
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cost Tracking (Individual Cost Entries)
CREATE TABLE costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id VARCHAR(50) REFERENCES projects(id),
  sale_id UUID REFERENCES sales(id), -- Link to specific delivery if applicable
  cost_category cost_category_enum NOT NULL,
  cost_type VARCHAR(100) NOT NULL, -- e.g., "Cement", "Driver Wages", "Fuel"
  amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  cost_date DATE NOT NULL,
  
  -- References
  vendor_id UUID REFERENCES vendors(id),
  equipment_id UUID REFERENCES equipment(id),
  
  -- Supporting documents
  invoice_number VARCHAR(100),
  receipt_url VARCHAR(500), -- Link to stored receipt/invoice
  
  -- Details
  quantity DECIMAL(10,3), -- Amount of material/hours
  unit_cost DECIMAL(10,3), -- Cost per unit
  unit_type VARCHAR(50), -- e.g., "tons", "hours", "gallons"
  description TEXT,
  
  -- Allocation
  is_direct_cost BOOLEAN DEFAULT true, -- Direct vs. indirect cost
  allocation_method VARCHAR(50), -- How cost is allocated across projects
  
  -- System fields
  created_by UUID REFERENCES users(id),
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Manufacturing Cost Templates (Standard Costs per Concrete Type)
CREATE TABLE manufacturing_cost_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concrete_type_id UUID NOT NULL REFERENCES concrete_types(id),
  effective_date DATE NOT NULL,
  
  -- Material costs per cubic yard
  cement_cost DECIMAL(8,4) NOT NULL,
  sand_cost DECIMAL(8,4) NOT NULL,
  gravel_cost DECIMAL(8,4) NOT NULL,
  water_cost DECIMAL(8,4) DEFAULT 0.50,
  admixture_cost DECIMAL(8,4) DEFAULT 0.00,
  fiber_cost DECIMAL(8,4) DEFAULT 0.00,
  
  -- Production costs per cubic yard
  mixing_cost DECIMAL(8,4) DEFAULT 2.00,
  quality_control_cost DECIMAL(8,4) DEFAULT 1.00,
  overhead_cost DECIMAL(8,4) DEFAULT 5.00,
  
  -- Total calculated cost
  total_manufacturing_cost DECIMAL(8,2) NOT NULL,
  
  -- System fields
  created_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Labor Cost Tracking
CREATE TABLE labor_costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_name VARCHAR(255) NOT NULL,
  employee_id VARCHAR(50),
  project_id VARCHAR(50) REFERENCES projects(id),
  work_date DATE NOT NULL,
  clock_in TIME,
  clock_out TIME,
  regular_hours DECIMAL(4,2) DEFAULT 0,
  overtime_hours DECIMAL(4,2) DEFAULT 0,
  regular_rate DECIMAL(8,2) NOT NULL,
  overtime_rate DECIMAL(8,2), -- Usually 1.5x regular rate
  total_wages DECIMAL(10,2),
  job_role VARCHAR(100), -- e.g., "Driver", "Plant Operator", "Dispatcher"
  equipment_used UUID REFERENCES equipment(id),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- ANALYTICS AND REPORTING TABLES
-- =============================================

-- Daily Production Summary
CREATE TABLE daily_production_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_date DATE NOT NULL UNIQUE,
  total_yards_produced DECIMAL(10,2) NOT NULL,
  total_yards_delivered DECIMAL(10,2) NOT NULL,
  total_revenue DECIMAL(12,2) NOT NULL,
  total_costs DECIMAL(12,2) NOT NULL,
  gross_profit DECIMAL(12,2) GENERATED ALWAYS AS (total_revenue - total_costs) STORED,
  profit_margin DECIMAL(5,2) GENERATED ALWAYS AS 
    (CASE WHEN total_revenue > 0 THEN ((total_revenue - total_costs) / total_revenue * 100) ELSE 0 END) STORED,
  number_of_deliveries INTEGER NOT NULL,
  number_of_projects INTEGER NOT NULL,
  average_yards_per_delivery DECIMAL(6,2) GENERATED ALWAYS AS 
    (CASE WHEN number_of_deliveries > 0 THEN (total_yards_delivered / number_of_deliveries) ELSE 0 END) STORED,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Material Price History (for trend analysis)
CREATE TABLE material_price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  material_type VARCHAR(100) NOT NULL, -- e.g., "Cement", "Sand", "Gravel"
  supplier VARCHAR(255),
  price_date DATE NOT NULL,
  unit_price DECIMAL(10,4) NOT NULL, -- Price per unit (ton, cubic yard, etc.)
  unit_type VARCHAR(50) NOT NULL, -- "tons", "cubic_yards", "gallons"
  currency VARCHAR(3) DEFAULT 'USD',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Profit Analysis Cache (for performance)
CREATE TABLE profit_analysis_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  analysis_key VARCHAR(255) NOT NULL, -- Hash of parameters
  date_range_start DATE NOT NULL,
  date_range_end DATE NOT NULL,
  analysis_type VARCHAR(50) NOT NULL, -- e.g., "monthly", "project", "customer"
  cached_result JSONB NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- AUDIT AND SYSTEM TABLES
-- =============================================

-- Audit Log for Data Changes
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name VARCHAR(100) NOT NULL,
  record_id VARCHAR(50) NOT NULL,
  operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
  old_values JSONB,
  new_values JSONB,
  changed_by UUID REFERENCES users(id),
  changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_address INET
);

-- System Configuration
CREATE TABLE system_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key VARCHAR(100) UNIQUE NOT NULL,
  config_value TEXT NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES users(id),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- PERFORMANCE INDEXES
-- =============================================

-- Users indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active);

-- Sales indexes
CREATE INDEX idx_sales_date_range ON sales(sale_date);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_project ON sales(project_id);
CREATE INDEX idx_sales_rep ON sales(sales_rep_id);
CREATE INDEX idx_sales_concrete_type ON sales(concrete_type_id);
CREATE INDEX idx_sales_delivery_status ON sales(delivery_status);

-- Composite indexes for analytics
CREATE INDEX idx_sales_analytics_date_type ON sales(sale_date, concrete_type_id);
CREATE INDEX idx_sales_profit_analysis ON sales(sale_date, profit_margin) WHERE profit_margin IS NOT NULL;
CREATE INDEX idx_sales_revenue_analysis ON sales(sale_date, total_revenue);

-- Costs indexes
CREATE INDEX idx_costs_project_date ON costs(project_id, cost_date);
CREATE INDEX idx_costs_category_date ON costs(cost_category, cost_date);
CREATE INDEX idx_costs_date_range ON costs(cost_date);
CREATE INDEX idx_costs_vendor ON costs(vendor_id);
CREATE INDEX idx_costs_equipment ON costs(equipment_id);

-- Projects indexes
CREATE INDEX idx_projects_customer ON projects(customer_id);
CREATE INDEX idx_projects_status ON projects(project_status);
CREATE INDEX idx_projects_dates ON projects(start_date, estimated_completion_date);
CREATE INDEX idx_projects_manager ON projects(project_manager_id);

-- Labor costs indexes
CREATE INDEX idx_labor_date_employee ON labor_costs(work_date, employee_id);
CREATE INDEX idx_labor_project_date ON labor_costs(project_id, work_date);

-- Manufacturing costs indexes
CREATE INDEX idx_manufacturing_costs_type_date ON manufacturing_cost_templates(concrete_type_id, effective_date);
CREATE INDEX idx_manufacturing_costs_active ON manufacturing_cost_templates(is_active, effective_date);

-- Analytics indexes
CREATE INDEX idx_daily_summary_date ON daily_production_summary(production_date);
CREATE INDEX idx_material_price_date ON material_price_history(material_type, price_date);
CREATE INDEX idx_profit_cache_key_expires ON profit_analysis_cache(analysis_key, expires_at);

-- =============================================
-- VIEWS FOR COMMON QUERIES
-- =============================================

-- Complete Sales View with Calculated Profit
CREATE OR REPLACE VIEW sales_with_profit AS
SELECT 
  s.*,
  c.company_name as customer_name,
  ct.name as concrete_type_name,
  ct.category as concrete_category,
  p.project_name,
  p.site_address,
  u.first_name || ' ' || u.last_name as sales_rep_name,
  
  -- Calculate total costs for this sale
  COALESCE(costs.total_costs, 0) as total_costs,
  
  -- Calculate actual profit
  (s.total_revenue - COALESCE(costs.total_costs, 0)) as calculated_profit,
  
  -- Calculate actual profit margin
  CASE 
    WHEN s.total_revenue > 0 
    THEN ((s.total_revenue - COALESCE(costs.total_costs, 0)) / s.total_revenue * 100)
    ELSE 0 
  END as calculated_profit_margin

FROM sales s
LEFT JOIN customers c ON s.customer_id = c.id
LEFT JOIN concrete_types ct ON s.concrete_type_id = ct.id
LEFT JOIN projects p ON s.project_id = p.id
LEFT JOIN users u ON s.sales_rep_id = u.id
LEFT JOIN (
  SELECT 
    sale_id,
    SUM(amount) as total_costs
  FROM costs 
  WHERE sale_id IS NOT NULL
  GROUP BY sale_id
) costs ON s.id = costs.sale_id;

-- Monthly Sales Summary View
CREATE OR REPLACE VIEW monthly_sales_summary AS
SELECT 
  DATE_TRUNC('month', sale_date) as month,
  COUNT(*) as total_deliveries,
  SUM(concrete_yards) as total_yards,
  SUM(total_revenue) as total_revenue,
  AVG(unit_price) as average_price_per_yard,
  AVG(concrete_yards) as average_yards_per_delivery,
  AVG(profit_margin) as average_profit_margin
FROM sales
WHERE delivery_status = 'delivered'
GROUP BY DATE_TRUNC('month', sale_date)
ORDER BY month DESC;

-- Project Profitability Summary View
CREATE OR REPLACE VIEW project_profitability AS
SELECT 
  p.id as project_id,
  p.project_name,
  p.customer_id,
  c.company_name as customer_name,
  p.project_status,
  
  -- Sales totals
  COUNT(s.id) as total_deliveries,
  COALESCE(SUM(s.concrete_yards), 0) as total_yards_delivered,
  COALESCE(SUM(s.total_revenue), 0) as total_revenue,
  
  -- Cost totals
  COALESCE(project_costs.total_costs, 0) as total_costs,
  
  -- Profit calculations
  (COALESCE(SUM(s.total_revenue), 0) - COALESCE(project_costs.total_costs, 0)) as gross_profit,
  
  CASE 
    WHEN COALESCE(SUM(s.total_revenue), 0) > 0 
    THEN ((COALESCE(SUM(s.total_revenue), 0) - COALESCE(project_costs.total_costs, 0)) / COALESCE(SUM(s.total_revenue), 0) * 100)
    ELSE 0 
  END as profit_margin_percentage

FROM projects p
LEFT JOIN customers c ON p.customer_id = c.id
LEFT JOIN sales s ON p.id = s.project_id AND s.delivery_status = 'delivered'
LEFT JOIN (
  SELECT 
    project_id,
    SUM(amount) as total_costs
  FROM costs
  WHERE project_id IS NOT NULL
  GROUP BY project_id
) project_costs ON p.id = project_costs.project_id
GROUP BY p.id, p.project_name, p.customer_id, c.company_name, p.project_status, project_costs.total_costs;

-- =============================================
-- TRIGGERS FOR AUDIT LOGGING
-- =============================================

-- Function to log data changes
CREATE OR REPLACE FUNCTION log_data_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log (table_name, record_id, operation, new_values, changed_by)
    VALUES (TG_TABLE_NAME, NEW.id::text, TG_OP, to_jsonb(NEW), NEW.created_by);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values, changed_by)
    VALUES (TG_TABLE_NAME, NEW.id::text, TG_OP, to_jsonb(OLD), to_jsonb(NEW), NEW.updated_by);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_log (table_name, record_id, operation, old_values, changed_by)
    VALUES (TG_TABLE_NAME, OLD.id::text, TG_OP, to_jsonb(OLD), NULL);
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to main tables
CREATE TRIGGER audit_users AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW EXECUTE FUNCTION log_data_changes();

CREATE TRIGGER audit_sales AFTER INSERT OR UPDATE OR DELETE ON sales
  FOR EACH ROW EXECUTE FUNCTION log_data_changes();

CREATE TRIGGER audit_costs AFTER INSERT OR UPDATE OR DELETE ON costs
  FOR EACH ROW EXECUTE FUNCTION log_data_changes();

CREATE TRIGGER audit_projects AFTER INSERT OR UPDATE OR DELETE ON projects
  FOR EACH ROW EXECUTE FUNCTION log_data_changes();

-- =============================================
-- INITIAL DATA SETUP
-- =============================================

-- Insert default admin user (password should be changed immediately)
INSERT INTO users (email, password_hash, first_name, last_name, role, is_active) VALUES
('admin@concretecompany.com', '$2b$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'System', 'Administrator', 'admin', true);

-- Insert default concrete types
INSERT INTO concrete_types (name, category, psi_strength, slump_rating, base_cost_per_yard, standard_price_per_yard) VALUES
('Standard 3000 PSI', 'standard', 3000, '4-6 inches', 70.00, 120.00),
('Standard 4000 PSI', 'standard', 4000, '4-6 inches', 75.00, 125.00),
('High Strength 5000 PSI', 'high_strength', 5000, '3-5 inches', 85.00, 140.00),
('Fiber Reinforced 4000 PSI', 'fiber_reinforced', 4000, '4-6 inches', 90.00, 150.00),
('Self-Consolidating', 'self_consolidating', 4000, 'Flowable', 95.00, 160.00);

-- Insert system configuration defaults
INSERT INTO system_config (config_key, config_value, description) VALUES
('company_name', 'ABC Concrete Company', 'Company name for reports and invoices'),
('base_manufacturing_cost', '70.00', 'Base manufacturing cost per cubic yard'),
('default_profit_margin_target', '25.0', 'Target profit margin percentage'),
('fuel_surcharge_rate', '5.00', 'Fuel surcharge per cubic yard'),
('overtime_multiplier', '1.5', 'Overtime wage multiplier');

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_concrete_types_updated_at BEFORE UPDATE ON concrete_types
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sales_updated_at BEFORE UPDATE ON sales
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_costs_updated_at BEFORE UPDATE ON costs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE sales IS 'Individual concrete delivery transactions';
COMMENT ON TABLE costs IS 'All cost entries associated with projects and sales';
COMMENT ON TABLE manufacturing_cost_templates IS 'Standard manufacturing costs per concrete type';
COMMENT ON TABLE daily_production_summary IS 'Aggregated daily production and financial metrics';
COMMENT ON VIEW sales_with_profit IS 'Complete sales data with calculated profit margins';
COMMENT ON VIEW project_profitability IS 'Project-level profitability analysis';

COMMENT ON COLUMN sales.concrete_yards IS 'Cubic yards of concrete delivered';
COMMENT ON COLUMN sales.unit_price IS 'Price per cubic yard charged to customer';
COMMENT ON COLUMN costs.is_direct_cost IS 'True for costs directly attributable to specific projects';
COMMENT ON COLUMN manufacturing_cost_templates.total_manufacturing_cost IS 'Total cost to manufacture one cubic yard';