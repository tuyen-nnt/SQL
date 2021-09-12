-- Tinh metrics RFM
WITH rfm_metrics AS (
    SELECT
          customer_guid,
          MAX(date(payment_date_time)) AS last_active_date,
          datediff(SYSDATE(),MAX(date(payment_date_time))) AS recency,
          COUNT(DISTINCT invoice_id) AS frequency,
          SUM(amount) AS monetary
    FROM invoice
    WHERE
          date(payment_date_time) >= SYSDATE() - INTERVAL 1 YEAR
    GROUP BY customer_guid
)
-- Tim phan vi frequency va monetary
, rfm_percent_rank AS (
    SELECT *,
           PERCENT_RANK() over (ORDER BY frequency) AS frequency_percent_rank,
           PERCENT_RANK() over (ORDER BY monetary)  AS monetary_percent_rank
    FROM rfm_metrics
)

-- Phan rank cho RFM tu 1-3
, rfm_rank AS (
    SELECT
        *,
        CASE
            WHEN recency BETWEEN 0 AND 100 THEN 3
            WHEN recency BETWEEN 100 AND 200 THEN 2
            WHEN recency BETWEEN 100 AND 200 THEN 1
            ELSE 0
            END
            AS recency_rank,
        CASE
            WHEN frequency_percent_rank BETWEEN 0.8 AND 1 THEN 3
            WHEN frequency_percent_rank BETWEEN 0.5 AND 0.8 THEN 2
            WHEN frequency_percent_rank BETWEEN 0 AND 0.5 THEN 1
            ELSE 0 END
            AS frequency_rank,
        CASE
            WHEN monetary_percent_rank BETWEEN 0.8 AND 1 THEN 3
            WHEN monetary_percent_rank BETWEEN 0.5 AND 0.8 THEN 2
            WHEN monetary_percent_rank BETWEEN 0 AND 0.5 THEN 1
            ELSE 0 END
            AS monetary_rank
    FROM rfm_percent_rank
)
-- Noi lai de easy phan loai
, rfm_rank_concat AS (
    SELECT *,
           CONCAT(recency_rank, frequency_rank, monetary_rank) AS rfm_rank
    FROM rfm_rank
)
-- Phan loai KH
SELECT
    *,
    CASE
        WHEN recency_rank = 1 THEN '1-Churned'
        WHEN recency_rank = 2 THEN '2-Churning'
        WHEN recency_rank = 3 THEN '3-Active'
        END AS recency_segment,

    CASE
        WHEN frequency_rank = 1 THEN '1-Least frequent'
        WHEN frequency_rank = 2 THEN '2-Frequent'
        WHEN recency_rank = 3 THEN '3-Most frequent'
        END AS frequency_segment,

   CASE
        WHEN monetary_rank = 1 THEN '1-Least spending'
        WHEN monetary_rank = 2 THEN '2-Normal spending'
        WHEN recency_rank = 3 THEN '3-Most spending'
        END AS monetary_segment,

    CASE
        WHEN rfm_rank IN ('333','323','313') THEN 'VIP'
        WHEN rfm_rank IN ('313','233','223','133','123','213','113') THEN 'VIP, churning/churned'
        WHEN rfm_rank IN ('332','331','322','321','222') THEN 'Normal'
        WHEN rfm_rank IN ('321', '311', '312', '212','211','221') THEN 'Low-spending'
        WHEN rfm_rank IN ('111', '112', '122', '121','221') THEN 'Not frequent'
        END
        AS rfm_segment
FROM rfm_rank_concat


