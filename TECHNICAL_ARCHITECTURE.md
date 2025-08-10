# Technical Architecture - Concrete Sales & Profit Analyzer

## System Architecture Overview

### High-Level Architecture Pattern
**Microservices Architecture** with domain-driven design, optimized for concrete industry workflows.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Client    │    │  Mobile Client  │    │  Admin Portal   │
│   (React/TS)    │    │   (React Native │    │   (React/TS)    │
└─────────────────┘    │    or PWA)      │    └─────────────────┘
         │              └─────────────────┘             │
         └──────────────────────┬────────────────────────┘
                                │
                    ┌─────────────────┐
                    │   API Gateway   │
                    │  (Kong/Express) │
                    └─────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Authentication │    │  Sales Service  │    │  Cost Service   │
│    Service      │    │   (Node.js)     │    │   (Node.js)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │              ┌─────────────────┐    ┌─────────────────┐
        │              │ Analytics Svc.  │    │ Reporting Svc.  │
        │              │  (Python/ML)    │    │   (Node.js)     │
        │              └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    │    Database     │
                    │  (with Redis)   │
                    └─────────────────┘
```

## Technology Stack Recommendations

### Frontend Stack
```yaml
Primary Framework: React 18+ with TypeScript
UI Components: Material-UI v5 or Ant Design
State Management: Redux Toolkit + RTK Query
Charts/Visualization: Chart.js or Recharts
Date Management: date-fns or dayjs
Form Management: React Hook Form + Zod
Testing: Jest + React Testing Library
Build Tool: Vite
```

### Backend Stack
```yaml
Runtime: Node.js 18+ (LTS)
Framework: Express.js with TypeScript
Authentication: JWT with refresh tokens
Validation: Joi or Zod
ORM/Query Builder: Prisma or TypeORM
API Documentation: Swagger/OpenAPI 3.0
Testing: Jest + Supertest
Process Management: PM2
```

### Database & Storage
```yaml
Primary Database: PostgreSQL 15+
Caching: Redis 7+
File Storage: AWS S3 or Google Cloud Storage
Search Engine: Elasticsearch (optional for large datasets)
Backup: Automated daily backups with 30-day retention
```

### DevOps & Infrastructure
```yaml
Containerization: Docker + Docker Compose
Orchestration: Kubernetes or Docker Swarm
CI/CD: GitHub Actions or GitLab CI
Monitoring: Prometheus + Grafana
Logging: ELK Stack (Elasticsearch, Logstash, Kibana)
Error Tracking: Sentry
Cloud Provider: AWS, Azure, or GCP
```

## Service Architecture Design

### 1. Authentication Service
```typescript
interface AuthService {
  // User management
  register(userData: UserRegistration): Promise<User>
  login(credentials: LoginCredentials): Promise<AuthToken>
  refreshToken(token: string): Promise<AuthToken>
  logout(userId: string): Promise<void>
  
  // Role-based access
  checkPermission(userId: string, resource: string, action: string): Promise<boolean>
  getUserRoles(userId: string): Promise<UserRole[]>
}

enum UserRole {
  ADMIN = 'admin',
  MANAGER = 'manager', 
  SALES = 'sales',
  ANALYST = 'analyst'
}
```

### 2. Sales Management Service
```typescript
interface SalesService {
  // CRUD operations
  createSale(saleData: CreateSaleRequest): Promise<Sale>
  updateSale(saleId: string, updates: UpdateSaleRequest): Promise<Sale>
  getSale(saleId: string): Promise<Sale>
  getSales(filters: SalesFilters): Promise<PaginatedSales>
  deleteSale(saleId: string): Promise<void>
  
  // Business logic
  calculateSaleProfit(saleId: string): Promise<ProfitCalculation>
  getSalesAnalytics(dateRange: DateRange): Promise<SalesAnalytics>
  importSalesData(file: FileUpload): Promise<ImportResult>
}

