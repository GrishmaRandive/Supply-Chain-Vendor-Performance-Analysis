CREATE DATABASE SupplyChainDB;
USE SupplyChainDB;


USE SupplyChainDB;
SELECT COUNT(*) FROM PurchaseOrders_Raw;
SELECT * FROM PurchaseOrders_Raw LIMIT 10;

-- PURCHASE ORDERS CLEAN TABLE

-- Create Clean Table with Proper Data Types

CREATE TABLE PurchaseOrders_Clean AS
SELECT
    PO_ID,
    Supplier,

    -- Dates
    STR_TO_DATE(NULLIF(Order_Date,''), '%Y-%m-%d') AS Order_Date,
    STR_TO_DATE(NULLIF(Delivery_Date,''), '%Y-%m-%d') AS Delivery_Date,
purchaseorders_rawpurchaseorders_raw
    Item_Category,
    Order_Status,

    -- Numbers (allow decimals, then cast to int safely)
    CAST(ROUND(CAST(NULLIF(Quantity,'') AS DECIMAL(10,2))) AS UNSIGNED) AS Quantity,
    CAST(NULLIF(Unit_Price,'') AS DECIMAL(10,2)) AS Unit_Price,
    CAST(NULLIF(Negotiated_Price,'') AS DECIMAL(10,2)) AS Negotiated_Price,
    COALESCE(CAST(ROUND(CAST(NULLIF(Defective_Units,'') AS DECIMAL(10,2))) AS UNSIGNED),0) AS Defective_Units,

    Compliance,

    -- KPIs
    DATEDIFF(
        STR_TO_DATE(NULLIF(Delivery_Date,''), '%Y-%m-%d'),
        STR_TO_DATE(NULLIF(Order_Date,''), '%Y-%m-%d')
    ) AS LeadTimeDays,

    CASE 
        WHEN STR_TO_DATE(NULLIF(Delivery_Date,''), '%Y-%m-%d') 
             <= DATE_ADD(STR_TO_DATE(NULLIF(Order_Date,''), '%Y-%m-%d'), INTERVAL 7 DAY)
        THEN 1 ELSE 0 
    END AS OnTimeFlag,

    COALESCE(CAST(ROUND(CAST(NULLIF(Defective_Units,'') AS DECIMAL(10,2))) AS UNSIGNED),0) 
       / NULLIF(CAST(ROUND(CAST(NULLIF(Quantity,'') AS DECIMAL(10,2))) AS UNSIGNED),0) AS DefectRate,

    1 - (
        COALESCE(CAST(ROUND(CAST(NULLIF(Defective_Units,'') AS DECIMAL(10,2))) AS UNSIGNED),0) 
        / NULLIF(CAST(ROUND(CAST(NULLIF(Quantity,'') AS DECIMAL(10,2))) AS UNSIGNED),0)
    ) AS FillRate

FROM PurchaseOrders_Raw;
select * from PurchaseOrders_Clean;

-- PURCHASE ORDERS ANALYSIS
-- Run Analysis Queries in MySQL
-- 1. Vendor Performance
SELECT
    Supplier,
    COUNT(*) AS TotalOrders,
    ROUND(AVG(OnTimeFlag),2) AS OnTimeRate,
    ROUND(AVG(LeadTimeDays),1) AS AvgLeadTime,
    SUM(Quantity) AS TotalQty,
    SUM(Defective_Units) AS TotalDefects,
    ROUND(SUM(Defective_Units)/SUM(Quantity),2) AS DefectRate,
    SUM(Quantity * Unit_Price) AS TotalSpend,
    SUM((Unit_Price - IFNULL(Negotiated_Price,Unit_Price)) * Quantity) AS NegotiatedSavings
FROM PurchaseOrders_Clean
GROUP BY Supplier
ORDER BY OnTimeRate DESC;
--  Gives supplier scorecard (on-time %, defect rate, spend, savings).

-- 2. Category Insights

SELECT
    Item_Category,
    COUNT(*) AS Orders,
    AVG(LeadTimeDays) AS AvgLeadTime,
    SUM(Quantity) AS TotalQty,
    SUM(Quantity * Unit_Price) AS Spend,
    SUM(Defective_Units) AS Defects
FROM PurchaseOrders_Clean
GROUP BY Item_Category
ORDER BY Spend DESC;
--  See which product categories cost the most, and defect-heavy ones.

-- 3. Time Trend
SELECT
    DATE_FORMAT(Order_Date, '%Y-%m') AS Month,
    ROUND(AVG(OnTimeFlag),2) AS AvgOnTimeRate,
    ROUND(AVG(DefectRate),2) AS AvgDefectRate,
    SUM(Quantity * Unit_Price) AS MonthlySpend
FROM PurchaseOrders_Clean
GROUP BY DATE_FORMAT(Order_Date, '%Y-%m')
ORDER BY Month;

--  Track performance month by month.


-- Instead of re-writing big queries, make a View so Power BI connects directly.

CREATE OR REPLACE VIEW v_VendorPerformance AS
SELECT
    Supplier,
    COUNT(*) AS TotalOrders,
    ROUND(AVG(OnTimeFlag),2) AS OnTimeRate,
    ROUND(AVG(LeadTimeDays),1) AS AvgLeadTime,
    SUM(Quantity) AS TotalQty,
    SUM(Defective_Units) AS TotalDefects,
    ROUND(SUM(Defective_Units)/SUM(Quantity),2) AS DefectRate,
    SUM(Quantity * Unit_Price) AS TotalSpend,
    SUM((Unit_Price - IFNULL(Negotiated_Price,Unit_Price)) * Quantity) AS NegotiatedSavings
FROM PurchaseOrders_Clean
GROUP BY Supplier;

-- load v_VendorPerformance directly in  Power BI .

