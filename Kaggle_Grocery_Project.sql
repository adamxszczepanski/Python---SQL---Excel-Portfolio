/* I create tables which will be filled with data */

CREATE TABLE categories(
   CategoryID INT auto_increment PRIMARY KEY,
   CategoryName VARCHAR(45) );
   
   
create table cities(
   CityID INT auto_increment PRIMARY KEY,
   CityName VARCHAR(45),
   Zipcode DECIMAL(5,0),
   CountryID INT,
   foreign key (CountryID) references countries(CountryID) );
   
CREATE TABLE countries(
  CountryID INT auto_increment PRIMARY KEY,
  CountryName VARCHAR(45),
  CountryCode VARCHAR(2) );
  
CREATE TABLE customers(
  CustomerID INT auto_increment PRIMARY KEY,
  FirstName VARCHAR(45),
  MiddleInitial VARCHAR(1),
  LastName VARCHAR(45),
  CityID INT,
  Address VARCHAR(90),
  FOREIGN KEY (cityID) REFERENCES cities(CityID) );
  
create table employees(
  EmployeeID INT auto_increment PRIMARY KEY,
  FirstName VARCHAR(45),
  MiddleInitial VARCHAR(1),
  LastName VARCHAR(45),
  BirthDate DATE,
  Gender VARCHAR(10),
  CityID INT,
  HireDate DATE,
  foreign key (CityID) references cities(CityID) );
  
CREATE TABLE sales(
  SalesID INT auto_increment PRIMARY KEY,
  SalesPersonID INT,
  CustomerID INT,
  ProductID INT,
  Quantity INT,
  Discount DECIMAL(10,2),
  TotalPrice DECIMAL(10,2),
  SalesDate DATETIME,
  TransactionNumber VARCHAR(25),
  foreign key (SalesPersonID) references employees(EmployeeID),
  foreign key (CustomerID) references customers(CustomerID),
  foreign key (ProductID) references products(ProductID) );
  
create table products(
  ProductID INT auto_increment PRIMARY KEY,
  ProductName VARCHAR(45),
  Price DECIMAL(4,0),
  CategoryID INT,
  Class VARCHAR(15),
  ModifyDate DATE,
  Resistant VARCHAR(45),
  ISAllergic VARCHAR(7),
  VitalityDays DECIMAL(3,0),
  FOREIGN KEY (CategoryID) REFERENCES categories(CategoryID) );
  

/*Bigger size files are loaded by commands below. Smaller ones are loaded by Data Wizard */

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:\\Program Files\\MySQL\\MySQL Workbench 8.0\\sys\\customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(CustomerID, FirstName, MiddleInitial, LastName, CityID, Address);

LOAD DATA LOCAL INFILE 'C:\\Program Files\\MySQL\\MySQL Workbench 8.0\\sys\\products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ProductID, ProductName, Price, CategoryID, Class, ModifyDate, Resistant , ISAllergic, VitalityDays);

select * from products;

LOAD DATA LOCAL INFILE 'C:\\Program Files\\MySQL\\MySQL Workbench 8.0\\sys\\sales.csv'
INTO TABLE sales
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(SalesID, SalesPersonID, CustomerID ,ProductID, Quantity, Discount, TotalPrice, SalesDate, TransactionNumber);

/* I add indexes on tables */

COMMIT;

CREATE INDEX i_sales ON sales(SalesID, ProductID, TotalPrice);
CREATE INDEX i_products ON products(ProductID);
CREATE INDEX i_customers ON customers(CustomerID);
CREATE INDEX i_sales2 ON sales(CustomerID, TotalPrice);

/* 

Due to error in 'sales' file, where TotalPrice column has only zero values, 'sales' table is updated by command below. 

TotalPrice = Price of product * quantity * (1- Discount)  -- Using this formula 'sales' table is updated

*/

UPDATE sales s
JOIN products p ON s.ProductID = p.ProductID
SET s.TotalPrice=p.price*s.Quantity*(1-s.Discount);

select * from sales;

/* BASIC EXPLORATORY DATA ANALYSIS */

SELECT COUNT(*) from categories;

/* We have 11 categories of products */

SELECT COUNT(*) from cities;

/* We have 96 cities where our customers live and our employees work */

SELECT COUNT(*) from customers;

/* We have '98759' customers recorded in the database */

SELECT COUNT(*) from employees;