interface Sale {
  id: string
  projectId: string
  customerName: string
  saleDate: Date
  concreteYards: number
  concreteType: string
  unitPrice: number
  totalRevenue: number
  deliveryAddress: string
  salesRep: string
  profitMargin?: number
  costs?: Cost[]
}
```

### 3. Cost Management Service
```typescript
interface CostService {
  // Cost tracking
  createCost(costData: CreateCostRequest): Promise<Cost>
  updateCost(costId: string, updates: UpdateCostRequest): Promise<Cost>
  getCosts(filters: CostFilters): Promise<PaginatedCosts>
  deleteCost(costId: string): Promise<void>
  
  // Cost analysis
  getCostBreakdown(projectId: string): Promise<CostBreakdown>
  getManufacturingCosts(concreteType: string): Promise<ManufacturingCost>
  updateManufacturingCost(costData: ManufacturingCostUpdate): Promise<void>
  getCostTrends(dateRange: DateRange): Promise<CostTrend[]>
}

interface Cost {
  id: string
  projectId: string
  costCategory: CostCategory
  costType: string
  amount: number
  costDate: Date
  description?: string
}

enum CostCategory {
  MANUFACTURING = 'manufacturing',
  LABOR = 'labor',
  EQUIPMENT = 'equipment', 
  FUEL = 'fuel',
  FIXED = 'fixed'
}
```

### 4. Analytics Service (Python/ML)
```python
class AnalyticsService:
    def calculate_profit_margins(self, sales_data: List[Sale]) -> ProfitAnalysis:
        """Calculate profit margins with concrete industry specifics"""
        pass
    
    def forecast_sales(self, historical_data: List[Sale], days: int) -> SalesForecast:
        """Predict future sales using time series analysis"""
        pass
    
    def analyze_cost_trends(self, cost_data: List[Cost]) -> CostTrendAnalysis:
        """Analyze cost trends and identify anomalies"""
        pass
    
    def benchmark_performance(self, metrics: PerformanceMetrics) -> BenchmarkReport:
        """Compare performance against industry benchmarks"""
        pass
```

### 5. Reporting Service
```typescript
interface ReportingService {
  // Report generation
  generateSalesReport(params: SalesReportParams): Promise<Report>
  generateProfitReport(params: ProfitReportParams): Promise<Report>
  generateCostAnalysisReport(params: CostReportParams): Promise<Report>
  generateCustomReport(config: CustomReportConfig): Promise<Report>
  
  // Export functionality
  exportToPDF(reportId: string): Promise<Buffer>
  exportToExcel(reportId: string): Promise<Buffer>
  scheduleReport(config: ScheduledReportConfig): Promise<void>
}
```

## Data Flow Architecture

### 1. Sales Data Entry Flow
```
User Input (Web/Mobile)
  ↓
Validation Layer (Zod/Joi)
  ↓
Sales Service (Business Logic)
  ↓
Database Write (PostgreSQL)
  ↓
Cache Update (Redis)
  ↓
Real-time Updates (WebSocket)
  ↓
Dashboard Refresh
```

### 2. Profit Calculation Flow
```
Sales Transaction Event
  ↓
Cost Data Retrieval
  ↓
Manufacturing Cost Lookup ($70/yard baseline)
  ↓
Labor Cost Calculation
  ↓
Fixed Cost Allocation  
  ↓
Total Cost Computation
  ↓
Profit Margin Calculation
  ↓
Database Update & Cache
  ↓
Analytics Pipeline Update
```

### 3. Report Generation Flow
```
Report Request
  ↓
Parameter Validation
  ↓
Data Aggregation (Multiple Services)
  ↓
Template Processing
  ↓
Format Conversion (PDF/Excel)
  ↓
File Storage (S3/Cloud)
  ↓
Download Link Generation
```

## Database Design Specifications

### Core Tables Schema

#### Users Table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  role user_role NOT NULL,
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE user_role AS ENUM ('admin', 'manager', 'sales', 'analyst');
```

