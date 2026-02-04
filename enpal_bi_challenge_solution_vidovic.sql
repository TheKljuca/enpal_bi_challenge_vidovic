/* Enpal BI Analyst Challenge 
   Author: Dino Vidovic
   Date: 04.02.2026
*/


/******************************************************************
 QUESTION 1: How far back does your data go, and how recent is it?
 	Results: 
 	Earliest Lead: 2024-01-16
 	Latest Closure: 2024-10-28
******************************************************************/

SELECT 
    (SELECT MIN(lead_created_date) FROM main.leads) AS earliest_lead_created_date,
    (SELECT MAX(case_closed_successful_date) FROM main.sales_funnel) AS latest_case_closed_successful_date;


/******************************************************************
 QUESTION 2: What is the best-performing marketing channel regarding:
    - Lead → PV System Sold conversion rate
    - Time to conversion
 	Results: 
 	Best Conversion: Channel A (9.91%)
 	Fastest Conversion: Channel C (43.81 days)
******************************************************************/

WITH lead_sales AS (
    SELECT 
        l.lead_id,
        l.marketing_channel,
        l.lead_created_date,
        sf.case_closed_successful_date AS sold_date
    FROM main.leads l
    LEFT JOIN main.sales_funnel sf 
        ON l.lead_id = sf.lead_id 
        AND sf.sales_funnel_steps = 'PV System Sold'
)
SELECT 
    marketing_channel,
    COUNT(lead_id) AS total_leads,
    -- COUNT(sold_date) ignores NULLs, effectively counting only successful conversions
    COUNT(sold_date) AS total_sales,
    -- Conversion Rate calculation
    ROUND(COUNT(sold_date) * 100.0 / COUNT(lead_id), 2) AS conv_rate_pct,
    -- Average days to convert (Ignoring leads that haven't sold)
    ROUND(AVG(DATE_DIFF('day', lead_created_date, sold_date)), 2) AS avg_days_to_sold
FROM lead_sales
GROUP BY 1
ORDER BY conv_rate_pct DESC;


/******************************************************************
 QUESTION 3: Return the top and bottom 3 days (lead_created_date) 
    by marketing channel using: Lead → Sales Call 1 conversion rate.
    
    NOTE: Conversion is defined as a SUCCESSFUL completion of 
    Sales Call 1 (non-null CASE_CLOSED_SUCCESSFUL_DATE).
******************************************************************/

WITH daily_stats AS (
    SELECT 
        l.marketing_channel,
        l.lead_created_date,
        COUNT(l.lead_id) AS total_leads,
        -- Corrected: Counting only successful closures
        COUNT(sf.case_closed_successful_date) AS successful_call_1,
        -- Daily Conversion Rate based on success, not just existence
        (COUNT(sf.case_closed_successful_date) * 100.0 / NULLIF(COUNT(l.lead_id), 0)) AS daily_conv_rate
    FROM main.leads l
    LEFT JOIN main.sales_funnel sf 
        ON l.lead_id = sf.lead_id 
        AND sf.sales_funnel_steps = 'Sales Call 1'
    GROUP BY 1, 2
),
ranked_days AS (
    SELECT 
        *,
        ROW_NUMBER() OVER(PARTITION BY marketing_channel ORDER BY daily_conv_rate DESC, total_leads DESC) AS top_rn,
        ROW_NUMBER() OVER(PARTITION BY marketing_channel ORDER BY daily_conv_rate ASC, total_leads DESC) AS bottom_rn
    FROM daily_stats
    -- Threshold: 100 leads/day (excludes bottom 10% of low-volume outliers)
    WHERE total_leads >= 100
)
SELECT 
    marketing_channel,
    lead_created_date,
    ROUND(daily_conv_rate, 2) AS conversion_rate,
    total_leads,
    CASE 
        WHEN top_rn <= 3 THEN 'Top 3'
        WHEN bottom_rn <= 3 THEN 'Bottom 3'
    END AS performance_category
FROM ranked_days
WHERE top_rn <= 3 OR bottom_rn <= 3
ORDER BY marketing_channel, performance_category DESC, daily_conv_rate DESC;


/******************************************************************************
 QUESTION 4: Prepare a dataset to enable cohort analysis by marketing channel.
*******************************************************************************/

DROP TABLE IF EXISTS main.flat_lead_performance;

CREATE TABLE main.flat_lead_performance AS
SELECT 
    l.lead_id,
    l.lead_created_date,
    l.marketing_channel,
    
    -- Case Opened Timestamps (To measure Response Times/SLA)
    MIN(CASE WHEN sf.sales_funnel_steps = 'Sales Call 1' THEN sf.case_opened_date END) AS date_call_1_opened,
    MIN(CASE WHEN sf.sales_funnel_steps = 'Sales Call 2' THEN sf.case_opened_date END) AS date_call_2_opened,
    MIN(CASE WHEN sf.sales_funnel_steps = 'PV System Sold' THEN sf.case_opened_date END) AS date_sold_opened,
    
    -- Success Timestamps (To measure Conversion & Cycle Time)
    MAX(CASE WHEN sf.sales_funnel_steps = 'Sales Call 1' THEN sf.case_closed_successful_date END) AS date_call_1_success,
    MAX(CASE WHEN sf.sales_funnel_steps = 'Sales Call 2' THEN sf.case_closed_successful_date END) AS date_call_2_success,
    MAX(CASE WHEN sf.sales_funnel_steps = 'PV System Sold' THEN sf.case_closed_successful_date END) AS date_sold_success,
    
    -- Success Flags (1/0) for easy summing/averaging in BI tools
    MAX(CASE WHEN sf.sales_funnel_steps = 'Sales Call 1' AND sf.case_closed_successful_date IS NOT NULL THEN 1 ELSE 0 END) AS is_call_1_success,
    MAX(CASE WHEN sf.sales_funnel_steps = 'Sales Call 2' AND sf.case_closed_successful_date IS NOT NULL THEN 1 ELSE 0 END) AS is_call_2_success,
    MAX(CASE WHEN sf.sales_funnel_steps = 'PV System Sold' AND sf.case_closed_successful_date IS NOT NULL THEN 1 ELSE 0 END) AS is_sold_success

FROM main.leads l
LEFT JOIN main.sales_funnel sf ON l.lead_id = sf.lead_id
GROUP BY 1, 2, 3;