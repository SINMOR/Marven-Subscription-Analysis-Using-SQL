SELECT *
FROM  marvensubscription
--|DATA CLEANING|
--change date format
SELECT created_date,CONVERT(date,created_date)
FROM marvensubscription
ALTER TABLE marvensubscription
ADD created_dateconv DATE
UPDATE marvensubscription
SET created_dateconv=CONVERT(date,created_date)
SELECT*
FROM marvensubscription
SELECT canceled_date,CONVERT(date,canceled_date)
FROM marvensubscription
ALTER TABLE marvensubscription
ADD canceled_dateconv DATE
UPDATE marvensubscription
SET canceled_dateconv=CONVERT(date,canceled_date)

ALTER TABLE marvensubscription
    DROP COLUMN canceled_dateconv ;
SELECT *
FROM marvensubscription

--checkingforduplicates
SELECT customer_id,COUNT(*) as Duplicates
FROM marvensubscription
GROUP BY customer_id
HAVING COUNT(*)>1 

SELECT*
FROM marvensubscription
WHERE customer_id=209743418
SELECT*
FROM marvensubscription
WHERE customer_id=214682826
SELECT*
FROM marvensubscription
WHERE customer_id=206121650
--use of partition by 
SELECT customer_id, created_date, canceled_date, ROW_NUMBER() OVER (PARTITION BY created_date, canceled_date ORDER BY created_date DESC) AS row_number
FROM marvensubscription;
--we have a total 185 duplicates with the same customer id but have difference created_date and canceled_id because a customer can have difference subscriptions in a year hence we will use CTES
--using CTEs and Partition 
WITH DuplicateRows AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS RowNum
    FROM marvensubscription
)
SELECT* FROM DuplicateRows WHERE RowNum >1 and created_date=canceled_date and canceled_date is NOT null;

--here we see we have 6 customers we the same customerid created_date and canceled_date hence we will delete the duplicates 
WITH DuplicateRows AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS RowNum
    FROM marvensubscription
)
DELETE FROM DuplicateRows WHERE RowNum >1 and created_date=canceled_date and canceled_date is NOT null;

--checking for null values
--because its a table with few columns we will use CASE
SELECT
  COUNT(CASE WHEN customer_id IS NULL THEN 1 END) as customer_idnulls,
  COUNT(CASE WHEN created_date IS NULL THEN 1 END) as created_datenulls,
  COUNT(CASE WHEN created_datestr IS NULL THEN 1 END) as canceled_datenull,
  COUNT(CASE WHEN subscription_cost IS NULL THEN 1 END) as subscription_costnulls,
  COUNT(CASE WHEN subscription_interval IS NULL THEN 1 END) as subscription_intervalnulls,
  COUNT(CASE WHEN was_subscription_paid IS NULL THEN 1 END) as was_subscription_paidnulls
FROM marvensubscription
---only canceled_date has 1065 null values 
--we will not use COALESCE to replace null values with NOT YET because we have different data types that is date and string hence it wont work 
--we will case to replace the null values in canceled date column 
SELECT canceled_dateconv,CONVERT(varchar(200),canceled_dateconv)
FROM marvensubscription
ALTER TABLE marvensubscription
ADD created_datestr VARCHAR(200)
UPDATE marvensubscription
SET created_datestr=CONVERT(varchar(200),canceled_dateconv)
SELECT *
FROM marvensubscription
UPDATE marvensubscription
SET created_datestr=COALESCE(created_datestr,'NOT YET')
WHERE created_datestr IS NULL 

UPDATE marvensubscription
SET canceled_dateconv = CASE
    WHEN canceled_date IS NULL THEN 'NOT YET'
    ELSE CONVERT(VARCHAR(10), canceled_date, 120) 
  END 
UPDATE marvensubscription
SET canceled_date = 
  CASE
    WHEN canceled_date IS NULL THEN 'NOT YET'
    ELSE CONVERT(DATETIME, canceled_date, 120)  -- Change the format as needed
  END
WHERE canceled_date IS NULL;

UPDATE marvensubscription
SET canceled_dateconv=ISNULL(CONVERT(VARCHAR(10), canceled_dateconv, 120),'NOT YET')
ALTER TABLE marvensubscription
DROP column canceled_dateconv

SELECT *
FROM marvensubscription
WHERE TRY_CAST(canceled_date AS DATETIME) IS NULL AND canceled_date IS NOT NULL

--|DATA ANALYSIS|
--1. what is the total number of subscriber 
SELECT COUNT(DISTINCT customer_id)
FROM marvensubscription
--2877 subsribers

--2.What is the average subscription cost
SELECT AVG(subscription_cost )
FROM marvensubscription
--39 Dollars

--3. Find the total number of unpaid  Subcription 
SELECT was_subscription_paid, COUNT(*)
FROM marvensubscription
WHERE was_subscription_paid='No'
GROUP BY was_subscription_paid
ORDER BY was_subscription_paid

--4.Find the total number of cancelled subscription 
SELECT COUNT(*)
FROM marvensubscription
WHERE canceled_dateconv is NOT NULL
-- 1998

--5.Which date did people cancel the most 
SELECT canceled_dateconv,COUNT(*)
FROM marvensubscription
WHERE canceled_dateconv is NOT NULL
GROUP BY canceled_dateconv
ORDER BY COUNT(*) DESC
--2023-06-27

