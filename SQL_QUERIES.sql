-- ============================================================================
-- Project Name: Global Online Retail Exploratory Data Analysis (EDA)
-- Developer / Analyst: Deepak Yogi
-- Business Logic & Strategy: Conceptualized and structured independently 
--   to analyze sales performance, customer behavior, and returns.
-- Development Approach: Leveraged AI-assisted prompt engineering for query 
--   optimization, advanced syntax structuring (CTEs, Window Functions), and workflow efficiency.
-- ============================================================================


CREATE DATABASE Global_Retail_Sales;

CREATE TABLE retail_sales (
    InvoiceNo VARCHAR(50),
    StockCode VARCHAR(50),
    Description TEXT,
    Quantity INT,
    InvoiceDate DATE,
    InvoiceTime TIME,
    UnitPrice DECIMAL(10, 2),
    Total_Price DECIMAL(10, 2),
    Transaction_type VARCHAR(50),
    CustomerID VARCHAR(50),
    Country VARCHAR(100)
);
	SELECT * FROM retail_sales;
DROP TABLE IF EXISTS retail_sales;

CREATE TABLE retail_sales (
    InvoiceNo VARCHAR(50),
    StockCode VARCHAR(50),
    Description TEXT,
    Quantity NUMERIC(10, 2),
    InvoiceDate DATE,
    InvoiceTime TIME,
    UnitPrice NUMERIC(10, 2),
    Total_Price NUMERIC(10, 2),
    Transaction_type VARCHAR(50),
    CustomerID VARCHAR(50),
    Country VARCHAR(100)
);

-- 1. Total Rows Check
-- Quick sanity check to confirm total dataset volume after import.
SELECT COUNT(*) AS total_records 
FROM retail_sales;


-- 2. Transaction Status Breakdown
-- Analyzes the volume and revenue impact of Completed vs Cancelled orders.
SELECT 
    Transaction_type,
    COUNT(InvoiceNo) AS total_orders,
    SUM(Total_Price) AS total_value
FROM retail_sales
GROUP BY Transaction_type;


-- 3. High-Level Key Performance Indicators (KPIs)
-- Calculates Overall Revenue, Total Quantity Sold, and Total Unique Customers for Completed Sales.
SELECT 
    SUM(Total_Price) AS overall_revenue,
    SUM(Quantity) AS total_items_sold,
    COUNT(DISTINCT InvoiceNo) AS total_successful_orders,
    COUNT(DISTINCT CustomerID) AS unique_customers
FROM retail_sales
WHERE Transaction_type = 'Completed Sale';


-- 4. Monthly Revenue Trend
-- Tracks month-on-month sales performance to identify seasonality and growth.
SELECT 
    TO_CHAR(InvoiceDate, 'YYYY-MM') AS sales_month,
    SUM(Total_Price) AS monthly_revenue,
    COUNT(DISTINCT InvoiceNo) AS monthly_orders
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
GROUP BY TO_CHAR(InvoiceDate, 'YYYY-MM')
ORDER BY sales_month;


-- 5. Peak Order Hours Analysis
-- Identifies the busiest time of day to optimize server load and customer support operations.
SELECT 
    EXTRACT(HOUR FROM InvoiceTime) AS order_hour,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Total_Price), 2) AS hourly_revenue
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
GROUP BY EXTRACT(HOUR FROM InvoiceTime)
ORDER BY total_orders DESC;


-- 6. Top 10 Revenue-Generating Products
-- Ranks the best-selling stock items by total monetary value.
SELECT 
    StockCode,
    COALESCE(Description, 'No Description') AS Description,
    SUM(Quantity) AS total_units_sold,
    ROUND(SUM(COALESCE(Total_Price, 0)), 2) AS total_revenue
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
  AND Total_Price IS NOT NULL
GROUP BY StockCode, Description
ORDER BY total_revenue DESC
LIMIT 10;


-- 7. Top 10 Countries by Sales Revenue
-- Shows geographical performance outside the UK market.
SELECT 
    Country,
    COUNT(DISTINCT CustomerID) AS total_customers,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Total_Price), 2) AS country_revenue
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
GROUP BY Country
ORDER BY country_revenue DESC
LIMIT 10;


