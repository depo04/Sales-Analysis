--creo tabella dim_product finale
DROP TABLE IF EXISTS mart.dim_product;
CREATE TABLE mart.dim_product (
	product_id VARCHAR(20) PRIMARY KEY,
	name VARCHAR(100),
	category VARCHAR(50),
	subcategory VARCHAR(50)
);

--verifico quanti prodotti distinti esistono nel dataset
SELECT DISTINCT product_id
FROM staging.sales_transactions
ORDER BY product_id; 

--standardizzo i nomi delle categorie e sottocategorie per avere una tabella di prodotti unici
--inserisco il risultato nella tabella dim_product finale
INSERT INTO mart.dim_product (product_id, name, category, subcategory)
SELECT DISTINCT 
	product_id, 
	product_name, 
	INITCAP(product_category), 
	INITCAP(product_subcategory)
FROM staging.sales_transactions
ORDER BY product_id;