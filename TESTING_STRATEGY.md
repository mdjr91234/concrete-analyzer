# Testing Strategy - Concrete Sales & Profit Analyzer

## Testing Philosophy

### Core Principles
- **Industry-Specific Validation**: Test concrete business logic and cost calculations
- **Data Accuracy**: Ensure financial calculations are precise and reliable
- **User-Centric Testing**: Validate real-world concrete industry workflows
- **Performance Under Load**: Test with realistic data volumes (10K+ sales records)
- **Cross-Browser Compatibility**: Support modern browsers used in construction offices

### Quality Gates
- **Unit Tests**: 90% code coverage minimum
- **Integration Tests**: 80% critical path coverage
- **End-to-End Tests**: 100% user workflow coverage
- **Performance Tests**: Sub-500ms response times for analytics
- **Security Tests**: OWASP compliance validation

## Unit Testing Strategy

### Backend Unit Testing (Node.js/TypeScript)

#### 1. Cost Calculation Engine Tests
```typescript
describe('Cost Calculation Engine', () => {
  describe('Manufacturing Cost Calculation', () => {
    it('should calculate standard concrete cost at $70/yard baseline', () => {
      const result = calculateManufacturingCost({
        concreteType: 'Standard 4000 PSI',
        yards: 25.5,
        effectiveDate: '2024-01-15'
      });
      
      expect(result.costPerYard).toBe(70.00);
      expect(result.totalCost).toBe(1785.00); // 25.5 * 70
      expect(result.breakdown).toEqual({
        cement: expect.any(Number),
        aggregate: expect.any(Number),
        additives: expect.any(Number),
        overhead: expect.any(Number)
      });
    });

    it('should handle high-strength concrete premium pricing', () => {
      const result = calculateManufacturingCost({
        concreteType: 'High Strength 5000 PSI',
        yards: 10.0,
        effectiveDate: '2024-01-15'
      });
      
      expect(result.costPerYard).toBe(85.00);
      expect(result.totalCost).toBe(850.00);
    });

    it('should apply seasonal cost adjustments', () => {
      const winterResult = calculateManufacturingCost({
        concreteType: 'Standard 4000 PSI',
        yards: 20.0,
        effectiveDate: '2024-12-15' // Winter date
      });
      
      const summerResult = calculateManufacturingCost({
        concreteType: 'Standard 4000 PSI',
        yards: 20.0,
        effectiveDate: '2024-06-15' // Summer date
      });
      
      expect(winterResult.costPerYard).toBeGreaterThan(summerResult.costPerYard);
    });
  });

  describe('Profit Margin Calculation', () => {
    it('should calculate profit margin correctly', () => {
      const saleData = {
        revenue: 3125.00,
        costs: 2343.75
      };
      
      const result = calculateProfitMargin(saleData);
      
      expect(result.grossProfit).toBe(781.25);
      expect(result.profitMargin).toBeCloseTo(25.0, 1); // 25% margin
      expect(result.profitPerYard).toBeCloseTo(31.25, 2);
    });

    it('should handle zero and negative margins', () => {
      const breakEvenSale = { revenue: 1000.00, costs: 1000.00 };
      const lossSale = { revenue: 1000.00, costs: 1200.00 };
      
      expect(calculateProfitMargin(breakEvenSale).profitMargin).toBe(0);
      expect(calculateProfitMargin(lossSale).profitMargin).toBe(-20.0);
    });
  });

  describe('Cost Allocation', () => {
    it('should allocate indirect costs across projects proportionally', () => {
      const projects = [
        { id: 'PROJ-001', totalYards: 100.0 },
        { id: 'PROJ-002', totalYards: 200.0 },
        { id: 'PROJ-003', totalYards: 50.0 }
      ];
      
      const indirectCosts = 1750.00; // $5/yard average
      
      const allocations = allocateIndirectCosts(projects, indirectCosts);
      
      expect(allocations['PROJ-001']).toBeCloseTo(500.00, 2);
      expect(allocations['PROJ-002']).toBeCloseTo(1000.00, 2);
      expect(allocations['PROJ-003']).toBeCloseTo(250.00, 2);
      
      // Total should equal original amount
      const totalAllocated = Object.values(allocations).reduce((sum, amt) => sum + amt, 0);
      expect(totalAllocated).toBeCloseTo(indirectCosts, 2);
    });
  });
});
```

