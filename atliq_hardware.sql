/* 1. Provide the list of markets in which customer "Atliq Exclusive" 
operates its business in the APAC region. */

SELECT customer,Market,region FROM dim_customer where customer = "Atliq Exclusive" and region = "APAC" ORDER BY market DESC;

/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg */

WITH unique_product_2020 AS
  (SELECT COUNT(DISTINCT product_code) AS unique_products_2020
   FROM fact_sales_monthly
   WHERE fiscal_year = 2020),
     unique_product_2021 AS
  (SELECT COUNT(DISTINCT product_code) AS unique_products_2021
   FROM fact_sales_monthly
   WHERE fiscal_year = 2021)
SELECT unique_products_2020,
       unique_products_2021,
       concat(ROUND((unique_products_2021 - unique_products_2020) / unique_products_2020 * 100, 2), '%') AS percentage_chg
FROM unique_product_2020
INNER JOIN unique_product_2021;



/* 3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
segment
product_count */

SELECT 
	segment, count(DISTINCT (product_code)) as product_count 
FROM dim_product 
GROUP BY segment 
ORDER BY product_count DESC;

 

/* 4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference */

WITH cte_table_20 AS
  (SELECT p.segment,
          count(DISTINCT (p.product_code)) AS product_count_2020
   FROM dim_product p
   INNER JOIN fact_sales_monthly s ON p.product_code = s.product_code
   WHERE s.fiscal_year = 2020
   GROUP BY p.segment
   ORDER BY product_count_2020 DESC),
     cte_table_21 AS
  (SELECT p.segment,
          count(DISTINCT (p.product_code)) AS product_count_2021
   FROM dim_product p
   INNER JOIN fact_sales_monthly s ON p.product_code = s.product_code
   WHERE s.fiscal_year = 2021
   GROUP BY p.segment
   ORDER BY product_count_2021 DESC)
SELECT cte_table_20.segment,
       product_count_2020,
       product_count_2021,
       product_count_2021-product_count_2020 AS difference
FROM cte_table_20
INNER JOIN cte_table_21 ON cte_table_20.segment = cte_table_21.segment
ORDER BY difference DESC;


/* 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost */

SELECT a.product_code,a.product,b.manufacturing_cost
FROM dim_product a JOIN fact_manufacturing_cost b
on a.product_code = b.product_code
WHERE manufacturing_cost = (SELECT min(manufacturing_cost) FROM fact_manufacturing_cost)
OR 
manufacturing_cost = (SELECT max(manufacturing_cost) FROM fact_manufacturing_cost)


/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */

WITH top_5_customers AS
(
    SELECT 
        c.customer_code,
        c.customer,
        round(avg(d.pre_invoice_discount_pct), 2) AS average_discount_percentage,
        rank() OVER (
            ORDER BY avg(d.pre_invoice_discount_pct) DESC
        ) AS ranks
    FROM dim_customer c
    INNER JOIN fact_pre_invoice_deductions d 
        ON c.customer_code = d.customer_code
    WHERE d.fiscal_year = 2021
        AND c.market = 'India'
        AND d.pre_invoice_discount_pct > 
            (
                SELECT avg(pre_invoice_discount_pct)
                FROM fact_pre_invoice_deductions
                WHERE fiscal_year = 2021
            )
    GROUP BY c.customer_code, c.customer
)
SELECT 
    customer_code,
    customer,
    concat(average_discount_percentage, '%') AS average_discount_percentage
FROM top_5_customers
WHERE ranks <= 5;






/* 7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount */

SELECT month(s.date) Month,
                     year(s.date) AS Year,
                     round(sum(s.sold_quantity * g.gross_price), 2) AS Gross_sales_Amount
FROM fact_gross_price g
INNER JOIN fact_sales_monthly s ON g.product_code = s.product_code
INNER JOIN dim_customer c ON c.customer_code = s.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY month(s.date),
         year(s.date)
ORDER BY month(s.date),
         year(s.date);


         
/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity
hint : derive the Month from the date and assign a Quarter. Note that fiscal_year
for Atliq Hardware starts from September(09)
 */

SELECT CASE
           WHEN monthname(date) in ('September','October','November') THEN 1
           WHEN monthname(date) in ('December','January','February') THEN 2
           WHEN monthname(date) in ('March','April','May') THEN 3
           WHEN monthname(date) in ('June','July','August') THEN 4
       END AS Quarter,
       sum(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020 
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;


/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage */

with req9 as
(select channel,
round(sum(gross_price*b.sold_quantity)/1000000,2)
as Gross_Sales_min
from dim_customer a join fact_sales_monthly b
on a.customer_code = b.customer_code
join fact_gross_price c
on c.product_code = b.product_code
where b.fiscal_year = 2021
group by channel order by Gross_Sales_min)
select *,(Gross_sales_min*100)/sum(Gross_sales_min)
over() as Percentage
from req9;

/* 10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
division
product_code
product
total_sold_quantity
rank_order
*/

WITH top_3_products AS
  (SELECT p.division,
          p.product_code,
          p.product,
          sum(s.sold_quantity) AS total_sold_quantity,
          DENSE_RANK() OVER(PARTITION BY p.division
                            ORDER BY sum(s.sold_quantity) DESC) AS rank_order
   FROM dim_product p
   INNER JOIN fact_sales_monthly s ON p.product_code = s.product_code
   WHERE s.fiscal_year = 2021
   GROUP BY p.division,
            p.product_code,
            p.product)
SELECT *
FROM top_3_products
WHERE rank_order <= 3;