-- 8. Top 10 High-Value VIP Customers
-- Identifies loyal customers generating the most revenue (excluding unknown guest checkouts).

SELECT 
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS order_frequency,
    ROUND(SUM(COALESCE(Total_Price, 0)), 2) AS lifetime_spend
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
  AND CustomerID <> 'Unknown'
  AND CustomerID IS NOT NULL
  AND Total_Price IS NOT NULL
GROUP BY CustomerID
ORDER BY lifetime_spend DESC
LIMIT 10;


-- 9. Non-Product & Service Fee Analysis
-- Isolates extra operational costs like Shipping/Postage and Manual Fees.
SELECT 
    StockCode,
    COALESCE(Description, 'No Description Available') AS Description,
    COUNT(*) AS frequency,
    ROUND(SUM(COALESCE(Total_Price, 0)), 2) AS total_fee_amount
FROM retail_sales
WHERE StockCode IN ('POST', 'D', 'M', 'BANK CHARGES', 'AMAZONFEE', 'DOT')
  AND Total_Price IS NOT NULL
GROUP BY StockCode, Description
ORDER BY total_fee_amount DESC;


-- 10. Customer Order Frequency Distribution
-- Groups customers by their order counts to understand repeat purchasing behavior.
WITH CustomerOrders AS (
    SELECT 
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS total_orders
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale' 
      AND CustomerID <> 'Unknown'
    GROUP BY CustomerID
)
SELECT 
    CASE 
        WHEN total_orders = 1 THEN '1 Single Order'
        WHEN total_orders BETWEEN 2 AND 5 THEN '2-5 Repeat Orders'
        WHEN total_orders BETWEEN 6 AND 10 THEN '6-10 Frequent Customer'
        ELSE '10+ VIP Regulars'
    END AS customer_category,
    COUNT(CustomerID) AS customer_count
FROM CustomerOrders
GROUP BY customer_category
ORDER BY customer_count DESC;


-- 11. Average Order Value (AOV) per Country
-- Evaluates the purchasing power of customers across different markets.
SELECT 
    Country,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Total_Price), 2) AS total_revenue,
    ROUND(SUM(Total_Price) / COUNT(DISTINCT InvoiceNo), 2) AS avg_order_value
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
GROUP BY Country
HAVING COUNT(DISTINCT InvoiceNo) > 10
ORDER BY avg_order_value DESC;


-- 12. Month-over-Month (MoM) Growth Rate
-- Calculates percentage revenue growth compared to the previous month using Window Functions.
WITH MonthlySales AS (
    SELECT 
        TO_CHAR(InvoiceDate, 'YYYY-MM') AS month,
        SUM(Total_Price) AS current_month_sales
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
    GROUP BY TO_CHAR(InvoiceDate, 'YYYY-MM')
)
SELECT 
    month,
    ROUND(current_month_sales, 2) AS revenue,
    ROUND(LAG(current_month_sales, 1) OVER (ORDER BY month), 2) AS previous_month_sales,
    ROUND(
        ((current_month_sales - LAG(current_month_sales, 1) OVER (ORDER BY month)) / 
        NULLIF(LAG(current_month_sales, 1) OVER (ORDER BY month), 0)) * 100, 2
    ) AS mom_growth_percentage
FROM MonthlySales;


-- 13. Running Cumulative Revenue
-- Calculates the running total of sales revenue over time.
WITH DailySales AS (
    SELECT 
        InvoiceDate,
        SUM(Total_Price) AS daily_revenue
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
    GROUP BY InvoiceDate
)
SELECT 
    InvoiceDate,
    ROUND(daily_revenue, 2) AS daily_revenue,
    ROUND(SUM(daily_revenue) OVER (ORDER BY InvoiceDate), 2) AS running_total_revenue
FROM DailySales
ORDER BY InvoiceDate;