#### 2. Business Logic Validation Tests
```typescript
describe('Sales Business Logic', () => {
  describe('Sale Validation', () => {
    it('should validate concrete yards within realistic ranges', () => {
      const validSale = { concreteYards: 25.5, unitPrice: 125.00 };
      const oversizedSale = { concreteYards: 250.0, unitPrice: 125.00 };
      const undersizedSale = { concreteYards: 0.05, unitPrice: 125.00 };
      
      expect(validateSaleData(validSale).isValid).toBe(true);
      expect(validateSaleData(oversizedSale).errors).toContain('Concrete yards exceed maximum delivery capacity');
      expect(validateSaleData(undersizedSale).errors).toContain('Minimum delivery is 0.1 cubic yards');
    });

    it('should validate pricing within market ranges', () => {
      const reasonablePrice = { concreteYards: 20.0, unitPrice: 125.00 };
      const lowPrice = { concreteYards: 20.0, unitPrice: 45.00 };
      const highPrice = { concreteYards: 20.0, unitPrice: 350.00 };
      
      expect(validateSaleData(reasonablePrice).isValid).toBe(true);
      expect(validateSaleData(lowPrice).warnings).toContain('Price below market average');
      expect(validateSaleData(highPrice).warnings).toContain('Price above typical range');
    });
  });

  describe('Project Management', () => {
    it('should track project completion accurately', () => {
      const project = createMockProject({
        estimatedYards: 500.0,
        contractAmount: 62500.00
      });
      
      // Add deliveries
      addSaleToProject(project, { yards: 125.0, revenue: 15625.00 });
      addSaleToProject(project, { yards: 100.0, revenue: 12500.00 });
      
      const status = getProjectStatus(project);
      
      expect(status.completionPercentage).toBe(45.0); // 225/500 yards
      expect(status.revenuePercentage).toBe(45.0); // 28125/62500 revenue
      expect(status.onBudget).toBe(true);
    });
  });
});
```

#### 3. Data Processing Tests
```typescript
describe('Data Processing', () => {
  describe('CSV Import', () => {
    it('should parse concrete industry CSV format correctly', () => {
      const csvData = `
Date,Customer,Project,Yards,Type,Price,Address
2024-01-15,"ABC Construction","PROJ-001",25.5,"Standard 4000 PSI",125.00,"123 Main St"
2024-01-16,"XYZ Builders","PROJ-002",30.0,"High Strength 5000 PSI",140.00,"456 Oak Ave"
      `.trim();
      
      const result = parseSalesCSV(csvData);
      
      expect(result.successful).toHaveLength(2);
      expect(result.errors).toHaveLength(0);
      expect(result.successful[0]).toMatchObject({
        saleDate: '2024-01-15',
        customerName: 'ABC Construction',
        concreteYards: 25.5,
        unitPrice: 125.00
      });
    });

    it('should handle malformed data gracefully', () => {
      const badCsvData = `
Date,Customer,Project,Yards,Type,Price
2024-13-45,"ABC Construction","PROJ-001",-25.5,"Invalid Type",abc
2024-01-16,"","PROJ-002",30.0,"Standard 4000 PSI",140.00
      `.trim();
      
      const result = parseSalesCSV(badCsvData);
      
      expect(result.errors).toHaveLength(2);
      expect(result.errors[0]).toContain('Invalid date format');
      expect(result.errors[1]).toContain('Customer name is required');
    });
  });
});
```

### Frontend Unit Testing (React/TypeScript)