/* Currently, there are 23 employees */

SELECT COUNT(*) FROM sales;

/* 6,758,125 transactions were recorded */

SELECT COUNT(*) from products;

/* There are/were 452 products available in the catalog */

SELECT * from products
where Price=0;

/* 
Three products in the catalog have a price equal 0. Their ID are: 165, 278 and 405. 

We assume that these are free samples available for ordering. 
*/


SELECT * from products
where Price<0;

/* There are no negative values ​​in the Price column */


/* 
In the next step, we check outliers in the top 1% of total prices. We do not observe any 'suspicious values'. */

WITH cte_sales_number AS (
  SELECT ROUND(COUNT(*)*0.01,0) AS sales_number FROM sales
),
cte_ranked AS (
  SELECT s.*, 
         ROW_NUMBER() OVER (ORDER BY Totalprice DESC) AS ranking
  FROM sales s
)
SELECT r.*
FROM cte_ranked r
CROSS JOIN cte_sales_number c
WHERE r.ranking < c.sales_number;

/* I also check outliers in IQR method */

WITH cte_75perc AS (
  SELECT ROUND(COUNT(*)*0.25,0) AS perc_75 FROM sales
),
cte_25perc AS (
  SELECT ROUND(COUNT(*)*0.75,0) AS perc_25 FROM sales),
cte_ranked AS (
  SELECT s.*, 
         ROW_NUMBER() OVER (ORDER BY Totalprice DESC) AS ranking
  FROM sales s
)
SELECT  r.totalprice, r.totalprice-LAG(r.totalprice) OVER (order by r.totalprice) AS iqr, r.totalprice+1.5*r.totalprice-LAG(r.totalprice) OVER (order by r.totalprice) as q3_iqr
FROM cte_ranked r
CROSS JOIN cte_25perc c
CROSS JOIN cte_75perc c1
WHERE r.ranking = c.perc_25 or r.ranking=c1.perc_75;

/* 
Outliers for IQR method are Total Price values above '2280.000'

Fo 1% analysis outliers were values above '2134.000', so still don't we have any suspicious value
*/

/* 
Let calculate some basic KPIs

Total sale value from all transactions is equal '4.333.740.027,60' */

SELECT SUM(TotalPrice) from sales;

/* 
TOTAL SALE PER MONTH

Month 0 means data, where SalesDate is not given
*/

SELECT MONTH(SalesDate), SUM(TotalPrice) from sales
group by MONTH(SalesDate)
order by MONTH(SalesDate);

/* TOTAL SALE OF EVERY PRODUCT */

SELECT p.ProductName, SUM(s.TotalPrice) as Suma_sprzedazy from sales s
join products p on p.productid=s.productid
group by p.productname
order by Suma_sprzedazy desc;

/* TOTAL SALE PER SALESPERSON */

SELECT e.FirstName, e.LastName, SUM(s.TotalPrice) as Suma_sprzedazy from sales s
join employees e on e.EmployeeID=s.SalesPersonID
group by e.EmployeeID
order by Suma_sprzedazy desc;

/* AVERAGE ORDER VALUE */

select ROUND(avg(s.TOTALPRICE),2) as AVG_Transaction_VALUE FROM SALES s;

/*AVERAGE PRODUCTS QUANTITY PER TRANSACTION*/

SELECT ROUND(AVG(s.Quantity),2) as AVG_Quantity_trans FROM sales s;

/*Number of products per city + new index due to large table connections ( 7 mln of rows in sales and 100000 of rows in customers) */

CREATE INDEX i_sales3 ON sales(CustomerID, quantity);

WITH sales_per_customer AS (
  SELECT s.CustomerID, SUM(s.quantity) AS qty_sum
  FROM sales s
  GROUP BY s.CustomerID
)
SELECT c.CityName, SUM(spc.qty_sum) AS Quantity_sum
FROM sales_per_customer spc
JOIN customers cs ON cs.CustomerID = spc.CustomerID
JOIN cities c ON c.CityID = cs.CityID
GROUP BY c.CityName;


/* RANKINGS */

/*TOP 10 PRODUCTS WITH THE BIGGEST SALE */

SELECT p.ProductName, SUM(s.Totalprice) as Sale, RANK() OVER(ORDER BY SUM(s.Totalprice) DESC) as sale_ranking, AVG(s.TotalPrice) as AVG_sale,
RANK() OVER(ORDER BY AVG(s.TotalPrice) DESC) as AVG_sale_ranking
from sales s
join products p
on s.ProductID=p.ProductID
group by p.ProductName
order by Sale DESC
limit 10;

