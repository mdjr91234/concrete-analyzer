# API Specification - Concrete Sales & Profit Analyzer

## API Overview

**Base URL**: `https://api.concreteanalyzer.com/v1`
**Authentication**: Bearer JWT tokens
**Content-Type**: `application/json`
**API Version**: 1.0

## Authentication Flow

### Endpoint: Authentication
```http
POST /auth/login
POST /auth/logout
POST /auth/refresh
GET  /auth/me
PUT  /auth/profile
```

#### Login Request
```typescript
POST /auth/login
Content-Type: application/json

{
  "email": "user@concretecompany.com",
  "password": "securePassword123"
}
```

#### Login Response
```typescript
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "uuid",
      "email": "user@concretecompany.com",
      "firstName": "John",
      "lastName": "Doe",
      "role": "manager"
    },
    "expiresIn": 900
  }
}
```

## Data Flow Specifications

### 1. Sales Data Entry Flow
```
Client Request → Input Validation → Cost Calculation → Database Write → Cache Update → Response
```

### 2. Profit Analysis Flow  
```
Analysis Request → Data Aggregation → Cost Allocation → Profit Calculation → Caching → Response
```

### 3. Report Generation Flow
```
Report Request → Parameter Validation → Data Query → Template Processing → File Generation → Storage → Download URL
```

## Core API Endpoints

### Sales Management

#### Get Sales List
```http
GET /sales?page=1&limit=50&startDate=2024-01-01&endDate=2024-12-31&customerId=uuid&projectId=PROJ-001
Authorization: Bearer {token}
```

**Query Parameters:**
- `page` (integer, default: 1): Page number for pagination
- `limit` (integer, default: 50, max: 200): Number of records per page
- `startDate` (date, ISO format): Filter sales from this date
- `endDate` (date, ISO format): Filter sales to this date  
- `customerId` (UUID): Filter by specific customer
- `projectId` (string): Filter by specific project
- `salesRepId` (UUID): Filter by sales representative
- `concreteType` (string): Filter by concrete type
- `deliveryStatus` (enum): pending|in_transit|delivered|cancelled
- `sortBy` (string): saleDate|totalRevenue|concreteYards|profitMargin
- `sortOrder` (enum): asc|desc

**Response:**
```typescript
{
  "success": true,
  "data": {
    "sales": [
      {
        "id": "uuid",
        "saleNumber": "INV-2024-001",
        "projectId": "PROJ-001",
        "customerName": "ABC Construction",
        "saleDate": "2024-01-15",
        "deliveryDate": "2024-01-15",
        "concreteType": "Standard 4000 PSI",
        "concreteYards": 25.5,
        "unitPrice": 125.00,
        "totalRevenue": 3187.50,
        "deliveryAddress": "123 Main St, City, ST",
        "deliveryStatus": "delivered",
        "salesRepName": "John Smith",
        "profitMargin": 22.5,
        "grossProfit": 717.19
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalRecords": 1247,
      "totalPages": 25,
      "hasNext": true,
      "hasPrevious": false
    },
    "summary": {
      "totalRevenue": 156750.00,
      "totalYards": 1254.0,
      "averagePrice": 125.00,
      "averageMargin": 18.5
    }
  }
}
```

