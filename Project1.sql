/* Tworzymy tabele pod dane */


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
  
/* Tu miała miejsce poprawa struktur tabel

ALTER TABLE sales
DROP FOREIGN KEY SALES_IBFK_3;
  
  
ALTER TABLE sales
ADD constraint sales_ibfk_3 FOREIGN KEY (ProductID) references products(ProductID);
  
DROP TABLE products;

*/

/*Większe pliki ładujemy do tabel przy pomocy poniższyhc komend, mniejsze za pomocą Data Wizard */

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

/* Dodaję indeks dla większych tabel */

COMMIT;

CREATE INDEX i_sales ON sales(SalesID, ProductID, TotalPrice);
CREATE INDEX i_products ON products(ProductID);
CREATE INDEX i_customers ON customers(CustomerID);
CREATE INDEX i_sales2 ON sales(CustomerID, TotalPrice);
/* 
W związku z błędem w danych w pliku sales (kolumna TotalPrice mająca uwzględniać cenę sprzedaży dla transakcji z uwzględnieniem ceny produktu jego ilości oraz zniżki
jest pusta. Poniżej wykoanny zostaje update tabeli po zwiększeniu maksymalnego czasu wykoannia query w panelu MySQL */

UPDATE sales s
JOIN products p ON s.ProductID = p.ProductID
SET s.TotalPrice=p.price*s.Quantity*(1-s.Discount);

select * from sales;

/* Podstawowa EDA */

SELECT COUNT(*) from categories;

/* Mamy 11 kategorii produktów */

SELECT COUNT(*) from cities;

/*Mamy 96 miast z których pochodzą klienci i pracownicy */

SELECT COUNT(*) from customers;

/* W bazie danych odnotowaliśmy '98759' klientów */

SELECT COUNT(*) from employees;

/* Aktualnie zatrudnionych jest 23 pracowników */

SELECT COUNT(*) FROM sales;

/* Odnotowano 6.758.125 transakcji */

SELECT COUNT(*) from products;

/* W katalogu jest/ było dostępnych 452 produktów */

SELECT * from products
where Price=0;

/* 3 produkty w katalogu mają cenę 0. Są to ID 165, 278 oraz 405. Przyjmujemy, że są to darmowe próbki dostępne do zamówienia. */

SELECT DISTINCT VitalityDays from products;

/* Wartości 0 dla VitalityDays to produkty bez terminu ważności. */

SELECT * from products
where Price<0;

/* Nie ma wartości ujemnych w tabeli produkty */


/* W kolejnym kroku sprawdzamy wartości odstające dla 1 % najwyższych TotalPrice. Nie zauważamy odbiegających wartości */

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

/* sprawdzam jeszcze wartości odstające dla IQR */

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

/* Wartości odstające dla klasycznego IQR to wszystkie sprzedaże ponad '2280.000'

Dla analizy 1% były to wartości ponad '2134.000', także uznajemy, że wszystko jest w porządku.
Maks zamówienie to 2500.000 i wśród tych zamowień nie ma 'podejrzanych' transakcji */

/* oliczymy podstawowe KPI /*

/* SUMA SPRZEDAŻY Z TRANSAKCJI W TOTALU WYNOSI '4.333.740.027,60' */

SELECT SUM(TotalPrice) from sales;

/* SUMA SPRZEDAŻY WZGLĘDEM KAŻDEGO MIESIĄCA - miesiąc 0 to dane, gdzie SalesDate nie jest podane */

SELECT MONTH(SalesDate), SUM(TotalPrice) from sales
group by MONTH(SalesDate)
order by MONTH(SalesDate);

/* SUMA SPRZEDAŻY KAŻDEGO Z PRODUKTÓW */

SELECT p.ProductName, SUM(s.TotalPrice) as Suma_sprzedazy from sales s
join products p on p.productid=s.productid
group by p.productname
order by Suma_sprzedazy desc;

/* SUMA SPRZEDAZY NA KONKRETNEGO PRACOWNIKA */

SELECT e.FirstName, e.LastName, SUM(s.TotalPrice) as Suma_sprzedazy from sales s
join employees e on e.EmployeeID=s.SalesPersonID
group by e.EmployeeID
order by Suma_sprzedazy desc;

/* ŚREDNIA WARTOŚC SPRZEDAŻY NA TRANSAKCJĘ*/

select ROUND(avg(s.TOTALPRICE),2) as AVG_Transaction_VALUE FROM SALES s;

/*średnia ilość produktów na transakcję*/

SELECT ROUND(AVG(s.Quantity),2) as AVG_Quantity_trans FROM sales s;

/*Liczba produktów/ miasto z użyciem CTE dla optymalizacji query (7 mln rekordów sales, 100000 rekordów customers) */

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


/* Rankingi */

