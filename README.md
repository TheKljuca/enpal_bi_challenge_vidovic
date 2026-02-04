# enpal_bi_challenge_vidovic
Submission of the solution for the BI / Data Analyst – Challenge by Dino Vidovic

# Project Overview

This repository contains the SQL solution for the Enpal BI Challenge. The analysis focuses on lead conversion, marketing channel performance, and funnel velocity tracking using a denormalized dataset optimized for BI tools.

# Key Assumptions & Logic

Definition of Conversion: Conversion is defined as a successful milestone completion (case_closed_successful_date is NOT NULL). This ensures we exclude administrative closures or failed sales attempts.

Volume Threshold (Outlier Handling): For daily performance ranking (Question 3), a threshold of >= 100 leads per day was applied. This filters out the bottom 10% of low-volume days (outliers/ramp-up periods) to ensure conversion rates are statistically significant.

Lead-to-Sold Velocity: Time-to-conversion is calculated only for successful sales. Leads still in the pipeline are excluded from average duration metrics to avoid skewing the results.

Funnel Flattening: The dataset for Question 4 was pivoted from a long event-log format to a wide "one-row-per-lead" format. This enables efficient cohort analysis and velocity tracking (SLA) in visualization tools.