#### Create Sale
```http
POST /sales
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**
```typescript
{
  "projectId": "PROJ-001",
  "customerId": "uuid",
  "saleDate": "2024-01-15",
  "deliveryDate": "2024-01-15",
  "concreteTypeId": "uuid",
  "concreteYards": 25.5,
  "unitPrice": 125.00,
  "deliveryAddress": "123 Main St, City, ST 12345",
  "salesRepId": "uuid",
  "truckNumber": "T-001",
  "driverName": "Mike Johnson",
  "pourTimeStart": "08:30",
  "pourTimeEnd": "09:45",
  "fuelSurcharge": 12.75,
  "overtimeCharges": 0,
  "additionalCharges": 0,
  "notes": "Customer requested early morning delivery"
}
```

**Validation Rules:**
- `concreteYards`: Required, positive number, max 200 yards per delivery
- `unitPrice`: Required, positive number, range $50-$300 per yard
- `saleDate`: Required, cannot be more than 30 days in the future
- `deliveryAddress`: Required, max 500 characters
- `projectId`: Must reference existing active project

**Response:**
```typescript
{
  "success": true,
  "data": {
    "sale": {
      "id": "uuid",
      "saleNumber": "INV-2024-002",
      // ... complete sale object
      "calculatedCosts": {
        "manufacturingCost": 1785.00,
        "laborCost": 255.00,
        "fuelCost": 127.50,
        "totalCosts": 2167.50
      },
      "profitAnalysis": {
        "grossProfit": 1020.00,
        "profitMargin": 32.0,
        "profitPerYard": 40.00
      }
    }
  }
}
```

### Cost Management

#### Get Costs
```http
GET /costs?projectId=PROJ-001&category=manufacturing&startDate=2024-01-01&endDate=2024-01-31
Authorization: Bearer {token}
```

**Query Parameters:**
- `projectId` (string): Filter by project
- `saleId` (UUID): Filter by specific sale
- `category` (enum): manufacturing|labor|equipment|fuel|fixed|overhead
- `startDate` (date): Filter from this date
- `endDate` (date): Filter to this date
- `vendorId` (UUID): Filter by vendor
- `approved` (boolean): Filter by approval status

**Response:**
```typescript
{
  "success": true,
  "data": {
    "costs": [
      {
        "id": "uuid",
        "projectId": "PROJ-001",
        "saleId": "uuid",
        "costCategory": "manufacturing",
        "costType": "Cement",
        "amount": 850.00,
        "costDate": "2024-01-15",
        "vendorName": "Regional Cement Co",
        "quantity": 17.0,
        "unitCost": 50.00,
        "unitType": "tons",
        "description": "Type I Portland Cement",
        "invoiceNumber": "RC-2024-001",
        "isDirectCost": true,
        "approvedBy": "Jane Manager",
        "approvedAt": "2024-01-16T10:30:00Z"
      }
    ],
    "summary": {
      "totalCosts": 15750.00,
      "breakdownByCategory": {
        "manufacturing": 8900.00,
        "labor": 3200.00,
        "equipment": 2100.00,
        "fuel": 950.00,
        "fixed": 600.00
      }
    }
  }
}
```

#### Create Cost Entry
```http
POST /costs
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**
```typescript
{
  "projectId": "PROJ-001",
  "saleId": "uuid", // Optional - links to specific delivery
  "costCategory": "manufacturing",
  "costType": "Cement",
  "amount": 850.00,
  "costDate": "2024-01-15",
  "vendorId": "uuid",
  "quantity": 17.0,
  "unitCost": 50.00,
  "unitType": "tons",
  "description": "Type I Portland Cement for standard mix",
  "invoiceNumber": "RC-2024-001",
  "isDirectCost": true,
  "equipmentId": "uuid" // Optional - for equipment-related costs
}
```

### Profit Analysis

#### Get Profit Analysis
```http
GET /profit/analysis?startDate=2024-01-01&endDate=2024-01-31&groupBy=week&customerId=uuid
Authorization: Bearer {token}
```

**Query Parameters:**
- `startDate` (date, required): Analysis period start
- `endDate` (date, required): Analysis period end
- `groupBy` (enum): day|week|month|quarter
- `customerId` (UUID): Filter by customer
- `projectId` (string): Filter by project
- `concreteType` (string): Filter by concrete type
- `salesRepId` (UUID): Filter by sales rep
- `includeForecasting` (boolean): Include predictive data

**Response:**
```typescript
{
  "success": true,
  "data": {
    "summary": {
      "dateRange": {
        "startDate": "2024-01-01",
        "endDate": "2024-01-31"
      },
      "totalRevenue": 89750.00,
      "totalCosts": 65200.00,
      "netProfit": 24550.00,
      "profitMargin": 27.4,
      "totalYards": 718.0,
      "profitPerYard": 34.20,
      "numberOfDeliveries": 28,
      "numberOfProjects": 8
    },
    "breakdown": {
      "costsByCategory": {
        "manufacturing": 45640.00, // 70% of total costs
        "labor": 11780.00,         // 18% of total costs
        "equipment": 4890.00,      // 7.5% of total costs
        "fuel": 2300.00,           // 3.5% of total costs
        "fixed": 590.00            // 1% of total costs
      },
      "revenueByConcreteType": {
        "Standard 3000 PSI": 32100.00,
        "Standard 4000 PSI": 41250.00,
        "High Strength 5000 PSI": 16400.00
      },
      "profitByProject": [
        {
          "projectId": "PROJ-001",
          "projectName": "Downtown Office Building",
          "revenue": 28750.00,
          "costs": 20125.00,
          "profit": 8625.00,
          "margin": 30.0
        }
      ]
    },
    "trends": [
      {
        "period": "2024-W03", // Week 3 of 2024
        "revenue": 22400.00,
        "costs": 16100.00,
        "profit": 6300.00,
        "margin": 28.1,
        "yards": 179.0
      }
    ],
    "benchmarks": {
      "industryAverageMargin": 22.0,
      "previousPeriodMargin": 25.8,
      "targetMargin": 25.0,
      "performanceVsTarget": "+2.4%"
    }
  }
}
```