/*TOP 10 produktów z największą sprzedażą */

SELECT p.ProductName, SUM(s.Totalprice) as Sprzedaz, RANK() OVER(ORDER BY SUM(s.Totalprice) DESC) as ranking_sprzedaz, AVG(s.TotalPrice) as Srednia_sprzedaz,
RANK() OVER(ORDER BY AVG(s.TotalPrice) DESC) as ranking_avg_sprzedaz
from sales s
join products p
on s.ProductID=p.ProductID
group by p.ProductName
order by Sprzedaz DESC
limit 10;

/*TOP 10 PRODUKTÓW Z NAJMNIEJSZĄ SPRZEDAŻĄ ( Z WYRZUCENIEM PRÓBEK) */

SELECT p.ProductName, SUM(s.Totalprice) as Sprzedaz, RANK() OVER(ORDER BY SUM(s.Totalprice) ASC) as ranking_sprzedaz, AVG(s.TotalPrice) as Srednia_sprzedaz,
RANK() OVER(ORDER BY AVG(s.TotalPrice) ASC) as ranking_avg_sprzedaz
from sales s
join products p
on s.ProductID=p.ProductID
group by p.ProductName
having Sprzedaz>0
order by Sprzedaz
limit 10;

/* Najbrdziej zyskowne kategorie */


SELECT c.CategoryName, SUM(s.TotalPrice) as Sprzedaz from sales s
join products p on p.productid=s.productid
join categories c on c.categoryid=p.categoryid
group by c.CategoryName
order by Sprzedaz DESC;

/*Porównanie średniej wartości sprzedaży na miesiąc */

SELECT month(s.salesdate) as miesiac_nr,  monthname(s.SalesDate) as miesiac, AVG(s.Totalprice) as srednia  from sales s
group by miesiac, miesiac_nr
order by miesiac_nr;

/* Sprawdzenie transkacji */

select count( distinct transactionnumber), count(*) from sales;

/* liczba transakcji pokrywa się z liczba sprzedaży. Sprawdzmy ilu klientów możemy zaliczyć do klientów VIP. 
Klientów VIP uznajemy za tych, którzy łącznie zakupili ponad 100000 pln. */

SET SESSION tmp_table_size = 268435456;    -- 256 MB
SET SESSION max_heap_table_size = 268435456;
SHOW FULL PROCESSLIST;

WITH CTE AS (SELECT s.CustomerID, SUM(s.TotalPrice) as sum_per_customer from sales s GROUP BY S.CUSTOMERid having SUM_PER_CUSTOMER>100000 )
select c.FirstName, c.LastName, ct.sum_per_customer, 'VIP' FROM customers c join cte ct on ct.CustomerID=c.customerID
ORDER BY sum_per_customer DESC;

WITH CTE AS (SELECT row_number() over(order by SUM(s.TotalPrice) desc) AS ROW_NUM from sales s GROUP BY S.CUSTOMERid having SUM(s.TotalPrice)>100000)
SELECT MAX(ROW_NUM) AS LICZBA_VIP FROM CTE;

/* zweryfikujmy jaki procent klientów wrócił do sklepu w kolejnych miesiącach. */

WITH CTE AS (SELECT s.CustomerID, MONTH(s.SalesDate) as miesiac, count(s.Totalprice) as ilosc_trans_miesiac from sales s
			GROUP BY s.CustomerID, miesiac),
	 cte2 as (select count(distinct CustomerID) as liczba_klientow from sales),
     cte3 as (select c1.customerID, count(c1.miesiac) as w_ilu_miesiacach from CTE c1 where c1.ilosc_trans_miesiac>0 group by c1.customerID having w_ilu_miesiacach>1),
     cte4 as (select count(c3.customerID) as powracajacy from cte3 c3)
select round(c4.powracajacy/c2.liczba_klientow, 2) from cte4 c4 join cte2 c2;

/* Wynik query mówi że każdy z klientów  kupował coś w więcej niż 1 miesiącu, co może być zgodne, ponieważ na 7 milionów transakcji mamy tylko 100 tys klientów.
Sprawdzamy jeszcze kod */

WITH CTE AS (SELECT s.CustomerID, MONTH(s.SalesDate) as miesiac, count(s.Totalprice) as ilosc_trans_miesiac from sales s
			GROUP BY s.CustomerID, miesiac),
cte3 as (select c1.customerID, count(c1.miesiac) as w_ilu_miesiacach from CTE c1 where c1.ilosc_trans_miesiac>0 group by c1.customerID having w_ilu_miesiacach>1)
select count(c3.customerID) as powracajacy from cte3 c3;

/* Na koniec przygotujmy procedurę wyświetlającą wszystkie dotychczasowe zakupy danego klienta */

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

DROP PROCEDURE customer_sales_data;