#### 1. Component Testing
```typescript
describe('SaleForm Component', () => {
  it('should render all required fields', () => {
    render(<SaleForm onSubmit={mockSubmit} onCancel={mockCancel} />);
    
    expect(screen.getByLabelText(/customer/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/project/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/cubic yards/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/price per yard/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/delivery address/i)).toBeInTheDocument();
  });

  it('should calculate total revenue in real-time', async () => {
    const user = userEvent.setup();
    render(<SaleForm onSubmit={mockSubmit} onCancel={mockCancel} />);
    
    const yardsInput = screen.getByLabelText(/cubic yards/i);
    const priceInput = screen.getByLabelText(/price per yard/i);
    
    await user.clear(yardsInput);
    await user.type(yardsInput, '25.5');
    await user.clear(priceInput);
    await user.type(priceInput, '125.00');
    
    expect(screen.getByText(/total revenue.*\$3,187.50/i)).toBeInTheDocument();
  });

  it('should validate concrete yards input', async () => {
    const user = userEvent.setup();
    render(<SaleForm onSubmit={mockSubmit} onCancel={mockCancel} />);
    
    const yardsInput = screen.getByLabelText(/cubic yards/i);
    
    await user.clear(yardsInput);
    await user.type(yardsInput, '0.05');
    await user.tab(); // Trigger blur event
    
    expect(screen.getByText(/minimum delivery is 0.1 cubic yards/i)).toBeInTheDocument();
    
    await user.clear(yardsInput);
    await user.type(yardsInput, '250');
    await user.tab();
    
    expect(screen.getByText(/exceeds maximum delivery capacity/i)).toBeInTheDocument();
  });
});

describe('ProfitAnalysisChart Component', () => {
  const mockData = [
    { period: '2024-W01', revenue: 15000, profit: 3750, margin: 25.0 },
    { period: '2024-W02', revenue: 18000, profit: 4500, margin: 25.0 },
    { period: '2024-W03', revenue: 22000, profit: 4400, margin: 20.0 }
  ];

  it('should render chart with profit trend data', () => {
    render(<ProfitAnalysisChart data={mockData} />);
    
    expect(screen.getByText(/profit trends/i)).toBeInTheDocument();
    
    // Check that chart elements are present (using data-testid)
    expect(screen.getByTestId('profit-chart')).toBeInTheDocument();
  });

  it('should highlight periods with low margins', () => {
    render(<ProfitAnalysisChart data={mockData} highlightThreshold={22.0} />);
    
    // Week 3 should be highlighted as below threshold
    const lowMarginPoint = screen.getByTestId('chart-point-2024-W03');
    expect(lowMarginPoint).toHaveClass('low-margin-highlight');
  });
});
```

#### 2. Hook Testing
```typescript
describe('useProfitAnalysis Hook', () => {
  it('should fetch and format profit analysis data', async () => {
    const mockApiResponse = {
      summary: { totalRevenue: 89750.00, netProfit: 24550.00 },
      breakdown: { manufacturing: 45640.00, labor: 11780.00 }
    };
    
    mockAPI.getProfitAnalysis.mockResolvedValue(mockApiResponse);
    
    const { result } = renderHook(() => 
      useProfitAnalysis({ startDate: '2024-01-01', endDate: '2024-01-31' })
    );
    
    expect(result.current.loading).toBe(true);
    
    await waitFor(() => {
      expect(result.current.loading).toBe(false);
      expect(result.current.data.summary.totalRevenue).toBe(89750.00);
    });
  });

  it('should handle API errors gracefully', async () => {
    mockAPI.getProfitAnalysis.mockRejectedValue(new Error('Network error'));
    
    const { result } = renderHook(() => 
      useProfitAnalysis({ startDate: '2024-01-01', endDate: '2024-01-31' })
    );
    
    await waitFor(() => {
      expect(result.current.loading).toBe(false);
      expect(result.current.error).toBe('Failed to load profit analysis');
    });
  });
});
```

## Integration Testing Strategy

### API Integration Tests

