# Cost Projections Backend Specification - Mixed Cost Basis

*Updated: 2025-08-10 - Mixed Cost Basis Implementation*

## Overview

The cost projections backend has been completely restructured to support **mixed cost basis** calculations:

- **Manufacturing Costs**: Remain **per-yard** basis ($70/yard baseline)
- **Labor Costs**: Changed to **lump sum** basis (total amount for selected period)
- **Fixed Costs**: Changed to **lump sum** basis (total amount for selected period)

This mixed approach aligns with how concrete businesses actually plan and budget their operations.

## Cost Projection Architecture

### 1. Mixed Cost Basis Model

```typescript
interface CostProjectionModel {
  // Manufacturing: Per-yard basis
  manufacturing: {
    basis: 'per_yard';
    historical: {
      averageCostPerYard: number;    // Historical average
      totalVolume: number;           // Cubic yards delivered
      totalCost: number;             // Total manufacturing cost
    };
    projected: {
      costPerYard: number;           // User input per-yard cost
      estimatedVolume: number;       // Projected volume
      totalProjectedCost: number;    // Calculated: costPerYard * volume
    };
  };
  
  // Labor: Lump sum basis  
  labor: {
    basis: 'lump_sum';
    historical: {
      totalCost: number;             // Total labor costs for period
      monthlyAverage: number;        // Average per month
      selectedMonthsTotal: number;   // Sum of selected months
    };
    projected: {
      totalProjectedCost: number;    // Direct lump sum input
      impliedPerYard: number;        // For reference: total/volume
    };
  };
  
  // Fixed: Lump sum basis
  fixed: {
    basis: 'lump_sum'; 
    historical: {
      totalCost: number;             // Total fixed costs for period
      monthlyAverage: number;        // Average per month
      selectedMonthsTotal: number;   // Sum of selected months
    };
    projected: {
      totalProjectedCost: number;    // Direct lump sum input
      impliedPerYard: number;        // For reference: total/volume
    };
  };
}
```

## Database Schema Changes

### New Tables

