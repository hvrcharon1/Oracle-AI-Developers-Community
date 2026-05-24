# Skill 06: Oracle APEX AI Assistant

**Category:** Low-Code | AI | **Level:** Beginner

---

## Overview

Oracle APEX AI Assistant is a built-in generative AI feature in APEX 24.1+ that lets developers generate applications, SQL queries, PL/SQL code, and page components using natural language. It represents the "GenDev" (Generative Development) paradigm: describing what you want and having AI build it.

---

## Key Features

- **App Generation**: Describe a business app and APEX generates pages, forms, reports, and navigation
- **SQL Workshop AI**: Write natural language questions and get SQL queries in return
- **Page Designer AI**: Ask AI to add or modify page components
- **Quick SQL AI**: Convert English data models into Quick SQL notation
- **PL/SQL Generation**: Generate triggers, procedures, and validations from plain descriptions

---

## Step-by-Step

### 1. Enable Generative AI in APEX

1. Log in to **APEX Administration Services**
2. Go to **Instance Settings** → **AI Attributes**
3. Select **OCI Generative AI** as the provider
4. Configure your OCI credentials and choose a model (e.g., `meta.llama-3-70b-instruct`)
5. Save and return to the App Builder

### 2. Generate an Application with AI

1. Click **Create** → **Create Application**
2. Select **Use AI to Generate Application**
3. Enter a description:

```
Create a sales dashboard app with pages for:
- Customer management (search, create, edit)
- Order tracking with status filters
- Revenue reports by region and product category
- A homepage with KPI cards for total revenue, orders, and new customers this month
```

4. Review the generated page outline, adjust as needed, and click **Create Application**

### 3. Use AI in SQL Workshop

1. Open **SQL Workshop** → **SQL Commands**
2. Click the **AI** button (sparkle icon)
3. Type in natural language:

```
Find the top 10 customers by total order value in the last 90 days, including their email and region.
```

4. Review the generated SQL, then run or copy it

### 4. AI-Assisted Page Design

1. Open any page in **Page Designer**
2. Click the AI Assistant panel
3. Ask:

```
Add a bar chart showing monthly revenue for the current year, grouped by product category.
```

4. APEX AI creates the chart region with the appropriate SQL and formatting

---

## Best Practices

- Be **specific and structured** in your descriptions — include entity names, filters, and layout preferences
- Always **review generated SQL** before deploying to production
- Use AI for **scaffolding**, then refine manually for business logic edge cases
- Combine AI-generated apps with **Oracle AI Vector Search** for semantic search features

---

## Related Skills

- [Skill 02: Select AI — Natural Language to SQL](02_select_ai_natural_language_to_sql.md)
- [Skill 07: OCI Generative AI Service](07_oci_generative_ai_service.md)

**#OracleAPEX #GenDev #LowCode #AIAssistant #OracleAI**
