# Frontend Specifications - Concrete Sales & Profit Analyzer

## UI/UX Design System

### Design Principles
- **Industry-Focused**: Optimized for concrete manufacturing workflows
- **Data-Dense**: Efficiently display complex financial and operational data
- **Mobile-Responsive**: Support for tablet use in field operations
- **Accessibility**: WCAG 2.1 AA compliance for inclusive design
- **Performance**: Fast loading with progressive data rendering

### Color Palette
```scss
// Primary Colors (Construction Industry Theme)
$primary-blue: #1976d2;        // Primary actions, headers
$secondary-orange: #ff9800;     // Alerts, highlights
$concrete-gray: #616161;       // Text, borders

// Status Colors
$success-green: #4caf50;       // Completed deliveries, positive margins
$warning-amber: #ff9800;       // Pending items, cautions
$error-red: #f44336;          // Failed deliveries, negative margins
$info-blue: #2196f3;          // Information, help text

// Neutral Colors
$background-light: #fafafa;    // Page backgrounds
$surface-white: #ffffff;       // Card backgrounds
$text-primary: #212121;       // Primary text
$text-secondary: #757575;     // Secondary text
$border-light: #e0e0e0;       // Dividers, borders
```

### Typography
```scss
// Primary Font: Roboto (Material Design)
$font-family-primary: 'Roboto', 'Helvetica', 'Arial', sans-serif;
$font-family-mono: 'Roboto Mono', 'Consolas', 'Monaco', monospace;

// Font Sizes
$font-size-xs: 12px;    // Helper text, labels
$font-size-sm: 14px;    // Body text, form inputs
$font-size-base: 16px;  // Default body text
$font-size-lg: 18px;    // Subheadings
$font-size-xl: 24px;    // Page headings
$font-size-xxl: 32px;   // Dashboard metrics
```

## Component Architecture

### Core Layout Components

#### 1. App Shell
```typescript
interface AppShellProps {
  user: User;
  navigationItems: NavigationItem[];
  notifications: Notification[];
  children: React.ReactNode;
}

// Main application shell with navigation, header, and content area
const AppShell: React.FC<AppShellProps> = ({
  user,
  navigationItems,
  notifications,
  children
}) => {
  return (
    <div className="app-shell">
      <AppHeader user={user} notifications={notifications} />
      <SideNavigation items={navigationItems} />
      <main className="main-content">
        {children}
      </main>
    </div>
  );
};
```

#### 2. Navigation Components
```typescript
interface NavigationItem {
  id: string;
  label: string;
  icon: string;
  path: string;
  badge?: number;
  children?: NavigationItem[];
  permissions?: string[];
}

const SideNavigation: React.FC<{items: NavigationItem[]}> = ({items}) => {
  const navigation = [
    { id: 'dashboard', label: 'Dashboard', icon: 'dashboard', path: '/' },
    { id: 'sales', label: 'Sales', icon: 'point_of_sale', path: '/sales' },
    { id: 'projects', label: 'Projects', icon: 'construction', path: '/projects' },
    { id: 'costs', label: 'Costs', icon: 'receipt', path: '/costs' },
    { id: 'analytics', label: 'Analytics', icon: 'analytics', path: '/analytics' },
    { id: 'reports', label: 'Reports', icon: 'assessment', path: '/reports' }
  ];
  
  // Navigation implementation with role-based visibility
};
```

### Dashboard Components

#### 1. KPI Cards
```typescript
interface KPICardProps {
  title: string;
  value: string | number;
  previousValue?: string | number;
  format?: 'currency' | 'percentage' | 'number' | 'yards';
  trend?: 'up' | 'down' | 'stable';
  onClick?: () => void;
}

const KPICard: React.FC<KPICardProps> = ({
  title,
  value,
  previousValue,
  format = 'number',
  trend,
  onClick
}) => {
  const formattedValue = formatValue(value, format);
  const changePercentage = calculateChange(value, previousValue);
  
  return (
    <Card className="kpi-card" onClick={onClick}>
      <CardContent>
        <Typography variant="h6" color="textSecondary">
          {title}
        </Typography>
        <Typography variant="h3" className="kpi-value">
          {formattedValue}
        </Typography>
        {previousValue && (
          <div className={`kpi-change kpi-change--${trend}`}>
            <TrendIcon trend={trend} />
            <span>{changePercentage}</span>
          </div>
        )}
      </CardContent>
    </Card>
  );
};
```

