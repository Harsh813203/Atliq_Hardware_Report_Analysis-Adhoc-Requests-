-- 1. Provide the list of markets in which customer  "Atliq  Exclusive"  operates its  business in the  APAC  region.

select market
from dim_customer
where customer='Atliq Exclusive' and region = 'APAC';

/*
 2.  What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, 
unique_products_2020 
unique_products_2021 
percentage_chg'''
*/
WITH product_count_2020 AS (
    SELECT COUNT(DISTINCT product_code) AS unique_products_2020
    FROM fact_sales_monthly 
    WHERE fiscal_year = 2020
),
product_count_2021 AS (
    SELECT COUNT(DISTINCT product_code) AS unique_products_2021
    FROM fact_sales_monthly
    WHERE fiscal_year = 2021
)
SELECT
    pc_2020.unique_products_2020,
    pc_2021.unique_products_2021,
    ROUND((pc_2021.unique_products_2021 - pc_2020.unique_products_2020) * 100.0 / pc_2020.unique_products_2020, 2) AS percentage_chg
FROM
    product_count_2020 pc_2020,
    product_count_2021 pc_2021;

/*
3.Provide a report with all the unique product counts for each  segment  and 
sort them in descending order of product counts. The final output contains 
2 fields, 
segment 
product_count */

SELECT segment,
count(distinct product_code) AS product_count
FROM
dim_product
GROUP BY segment
ORDER BY product_count DESC;

/*
Which segment had the most increase in unique products in 
2021 vs 2020? The final output contains these fields, 
segment 
product_count_2020 
product_count_2021 
difference
*/

WITH unique_product_2020 AS (
    SELECT
        dim_product.segment,
        COUNT(DISTINCT fact_sales_monthly.product_code) AS product_count_2020 
    FROM
        fact_sales_monthly,
        dim_product
    WHERE
        fact_sales_monthly.product_code = dim_product.product_code
        AND fiscal_year = 2020
    GROUP BY
        dim_product.segment
),
unique_product_2021 AS (
    SELECT
        dim_product.segment,
        COUNT(DISTINCT fact_sales_monthly.product_code) AS product_count_2021 
    FROM
        fact_sales_monthly,
        dim_product
    WHERE
        fact_sales_monthly.product_code = dim_product.product_code
        AND fiscal_year = 2021
    GROUP BY
        dim_product.segment
)

SELECT
    uc_2020.segment,
    uc_2020.product_count_2020,
    uc_2021.product_count_2021,
    (uc_2021.product_count_2021 - uc_2020.product_count_2020) AS difference 
FROM
    unique_product_2020 uc_2020,
	unique_product_2021 uc_2021
WHERE uc_2020.segment = uc_2021.segment
ORDER BY difference DESC;


/* 
5.Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, 
product_code 
product 
manufacturing_cost 
*/
select pr.product_code,pr.product,ma.manufacturing_cost
from dim_product pr,fact_manufacturing_cost ma
where pr.product_code = ma.product_code
and ma.manufacturing_cost In (
select max(manufacturing_cost) from fact_manufacturing_cost
Union 
Select min(manufacturing_cost) from fact_manufacturing_cost
)
order by ma.manufacturing_cost desc ;

/*
Generate a report which contains the top 5 customers who received an 
average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
Indian  market. The final output contains these fields, 
customer_code 
customer 
average_discount_percentage 
*/

SELECT c.customer_code,
c.customer,
pid.pre_invoice_discount_pct AS average_discount_pct
FROM dim_customer c, fact_pre_invoice_deductions pid
WHERE 
c.customer_code = pid.customer_code
AND pid.fiscal_year = 2021 AND c.market= 'India'
AND pid.pre_invoice_discount_pct > (SELECT AVG(pre_invoice_discount_pct) FROM fact_pre_invoice_deductions)
ORDER BY average_discount_pct DESC
LIMIT 5;


/*
7.  Get the complete report of the Gross sales amount for the customer  “Atliq 
Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
high-performing months and take strategic decisions. 
The final report contains these columns: 
Month 
Year 
Gross sales Amount */


with report as
(
select monthname(sm.date) as 'Month',year(sm.date) as 'year', 
round(sum(gp.gross_price*sm.sold_quantity),2) as gross_sales
from fact_sales_monthly sm
Join dim_customer c
ON sm.customer_code = c.customer_code
JOIN fact_gross_price gp
ON sm.product_code = gp.product_code
where c.customer = 'Atliq Exclusive'
group by Month,year
order by Month,year
)

select Month,year,gross_sales from report
where gross_sales In 
(Select max(gross_sales) from report
Union
Select min(gross_sales) from report
)


/*
8.In which quarter of 2020, got the maximum total_sold_quantity? The final 
output contains these fields sorted by the total_sold_quantity, 
Quarter 
total_sold_quantity. 
Note that fiscal_year for Atliq Hardware starts from September(09) 
if the fiscal year (FY) starts on September 1, 2019, the end date for the first quarter would typically be November 30, 2019.
This is because a fiscal quarter is usually three months long, 
and the first quarter would cover September, October, and November.
*/


SELECT 
CASE 
WHEN date BETWEEN '2019-09-01' and '2019-11-01' THEN 1
WHEN date BETWEEN '2019-12-01' and '2020-02-01' THEN 2
WHEN date BETWEEN '2020-03-01' and '2020-05-01' THEN 3
WHEN date BETWEEN '2020-06-01' and '2020-08-01' THEN 4
END AS Quarters,
	sum(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters
ORDER BY total_sold_quantity desc;


/*
9.  Which channel helped to bring more gross sales in the fiscal year 2021 
and the percentage of contribution?  The final output  contains these fields, 
channel 
gross_sales_mln 
percentage 
*/
with Output as
(
SELECT c.channel as 'Channel',
ROUND(SUM(gp.gross_price*sm.sold_quantity/1000000),2) as gross_sales_mln
FROM fact_sales_monthly sm
JOIN fact_gross_price gp
ON	sm.product_code = gp.product_code
Join dim_customer c
ON sm.customer_code = c.customer_code
where sm.fiscal_year = 2021
Group by c.channel
)

select Channel, gross_sales_mln,
Concat(round(gross_sales_mln*100/total,2),'%')as percentage
from 
(
(select sum(gross_sales_mln) as total from Output) A,
(select * from Output ) B
)
order by percentage desc;


/* 10.  Get the Top 3 products in each division that have a high 
total_sold_quantity in the fiscal_year 2021? The final output contains these 
fields:- 
division 
product_code 
product 
total_sold_quantity 
rank_order 
*/

SELECT division, product_code, product, total_sold_quantity, rank_order
FROM (
    SELECT 
        p.division,
        p.product_code,
        product,
        SUM(sm.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY p.division ORDER BY SUM(sm.sold_quantity) DESC) AS rank_order
    FROM 
        dim_product p 
    JOIN 
        fact_sales_monthly sm ON p.product_code = sm.product_code
    WHERE 
        sm.fiscal_year = 2021
    GROUP BY 
        p.division, p.product_code, product
) ranked_products
WHERE rank_order <= 3;