#### 1. Sales Management Integration
```typescript
describe('Sales API Integration', () => {
  beforeEach(async () => {
    await setupTestDatabase();
    await seedTestData();
  });

  afterEach(async () => {
    await cleanupTestDatabase();
  });

  describe('Sales CRUD Operations', () => {
    it('should create sale with automatic profit calculation', async () => {
      const saleData = {
        projectId: 'TEST-PROJ-001',
        customerId: testCustomer.id,
        saleDate: '2024-01-15',
        concreteTypeId: standardConcreteType.id,
        concreteYards: 25.5,
        unitPrice: 125.00,
        deliveryAddress: '123 Test Street'
      };

      const response = await request(app)
        .post('/api/v1/sales')
        .set('Authorization', `Bearer ${validToken}`)
        .send(saleData)
        .expect(201);

      expect(response.body.data.sale).toMatchObject({
        ...saleData,
        totalRevenue: 3187.50,
        profitMargin: expect.any(Number),
        grossProfit: expect.any(Number)
      });

      // Verify cost calculations
      expect(response.body.data.sale.calculatedCosts).toMatchObject({
        manufacturingCost: 1785.00, // 25.5 * $70
        totalCosts: expect.any(Number)
      });
    });

    it('should update project totals when sale is created', async () => {
      const projectBefore = await getProject('TEST-PROJ-001');
      
      await request(app)
        .post('/api/v1/sales')
        .set('Authorization', `Bearer ${validToken}`)
        .send(testSaleData)
        .expect(201);

      const projectAfter = await getProject('TEST-PROJ-001');
      
      expect(projectAfter.actualTotalYards).toBe(
        projectBefore.actualTotalYards + testSaleData.concreteYards
      );
    });
  });

  describe('Profit Analysis Integration', () => {
    it('should return accurate profit analysis with real data', async () => {
      // Create test sales with known profit margins
      await createTestSales([
        { revenue: 5000.00, costs: 3750.00, date: '2024-01-15' }, // 25% margin
        { revenue: 6000.00, costs: 4200.00, date: '2024-01-20' }, // 30% margin
        { revenue: 4000.00, costs: 3200.00, date: '2024-01-25' }  // 20% margin
      ]);

      const response = await request(app)
        .get('/api/v1/profit/analysis')
        .query({
          startDate: '2024-01-01',
          endDate: '2024-01-31'
        })
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.data.summary).toMatchObject({
        totalRevenue: 15000.00,
        totalCosts: 11150.00,
        netProfit: 3850.00,
        profitMargin: 25.67 // Weighted average
      });
    });
  });
});
```

#### 2. Database Integration Tests
```typescript
describe('Database Integration', () => {
  describe('Complex Queries', () => {
    it('should perform project profitability analysis efficiently', async () => {
      // Create large dataset
      await createBulkTestData({
        projects: 50,
        salesPerProject: 20,
        costsPerSale: 5
      });

      const startTime = Date.now();
      
      const results = await request(app)
        .get('/api/v1/profit/projects/ranking')
        .query({ sortBy: 'profitMargin', limit: 10 })
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      const duration = Date.now() - startTime;
      
      expect(duration).toBeLessThan(500); // Sub-500ms requirement
      expect(results.body.data.projects).toHaveLength(10);
      
      // Verify sorting
      const margins = results.body.data.projects.map(p => p.profitMargin);
      expect(margins).toEqual(margins.sort((a, b) => b - a));
    });

    it('should handle concurrent sale creation without conflicts', async () => {
      const concurrentSales = Array.from({ length: 10 }, (_, i) => 
        request(app)
          .post('/api/v1/sales')
          .set('Authorization', `Bearer ${validToken}`)
          .send({
            ...testSaleData,
            saleDate: `2024-01-${15 + i}`,
            concreteYards: 10 + i
          })
      );

      const results = await Promise.all(concurrentSales);
      
      results.forEach(response => {
        expect(response.status).toBe(201);
      });

      // Verify no duplicate sale numbers
      const saleNumbers = results.map(r => r.body.data.sale.saleNumber);
      expect(new Set(saleNumbers).size).toBe(saleNumbers.length);
    });
  });
});
```

## End-to-End Testing Strategy

### User Workflow Testing (Playwright)