#### 2. Revenue Trend Chart
```typescript
interface RevenueTrendProps {
  data: Array<{
    date: string;
    revenue: number;
    profit: number;
    yards: number;
  }>;
  period: 'day' | 'week' | 'month';
  onPeriodChange: (period: string) => void;
}

const RevenueTrendChart: React.FC<RevenueTrendProps> = ({
  data,
  period,
  onPeriodChange
}) => {
  return (
    <Card className="chart-card">
      <CardHeader>
        <Typography variant="h6">Revenue Trends</Typography>
        <PeriodSelector 
          value={period} 
          onChange={onPeriodChange}
          options={['day', 'week', 'month']}
        />
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="date" />
            <YAxis />
            <Tooltip formatter={formatCurrency} />
            <Legend />
            <Line type="monotone" dataKey="revenue" stroke="#1976d2" strokeWidth={2} />
            <Line type="monotone" dataKey="profit" stroke="#4caf50" strokeWidth={2} />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
};
```

### Sales Management Components

#### 1. Sales Data Grid
```typescript
interface SalesDataGridProps {
  sales: Sale[];
  loading?: boolean;
  onEdit: (saleId: string) => void;
  onDelete: (saleId: string) => void;
  onViewDetails: (saleId: string) => void;
}

const SalesDataGrid: React.FC<SalesDataGridProps> = ({
  sales,
  loading = false,
  onEdit,
  onDelete,
  onViewDetails
}) => {
  const columns: GridColDef[] = [
    {
      field: 'saleNumber',
      headerName: 'Sale #',
      width: 120,
      renderCell: (params) => (
        <Link onClick={() => onViewDetails(params.row.id)}>
          {params.value}
        </Link>
      )
    },
    {
      field: 'saleDate',
      headerName: 'Date',
      width: 120,
      type: 'date',
      valueFormatter: (params) => formatDate(params.value)
    },
    {
      field: 'customerName',
      headerName: 'Customer',
      width: 200,
      renderCell: (params) => (
        <CustomerCell customer={params.row.customer} />
      )
    },
    {
      field: 'concreteYards',
      headerName: 'Yards',
      width: 100,
      type: 'number',
      valueFormatter: (params) => `${params.value} yd³`
    },
    {
      field: 'unitPrice',
      headerName: 'Price/Yard',
      width: 120,
      type: 'number',
      valueFormatter: (params) => formatCurrency(params.value)
    },
    {
      field: 'totalRevenue',
      headerName: 'Revenue',
      width: 130,
      type: 'number',
      valueFormatter: (params) => formatCurrency(params.value)
    },
    {
      field: 'profitMargin',
      headerName: 'Margin',
      width: 100,
      renderCell: (params) => (
        <ProfitMarginCell 
          margin={params.value} 
          target={25.0} 
        />
      )
    },
    {
      field: 'deliveryStatus',
      headerName: 'Status',
      width: 120,
      renderCell: (params) => (
        <StatusChip status={params.value} />
      )
    }
  ];

  return (
    <DataGrid
      rows={sales}
      columns={columns}
      loading={loading}
      pageSize={50}
      rowsPerPageOptions={[25, 50, 100]}
      checkboxSelection
      disableSelectionOnClick
      components={{
        Toolbar: SalesGridToolbar
      }}
      onCellDoubleClick={(params) => onEdit(params.row.id)}
    />
  );
};
```