/*
TOP 10 PRODUCTS WITH THE LOWEST SALE (WITHOUT FREE SAMPLES FOR CLIENTS)
*/

SELECT p.ProductName, SUM(s.Totalprice) as Sale, RANK() OVER(ORDER BY SUM(s.Totalprice) ASC) as sale_ranking, AVG(s.TotalPrice) as AVG_sale,
RANK() OVER(ORDER BY AVG(s.TotalPrice) ASC) as AVG_sales_ranking
from sales s
join products p
on s.ProductID=p.ProductID
group by p.ProductName
having Sale>0
order by Sale
limit 10;

/* The most profitable categories */

SELECT c.CategoryName, SUM(s.TotalPrice) as Sale from sales s
join products p on p.productid=s.productid
join categories c on c.categoryid=p.categoryid
group by c.CategoryName
order by Sale DESC;

/*Comparison of average sales value per month */

SELECT month(s.salesdate) as month_number,  monthname(s.SalesDate) as month_name, AVG(s.Totalprice) as AVG_sale  from sales s
group by month_name, month_number
order by month_number;

/* Transaction check */

select count( distinct transactionnumber), count(*) from sales;

/* Transaction number is eqaul to Sales number. Let's check how many customers we can consider VIP customers. 
We consider a VIP customer to be a customer who has spent over 100,000 in our store. */

SET SESSION tmp_table_size = 268435456;    -- 256 MB
SET SESSION max_heap_table_size = 268435456;
SHOW FULL PROCESSLIST;

WITH CTE AS (SELECT s.CustomerID, SUM(s.TotalPrice) as sum_per_customer 
             from sales s 
             GROUP BY S.CUSTOMERid 
             having SUM_PER_CUSTOMER>100000 )
select c.FirstName, c.LastName, ct.sum_per_customer, 'VIP' 
FROM customers c 
join cte ct on ct.CustomerID=c.customerID
ORDER BY sum_per_customer DESC;

WITH CTE AS (SELECT row_number() over(order by SUM(s.TotalPrice) desc) AS ROW_NUM 
             from sales s 
             GROUP BY S.CUSTOMERid 
             having SUM(s.TotalPrice)>100000)
SELECT MAX(ROW_NUM) AS VIP_clients_number FROM CTE;

/* Let's check what percentage of customers returned in the following months */

WITH CTE AS (SELECT s.CustomerID, MONTH(s.SalesDate) as month_number, count(s.Totalprice) as month_trans_number from sales s
			GROUP BY s.CustomerID, month_number),
	 cte2 as (select count(distinct CustomerID) as number_of_clients from sales),
     cte3 as (select c1.customerID, count(c1.month_number) as in_how_many_months from CTE c1 where c1.month_trans_number>0 group by c1.customerID having in_how_many_months>1),
     cte4 as (select count(c3.customerID) as returned from cte3 c3)
select round(c4.returned/c2.number_of_clients, 2) as Percentage_of_returned from cte4 c4 join cte2 c2;

/* The query result indicates that each customer is a customer who bought something in more than 1 month

It shouldn't be surprising, because proportion of transaction to customers is around 70:1*/

/*The CTEs check */

WITH CTE AS (SELECT s.CustomerID, MONTH(s.SalesDate) as month_number, count(s.Totalprice) as trans_num_per_month from sales s
			GROUP BY s.CustomerID, month_number),
cte3 as (select c1.customerID, count(c1.month_number) as in_how_many_months from CTE c1 where c1.trans_num_per_month>0 group by c1.customerID having in_how_many_months>1)
select count(c3.customerID) as returned from cte3 c3;

/* At the end, lets prepare a procedure which return basic data about given customer_ID. */

DELIMITER $$

CREATE PROCEDURE customer_sales_data (IN p_ID INT)
BEGIN
SELECT c.firstName, c.lastname, s.salesdate, s.transactionnumber,  P.ProductName, s.totalprice, c.address
from sales s
join customers c on c.customerid=s.customerId
join products p on s.productid=p.productid
where s.customerID=p_ID
ORDER BY SALESDATE;
end $$

DELIMITER ;

CALL CUSTOMER_SALES_DATA(15678);