#### Get Margin Trends
```http
GET /profit/margins/trends?months=12&concreteType=Standard+4000+PSI
Authorization: Bearer {token}
```

**Response:**
```typescript
{
  "success": true,
  "data": {
    "trends": [
      {
        "month": "2024-01",
        "averageMargin": 27.4,
        "volumeYards": 718.0,
        "averageCostPerYard": 90.85,
        "averagePricePerYard": 125.00
      }
    ],
    "insights": {
      "trendDirection": "increasing", // increasing|decreasing|stable
      "seasonalPatterns": [
        {
          "season": "winter",
          "typicalMargin": 28.5,
          "note": "Higher margins due to reduced competition"
        }
      ],
      "recommendations": [
        "Consider raising prices for Standard 4000 PSI during Q2",
        "Monitor cement cost increases affecting margin"
      ]
    }
  }
}
```

### Project Management

#### Get Projects
```http
GET /projects?status=active&customerId=uuid&page=1&limit=25
Authorization: Bearer {token}
```

**Response:**
```typescript
{
  "success": true,
  "data": {
    "projects": [
      {
        "id": "PROJ-001",
        "projectName": "Downtown Office Building",
        "customerName": "ABC Construction",
        "siteAddress": "456 Business Ave, City, ST",
        "projectStatus": "active",
        "startDate": "2024-01-10",
        "estimatedCompletionDate": "2024-03-15",
        "estimatedTotalYards": 500.0,
        "actualTotalYards": 125.0,
        "contractAmount": 62500.00,
        "projectManagerName": "Sarah Johnson",
        "deliveriesCompleted": 5,
        "currentProfitMargin": 28.5,
        "progressPercentage": 25.0
      }
    ]
  }
}
```

#### Create Project
```http
POST /projects
Authorization: Bearer {token}
```

**Request Body:**
```typescript
{
  "projectName": "New Shopping Center",
  "customerId": "uuid",
  "siteAddress": "789 Commerce St, City, ST 12345",
  "startDate": "2024-02-01",
  "estimatedCompletionDate": "2024-04-30",
  "estimatedTotalYards": 850.0,
  "contractAmount": 106250.00,
  "projectManagerId": "uuid",
  "notes": "Large commercial project with multiple pours"
}
```

### Reporting