#### 2. Sale Entry Form
```typescript
interface SaleFormProps {
  initialData?: Partial<Sale>;
  onSubmit: (data: CreateSaleRequest) => void;
  onCancel: () => void;
  loading?: boolean;
}

const SaleForm: React.FC<SaleFormProps> = ({
  initialData,
  onSubmit,
  onCancel,
  loading = false
}) => {
  const {
    control,
    handleSubmit,
    watch,
    formState: { errors }
  } = useForm<CreateSaleRequest>({
    defaultValues: initialData,
    resolver: zodResolver(saleFormSchema)
  });

  const watchedYards = watch('concreteYards');
  const watchedPrice = watch('unitPrice');
  const totalRevenue = (watchedYards || 0) * (watchedPrice || 0);

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Grid container spacing={3}>
        {/* Customer and Project Selection */}
        <Grid item xs={12} md={6}>
          <Controller
            name="customerId"
            control={control}
            render={({ field }) => (
              <CustomerSelect
                {...field}
                label="Customer"
                error={!!errors.customerId}
                helperText={errors.customerId?.message}
              />
            )}
          />
        </Grid>
        
        <Grid item xs={12} md={6}>
          <Controller
            name="projectId"
            control={control}
            render={({ field }) => (
              <ProjectSelect
                {...field}
                label="Project"
                customerId={watch('customerId')}
                error={!!errors.projectId}
                helperText={errors.projectId?.message}
              />
            )}
          />
        </Grid>

        {/* Concrete Specifications */}
        <Grid item xs={12} md={4}>
          <Controller
            name="concreteTypeId"
            control={control}
            render={({ field }) => (
              <ConcreteTypeSelect
                {...field}
                label="Concrete Type"
                error={!!errors.concreteTypeId}
                helperText={errors.concreteTypeId?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} md={4}>
          <Controller
            name="concreteYards"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                type="number"
                label="Cubic Yards"
                inputProps={{ min: 0.1, max: 200, step: 0.1 }}
                error={!!errors.concreteYards}
                helperText={errors.concreteYards?.message}
                InputProps={{
                  endAdornment: <InputAdornment position="end">yd³</InputAdornment>
                }}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} md={4}>
          <Controller
            name="unitPrice"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                type="number"
                label="Price per Yard"
                inputProps={{ min: 50, max: 300, step: 0.01 }}
                error={!!errors.unitPrice}
                helperText={errors.unitPrice?.message}
                InputProps={{
                  startAdornment: <InputAdornment position="start">$</InputAdornment>
                }}
              />
            )}
          />
        </Grid>

        {/* Revenue Calculation Display */}
        <Grid item xs={12}>
          <RevenueCalculationCard 
            yards={watchedYards}
            pricePerYard={watchedPrice}
            totalRevenue={totalRevenue}
          />
        </Grid>

        {/* Delivery Details */}
        <Grid item xs={12} md={6}>
          <Controller
            name="saleDate"
            control={control}
            render={({ field }) => (
              <DatePicker
                {...field}
                label="Sale Date"
                maxDate={addDays(new Date(), 30)}
                renderInput={(params) => (
                  <TextField 
                    {...params}
                    error={!!errors.saleDate}
                    helperText={errors.saleDate?.message}
                  />
                )}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <Controller
            name="deliveryDate"
            control={control}
            render={({ field }) => (
              <DatePicker
                {...field}
                label="Delivery Date"
                minDate={watch('saleDate')}
                renderInput={(params) => (
                  <TextField {...params} />
                )}
              />
            )}
          />
        </Grid>

        <Grid item xs={12}>
          <Controller
            name="deliveryAddress"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                label="Delivery Address"
                multiline
                rows={2}
                fullWidth
                error={!!errors.deliveryAddress}
                helperText={errors.deliveryAddress?.message}
              />
            )}
          />
        </Grid>

        {/* Form Actions */}
        <Grid item xs={12}>
          <Box display="flex" justifyContent="flex-end" gap={2}>
            <Button onClick={onCancel} disabled={loading}>
              Cancel
            </Button>
            <Button
              type="submit"
              variant="contained"
              disabled={loading}
              startIcon={loading ? <CircularProgress size={20} /> : <SaveIcon />}
            >
              {loading ? 'Saving...' : 'Save Sale'}
            </Button>
          </Box>
        </Grid>
      </Grid>
    </form>
  );
};
```

### Analytics Components

