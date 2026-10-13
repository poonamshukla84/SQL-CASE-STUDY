-- Danny's Diner: solutions (SQLite; notes mark the two lines that differ in other dialects)
-- Each answer is tagged "-- @q<n>" so run_solutions.py can execute and print it.

-- @q1 Total amount each customer spent
SELECT s.customer_id,
       SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- @q2 Number of distinct days each customer visited
SELECT customer_id,
       COUNT(DISTINCT order_date) AS visit_days
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

-- @q3 First item(s) purchased by each customer
-- DENSE_RANK keeps ties: orders on the same first day have no time stamp, so all count as "first".
WITH ranked AS (
  SELECT s.customer_id, m.product_name,
         DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rnk
  FROM sales s
  JOIN menu m ON s.product_id = m.product_id
)
SELECT DISTINCT customer_id, product_name
FROM ranked
WHERE rnk = 1
ORDER BY customer_id, product_name;

-- @q4 Most purchased item overall and how many times
-- (SQL Server: use SELECT TOP 1 ... instead of LIMIT 1)
SELECT m.product_name,
       COUNT(*) AS times_purchased
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY times_purchased DESC
LIMIT 1;

-- @q5 Most popular item for each customer (ties kept)
WITH counts AS (
  SELECT s.customer_id, m.product_name, COUNT(*) AS order_count,
         DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS rnk
  FROM sales s
  JOIN menu m ON s.product_id = m.product_id
  GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name, order_count
FROM counts
WHERE rnk = 1
ORDER BY customer_id, product_name;

-- @q6 First item purchased after becoming a member (join day counts as member)
WITH member_orders AS (
  SELECT s.customer_id, s.order_date, m.product_name,
         DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rnk
  FROM sales s
  JOIN members mb ON s.customer_id = mb.customer_id
  JOIN menu m     ON s.product_id  = m.product_id
  WHERE s.order_date >= mb.join_date
)
SELECT customer_id, order_date, product_name
FROM member_orders
WHERE rnk = 1
ORDER BY customer_id;

-- @q7 Item(s) purchased just before becoming a member
WITH pre_member AS (
  SELECT s.customer_id, s.order_date, m.product_name,
         DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rnk
  FROM sales s
  JOIN members mb ON s.customer_id = mb.customer_id
  JOIN menu m     ON s.product_id  = m.product_id
  WHERE s.order_date < mb.join_date
)
SELECT customer_id, order_date, product_name
FROM pre_member
WHERE rnk = 1
ORDER BY customer_id, product_name;

-- @q8 Total items and amount spent before becoming a member
SELECT s.customer_id,
       COUNT(*)     AS items_before_joining,
       SUM(m.price) AS spent_before_joining
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m     ON s.product_id  = m.product_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- @q9 Points: $1 = 10 points, sushi earns 2x
SELECT s.customer_id,
       SUM(CASE WHEN m.product_name = 'sushi' THEN m.price * 20
                ELSE m.price * 10 END) AS points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- @q10 Points for A and B at end of January, with 2x on everything in the first week of membership
-- First week = join_date through join_date + 6 days (7 days including the join date).
-- (SQL Server: DATEADD(day, 6, mb.join_date); MySQL: DATE_ADD(mb.join_date, INTERVAL 6 DAY))
SELECT s.customer_id,
       SUM(CASE
             WHEN s.order_date BETWEEN mb.join_date AND date(mb.join_date, '+6 days')
               THEN m.price * 20
             WHEN m.product_name = 'sushi' THEN m.price * 20
             ELSE m.price * 10
           END) AS january_points
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m     ON s.product_id  = m.product_id
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- @bonus Join-all-things table with member flag and member-only ranking (Danny's bonus questions)
SELECT s.customer_id, s.order_date, m.product_name, m.price,
       CASE WHEN s.order_date >= mb.join_date THEN 'Y' ELSE 'N' END AS member,
       CASE WHEN s.order_date >= mb.join_date
            THEN DENSE_RANK() OVER (PARTITION BY s.customer_id,
                                    CASE WHEN s.order_date >= mb.join_date THEN 1 ELSE 0 END
                                    ORDER BY s.order_date)
       END AS member_ranking
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id
ORDER BY s.customer_id, s.order_date, m.product_name;