--6.List the most common subscription intervals 
SELECT subscription_interval,COUNT(*)
FROM marvensubscription
GROUP BY subscription_interval
ORDER BY COUNT(*) DESC
--month with 3063

--7.Calculate the percentage of paid  subscription 
SELECT
  (COUNT(CASE WHEN was_subscription_paid = 'Yes' THEN 1 END) * 100.0) / COUNT(*) AS PaidPercentage
FROM marvensubscription
--95.65%

--calculate the monthly revenue for a year 
WITH MonthlyRevenue AS (
  SELECT
    MONTH(created_dateconv) AS Month,
    YEAR(created_dateconv) AS Year,
    SUM(subscription_cost) AS MonthlyTotalRevenue
  FROM marvensubscription
  GROUP BY YEAR(created_dateconv), MONTH(created_dateconv)
  
)
SELECT Year, Month, MonthlyTotalRevenue
FROM MonthlyRevenue
ORDER BY MonthlyTotalRevenue DESC
--without the use of CTEs 
SELECT
    MONTH(created_dateconv) AS Month,
    YEAR(created_dateconv) AS Year,
    SUM(subscription_cost) AS MonthlyTotalRevenue
  FROM marvensubscription
  GROUP BY YEAR(created_dateconv), MONTH(created_dateconv)
  ORDER BY MonthlyTotalRevenue DESC
--The Month with the highest grossing revenue was July with a total of $11856 and the lowest month was September with $2574
SELECT *
FROM marvensubscription

--8.Find the subscriptions with the longest duration 
SELECT
  customer_id,
  DATEDIFF(DAY, created_date, canceled_date) AS SubscriptionDuration
FROM marvensubscription
ORDER BY SubscriptionDuration DESC
OFFSET 0 ROWS
FETCH FIRST 5 ROWS ONLY
--customer 155406449   had the highest subscription days with 348 days  then followed by 118029150 with 341

--9.Identify customers with multiple subscriptions 
WITH CustomerSubscriptionCounts AS (
  SELECT customer_id, COUNT(DISTINCT created_date) AS SubscriptionCount
  FROM marvensubscription
  GROUP BY customer_id
)
SELECT customer_id, SubscriptionCount
FROM CustomerSubscriptionCounts
WHERE SubscriptionCount > 1
--instead of using CTEs you can use HAVING Clause
SELECT customer_id, COUNT(DISTINCT created_date) AS SubscriptionCount
FROM marvensubscription
GROUP BY customer_id
HAVING COUNT(DISTINCT created_date) > 1

--Find the Customers Lifetime Value (CLV)
WITH CustomerRevenue AS (
  SELECT customer_id, SUM(subscription_cost) AS TotalRevenue
  FROM marvensubscription
  GROUP BY customer_id
)
SELECT
  customer_id,
  TotalRevenue,
  (TotalRevenue / COUNT(customer_id)) AS CLV
FROM CustomerRevenue
GROUP BY customer_id,TotalRevenue

--Find Customers with Unpaid Subscriptions
SELECT customer_id, created_dateconv
FROM marvensubscription
WHERE was_subscription_paid = 'No'
GROUP BY customer_id,created_dateconv
--find the number of unpaid subscription 
SELECT COUNT(*) AS TotalUnpaidSubscriptions
FROM marvensubscription
WHERE was_subscription_paid = 'No'
--find the number of paid subscription 
SELECT COUNT(*) AS TotalpaidSubscriptions
FROM marvensubscription
WHERE was_subscription_paid = 'Yes'

---Calculate Churn Rate for Each Subscription Interval
WITH ChurnRate AS (
  SELECT
    subscription_interval,
    COUNT(CASE WHEN canceled_date IS NOT NULL THEN 1 END) AS Churned,
    COUNT(*) AS TotalSubscriptions
  FROM marvensubscription
  GROUP BY subscription_interval
)
SELECT
  subscription_interval,
  (Churned * 100.0) / TotalSubscriptions AS ChurnPercentage
FROM ChurnRate
--65.23%

---Identify Seasonal Subscription Patterns

  SELECT
    MONTH(created_dateconv)  AS Month,
    COUNT(DISTINCT customer_id) AS NewSubscriptions
  FROM marvensubscription
  GROUP BY MONTH(created_dateconv)


---Determine the Impact of Subscription Cost on Churn
  SELECT subscription_cost, COUNT(CASE WHEN canceled_date IS NOT NULL THEN 1 END) AS Churned, COUNT(*) AS TotalSubscriptions
  FROM marvensubscription
  GROUP BY subscription_cost


---Calculate Customer Retention Rate Over Time
WITH RetentionRate AS (
  SELECT
    MONTH(created_dateconv) AS Month,
    COUNT(DISTINCT customer_id) AS CurrentSubscribers
  FROM marvensubscription
  GROUP BY MONTH(created_dateconv)
)
SELECT
  Month,
  COALESCE(LAG(CurrentSubscribers, 1) OVER (ORDER BY Month), 0) AS PreviousSubscribers,
  CASE
    WHEN LAG(CurrentSubscribers, 1) OVER (ORDER BY Month) IS NOT NULL THEN
      (CurrentSubscribers * 100.0) / LAG(CurrentSubscribers, 1) OVER (ORDER BY Month)
    ELSE
      100.0  -- Set a default retention percentage for the first month
  END AS RetentionPercentage
FROM RetentionRate;