#### 1. Complete Sales Entry Workflow
```typescript
describe('Sales Entry Workflow', () => {
  test('Plant manager enters daily sales data', async ({ page }) => {
    // Login as plant manager
    await page.goto('/login');
    await page.fill('[data-testid="email"]', 'manager@concretecompany.com');
    await page.fill('[data-testid="password"]', 'password123');
    await page.click('[data-testid="login-button"]');

    // Navigate to sales entry
    await page.click('[data-testid="nav-sales"]');
    await page.click('[data-testid="add-sale-button"]');

    // Fill out sale form
    await page.selectOption('[data-testid="customer-select"]', { label: 'ABC Construction' });
    await page.selectOption('[data-testid="project-select"]', { label: 'Downtown Office Building' });
    await page.selectOption('[data-testid="concrete-type-select"]', { label: 'Standard 4000 PSI' });
    
    await page.fill('[data-testid="concrete-yards"]', '25.5');
    await page.fill('[data-testid="unit-price"]', '125.00');
    await page.fill('[data-testid="delivery-address"]', '123 Main Street, City, ST');
    
    // Verify real-time calculation
    await expect(page.locator('[data-testid="total-revenue"]')).toContainText('$3,187.50');
    
    // Submit sale
    await page.click('[data-testid="submit-sale"]');
    
    // Verify success message and redirect
    await expect(page.locator('[data-testid="success-message"]')).toContainText('Sale created successfully');
    await expect(page).toHaveURL(/\/sales$/);
    
    // Verify sale appears in list
    await expect(page.locator('[data-testid="sales-grid"]')).toContainText('ABC Construction');
    await expect(page.locator('[data-testid="sales-grid"]')).toContainText('25.5 yd³');
  });

  test('Sales data validation prevents invalid entries', async ({ page }) => {
    await loginAsManager(page);
    await page.goto('/sales/new');

    // Try to submit with invalid data
    await page.fill('[data-testid="concrete-yards"]', '0.05');
    await page.fill('[data-testid="unit-price"]', '25.00');
    await page.click('[data-testid="submit-sale"]');

    // Verify validation errors
    await expect(page.locator('[data-testid="yards-error"]')).toContainText('Minimum delivery is 0.1 cubic yards');
    await expect(page.locator('[data-testid="price-error"]')).toContainText('Price below market minimum');
    
    // Form should not submit
    await expect(page).toHaveURL(/\/sales\/new$/);
  });
});
```

#### 2. Profit Analysis Workflow
```typescript
describe('Profit Analysis Workflow', () => {
  test('Management reviews monthly profit performance', async ({ page }) => {
    await loginAsManager(page);
    await page.goto('/analytics');

    // Set date range for analysis
    await page.click('[data-testid="date-range-selector"]');
    await page.click('[data-testid="last-30-days"]');
    
    // Verify dashboard loads with data
    await expect(page.locator('[data-testid="total-revenue-kpi"]')).toBeVisible();
    await expect(page.locator('[data-testid="profit-margin-kpi"]')).toBeVisible();
    await expect(page.locator('[data-testid="profit-trend-chart"]')).toBeVisible();
    
    // Drill down into specific project
    await page.click('[data-testid="project-profit-table"] [data-project="PROJ-001"]');
    
    // Verify project detail view
    await expect(page.locator('[data-testid="project-details"]')).toContainText('Downtown Office Building');
    await expect(page.locator('[data-testid="project-profit-breakdown"]')).toBeVisible();
    
    // Export analysis report
    await page.click('[data-testid="export-report"]');
    await page.selectOption('[data-testid="export-format"]', 'pdf');
    await page.click('[data-testid="generate-report"]');
    
    // Verify report generation
    await expect(page.locator('[data-testid="report-status"]')).toContainText('Report generated successfully');
  });

  test('Cost breakdown visualization displays accurate data', async ({ page }) => {
    await loginAsManager(page);
    await page.goto('/analytics');

    // Wait for chart to load
    await page.waitForSelector('[data-testid="cost-breakdown-chart"]');
    
    // Verify cost categories are displayed
    const chartLegend = page.locator('[data-testid="chart-legend"]');
    await expect(chartLegend).toContainText('Manufacturing (70.0%)');
    await expect(chartLegend).toContainText('Labor (18.0%)');
    await expect(chartLegend).toContainText('Equipment (7.5%)');
    
    // Verify tooltips show actual amounts
    await page.hover('[data-testid="manufacturing-slice"]');
    await expect(page.locator('[data-testid="chart-tooltip"]')).toContainText('$45,640.00');
  });
});
```