-- 14. RFM Segmentation: Recency, Frequency, Monetary (RFM Base Metric)
-- Prepares essential parameters to segment customers based on purchasing recency and value.
SELECT 
    CustomerID,
    MAX(InvoiceDate) AS last_purchase_date,
    COUNT(DISTINCT InvoiceNo) AS order_frequency,
    ROUND(SUM(COALESCE(Total_Price, 0)), 2) AS total_monetary_value
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
  AND CustomerID <> 'Unknown'
  AND Total_Price IS NOT NULL
GROUP BY CustomerID
ORDER BY total_monetary_value DESC;

-- 15. Top Selling Product in Each Country (Window Function)
-- Determines the most popular item per country using dense rank.
WITH RankedProducts AS (
    SELECT 
        Country,
        Description,
        SUM(Quantity) AS total_quantity,
        DENSE_RANK() OVER (PARTITION BY Country ORDER BY SUM(Quantity) DESC) AS rank
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale' 
      AND Description IS NOT NULL
    GROUP BY Country, Description
)
SELECT 
    Country,
    Description AS top_product,
    total_quantity
FROM RankedProducts
WHERE rank = 1
ORDER BY total_quantity DESC
LIMIT 15;

-- 16. Churn Risk Analysis
-- Identifies previously active customers who haven't ordered in the last 90 days

WITH LastOverallDate AS (
    SELECT MAX(InvoiceDate) AS max_date 
    FROM retail_sales
),
CustomerMetrics AS (
    SELECT 
        CustomerID,
        MAX(InvoiceDate) AS last_order_date,
        COUNT(DISTINCT InvoiceNo) AS total_orders,
        ROUND(SUM(COALESCE(Total_Price, 0)), 2) AS lifetime_spend
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
      AND CustomerID <> 'Unknown'
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
)
SELECT 
    cm.CustomerID,
    cm.last_order_date,
    (ld.max_date - cm.last_order_date) AS days_since_last_order,
    cm.total_orders,
    cm.lifetime_spend
FROM CustomerMetrics cm
CROSS JOIN LastOverallDate ld
WHERE cm.total_orders >= 2
  AND (ld.max_date - cm.last_order_date) > 90
ORDER BY cm.lifetime_spend DESC;

-- 17. Pareto 80/20 Revenue Analysis
-- Identifies the top products contributing to 80% of total revenue
WITH ProductRevenue AS (
    SELECT 
        StockCode,
        COALESCE(Description, 'No Description') AS Description,
        SUM(COALESCE(Total_Price, 0)) AS product_revenue
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
      AND Description IS NOT NULL
    GROUP BY StockCode, Description
),
CumulativeRevenue AS (
    SELECT 
        StockCode,
        Description,
        ROUND(product_revenue, 2) AS product_revenue,
        ROUND(
            (SUM(product_revenue) OVER (ORDER BY product_revenue DESC) / 
             SUM(product_revenue) OVER ()) * 100, 2
        ) AS cumulative_revenue_pct
    FROM ProductRevenue
)
SELECT 
    StockCode,
    Description,
    product_revenue,
    cumulative_revenue_pct
FROM CumulativeRevenue
WHERE cumulative_revenue_pct <= 80.00
ORDER BY product_revenue DESC;

-- 18. New vs. Repeat Customer Revenue Analysis
-- Classifies transactions based on whether it was a customer's first purchase or repeat purchase
WITH CustomerFirstPurchase AS (
    SELECT 
        CustomerID,
        MIN(InvoiceDate) AS first_purchase_date
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
      AND CustomerID <> 'Unknown'
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),
TransactionClassification AS (
    SELECT 
        s.InvoiceNo,
        s.CustomerID,
        s.Total_Price,
        CASE 
            WHEN s.InvoiceDate = f.first_purchase_date THEN 'New Customer'
            ELSE 'Repeat Customer'
        END AS customer_type
    FROM retail_sales s
    JOIN CustomerFirstPurchase f ON s.CustomerID = f.CustomerID
    WHERE s.Transaction_type = 'Completed Sale'
      AND s.Total_Price IS NOT NULL
)
SELECT 
    customer_type,
    COUNT(DISTINCT CustomerID) AS total_customers,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Total_Price), 2) AS total_revenue,
    ROUND(
        (SUM(Total_Price) / (SELECT SUM(Total_Price) FROM TransactionClassification)) * 100, 2
    ) AS revenue_share_percentage