#### 1. Cost Projection Sessions
```sql
CREATE TABLE cost_projection_sessions (
  id UUID PRIMARY KEY,
  session_name VARCHAR(255),
  created_by UUID REFERENCES users(id),
  
  -- Historical analysis parameters
  selected_months TEXT[], -- ['2024-01', '2024-02', '2024-03']
  historical_start_date DATE,
  historical_end_date DATE,
  
  -- Volume data
  historical_total_volume DECIMAL(10,2),
  estimated_future_volume DECIMAL(10,2),
  
  -- Profit goal (lump sum for entire period)
  profit_goal_total DECIMAL(12,2),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. Mixed Cost Projections
```sql
CREATE TABLE cost_projections (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES cost_projection_sessions(id),
  
  cost_category cost_category_enum, -- manufacturing, labor, fixed
  cost_basis VARCHAR(20) CHECK (cost_basis IN ('per_yard', 'lump_sum')),
  
  -- Historical data
  historical_total_cost DECIMAL(12,2),
  historical_cost_per_yard DECIMAL(8,4), -- NULL for lump_sum
  historical_monthly_average DECIMAL(10,2), -- For lump_sum costs
  
  -- Projected data
  projected_cost_per_yard DECIMAL(8,4), -- NULL for lump_sum
  projected_total_cost DECIMAL(12,2),   -- User input for lump_sum
  projected_volume DECIMAL(10,2),       -- For per_yard calculations
  
  -- Variance
  cost_variance DECIMAL(12,2),
  variance_percentage DECIMAL(5,2),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### 1. Historical Analysis (Step 1)

```typescript
GET /api/v1/cost-projections/historical-analysis
Query: { selectedMonths: string[] } // ['2024-01', '2024-02']

Response: {
  success: true,
  data: {
    period: {
      startDate: string,
      endDate: string, 
      totalVolume: number,
      monthlyBreakdown: Array<{
        month: string,
        volume: number,
        revenue: number,
        costs: number,
        profit: number
      }>
    },
    costBreakdown: {
      manufacturing: {
        totalCost: number,
        averageCostPerYard: number, // Historical per-yard average
        percentage: number
      },
      labor: {
        totalCost: number,           // Total lump sum for period
        monthlyAverage: number,      // Average per month
        percentage: number
      },
      fixed: {
        totalCost: number,           // Total lump sum for period  
        monthlyAverage: number,      // Average per month
        percentage: number
      }
    },
    profitability: {
      totalRevenue: number,
      totalCosts: number, 
      netProfit: number,
      profitMargin: number
    }
  }
}
```

### 2. Cost Projection Creation (Step 3)

```typescript
POST /api/v1/cost-projections/create
Body: {
  selectedMonths: string[],
  estimatedVolume: number,
  projectedCosts: {
    manufacturing: {
      costPerYard: number        // Per-yard input
    },
    labor: {
      totalCost: number          // Lump sum input
    },
    fixed: {
      totalCost: number          // Lump sum input  
    }
  },
  profitGoal?: number            // Total profit goal (lump sum)
}

Response: {
  success: true,
  data: {
    projectionId: string,
    historical: {
      manufacturing: { total: number, perYard: number },
      labor: { total: number, monthlyAverage: number },
      fixed: { total: number, monthlyAverage: number },
      totals: { revenue: number, costs: number, profit: number }
    },
    projected: {
      manufacturing: { 
        costPerYard: number,
        totalCost: number        // calculated: costPerYard * volume
      },
      labor: {
        totalCost: number,       // direct input
        impliedPerYard: number   // for reference: total/volume
      },
      fixed: {
        totalCost: number,       // direct input
        impliedPerYard: number   // for reference: total/volume
      },
      totals: {
        totalCosts: number,
        projectedProfit: number,
        projectedMargin: number
      }
    },
    variance: {
      manufacturingVariance: number,
      laborVariance: number,
      fixedVariance: number,
      totalCostVariance: number,
      profitVariance: number
    }
  }
}
```

## Business Logic Implementation

### 1. Cost Calculation Service

```typescript
class CostProjectionService {
  
  // Calculate historical averages with mixed basis
  async calculateHistoricalCosts(selectedMonths: string[]): Promise<HistoricalCosts> {
    const historicalData = await this.getHistoricalData(selectedMonths);
    
    return {
      manufacturing: {
        basis: 'per_yard',
        totalCost: sum(historicalData.map(d => d.manufacturingCosts)),
        averageCostPerYard: average(historicalData.map(d => d.manufacturingCostPerYard)),
        totalVolume: sum(historicalData.map(d => d.volume))
      },
      labor: {
        basis: 'lump_sum', 
        totalCost: sum(historicalData.map(d => d.laborCosts)),
        monthlyAverage: average(historicalData.map(d => d.laborCosts)),
        selectedMonthsTotal: sum(historicalData.map(d => d.laborCosts))
      },
      fixed: {
        basis: 'lump_sum',
        totalCost: sum(historicalData.map(d => d.fixedCosts)), 
        monthlyAverage: average(historicalData.map(d => d.fixedCosts)),
        selectedMonthsTotal: sum(historicalData.map(d => d.fixedCosts))
      }
    };
  }
  
  // Calculate projected costs with mixed basis
  async calculateProjectedCosts(projectionData: ProjectionInput): Promise<ProjectedCosts> {
    const { estimatedVolume, projectedCosts } = projectionData;
    
    return {
      manufacturing: {
        costPerYard: projectedCosts.manufacturing.costPerYard,
        totalCost: projectedCosts.manufacturing.costPerYard * estimatedVolume // calculated
      },
      labor: {
        totalCost: projectedCosts.labor.totalCost, // direct input
        impliedPerYard: projectedCosts.labor.totalCost / estimatedVolume // for reference
      },
      fixed: {
        totalCost: projectedCosts.fixed.totalCost, // direct input  
        impliedPerYard: projectedCosts.fixed.totalCost / estimatedVolume // for reference
      }
    };
  }
  
  // Calculate variance between historical and projected
  calculateVariance(historical: HistoricalCosts, projected: ProjectedCosts): CostVariance {
    return {
      manufacturingVariance: projected.manufacturing.totalCost - historical.manufacturing.totalCost,
      laborVariance: projected.labor.totalCost - historical.labor.totalCost,
      fixedVariance: projected.fixed.totalCost - historical.fixed.totalCost,
      totalVariance: (projected.manufacturing.totalCost + projected.labor.totalCost + projected.fixed.totalCost) - 
                    (historical.manufacturing.totalCost + historical.labor.totalCost + historical.fixed.totalCost)
    };
  }
}
```

### 2. Database Functions

```sql
-- Function to calculate mixed cost projections
CREATE OR REPLACE FUNCTION calculate_mixed_cost_projection(
  p_session_id UUID,
  p_manufacturing_per_yard DECIMAL(8,4),
  p_labor_total DECIMAL(12,2),
  p_fixed_total DECIMAL(12,2),
  p_estimated_volume DECIMAL(10,2)
)
RETURNS void AS $$
DECLARE
  v_manufacturing_total DECIMAL(12,2);
BEGIN
  -- Calculate manufacturing total (per-yard * volume)
  v_manufacturing_total := p_manufacturing_per_yard * p_estimated_volume;
  
  -- Insert/Update manufacturing projection (per-yard basis)
  INSERT INTO cost_projections (
    session_id, cost_category, cost_basis,
    projected_cost_per_yard, projected_volume, projected_total_cost
  ) VALUES (
    p_session_id, 'manufacturing', 'per_yard',
    p_manufacturing_per_yard, p_estimated_volume, v_manufacturing_total
  )
  ON CONFLICT (session_id, cost_category) DO UPDATE SET
    projected_cost_per_yard = EXCLUDED.projected_cost_per_yard,
    projected_volume = EXCLUDED.projected_volume,
    projected_total_cost = EXCLUDED.projected_total_cost;
  
  -- Insert/Update labor projection (lump sum basis)
  INSERT INTO cost_projections (
    session_id, cost_category, cost_basis, projected_total_cost
  ) VALUES (
    p_session_id, 'labor', 'lump_sum', p_labor_total
  )
  ON CONFLICT (session_id, cost_category) DO UPDATE SET
    projected_total_cost = EXCLUDED.projected_total_cost;
  
  -- Insert/Update fixed projection (lump sum basis)
  INSERT INTO cost_projections (
    session_id, cost_category, cost_basis, projected_total_cost
  ) VALUES (
    p_session_id, 'fixed', 'lump_sum', p_fixed_total
  )
  ON CONFLICT (session_id, cost_category) DO UPDATE SET
    projected_total_cost = EXCLUDED.projected_total_cost;
    
END;
$$ LANGUAGE plpgsql;
```

## Frontend Integration

### UI Components

```typescript
// Two-column comparison component (user-validated pattern)
const CostProjectionComparison = ({ historicalData, projectedData, onUpdate }) => (
  <Grid container spacing={3}>
    {/* Historical Period (Read-only) */}
    <Grid item xs={12} md={6}>
      <Paper>
        <Typography variant="h6">Previous Period (Historical Average)</Typography>
        
        {/* Manufacturing - show per-yard */}
        <CostItem
          label="Concrete Manufacturing"
          value={`$${historicalData.manufacturing.averageCostPerYard}/yard`}
          total={`Total: $${historicalData.manufacturing.totalCost.toLocaleString()}`}
          readonly
        />
        
        {/* Labor - show lump sum */}
        <CostItem  
          label="Labor Costs"
          value={`$${historicalData.labor.totalCost.toLocaleString()} total`}
          detail={`Avg: $${historicalData.labor.monthlyAverage.toLocaleString()}/month`}
          readonly
        />
        
        {/* Fixed - show lump sum */}
        <CostItem
          label="Fixed Costs" 
          value={`$${historicalData.fixed.totalCost.toLocaleString()} total`}
          detail={`Avg: $${historicalData.fixed.monthlyAverage.toLocaleString()}/month`}
          readonly
        />
      </Paper>
    </Grid>
    
    {/* Future Period (Editable) */}
    <Grid item xs={12} md={6}>
      <Paper>
        <Typography variant="h6">Future Period (Your Projections)</Typography>
        
        {/* Manufacturing - per-yard input */}
        <CostInput
          label="Concrete Manufacturing"
          value={projectedData.manufacturing.costPerYard}
          onChange={(value) => onUpdate('manufacturing', { costPerYard: value })}
          suffix="/yard"
          calculated={`Total: $${(projectedData.manufacturing.costPerYard * estimatedVolume).toLocaleString()}`}
        />
        
        {/* Labor - lump sum input */}
        <CostInput
          label="Labor Costs"
          value={projectedData.labor.totalCost}
          onChange={(value) => onUpdate('labor', { totalCost: value })}
          suffix="total"
          calculated={`Per yard: $${(projectedData.labor.totalCost / estimatedVolume).toFixed(2)}`}
        />
        
        {/* Fixed - lump sum input */}
        <CostInput
          label="Fixed Costs"
          value={projectedData.fixed.totalCost}
          onChange={(value) => onUpdate('fixed', { totalCost: value })}
          suffix="total"
          calculated={`Per yard: $${(projectedData.fixed.totalCost / estimatedVolume).toFixed(2)}`}
        />
      </Paper>
    </Grid>
  </Grid>
);
```

## Key Benefits

### 1. Business Logic Alignment
- **Manufacturing costs** remain per-yard (aligns with industry pricing)
- **Labor costs** as lump sums (aligns with project budgeting)
- **Fixed costs** as lump sums (aligns with period budgeting)

### 2. User Experience
- **Two-column comparison** layout (strongly validated by user testing)
- **Clear visual distinction** between historical and projected costs
- **Mixed input types** match real business planning workflows

### 3. Technical Implementation
- **Database flexibility** with `cost_basis` field
- **API consistency** with mixed calculation methods
- **Frontend simplicity** with appropriate input controls

## Migration Strategy

### Phase 1: Database Updates
1. Deploy new cost projection tables
2. Add `cost_basis` column to existing costs table
3. Create calculation functions and views

### Phase 2: API Implementation
1. Update Cost Management Service
2. Implement new projection endpoints
3. Add mixed cost calculation logic

### Phase 3: Frontend Updates
1. Update cost projection UI components
2. Implement two-column comparison layout
3. Add appropriate input controls for mixed basis

This mixed cost basis approach provides the flexibility needed for concrete industry cost planning while maintaining the user-validated two-column comparison interface.