#### 1. Profit Analysis Dashboard
```typescript
interface ProfitAnalysisDashboardProps {
  dateRange: DateRange;
  onDateRangeChange: (range: DateRange) => void;
}

const ProfitAnalysisDashboard: React.FC<ProfitAnalysisDashboardProps> = ({
  dateRange,
  onDateRangeChange
}) => {
  const { data: profitData, loading } = useProfitAnalysis(dateRange);

  if (loading) return <AnalysisSkeletonLoader />;

  return (
    <Grid container spacing={3}>
      {/* Date Range Selector */}
      <Grid item xs={12}>
        <DateRangeSelector 
          value={dateRange}
          onChange={onDateRangeChange}
          presets={['7days', '30days', '3months', '1year']}
        />
      </Grid>

      {/* Key Metrics */}
      <Grid item xs={12} md={3}>
        <KPICard
          title="Total Revenue"
          value={profitData.summary.totalRevenue}
          previousValue={profitData.comparison?.totalRevenue}
          format="currency"
          trend={profitData.trends?.revenue}
        />
      </Grid>

      <Grid item xs={12} md={3}>
        <KPICard
          title="Net Profit"
          value={profitData.summary.netProfit}
          previousValue={profitData.comparison?.netProfit}
          format="currency"
          trend={profitData.trends?.profit}
        />
      </Grid>

      <Grid item xs={12} md={3}>
        <KPICard
          title="Profit Margin"
          value={profitData.summary.profitMargin}
          previousValue={profitData.comparison?.profitMargin}
          format="percentage"
          trend={profitData.trends?.margin}
        />
      </Grid>

      <Grid item xs={12} md={3}>
        <KPICard
          title="Profit per Yard"
          value={profitData.summary.profitPerYard}
          previousValue={profitData.comparison?.profitPerYard}
          format="currency"
          trend={profitData.trends?.profitPerYard}
        />
      </Grid>

      {/* Cost Breakdown Chart */}
      <Grid item xs={12} md={6}>
        <CostBreakdownChart 
          data={profitData.breakdown.costsByCategory}
          title="Cost Analysis"
        />
      </Grid>

      {/* Profit Trend Chart */}
      <Grid item xs={12} md={6}>
        <ProfitTrendChart
          data={profitData.trends}
          groupBy="week"
        />
      </Grid>

      {/* Top Performing Projects */}
      <Grid item xs={12}>
        <ProjectProfitabilityTable
          projects={profitData.breakdown.profitByProject}
          title="Project Performance"
        />
      </Grid>
    </Grid>
  );
};
```

#### 2. Cost Breakdown Visualization
```typescript
const CostBreakdownChart: React.FC<{
  data: Record<string, number>;
  title: string;
}> = ({ data, title }) => {
  const chartData = Object.entries(data).map(([category, amount]) => ({
    name: category.charAt(0).toUpperCase() + category.slice(1),
    value: amount,
    percentage: ((amount / Object.values(data).reduce((a, b) => a + b, 0)) * 100)
  }));

  const COLORS = {
    manufacturing: '#1976d2',
    labor: '#ff9800',
    equipment: '#4caf50',
    fuel: '#f44336',
    fixed: '#9c27b0'
  };

  return (
    <Card>
      <CardHeader>
        <Typography variant="h6">{title}</Typography>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <PieChart>
            <Pie
              data={chartData}
              cx="50%"
              cy="50%"
              labelLine={false}
              label={({ name, percentage }) => `${name}: ${percentage.toFixed(1)}%`}
              outerRadius={80}
              fill="#8884d8"
              dataKey="value"
            >
              {chartData.map((entry, index) => (
                <Cell 
                  key={`cell-${index}`} 
                  fill={COLORS[entry.name.toLowerCase()]} 
                />
              ))}
            </Pie>
            <Tooltip formatter={(value) => formatCurrency(value)} />
            <Legend />
          </PieChart>
        </ResponsiveContainer>
        
        {/* Detailed Breakdown */}
        <List>
          {chartData.map((item) => (
            <ListItem key={item.name}>
              <ListItemIcon>
                <Box 
                  width={16} 
                  height={16} 
                  bgcolor={COLORS[item.name.toLowerCase()]}
                  borderRadius="50%"
                />
              </ListItemIcon>
              <ListItemText
                primary={item.name}
                secondary={`${formatCurrency(item.value)} (${item.percentage.toFixed(1)}%)`}
              />
            </ListItem>
          ))}
        </List>
      </CardContent>
    </Card>
  );
};
```

### Utility Components

