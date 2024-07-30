--Case 1
--Sipariş Analizi
--Question 1 : Aylık olarak order dağılımını inceleyiniz. 
--( Tarih verisi için order_approved_at kullanılmalıdır.)

SELECT DISTINCT 
    EXTRACT(year from order_approved_at) as order_year,
    EXTRACT(month from order_approved_at) as  order_month,
    COUNT(*) as total_orders
FROM orders
WHERE order_approved_at IS NOT NULL
GROUP BY 1,2
ORDER BY 1 asc, 2 asc;

--CONTROL QUERY;

SELECT *
FROM Orders
WHERE  EXTRACT(YEAR FROM order_approved_at) = 2018 AND
               EXTRACT(MONTH FROM order_approved_at) = 9;


--Question 2 : 
--Aylık olarak order status kırılımında order sayılarını inceleyiniz. Sorgu sonucunda çıkan             
--outputu excel ile görselleştiriniz. Dramatik bir düşüşün ya da yükselişin olduğu aylar var mı? 
--Veriyi inceleyerek yorumlayınız.

SELECT
    TO_CHAR(order_approved_at, 'YYYY-MM') as order_year_month,
    order_status,
    COUNT(*) as total_orders
FROM orders
WHERE order_approved_at IS NOT NULL
GROUP BY order_year_month, order_status
ORDER BY order_year_month ASC, order_status;

--Question 3 : 
--Ürün kategorisi kırılımında sipariş sayılarını inceleyiniz. Özel günlerde öne çıkan
--kategoriler nelerdir? Örneğin yılbaşı, sevgililer günü…
--(Seçtiğim tarihler 12 Ekim Çocuk Bayramı ve 8 Mart Dünya Kadınlar Günü)

WITH order_count AS (
    SELECT
        to_char(o.order_purchase_timestamp, 'YYYY-MM') AS order_date,
        p.product_category_name,
        COUNT(DISTINCT oi.order_id) AS orderCount
    FROM
        order_items AS oi
        JOIN products AS p ON p.product_id = oi.product_id
        JOIN orders AS o ON o.order_id = oi.order_id
    WHERE
        o.order_purchase_timestamp IS NOT NULL
        AND (
            (EXTRACT(MONTH FROM o.order_purchase_timestamp) = 10 AND EXTRACT(YEAR FROM o.order_purchase_timestamp) IN ('2016', '2017', '2018'))
            OR 
            (EXTRACT(MONTH FROM o.order_purchase_timestamp) = 3 AND EXTRACT(YEAR FROM o.order_purchase_timestamp) IN ('2016', '2017', '2018'))
        )
    GROUP BY 1, 2
)

SELECT
    oc.order_date,
    oc.orderCount,
    t.category_name_english
FROM
    order_count AS oc
    INNER JOIN translation AS t ON t.category_name = oc.product_category_name
ORDER BY
    oc.orderCount DESC;

--Question 4 : 
--Haftanın günleri(pazartesi, perşembe, ….) ve ay günleri (ayın 1’i,2’si gibi) bazında order sayılarını      --inceleyiniz. Yazdığınız sorgunun outputu ile excel’de bir görsel oluşturup yorumlayınız.
--QUERY 1

WITH day_based AS (
  SELECT
          to_char(order_purchase_timestamp, 'Day') AS days,
         COUNT(DISTINCT order_id) AS ordercount
  FROM orders
  WHERE order_status <> 'canceled' AND order_status <> 'unavailable'
  GROUP BY 1
)
SELECT days, ordercount FROM day_based;

--QUERY 2

WITH monthday_based AS (
  SELECT
         EXTRACT(DAY FROM order_purchase_timestamp) AS monthday,
         COUNT(DISTINCT order_id) AS ordercount
  FROM orders
  WHERE order_status <> 'canceled' AND order_status <> 'unavailable'
  GROUP BY monthday
)
SELECT monthday, ordercount FROM monthday_based;