#### 3. Cross-Browser Testing
```typescript
// Test configuration for multiple browsers
const browsers = ['chromium', 'firefox', 'webkit'];

browsers.forEach(browserName => {
  test.describe(`${browserName} browser tests`, () => {
    test.use({ browserName });

    test('Core functionality works across browsers', async ({ page }) => {
      await page.goto('/');
      await loginAsManager(page);
      
      // Test critical functionality
      await testSalesEntry(page);
      await testProfitAnalysis(page);
      await testReportGeneration(page);
      
      // Verify no console errors
      const consoleErrors = [];
      page.on('console', msg => {
        if (msg.type() === 'error') {
          consoleErrors.push(msg.text());
        }
      });
      
      expect(consoleErrors).toHaveLength(0);
    });
  });
});
```

## Industry-Specific Test Scenarios

### Concrete Business Scenarios

#### 1. High-Volume Day Testing
```typescript
describe('High-Volume Day Scenarios', () => {
  test('System handles 50+ deliveries in single day', async () => {
    const deliveries = Array.from({ length: 55 }, (_, i) => ({
      projectId: `PROJ-${Math.floor(i / 10) + 1}`,
      concreteYards: 15 + (i % 20),
      unitPrice: 120 + (i % 30),
      saleDate: '2024-01-15',
      deliveryTime: `${6 + Math.floor(i / 6)}:${(i % 6) * 10}:00`
    }));

    const startTime = Date.now();
    
    const results = await Promise.all(
      deliveries.map(delivery => 
        request(app)
          .post('/api/v1/sales')
          .set('Authorization', `Bearer ${validToken}`)
          .send(delivery)
      )
    );

    const totalTime = Date.now() - startTime;
    
    expect(results.every(r => r.status === 201)).toBe(true);
    expect(totalTime).toBeLessThan(30000); // Complete within 30 seconds
    
    // Verify daily summary calculation
    const summaryResponse = await request(app)
      .get('/api/v1/analytics/daily-summary/2024-01-15')
      .set('Authorization', `Bearer ${validToken}`);

    expect(summaryResponse.body.data).toMatchObject({
      numberOfDeliveries: 55,
      totalYards: expect.any(Number),
      totalRevenue: expect.any(Number),
      averageYardsPerDelivery: expect.any(Number)
    });
  });
});
```

#### 2. Cost Spike Event Testing
```typescript
describe('Cost Spike Event Handling', () => {
  test('System adapts to sudden cement price increase', async ({ page }) => {
    // Setup initial pricing
    await updateManufacturingCost('Standard 4000 PSI', {
      cementCost: 50.00,
      totalCost: 70.00
    });

    // Create sale with current pricing
    await page.goto('/sales/new');
    await fillSaleForm(page, {
      concreteType: 'Standard 4000 PSI',
      yards: 25.0,
      price: 125.00
    });

    await expect(page.locator('[data-testid="estimated-profit"]')).toContainText('25.0%');

    // Simulate cost spike (cement price increases 20%)
    await updateManufacturingCost('Standard 4000 PSI', {
      cementCost: 60.00, // 20% increase
      totalCost: 78.00   // Adjusted total
    });

    // Refresh calculation
    await page.click('[data-testid="recalculate-costs"]');

    // Verify profit margin updated
    await expect(page.locator('[data-testid="estimated-profit"]')).toContainText('21.6%');
    
    // Verify warning about margin impact
    await expect(page.locator('[data-testid="cost-alert"]')).toContainText('Recent cost increase affects margin');
  });
});
```