#### Generate Sales Report
```http
POST /reports/sales
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**
```typescript
{
  "reportType": "monthly_summary", // daily_detail|monthly_summary|custom
  "dateRange": {
    "startDate": "2024-01-01",
    "endDate": "2024-01-31"
  },
  "filters": {
    "customerId": "uuid",
    "salesRepId": "uuid",
    "concreteType": "Standard 4000 PSI"
  },
  "groupBy": "customer", // date|customer|project|sales_rep|concrete_type
  "includeCharts": true,
  "format": "pdf", // pdf|excel|json
  "title": "January 2024 Sales Performance Report"
}
```

**Response:**
```typescript
{
  "success": true,
  "data": {
    "reportId": "uuid",
    "status": "generating", // generating|completed|failed
    "estimatedCompletionTime": "2024-01-15T10:35:00Z",
    "downloadUrl": null // Available when status is "completed"
  }
}
```

#### Get Report Status
```http
GET /reports/{reportId}
Authorization: Bearer {token}
```

**Response:**
```typescript
{
  "success": true,
  "data": {
    "reportId": "uuid",
    "status": "completed",
    "generatedAt": "2024-01-15T10:34:22Z",
    "downloadUrl": "https://api.concreteanalyzer.com/v1/reports/uuid/download",
    "expiresAt": "2024-01-22T10:34:22Z", // 7 days from generation
    "fileSize": 2457600, // bytes
    "format": "pdf"
  }
}
```

### Analytics & Insights

#### Get Dashboard Data
```http
GET /analytics/dashboard?period=30days
Authorization: Bearer {token}
```

**Response:**
```typescript
{
  "success": true,
  "data": {
    "kpis": {
      "totalRevenue": {
        "value": 89750.00,
        "previousPeriod": 78650.00,
        "change": "+14.1%",
        "trend": "up"
      },
      "totalYards": {
        "value": 718.0,
        "previousPeriod": 634.0,
        "change": "+13.2%",
        "trend": "up"
      },
      "averageMargin": {
        "value": 27.4,
        "previousPeriod": 25.8,
        "change": "+1.6pp",
        "trend": "up"
      },
      "activeProjects": {
        "value": 12,
        "previousPeriod": 14,
        "change": "-2",
        "trend": "down"
      }
    },
    "charts": {
      "dailyRevenue": [
        {"date": "2024-01-01", "revenue": 2850.00, "yards": 22.8},
        {"date": "2024-01-02", "revenue": 3750.00, "yards": 30.0}
      ],
      "profitTrends": [
        {"week": "2024-W01", "margin": 26.2},
        {"week": "2024-W02", "margin": 28.1}
      ],
      "costBreakdown": {
        "manufacturing": 70.0,
        "labor": 18.0,
        "equipment": 7.5,
        "fuel": 3.5,
        "fixed": 1.0
      }
    },
    "alerts": [
      {
        "type": "margin_low",
        "severity": "warning",
        "message": "Profit margin below target for Project PROJ-003",
        "projectId": "PROJ-003"
      }
    ],
    "upcomingDeliveries": [
      {
        "saleId": "uuid",
        "projectName": "Downtown Office",
        "scheduledDate": "2024-01-16",
        "yards": 45.0,
        "customerName": "ABC Construction"
      }
    ]
  }
}
```

## Error Handling

### Standard Error Response Format
```typescript
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "concreteYards",
        "message": "Must be a positive number",
        "value": -5
      }
    ],
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "req-uuid"
  }
}
```

### Error Codes
- `VALIDATION_ERROR` (400): Request data validation failed
- `UNAUTHORIZED` (401): Invalid or missing authentication token
- `FORBIDDEN` (403): Insufficient permissions for requested operation
- `NOT_FOUND` (404): Requested resource not found
- `CONFLICT` (409): Request conflicts with current state (e.g., duplicate sale number)
- `RATE_LIMIT_EXCEEDED` (429): Too many requests
- `INTERNAL_ERROR` (500): Unexpected server error
- `SERVICE_UNAVAILABLE` (503): Service temporarily unavailable

## Rate Limiting

**Limits per API key per hour:**
- Authentication: 100 requests
- Read operations: 1000 requests  
- Write operations: 500 requests
- Report generation: 50 requests

**Headers included in responses:**
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
X-RateLimit-Window: 3600
```

## Data Validation

### Input Validation Rules

#### Sales Data
```typescript
const saleValidation = {
  concreteYards: {
    type: 'number',
    min: 0.1,
    max: 200.0,
    required: true
  },
  unitPrice: {
    type: 'number',
    min: 50.00,
    max: 300.00,
    required: true
  },
  saleDate: {
    type: 'date',
    maxFutureDays: 30,
    required: true
  },
  deliveryAddress: {
    type: 'string',
    maxLength: 500,
    required: true
  }
}
```

#### Cost Data
```typescript
const costValidation = {
  amount: {
    type: 'number',
    min: 0,
    max: 100000.00,
    required: true
  },
  costDate: {
    type: 'date',
    maxFutureDays: 0,
    minPastDays: 365,
    required: true
  },
  costCategory: {
    type: 'enum',
    values: ['manufacturing', 'labor', 'equipment', 'fuel', 'fixed', 'overhead'],
    required: true
  }
}
```

## Performance Considerations

### Caching Strategy
- **Authentication tokens**: 15 minutes (in-memory)
- **Static data** (concrete types, users): 1 hour (Redis)
- **Dashboard data**: 5 minutes (Redis)
- **Report results**: 24 hours (S3 + CDN)

### Pagination
- **Default page size**: 50 records
- **Maximum page size**: 200 records
- **Large datasets**: Use cursor-based pagination for >10K records

### Response Time Targets
- **Simple queries**: <200ms
- **Complex analytics**: <500ms  
- **Report generation**: <30 seconds
- **Dashboard refresh**: <300ms

This API specification provides a comprehensive interface for the concrete sales and profit analyzer with industry-specific functionality and robust error handling.