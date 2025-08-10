-- DATABASE SCHEMA UPDATE: Mixed Cost Basis Support
-- Concrete Sales & Profit Analyzer - Cost Projections Enhancement
-- This update adds support for mixed cost basis: per-yard (manufacturing) vs lump sum (labor, fixed)

-- =============================================
-- COST PROJECTIONS ENHANCEMENT TABLES
-- =============================================

-- Cost Projection Sessions (User Analysis Sessions)
CREATE TABLE cost_projection_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_name VARCHAR(255),
  created_by UUID NOT NULL REFERENCES users(id),
  
  -- Historical analysis parameters
  selected_months TEXT[] NOT NULL, -- Array of month strings: ['2024-01', '2024-02']
  historical_start_date DATE NOT NULL,
  historical_end_date DATE NOT NULL,
  
  -- Volume data
  historical_total_volume DECIMAL(10,2) NOT NULL,
  estimated_future_volume DECIMAL(10,2) NOT NULL,
  
  -- Profit goal (lump sum for all selected months)
  profit_goal_total DECIMAL(12,2),
  
  -- Session metadata
  is_active BOOLEAN DEFAULT true,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Mixed Cost Projections (Per-Yard vs Lump Sum)
CREATE TABLE cost_projections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES cost_projection_sessions(id) ON DELETE CASCADE,
  
  -- Cost category and basis type
  cost_category cost_category_enum NOT NULL,
  cost_basis VARCHAR(20) NOT NULL CHECK (cost_basis IN ('per_yard', 'lump_sum')),
  
  -- Historical data (calculated from actual costs)
  historical_total_cost DECIMAL(12,2) NOT NULL,
  historical_volume DECIMAL(10,2), -- NULL for lump sum costs
  historical_cost_per_yard DECIMAL(8,4), -- NULL for lump sum costs
  historical_monthly_average DECIMAL(10,2), -- For lump sum costs
  
  -- Projected data (user input)
  projected_cost_per_yard DECIMAL(8,4), -- NULL for lump sum costs
  projected_total_cost DECIMAL(12,2), -- User input for lump sum, calculated for per_yard
  projected_volume DECIMAL(10,2), -- Same as session volume for per_yard costs
  
  -- Calculated fields
  cost_variance DECIMAL(12,2), -- Difference between projected and historical total costs
  variance_percentage DECIMAL(5,2), -- Percentage change
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cost Projection Summary Cache (For Performance)
CREATE TABLE cost_projection_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES cost_projection_sessions(id) ON DELETE CASCADE,
  
  -- Historical totals
  historical_manufacturing_cost DECIMAL(12,2) NOT NULL,
  historical_labor_cost DECIMAL(12,2) NOT NULL,
  historical_fixed_cost DECIMAL(12,2) NOT NULL,
  historical_total_cost DECIMAL(12,2) NOT NULL,
  historical_revenue DECIMAL(12,2) NOT NULL,
  historical_profit DECIMAL(12,2) NOT NULL,
  historical_profit_margin DECIMAL(5,2) NOT NULL,
  
  -- Projected totals
  projected_manufacturing_cost DECIMAL(12,2) NOT NULL,
  projected_labor_cost DECIMAL(12,2) NOT NULL,
  projected_fixed_cost DECIMAL(12,2) NOT NULL,
  projected_total_cost DECIMAL(12,2) NOT NULL,
  projected_revenue DECIMAL(12,2), -- Estimated
  projected_profit DECIMAL(12,2), -- Calculated or from goal
  projected_profit_margin DECIMAL(5,2),
  
  -- Variance analysis
  cost_variance_total DECIMAL(12,2),
  profit_variance DECIMAL(12,2),
  margin_variance DECIMAL(5,2),
  
  -- Performance metrics
  break_even_volume DECIMAL(10,2),
  break_even_price_per_yard DECIMAL(8,2),
  
  last_calculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Historical Month Analysis (Detailed Breakdown)
CREATE TABLE historical_month_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES cost_projection_sessions(id) ON DELETE CASCADE,
  
  -- Month identifier
  month_year VARCHAR(7) NOT NULL, -- Format: '2024-01'
  month_start_date DATE NOT NULL,
  month_end_date DATE NOT NULL,
  
  -- Volume and revenue
  total_volume DECIMAL(10,2) NOT NULL,
  total_revenue DECIMAL(12,2) NOT NULL,
  average_price_per_yard DECIMAL(8,2),
  
  -- Cost breakdown by category
  manufacturing_costs DECIMAL(10,2) NOT NULL,
  labor_costs DECIMAL(10,2) NOT NULL,
  fixed_costs DECIMAL(10,2) NOT NULL,
  equipment_costs DECIMAL(10,2) DEFAULT 0,
  fuel_costs DECIMAL(10,2) DEFAULT 0,
  other_costs DECIMAL(10,2) DEFAULT 0,
  total_costs DECIMAL(10,2) NOT NULL,
  
  -- Profitability
  gross_profit DECIMAL(10,2) NOT NULL,
  profit_margin DECIMAL(5,2) NOT NULL,
  
  -- Per-yard metrics
  manufacturing_cost_per_yard DECIMAL(8,4),
  total_cost_per_yard DECIMAL(8,4),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- UPDATED COST BASIS ENUM AND CONSTRAINTS