#### 3. Seasonal Variation Testing
```typescript
describe('Seasonal Business Patterns', () => {
  test('Winter demand patterns affect pricing recommendations', async () => {
    // Setup winter season data
    const winterSales = await createSeasonalTestData('winter', {
      averageMargin: 28.5,
      demandMultiplier: 0.7,
      costMultiplier: 1.1
    });

    const summerSales = await createSeasonalTestData('summer', {
      averageMargin: 22.0,
      demandMultiplier: 1.3,
      costMultiplier: 0.9
    });

    const seasonalAnalysis = await request(app)
      .get('/api/v1/analytics/seasonal-analysis')
      .set('Authorization', `Bearer ${validToken}`)
      .expect(200);

    expect(seasonalAnalysis.body.data.patterns).toMatchObject({
      winter: {
        typicalMargin: 28.5,
        note: expect.stringContaining('Higher margins due to reduced competition')
      },
      summer: {
        typicalMargin: 22.0,
        note: expect.stringContaining('Increased competition affects pricing')
      }
    });
  });
});
```

## Performance Testing Strategy

### Load Testing Configuration
```typescript
describe('Performance Tests', () => {
  test('Dashboard loads within 300ms with realistic data', async () => {
    // Setup realistic dataset
    await createPerformanceTestData({
      sales: 10000,
      projects: 500,
      customers: 100,
      timespan: '1year'
    });

    const startTime = Date.now();
    
    const response = await request(app)
      .get('/api/v1/analytics/dashboard')
      .query({ period: '30days' })
      .set('Authorization', `Bearer ${validToken}`)
      .expect(200);

    const responseTime = Date.now() - startTime;
    
    expect(responseTime).toBeLessThan(300);
    expect(response.body.data.kpis).toBeDefined();
    expect(response.body.data.charts).toBeDefined();
  });

  test('Concurrent user simulation', async () => {
    const concurrentUsers = 50;
    const requests = Array.from({ length: concurrentUsers }, () => 
      request(app)
        .get('/api/v1/sales')
        .set('Authorization', `Bearer ${validToken}`)
        .query({ page: 1, limit: 50 })
    );

    const startTime = Date.now();
    const responses = await Promise.all(requests);
    const totalTime = Date.now() - startTime;

    expect(responses.every(r => r.status === 200)).toBe(true);
    expect(totalTime).toBeLessThan(2000); // All requests complete within 2 seconds
  });
});
```

### Memory and Resource Testing
```typescript
describe('Resource Usage Tests', () => {
  test('Memory usage remains stable during large data operations', async () => {
    const initialMemory = process.memoryUsage();
    
    // Process large dataset
    await request(app)
      .post('/api/v1/sales/bulk/import')
      .set('Authorization', `Bearer ${validToken}`)
      .attach('file', path.join(__dirname, 'fixtures/large-sales-data.csv'))
      .expect(201);

    const afterProcessingMemory = process.memoryUsage();
    
    // Memory increase should be reasonable (< 100MB)
    const memoryIncrease = afterProcessingMemory.heapUsed - initialMemory.heapUsed;
    expect(memoryIncrease).toBeLessThan(100 * 1024 * 1024); // 100MB
  });
});
```

## Test Data Management

### Test Data Factory
```typescript
class TestDataFactory {
  static createSale(overrides: Partial<CreateSaleRequest> = {}): CreateSaleRequest {
    return {
      projectId: 'TEST-PROJ-001',
      customerId: 'test-customer-uuid',
      saleDate: '2024-01-15',
      concreteTypeId: 'standard-4000-psi-uuid',
      concreteYards: 25.5,
      unitPrice: 125.00,
      deliveryAddress: '123 Test Street, Test City, TS 12345',
      ...overrides
    };
  }

  static createProject(overrides: Partial<CreateProjectRequest> = {}): CreateProjectRequest {
    return {
      projectName: 'Test Construction Project',
      customerId: 'test-customer-uuid',
      siteAddress: '456 Project Ave, Test City, TS 12345',
      estimatedTotalYards: 500.0,
      contractAmount: 62500.00,
      startDate: '2024-01-10',
      estimatedCompletionDate: '2024-03-15',
      ...overrides
    };
  }

  static async createRealisticDataset(options: {
    projects: number;
    salesPerProject: number;
    timeSpanDays: number;
  }): Promise<{ projects: Project[]; sales: Sale[] }> {
    // Implementation for creating realistic test data
    // with proper relationships and business logic
  }
}
```

This comprehensive testing strategy ensures the concrete sales and profit analyzer meets industry requirements with reliable financial calculations, robust performance, and user-friendly workflows.