#### 1. Data Table with Advanced Features
```typescript
interface AdvancedDataTableProps<T> {
  data: T[];
  columns: Column<T>[];
  loading?: boolean;
  pagination?: PaginationConfig;
  sorting?: SortingConfig;
  filtering?: FilterConfig;
  selection?: SelectionConfig;
  onRowClick?: (row: T) => void;
  onRowDoubleClick?: (row: T) => void;
}

const AdvancedDataTable = <T extends { id: string | number }>({
  data,
  columns,
  loading = false,
  pagination,
  sorting,
  filtering,
  selection,
  onRowClick,
  onRowDoubleClick
}: AdvancedDataTableProps<T>) => {
  const [sortBy, setSortBy] = useState(sorting?.defaultSort);
  const [filters, setFilters] = useState(filtering?.defaultFilters);
  const [selectedRows, setSelectedRows] = useState<T['id'][]>([]);

  return (
    <Paper>
      {filtering && (
        <TableToolbar
          filters={filters}
          onFiltersChange={setFilters}
          columns={columns}
        />
      )}
      
      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              {selection && (
                <TableCell padding="checkbox">
                  <Checkbox
                    indeterminate={selectedRows.length > 0 && selectedRows.length < data.length}
                    checked={data.length > 0 && selectedRows.length === data.length}
                    onChange={handleSelectAll}
                  />
                </TableCell>
              )}
              {columns.map((column) => (
                <TableCell
                  key={column.id}
                  sortDirection={sortBy?.field === column.id ? sortBy.direction : false}
                >
                  {sorting && column.sortable ? (
                    <TableSortLabel
                      active={sortBy?.field === column.id}
                      direction={sortBy?.field === column.id ? sortBy.direction : 'asc'}
                      onClick={() => handleSort(column.id)}
                    >
                      {column.header}
                    </TableSortLabel>
                  ) : (
                    column.header
                  )}
                </TableCell>
              ))}
            </TableRow>
          </TableHead>
          
          <TableBody>
            {loading ? (
              <TableSkeletonRows columns={columns.length} rows={10} />
            ) : (
              data.map((row) => (
                <TableRow
                  key={row.id}
                  selected={selectedRows.includes(row.id)}
                  onClick={() => onRowClick?.(row)}
                  onDoubleClick={() => onRowDoubleClick?.(row)}
                  hover
                  sx={{ cursor: onRowClick ? 'pointer' : 'default' }}
                >
                  {selection && (
                    <TableCell padding="checkbox">
                      <Checkbox
                        checked={selectedRows.includes(row.id)}
                        onChange={() => handleRowSelect(row.id)}
                      />
                    </TableCell>
                  )}
                  {columns.map((column) => (
                    <TableCell key={column.id}>
                      {column.render ? 
                        column.render(row[column.field], row) : 
                        row[column.field]
                      }
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      {pagination && (
        <TablePagination
          component="div"
          count={pagination.totalRecords}
          page={pagination.page}
          rowsPerPage={pagination.pageSize}
          rowsPerPageOptions={pagination.pageSizeOptions}
          onPageChange={pagination.onPageChange}
          onRowsPerPageChange={pagination.onPageSizeChange}
        />
      )}
    </Paper>
  );
};
```

## User Workflows

### 1. Daily Sales Entry Workflow
```typescript
const DailySalesEntryWorkflow: React.FC = () => {
  const [currentStep, setCurrentStep] = useState(0);
  const [salesData, setSalesData] = useState<CreateSaleRequest[]>([]);

  const steps = [
    'Select Projects',
    'Enter Deliveries', 
    'Review & Submit',
    'Confirmation'
  ];

  const StepContent = () => {
    switch (currentStep) {
      case 0:
        return (
          <ProjectSelectionStep
            onProjectsSelected={(projects) => {
              // Initialize sales entries for selected projects
              const initialSales = projects.map(project => ({
                projectId: project.id,
                customerId: project.customerId,
                saleDate: new Date().toISOString().split('T')[0]
              }));
              setSalesData(initialSales);
              setCurrentStep(1);
            }}
          />
        );
      
      case 1:
        return (
          <MultiSaleEntryStep
            salesData={salesData}
            onSalesChange={setSalesData}
            onNext={() => setCurrentStep(2)}
            onPrevious={() => setCurrentStep(0)}
          />
        );
      
      case 2:
        return (
          <SalesReviewStep
            salesData={salesData}
            onSubmit={handleBatchSubmit}
            onPrevious={() => setCurrentStep(1)}
          />
        );
      
      case 3:
        return (
          <ConfirmationStep
            submittedSales={salesData}
            onComplete={() => {
              // Reset workflow
              setCurrentStep(0);
              setSalesData([]);
            }}
          />
        );
    }
  };

  return (
    <Container maxWidth="lg">
      <Paper sx={{ p: 3 }}>
        <Stepper activeStep={currentStep} alternativeLabel>
          {steps.map((label) => (
            <Step key={label}>
              <StepLabel>{label}</StepLabel>
            </Step>
          ))}
        </Stepper>
        
        <Box mt={3}>
          <StepContent />
        </Box>
      </Paper>
    </Container>
  );
};
```