FROM TransactionClassification
GROUP BY customer_type;

-- 19. Average Purchase Repeat Interval
-- Calculates the average number of days a customer takes to make their next purchase
WITH OrderedInvoices AS (
    SELECT DISTINCT
        CustomerID,
        InvoiceNo,
        InvoiceDate
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
      AND CustomerID <> 'Unknown'
      AND CustomerID IS NOT NULL
),
NextPurchaseDates AS (
    SELECT 
        CustomerID,
        InvoiceDate,
        LEAD(InvoiceDate) OVER (PARTITION BY CustomerID ORDER BY InvoiceDate) AS next_invoice_date
    FROM OrderedInvoices
),
OrderIntervals AS (
    SELECT 
        CustomerID,
        (next_invoice_date - InvoiceDate) AS days_between_orders
    FROM NextPurchaseDates
    WHERE next_invoice_date IS NOT NULL
)
SELECT 
    ROUND(AVG(days_between_orders), 1) AS avg_days_between_orders,
    MIN(days_between_orders) AS min_days_gap,
    MAX(days_between_orders) AS max_days_gap
FROM OrderIntervals;

-- 20. Top 10 Frequently Cancelled Products
-- Identifies products that face the highest cancellation rates to minimize losses.
SELECT 
    StockCode,
    COALESCE(Description, 'No Description') AS Description,
    COUNT(*) AS cancellation_count,
    ROUND(SUM(ABS(Total_Price)), 2) AS total_cancelled_value
FROM retail_sales
WHERE LOWER(Transaction_type) LIKE '%cancel%'
  AND Total_Price IS NOT NULL
GROUP BY StockCode, Description
ORDER BY cancellation_count DESC
LIMIT 10;

-- 21. Sales Performance by Day of the Week
-- Analyzes which day of the week generates the highest orders and revenue.
SELECT 
    TO_CHAR(InvoiceDate, 'Day') AS day_of_week,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Total_Price), 2) AS total_revenue
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
GROUP BY TO_CHAR(InvoiceDate, 'Day'), EXTRACT(DOW FROM InvoiceDate)
ORDER BY total_revenue DESC;

-- 22. Customer Lifetime Value (LTV) Segmentation
-- Categorizes customers into tiers based on their total spending power.
WITH CustomerSpend AS (
    SELECT 
        CustomerID,
        ROUND(SUM(COALESCE(Total_Price, 0)), 2) AS total_spend
    FROM retail_sales
    WHERE Transaction_type = 'Completed Sale'
      AND CustomerID <> 'Unknown'
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
)
SELECT 
    CASE 
        WHEN total_spend > 5000 THEN 'Platinum VIP'
        WHEN total_spend BETWEEN 2000 AND 5000 THEN 'Gold Customer'
        WHEN total_spend BETWEEN 500 AND 1999 THEN 'Silver Customer'
        ELSE 'Standard Customer'
    END AS customer_tier,
    COUNT(CustomerID) AS total_customers,
    ROUND(SUM(total_spend), 2) AS tier_total_revenue
FROM CustomerSpend
GROUP BY customer_tier
ORDER BY tier_total_revenue DESC;

-- 23. Hourly Order Distribution and Revenue Contribution (12-Hour Format with AM/PM)
-- Analyzes peak hours of the day in AM/PM format to optimize server load and support availability.
SELECT 
    TO_CHAR(InvoiceTime, 'HH12:00 AM') AS order_time_slot,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Total_Price), 2) AS hourly_revenue,
    ROUND(AVG(Total_Price), 2) AS average_order_value_per_hour
FROM retail_sales
WHERE Transaction_type = 'Completed Sale'
  AND InvoiceTime IS NOT NULL
GROUP BY TO_CHAR(InvoiceTime, 'HH12:00 AM'), EXTRACT(HOUR FROM InvoiceTime)
ORDER BY EXTRACT(HOUR FROM InvoiceTime) ASC;
