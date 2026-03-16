-- Classic MOdel Practice
-- Sales overview by products & country 
select t1.orderdate, t1.ordernumber, quantityOrdered, priceeach, productname, productline, buyprice, city,country
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join products t3
on t2.productCode = t3.productCode
inner join customers t4
on t1.customerNumber = t4.customerNumber
where year(orderDate) = 2004;

-- Product that purchased togehter
with prod_sales as
(
select distinct orderNumber, t1.productCode, productLine
from orderdetails t1
inner join products t2
on t1.productcode = t2.productCode
)
select t1.orderNumber, t1.productLine as product_1, t2.productLine as product_2
from prod_sales t1
left join prod_sales t2
on t1.ordernumber = t2.ordernumber and t1.productLine <> t2.productLine
group by orderNumber, product_1,product_2
order by orderNumber;

-- Customers' sales value by credit limit
with sales as
(
select t1.orderNumber, t1.customernumber, productcode, quantityOrdered, priceEach*quantityOrdered as sales_value,
creditLimit
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join customers t3
on t1.customerNumber = t3.customerNumber
)
select orderNumber, customerNumber,
case when creditLimit < 75000 then 'a:Less than $75k'
when creditLimit between 75000 and 100000 then 'a:$75k - $100k'
when creditLimit between 100000 and 150000 then 'a:$100k - $150k'
when creditLimit > 150000  then 'a:Over $150k'
else 'Other'
end as creditlimit_group,
sum(sales_value) as sales_value
from sales
group by ordernumber, customernumber, creditlimit_group ;

-- Sales Value change from Previous Order 
with main_cte as
(
select orderNumber, orderdate,customerNumber, sum(sales_value) as sales_value
from
(select t1.orderNumber, orderdate, customerNumber, productcode, quantityOrdered * priceEach as sales_value
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber) main
group by orderNumber, orderdate, customerNumber
),

sales_query as 
( 
select t1.*, customerName, row_number() over(partition by customerName order by orderdate) as purchase_number, 
lag(sales_value) over(partition by  customerName order by orderdate) as prev_sales_value
from main_cte t1
inner join customers t2
on t1.customerNumber = t2.customerNumber)

select *, sales_value - prev_sales_value as purchase_value_change
from sales_query
where prev_sales_value is not null;

-- office sales by customer country

WITH main_cte AS (

    SELECT 
        t1.orderNumber,
        t2.productCode,
        t2.quantityOrdered,
        t2.priceEach,
        quantityOrdered * priceEach AS sales_value,

        t3.city AS customer_city,
        t3.country AS customer_country,

        t4.productLine,

        t6.city AS office_city,
        t6.country AS office_country

    FROM orders t1

    INNER JOIN orderdetails t2
        ON t1.orderNumber = t2.orderNumber

    INNER JOIN customers t3
        ON t1.customerNumber = t3.customerNumber   -- fixed spelling

    INNER JOIN products t4
        ON t2.productCode = t4.productCode

    INNER JOIN employees t5
        ON t3.salesRepEmployeeNumber = t5.employeeNumber

    INNER JOIN offices t6
        ON t5.officeCode = t6.officeCode   -- missing join before
)

SELECT 
    orderNumber,
    customer_city,
    customer_country,
    productLine,
    office_city,
    office_country,
    SUM(sales_value) AS sales_value

FROM main_cte

GROUP BY 
    orderNumber,
    customer_city,
    customer_country,
    productLine,
    office_city,
    office_country;


-- Total sales on each customers
with cte_sales as
(
select 
t1.orderDate, 
    t1.customerNumber, 
    t1.orderNumber,
    t3.customerName, 
    t2.productCode, 
    t3.creditLimit, 
    t2.quantityOrdered * t2.priceEach as sales_value
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join customers t3
on t1.customerNumber = t3.customerNumber
),

running_total_sales_cate as
(
select *, lead(orderdate) over(partition by customerNumber order by orderdate) as next_order_date
from
	(
	select 
	orderDate,     
	customerNumber,     
	orderNumber,     
	customerName,     
	creditLimit,  
	sum(sales_value) as sales_value
	from cte_sales
	group by 
	orderdate,
	orderNumber,
	customernumber,
	customername,
	creditlimit
	) subquery
),

/* payments_cte as 
(select *, sum(amount) over (partition by customerNumber order by paymentdate) as running_total_payment
from payments)*/
payments_cte as 
(select *
from payments),

main_cte as 
(
	select  
	t1.orderDate,
	t1.customerNumber,
	t1.orderNumber,
	t1.customerName,
	t1.creditLimit,
	t1.sales_value,
	t2.paymentDate,
	t2.amount,
	sum(sales_value)over (partition by t1.customerNumber order by orderdate) as running_total_sales,
	sum(amount) over (partition by t1.customerNumber order by paymentdate) as running_total_payment
	from running_total_sales_cate t1
	left join payments_cte t2
	on t1.customerNumber = t2.customerNumber and t2.paymentdate between t1.orderdate and case when t1.next_order_date is null then current_date else next_order_date end
	order by t1.customerNumber, orderdate
)

select *, running_total_sales - running_total_payment as money_owed,
creditLimit - (running_total_sales - running_total_payment) as difference
from main_cte;