### 2. Cost Analysis Workflow
```typescript
const CostAnalysisWorkflow: React.FC = () => {
  const [analysisConfig, setAnalysisConfig] = useState<AnalysisConfig>({
    dateRange: getDefaultDateRange(),
    groupBy: 'project',
    includeForecast: false
  });

  return (
    <Grid container spacing={3}>
      {/* Analysis Configuration */}
      <Grid item xs={12} md={4}>
        <Card>
          <CardHeader>
            <Typography variant="h6">Analysis Settings</Typography>
          </CardHeader>
          <CardContent>
            <CostAnalysisConfigForm
              config={analysisConfig}
              onChange={setAnalysisConfig}
            />
          </CardContent>
        </Card>
      </Grid>

      {/* Results Display */}
      <Grid item xs={12} md={8}>
        <CostAnalysisResults config={analysisConfig} />
      </Grid>

      {/* Export Options */}
      <Grid item xs={12}>
        <CostAnalysisExport config={analysisConfig} />
      </Grid>
    </Grid>
  );
};
```

## State Management

### Redux Store Structure
```typescript
interface AppState {
  auth: {
    user: User | null;
    accessToken: string | null;
    refreshToken: string | null;
    isAuthenticated: boolean;
  };
  
  sales: {
    list: Sale[];
    currentSale: Sale | null;
    filters: SalesFilters;
    pagination: PaginationState;
    loading: boolean;
    error: string | null;
  };
  
  projects: {
    list: Project[];
    activeProjects: Project[];
    currentProject: Project | null;
    loading: boolean;
  };
  
  analytics: {
    dashboard: DashboardData | null;
    profitAnalysis: ProfitAnalysisData | null;
    trends: TrendData[];
    loading: boolean;
    lastUpdated: string | null;
  };
  
  ui: {
    sidebarOpen: boolean;
    theme: 'light' | 'dark';
    notifications: Notification[];
    modals: ModalState[];
  };
}
```

### API Integration with RTK Query
```typescript
export const concreteAnalyzerAPI = createApi({
  reducerPath: 'concreteAPI',
  baseQuery: fetchBaseQuery({
    baseUrl: '/api/v1/',
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as AppState).auth.accessToken;
      if (token) {
        headers.set('authorization', `Bearer ${token}`);
      }
      return headers;
    },
  }),
  tagTypes: ['Sale', 'Project', 'Cost', 'Analytics'],
  endpoints: (builder) => ({
    getSales: builder.query<SalesResponse, SalesQueryParams>({
      query: (params) => ({
        url: 'sales',
        params
      }),
      providesTags: ['Sale']
    }),
    
    createSale: builder.mutation<Sale, CreateSaleRequest>({
      query: (saleData) => ({
        url: 'sales',
        method: 'POST',
        body: saleData
      }),
      invalidatesTags: ['Sale', 'Analytics']
    }),
    
    getProfitAnalysis: builder.query<ProfitAnalysisData, DateRange>({
      query: (dateRange) => ({
        url: 'profit/analysis',
        params: dateRange
      }),
      providesTags: ['Analytics']
    })
  })
});
```

## Performance Optimization

### Code Splitting Strategy
```typescript
// Route-based code splitting
const Dashboard = lazy(() => import('../pages/Dashboard'));
const Sales = lazy(() => import('../pages/Sales'));
const Analytics = lazy(() => import('../pages/Analytics'));
const Reports = lazy(() => import('../pages/Reports'));

// Component-based splitting for heavy components
const ProfitAnalysisChart = lazy(() => import('../components/charts/ProfitAnalysisChart'));
const DataVisualization = lazy(() => import('../components/DataVisualization'));
```

### Data Virtualization for Large Tables
```typescript
const VirtualizedSalesTable: React.FC<{sales: Sale[]}> = ({ sales }) => {
  return (
    <FixedSizeList
      height={600}
      itemCount={sales.length}
      itemSize={60}
      itemData={sales}
    >
      {({ index, style, data }) => (
        <div style={style}>
          <SalesTableRow sale={data[index]} />
        </div>
      )}
    </FixedSizeList>
  );
};
```

### Caching Strategy
```typescript
// React Query configuration
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      retry: (failureCount, error) => {
        // Don't retry on 4xx errors
        if (error.status >= 400 && error.status < 500) {
          return false;
        }
        return failureCount < 3;
      }
    }
  }
});
```

This frontend specification provides a comprehensive guide for building a professional, industry-focused concrete sales and profit analyzer interface with modern React patterns and Material-UI components.