--Case 2 
--Müşteri Analizi 
--Question 1 :                                                                                                                                                   --Hangi şehirlerdeki müşteriler daha çok alışveriş yapıyor? Müşterinin şehrini en çok sipariş        --verdiği şehir olarak belirleyip analizi ona göre yapınız. 
WITH tablo1 AS(
SELECT 
		c.customer_unique_id,
		customer_city,
		COUNT(DISTINCT order_id) as order_count
		FROM orders AS o
		LEFT JOIN customers AS c ON c.customer_id=o.customer_id
	--where c.customer_unique_id= 'f34cd7fd85a1f8baff886edf09567be3'
	GROUP BY 1,2
),
tablo2 as(
SELECT
	 customer_unique_id,
	 customer_city,
	 order_count,
	 ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_count DESC) AS rn
	 FROM tablo1
	 ORDER BY 1
),
tablo3 as(
SELECT 
	customer_unique_id,
	customer_city
FROM tablo2
WHERE rn =1
),
tablo4 as(
SELECT 
	customer_unique_id,
	sum(order_count) total
FROM tablo2
GROUP BY 1
),
son_tablo as(
SELECT
	t3.customer_unique_id,
	customer_city,
	total
FROM tablo4 AS t4
JOIN tablo3 AS t3 ON t4.customer_unique_id=t3.customer_unique_id
)
SELECT
	customer_city,
	sum(total)
FROM son_tablo
GROUP BY 1
ORDER BY 2 DESC;

--Case 3
--Satıcı Analizi
--Question 1 : 
--Siparişleri en hızlı şekilde müşterilere ulaştıran satıcılar kimlerdir? Top 5 getiriniz. Bu satıcıların 
--order sayıları ile ürünlerindeki yorumlar ve puanlamaları inceleyiniz ve yorumlayınız.
WITH SellerInfo AS (
    SELECT 
        oi.seller_id,
        (o.order_delivered_customer_date - o.order_approved_at) AS deliveredday,
        r.review_score
    FROM orders as o
    JOIN  order_items as oi ON o.order_id = oi.order_id
    JOIN reviews as r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
)
SELECT 
    seller_id,
    LEFT(seller_id, 3) AS seller_name,
    AVG(deliveredday) AS avg_day,
    ROUND(AVG(review_score), 2) AS avg_score,
    COUNT(*) AS total_order
FROM SellerInfo
GROUP BY 1
HAVING COUNT(*) > 20
ORDER BY 3
LIMIT 5;

--Question 2 : 
--Hangi satıcılar daha fazla kategoriye ait ürün satışı yapmaktadır? 
--Fazla kategoriye sahip satıcıların order sayıları da fazla mı? 

SELECT 
    s.seller_id,
    COUNT(DISTINCT p.product_category_name) AS category_count,
    COUNT(DISTINCT oi.order_id) AS order_count
FROM Sellers AS s
JOIN Order_items AS oi ON s.seller_id = oi.seller_id
JOIN Products AS p ON oi.product_id = p.product_id
WHERE p.product_category_name IS NOT NULL
GROUP BY s.seller_id
ORDER BY category_count DESC, order_count DESC
LIMIT 5;

--Case 4 
--Payment Analizi
--Question 1 : 
--Ödeme yaparken taksit sayısı fazla olan kullanıcılar en çok hangi bölgede yaşamaktadır? Bu çıktıyı
 --yorumlayınız.

 WITH QualifiedPayments AS (
  SELECT
         c.customer_city,
	     c.customer_state,
	     COUNT(DISTINCT customer_unique_id) AS customer_count
  FROM payments p
	INNER JOIN orders o on o.order_id=p.order_id
	INNER JOIN customers c on c.customer_id = o.customer_id
  WHERE payment_installments >4
  GROUP BY 1,2
)
SELECT qp.customer_state,
              qp.customer_city,
	 qp.customer_count
FROM QualifiedPayments qp
WHERE customer_count>1
ORDER BY 3 DESC

--Question 2 : 
--Ödeme tipine göre başarılı order sayısı ve toplam başarılı ödeme tutarını hesaplayınız. En çok
 --kullanılan ödeme tipinden en az olana göre sıralayınız.
SELECT 
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS delivered_ordercount,
    ROUND(SUM(payment_value)::numeric, 2) || ' BRL' AS total_payment
FROM orders AS o
JOIN  payments AS p ON o.order_id = p.order_id
WHERE  order_status = 'delivered'
GROUP BY 1
ORDER BY 2 DESC;

--Question 3 : 
--Taksitle ödenen siparişlerin kategori bazlı analizini yapınız. En çok hangi 
--kategorilerde taksitle ödeme kullanılmaktadır?

-- TAKSİTLİ ÖDEME SORGUSU