#### Enhanced Sales Table
```sql
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id VARCHAR(50) NOT NULL,
  customer_id UUID REFERENCES customers(id),
  sale_date DATE NOT NULL,
  concrete_yards DECIMAL(10,2) NOT NULL CHECK (concrete_yards > 0),
  concrete_type_id UUID REFERENCES concrete_types(id),
  unit_price DECIMAL(8,2) NOT NULL CHECK (unit_price > 0),
  total_revenue DECIMAL(10,2) GENERATED ALWAYS AS (concrete_yards * unit_price) STORED,
  delivery_address TEXT,
  sales_rep_id UUID REFERENCES users(id),
  delivery_status delivery_status_enum DEFAULT 'pending',
  profit_margin DECIMAL(5,2),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE delivery_status_enum AS ENUM ('pending', 'delivered', 'cancelled');
```

#### Comprehensive Costs Table
```sql
CREATE TABLE costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id VARCHAR(50) NOT NULL,
  cost_category cost_category_enum NOT NULL,
  cost_type VARCHAR(100) NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  cost_date DATE NOT NULL,
  description TEXT,
  vendor_id UUID REFERENCES vendors(id),
  invoice_number VARCHAR(100),
  is_recurring BOOLEAN DEFAULT false,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE cost_category_enum AS ENUM ('manufacturing', 'labor', 'equipment', 'fuel', 'fixed', 'overhead');
```

#### Concrete Types & Manufacturing Costs
```sql
CREATE TABLE concrete_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  psi_strength INTEGER,
  slump_rating VARCHAR(20),
  base_cost_per_yard DECIMAL(8,2) DEFAULT 70.00,
  cement_ratio DECIMAL(4,2),
  aggregate_ratio DECIMAL(4,2),
  water_ratio DECIMAL(4,2),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE manufacturing_cost_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concrete_type_id UUID REFERENCES concrete_types(id),
  effective_date DATE NOT NULL,
  cement_cost_per_yard DECIMAL(8,2),
  aggregate_cost_per_yard DECIMAL(8,2),
  additive_cost_per_yard DECIMAL(8,2),
  total_cost_per_yard DECIMAL(8,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Performance Indexes
```sql
-- Core performance indexes
CREATE INDEX idx_sales_date_range ON sales(sale_date);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_project ON sales(project_id);
CREATE INDEX idx_costs_project_date ON costs(project_id, cost_date);
CREATE INDEX idx_costs_category_date ON costs(cost_category, cost_date);

-- Composite indexes for analytics
CREATE INDEX idx_sales_analytics ON sales(sale_date, concrete_type_id, sales_rep_id);
CREATE INDEX idx_profit_analysis ON sales(sale_date, profit_margin) WHERE profit_margin IS NOT NULL;
```

## API Design Specifications

### RESTful Endpoint Structure

#### Authentication Endpoints
```typescript
// Authentication
POST   /api/v1/auth/login
POST   /api/v1/auth/logout  
POST   /api/v1/auth/refresh
GET    /api/v1/auth/me
PUT    /api/v1/auth/profile

// User management (admin only)
GET    /api/v1/users
POST   /api/v1/users
GET    /api/v1/users/:id
PUT    /api/v1/users/:id
DELETE /api/v1/users/:id
```

#### Sales Management Endpoints
```typescript
// Sales CRUD
GET    /api/v1/sales?page=1&limit=50&startDate=2024-01-01&endDate=2024-12-31
POST   /api/v1/sales
GET    /api/v1/sales/:id
PUT    /api/v1/sales/:id
DELETE /api/v1/sales/:id

// Sales analytics
GET    /api/v1/sales/analytics/summary?dateRange=30days
GET    /api/v1/sales/analytics/trends?groupBy=month
GET    /api/v1/sales/analytics/by-rep?repId=uuid
GET    /api/v1/sales/analytics/by-concrete-type

