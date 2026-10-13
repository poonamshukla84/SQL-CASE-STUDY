# SQL Case Study #1: Danny's Diner

Customer-behaviour analysis for a small restaurant deciding whether to expand its loyalty program, from the [8 Week SQL Challenge](https://8weeksqlchallenge.com/case-study-1/).

**Skills shown:** `JOIN`s · `GROUP BY` aggregation · CTEs · window functions (`DENSE_RANK() OVER (PARTITION BY …)`) · `CASE` logic · date filtering

## Business questions

Danny wants to understand his customers' visiting patterns, spending and favourite menu items, and decide whether to expand the loyalty program.

## Data

| Table | Columns | Description |
|---|---|---|
| `sales` | customer_id, order_date, product_id | every order (15 rows) |
| `menu` | product_id, product_name, price | sushi $10, curry $15, ramen $12 |
| `members` | customer_id, join_date | loyalty sign-ups (A on Jan 7, B on Jan 9) |

## Key insights

1. **A is the top spender ($76), B is the most frequent visitor (6 days).** Two different kinds of "best customer", which need two different rewards.
2. **Ramen is the best-seller** (8 of 15 orders) and the favourite of A and C. It's the natural loyalty reward item.
3. **Members were already regulars:** A and B spent $25 and $40 before joining. The program rewards existing loyalty more than it creates new loyalty.
4. **The first-week 2x bonus favours early, active members:** A visited three times (4 orders) in their first member week, lifting January points to 1,370 vs. 820 for B.
5. **Customer C (ramen only, not a member) is the clearest sign-up opportunity.**

**Recommendation:** expand the program, use ramen as the reward hook, and target C-type customers (repeat single-item buyers who aren't members yet).

## How to run

```bash
python run_solutions.py      # builds an in-memory SQLite DB from schema.sql and prints every answer
```
Or paste `schema.sql` + `solutions.sql` into [DB Fiddle](https://www.db-fiddle.com/) (SQLite). The solutions are written in portable SQL. The only dialect-specific pieces (`LIMIT` and the date math in Q10) have their SQL Server / MySQL equivalents in the comments.

## Solutions

### Q1. What is the total amount each customer spent at the restaurant?

```sql
SELECT s.customer_id,
       SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;
```

**Result**

| customer_id | total_spent |
|---|---|
| A | 76 |
| B | 74 |
| C | 36 |

**Insight:** Customer A spends the most ($76), just ahead of B ($74). C spends less than half as much.

### Q2. How many days has each customer visited the restaurant?

```sql
SELECT customer_id,
       COUNT(DISTINCT order_date) AS visit_days
FROM sales
GROUP BY customer_id
ORDER BY customer_id;
```

**Result**

| customer_id | visit_days |
|---|---|
| A | 4 |
| B | 6 |
| C | 2 |

**Insight:** B visits most often (6 days) but spends slightly less than A, so B is the most *frequent* customer and A the highest *spender*.

### Q3. What was the first item from the menu purchased by each customer?

```sql
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
```

**Result**

| customer_id | product_name |
|---|---|
| A | curry |
| A | sushi |
| B | curry |
| C | ramen |

**Insight:** Without order timestamps, A's first-day sushi and curry tie, so both are returned. `DENSE_RANK` keeps ties instead of picking one at random.

### Q4. What is the most purchased item on the menu and how many times was it purchased by all customers?

```sql
-- (SQL Server: use SELECT TOP 1 ... instead of LIMIT 1)
SELECT m.product_name,
       COUNT(*) AS times_purchased
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY times_purchased DESC
LIMIT 1;
```

**Result**

| product_name | times_purchased |
|---|---|
| ramen | 8 |

**Insight:** Ramen is the clear best-seller (8 of 15 orders), a strong candidate for a loyalty-program reward item.

### Q5. Which item was the most popular for each customer?

```sql
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
```

**Result**

| customer_id | product_name | order_count |
|---|---|---|
| A | ramen | 3 |
| B | curry | 2 |
| B | ramen | 2 |
| B | sushi | 2 |
| C | ramen | 3 |

**Insight:** A and C are ramen loyalists; B buys all three items equally, so B is the best target for menu-wide promotions.

### Q6. Which item was purchased first by the customer after they became a member?

```sql
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
```

**Result**

| customer_id | order_date | product_name |
|---|---|---|
| A | 2021-01-07 | curry |
| B | 2021-01-11 | sushi |

### Q7. Which item was purchased just before the customer became a member?

```sql
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
```

**Result**

| customer_id | order_date | product_name |
|---|---|---|
| A | 2021-01-01 | curry |
| A | 2021-01-01 | sushi |
| B | 2021-01-04 | sushi |

### Q8. What is the total items and amount spent for each member before they became a member?

```sql
SELECT s.customer_id,
       COUNT(*)     AS items_before_joining,
       SUM(m.price) AS spent_before_joining
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m     ON s.product_id  = m.product_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;
```

**Result**

| customer_id | items_before_joining | spent_before_joining |
|---|---|---|
| A | 2 | 25 |
| B | 3 | 40 |

**Insight:** Both members were already spending $25–$40 before joining, so the program converted existing regulars.

### Q9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?

```sql
SELECT s.customer_id,
       SUM(CASE WHEN m.product_name = 'sushi' THEN m.price * 20
                ELSE m.price * 10 END) AS points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;
```

**Result**

| customer_id | points |
|---|---|
| A | 860 |
| B | 940 |
| C | 360 |

### Q10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi. How many points do customer A and B have at the end of January?

```sql
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
```

**Result**

| customer_id | january_points |
|---|---|
| A | 1370 |
| B | 820 |

**Insight:** All of A's first-week member orders (Jan 7–11) earn 2x, so A finishes January well ahead of B, who had only one order in that window.

### Bonus. Bonus: build a "join all the things" table with a member flag, ranking only member purchases.

```sql
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
```

**Result**

| customer_id | order_date | product_name | price | member | member_ranking |
|---|---|---|---|---|---|
| A | 2021-01-01 | curry | 15 | N |  |
| A | 2021-01-01 | sushi | 10 | N |  |
| A | 2021-01-07 | curry | 15 | Y | 1 |
| A | 2021-01-10 | ramen | 12 | Y | 2 |
| A | 2021-01-11 | ramen | 12 | Y | 3 |
| A | 2021-01-11 | ramen | 12 | Y | 3 |
| B | 2021-01-01 | curry | 15 | N |  |
| B | 2021-01-02 | curry | 15 | N |  |
| B | 2021-01-04 | sushi | 10 | N |  |
| B | 2021-01-11 | sushi | 10 | Y | 1 |
| B | 2021-01-16 | ramen | 12 | Y | 2 |
| B | 2021-02-01 | ramen | 12 | Y | 3 |
| C | 2021-01-01 | ramen | 12 | N |  |
| C | 2021-01-01 | ramen | 12 | N |  |
| C | 2021-01-07 | ramen | 12 | N |  |


---
**Poonam Shukla** · Data Analyst · [LinkedIn](https://linkedin.com/in/poonam-shukla-10683b31b) · See also: [Fresh Department Shrink & Labor Analytics](https://github.com/poonamshukla84/fresh-dept-shrink-analytics)