WITH categorization AS (
  SELECT
    CASE
      WHEN category_name_english IS NULL THEN 'UNCATEGORIZED'
      ELSE category_name_english
      END AS category_name_english,
    COUNT(DISTINCT o.order_id) AS installment_order
  FROM orders AS o
  LEFT JOIN payments AS p ON o.ORDER_ID = p.ORDER_ID
  LEFT JOIN order_items AS oi ON o.ORDER_ID = oi.ORDER_ID
  LEFT JOIN products AS pr ON oi.PRODUCT_ID = pr.PRODUCT_ID
  INNER JOIN translation AS t ON pr.product_category_name = t.category_name
  WHERE payment_installments > 1 AND payment_type = 'credit_card'
  GROUP BY 1
  ORDER BY 2 DESC
  LIMIT 10
)
SELECT category_name_english, installment_order FROM categorization;

--Case 5 
--RFM Analizi
--Aşağıdaki e_commerce_data_.csv doyasındaki veri setini kullanarak RFM analizi yapınız. 
--Recency hesaplarken bugünün tarihi değil en son sipariş tarihini baz alınız. 

SELECT 
    CASE
        WHEN rfm_score IN ('5-5-5') THEN 'Champions'
        WHEN rfm_score IN ('4-5-5', '5-4-5', '5-5-4') THEN 'Loyal Customers'
        WHEN rfm_score IN ('5-1-1', '5-2-1', '5-1-2', '5-2-2') THEN 'New Customers'
        WHEN rfm_score IN ('2-2-2', '2-1-2', '2-2-1', '2-1-1') THEN 'Hibernating'
        WHEN rfm_score IN ('3-2-2', '2-3-2', '2-2-3', '3-2-1', '3-1-2', '2-3-1', '2-1-3', '1-3-2', '1-2-3') THEN 'About to Sleep'
        WHEN rfm_score IN ('4-1-1', '4-2-1', '4-1-2', '4-2-2') THEN 'Promising'
        WHEN rfm_score IN ('1-5-5', '1-4-5', '1-5-4', '2-5-5', '2-4-5', '2-5-4') THEN 'Cant Lose Them'
        WHEN rfm_score IN ('1-1-1', '1-2-1', '1-1-2', '1-2-2') THEN 'At Risk'
        WHEN rfm_score IN ('3-5-5', '4-5-4', '3-4-5', '3-5-4', '4-4-5') THEN 'Potential Loyalists'
        WHEN rfm_score IN ('5-3-3', '5-4-3', '5-3-4') THEN 'Need Attention'
		 ELSE 'Diğer'
    END AS customer_segment,
    COUNT(customer_id) AS customer_count
FROM 
(
    SELECT 
        customer_id,
        recency_score::text || '-' || frequency_score::text || '-' || monetary_score::text as rfm_score
    FROM 
    (
        WITH recency AS 
        (
            WITH tablo_1 AS 
            (
                SELECT
                    customer_id,
                    max(invoicedate::date) as max_invoice_date
                FROM rfm AS r
                WHERE customer_id IS NOT NULL AND invoiceno IS NOT NULL AND invoiceno NOT LIKE 'C%'
                GROUP BY 1
            )
            SELECT
                customer_id,
                max_invoice_date,
                ('2011-12-09'::date-max_invoice_date) as recency
            FROM tablo_1
        ), 
        frequency AS
        (
            SELECT
                customer_id,
                COUNT(DISTINCT invoiceno) as frequency
            FROM rfm AS r
            WHERE customer_id IS NOT NULL AND invoiceno IS NOT NULL AND invoiceno NOT LIKE 'C%'
            GROUP BY 1
        ), 
        monetary AS
        (
            SELECT
                customer_id,
                ROUND (SUM(quantity*unitprice)::numeric,2) AS monetary
            FROM rfm AS r
            WHERE customer_id IS NOT NULL AND invoiceno IS NOT NULL AND invoiceno NOT LIKE 'C%'
            GROUP BY 1
        )
        SELECT
            r.customer_id,
            r.recency,
            NTILE(5) OVER (ORDER BY recency DESC) as recency_score,
            f.frequency,
            CASE WHEN f.frequency>=1 AND f.frequency<=4 
                THEN f.frequency
                ELSE 5 END as frequency_score,
            m.monetary,
            NTILE(5) OVER (ORDER BY monetary) as monetary_score
        FROM recency as r
        INNER JOIN frequency as f ON r.customer_id=f.customer_id
        INNER JOIN monetary as m ON m.customer_id=r.customer_id
        ORDER BY f.frequency DESC
    ) as rfm
) as rfm_score
GROUP BY customer_segment
ORDER BY customer_count DESC