// Bulk operations
POST   /api/v1/sales/bulk/import
POST   /api/v1/sales/bulk/update
DELETE /api/v1/sales/bulk/delete
```

#### Cost Management Endpoints
```typescript
// Cost tracking
GET    /api/v1/costs?projectId=ABC123&category=manufacturing
POST   /api/v1/costs
GET    /api/v1/costs/:id  
PUT    /api/v1/costs/:id
DELETE /api/v1/costs/:id

// Cost analysis
GET    /api/v1/costs/breakdown?projectId=ABC123
GET    /api/v1/costs/trends?category=manufacturing&months=12
GET    /api/v1/costs/manufacturing/current
PUT    /api/v1/costs/manufacturing/update
```

#### Profit Analysis Endpoints  
```typescript
// Profit analytics
GET    /api/v1/profit/analysis?dateRange=2024-01-01:2024-12-31
GET    /api/v1/profit/margins/trends?groupBy=week
GET    /api/v1/profit/projects/ranking?sortBy=profitMargin
GET    /api/v1/profit/forecasting?horizon=90days

// Comparative analysis
GET    /api/v1/profit/compare/periods?period1=Q1&period2=Q2
GET    /api/v1/profit/benchmarks/industry
```

### Request/Response Schemas

#### Sale Creation Request
```typescript
interface CreateSaleRequest {
  projectId: string          // Required, alphanumeric
  customerName: string       // Required, max 255 chars
  saleDate: string          // Required, ISO date
  concreteYards: number     // Required, positive, max 1000
  concreteTypeId: string    // Required, UUID
  unitPrice: number         // Required, positive, $50-$300 range
  deliveryAddress: string   // Optional
  salesRepId?: string       // Optional, UUID
  notes?: string           // Optional, max 1000 chars
}
```

#### Profit Analysis Response
```typescript
interface ProfitAnalysisResponse {
  dateRange: {
    startDate: string
    endDate: string
  }
  summary: {
    totalRevenue: number
    totalCosts: number
    netProfit: number
    profitMargin: number
    averageProfitPerYard: number
  }
  breakdown: {
    manufacturingCosts: number
    laborCosts: number
    equipmentCosts: number
    fuelCosts: number
    fixedCosts: number
  }
  trends: Array<{
    date: string
    profit: number
    margin: number
  }>
  topProjects: Array<{
    projectId: string
    customerName: string
    profit: number
    margin: number
  }>
}
```

## Security Architecture

### Authentication & Authorization
```typescript
interface SecurityConfig {
  jwt: {
    secret: string
    expiresIn: '15m'           // Access token
    refreshExpiresIn: '7d'     // Refresh token
  }
  password: {
    minLength: 8
    requireUppercase: true
    requireLowercase: true
    requireNumbers: true
    requireSymbols: true
  }
  rateLimit: {
    windowMs: 15 * 60 * 1000   // 15 minutes
    max: 100                    // Requests per window
  }
}
```

### Role-Based Permissions
```typescript
const permissions = {
  admin: ['*'],
  manager: [
    'sales:read', 'sales:write', 'sales:delete',
    'costs:read', 'costs:write', 'costs:delete', 
    'reports:read', 'reports:write',
    'users:read'
  ],
  sales: [
    'sales:read', 'sales:write',
    'costs:read',
    'reports:read'
  ],
  analyst: [
    'sales:read',
    'costs:read', 
    'reports:read', 'reports:write'
  ]
}
```

### Data Protection Measures
- **Encryption at Rest**: AES-256 for sensitive data
- **Encryption in Transit**: TLS 1.3 for all communications  
- **Input Sanitization**: SQL injection prevention
- **CSRF Protection**: Token-based CSRF protection
- **XSS Prevention**: Content Security Policy headers
- **API Rate Limiting**: Prevent abuse and DoS attacks
- **Audit Logging**: Track all data modifications

This technical architecture provides a robust foundation for the concrete sales and profit analyzer, with emphasis on scalability, security, and industry-specific requirements.