-- =============================================

-- Add cost basis type to existing costs table (for future use)
ALTER TABLE costs ADD COLUMN cost_basis VARCHAR(20) DEFAULT 'per_yard' 
  CHECK (cost_basis IN ('per_yard', 'lump_sum', 'percentage', 'fixed_amount'));

-- Add comments for the new cost basis field
COMMENT ON COLUMN costs.cost_basis IS 'How this cost should be calculated: per_yard, lump_sum, percentage, or fixed_amount';

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Cost projection session indexes
CREATE INDEX idx_cost_projection_sessions_user ON cost_projection_sessions(created_by);
CREATE INDEX idx_cost_projection_sessions_dates ON cost_projection_sessions(historical_start_date, historical_end_date);
CREATE INDEX idx_cost_projection_sessions_active ON cost_projection_sessions(is_active, created_by);

-- Cost projections indexes
CREATE INDEX idx_cost_projections_session ON cost_projections(session_id);
CREATE INDEX idx_cost_projections_category_basis ON cost_projections(cost_category, cost_basis);

-- Summary cache indexes
CREATE INDEX idx_cost_projection_summary_session ON cost_projection_summary(session_id);
CREATE INDEX idx_cost_projection_summary_calculated ON cost_projection_summary(last_calculated);

-- Historical analysis indexes
CREATE INDEX idx_historical_month_analysis_session ON historical_month_analysis(session_id);
CREATE INDEX idx_historical_month_analysis_month ON historical_month_analysis(month_year);
CREATE INDEX idx_historical_month_analysis_dates ON historical_month_analysis(month_start_date, month_end_date);

-- =============================================
-- VIEWS FOR COST PROJECTIONS
-- =============================================

-- Complete Cost Projection Analysis View
CREATE OR REPLACE VIEW cost_projection_analysis AS
SELECT 
  s.id as session_id,
  s.session_name,
  s.selected_months,
  s.historical_start_date,
  s.historical_end_date,
  s.historical_total_volume,
  s.estimated_future_volume,
  s.profit_goal_total,
  
  -- User information
  u.first_name || ' ' || u.last_name as created_by_name,
  s.created_at,
  s.last_updated,
  
  -- Summary data
  sum.historical_total_cost,
  sum.historical_profit,
  sum.historical_profit_margin,
  sum.projected_total_cost,
  sum.projected_profit,
  sum.projected_profit_margin,
  sum.cost_variance_total,
  sum.profit_variance,
  sum.margin_variance,
  
  -- Manufacturing (per-yard) projections
  mfg.historical_cost_per_yard as manufacturing_historical_per_yard,
  mfg.projected_cost_per_yard as manufacturing_projected_per_yard,
  mfg.projected_total_cost as manufacturing_projected_total,
  
  -- Labor (lump sum) projections  
  labor.historical_total_cost as labor_historical_total,
  labor.projected_total_cost as labor_projected_total,
  labor.cost_variance as labor_variance,
  
  -- Fixed (lump sum) projections
  fixed.historical_total_cost as fixed_historical_total,
  fixed.projected_total_cost as fixed_projected_total,
  fixed.cost_variance as fixed_variance

FROM cost_projection_sessions s
LEFT JOIN users u ON s.created_by = u.id
LEFT JOIN cost_projection_summary sum ON s.id = sum.session_id
LEFT JOIN cost_projections mfg ON s.id = mfg.session_id AND mfg.cost_category = 'manufacturing'
LEFT JOIN cost_projections labor ON s.id = labor.session_id AND labor.cost_category = 'labor'  
LEFT JOIN cost_projections fixed ON s.id = fixed.session_id AND fixed.cost_category = 'fixed'
WHERE s.is_active = true;

-- Monthly Historical Performance View
CREATE OR REPLACE VIEW monthly_cost_breakdown AS
SELECT 
  h.session_id,
  h.month_year,
  h.total_volume,
  h.total_revenue,
  
  -- Cost breakdown
  h.manufacturing_costs,
  h.labor_costs,
  h.fixed_costs,
  h.total_costs,
  
  -- Per-yard calculations
  h.manufacturing_cost_per_yard,
  CASE WHEN h.total_volume > 0 
    THEN h.labor_costs / h.total_volume 
    ELSE 0 
  END as labor_cost_per_yard_equivalent,
  CASE WHEN h.total_volume > 0 
    THEN h.fixed_costs / h.total_volume 
    ELSE 0 
  END as fixed_cost_per_yard_equivalent,
  h.total_cost_per_yard,
  
  -- Profitability
  h.gross_profit,
  h.profit_margin,
  
  -- Rankings
  ROW_NUMBER() OVER (PARTITION BY h.session_id ORDER BY h.profit_margin DESC) as profitability_rank,
  ROW_NUMBER() OVER (PARTITION BY h.session_id ORDER BY h.total_volume DESC) as volume_rank

FROM historical_month_analysis h
ORDER BY h.session_id, h.month_start_date;

-- =============================================
-- FUNCTIONS FOR COST PROJECTIONS
-- =============================================

-- Function to calculate mixed cost projections
CREATE OR REPLACE FUNCTION calculate_cost_projection_summary(p_session_id UUID)
RETURNS void AS $$
DECLARE
  v_historical_volume DECIMAL(10,2);
  v_projected_volume DECIMAL(10,2);
  v_manufacturing_proj DECIMAL(12,2);
  v_labor_proj DECIMAL(12,2);
  v_fixed_proj DECIMAL(12,2);
  v_total_proj_cost DECIMAL(12,2);
BEGIN
  -- Get session volume data
  SELECT historical_total_volume, estimated_future_volume
  INTO v_historical_volume, v_projected_volume
  FROM cost_projection_sessions
  WHERE id = p_session_id;
  
  -- Calculate projected costs
  SELECT 
    COALESCE(SUM(CASE WHEN cost_category = 'manufacturing' THEN projected_total_cost ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN cost_category = 'labor' THEN projected_total_cost ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN cost_category = 'fixed' THEN projected_total_cost ELSE 0 END), 0)
  INTO v_manufacturing_proj, v_labor_proj, v_fixed_proj
  FROM cost_projections
  WHERE session_id = p_session_id;
  
  v_total_proj_cost := v_manufacturing_proj + v_labor_proj + v_fixed_proj;
  
  -- Update or insert summary
  INSERT INTO cost_projection_summary (
    session_id,
    projected_manufacturing_cost,
    projected_labor_cost, 
    projected_fixed_cost,
    projected_total_cost,
    last_calculated
  ) VALUES (
    p_session_id,
    v_manufacturing_proj,
    v_labor_proj,
    v_fixed_proj,
    v_total_proj_cost,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (session_id) DO UPDATE SET
    projected_manufacturing_cost = EXCLUDED.projected_manufacturing_cost,
    projected_labor_cost = EXCLUDED.projected_labor_cost,
    projected_fixed_cost = EXCLUDED.projected_fixed_cost,
    projected_total_cost = EXCLUDED.projected_total_cost,
    last_calculated = EXCLUDED.last_calculated;
    
END;
$$ LANGUAGE plpgsql;

-- Function to update projected totals when per-yard costs change
CREATE OR REPLACE FUNCTION update_manufacturing_projected_total()
RETURNS TRIGGER AS $$
BEGIN
  -- For manufacturing (per_yard basis), calculate total from per-yard cost and volume
  IF NEW.cost_category = 'manufacturing' AND NEW.cost_basis = 'per_yard' THEN
    NEW.projected_total_cost := NEW.projected_cost_per_yard * NEW.projected_volume;
  END IF;
  
  -- For lump sum costs, ensure per-yard calculation is NULL
  IF NEW.cost_basis = 'lump_sum' THEN
    NEW.projected_cost_per_yard := NULL;
    NEW.projected_volume := NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to cost projections
CREATE TRIGGER trigger_update_manufacturing_totals 
  BEFORE INSERT OR UPDATE ON cost_projections
  FOR EACH ROW EXECUTE FUNCTION update_manufacturing_projected_total();

-- =============================================
-- SEED DATA FOR TESTING
-- =============================================

-- Insert sample cost projection session for testing
INSERT INTO cost_projection_sessions (
  session_name,
  created_by,
  selected_months,
  historical_start_date,
  historical_end_date,
  historical_total_volume,
  estimated_future_volume,
  profit_goal_total
) VALUES (
  'Q1 2024 Analysis',
  (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
  ARRAY['2024-01', '2024-02', '2024-03'],
  '2024-01-01',
  '2024-03-31', 
  1500.00,
  1800.00,
  125000.00
);

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE cost_projection_sessions IS 'User analysis sessions with selected historical months and projection parameters';
COMMENT ON TABLE cost_projections IS 'Mixed cost basis projections - per-yard for manufacturing, lump sum for labor/fixed';
COMMENT ON TABLE cost_projection_summary IS 'Cached calculation results for cost projection analysis';
COMMENT ON TABLE historical_month_analysis IS 'Detailed breakdown of historical performance by month';

COMMENT ON COLUMN cost_projections.cost_basis IS 'per_yard for manufacturing costs, lump_sum for labor/fixed costs';
COMMENT ON COLUMN cost_projections.projected_cost_per_yard IS 'Used only for per_yard basis (manufacturing)';
COMMENT ON COLUMN cost_projections.projected_total_cost IS 'Direct input for lump_sum, calculated for per_yard';
COMMENT ON COLUMN cost_projection_sessions.profit_goal_total IS 'Total profit goal for all selected months combined (lump sum)';