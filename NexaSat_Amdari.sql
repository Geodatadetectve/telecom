SELECT * FROM amdari.nexasat_data;
## DATA CLEANING
## Checking for duplicates

Select Customer_ID,gender,Partner,Dependents,Senior_Citizen,Call_Duration,Data_Usage,Plan_Type,Plan_Level,Monthly_Bill_Amount,Tenure_Months,Multiple_Lines,Tech_Support,Churn
FROM amdari.nexasat_data
group by Customer_ID,gender,Partner,Dependents,Senior_Citizen,Call_Duration,Data_Usage,Plan_Type,Plan_Level,Monthly_Bill_Amount,Tenure_Months,Multiple_Lines,Tech_Support,Churn
Having count(*) >1; ## To filter out duplicates

## Check for NULL values
SELECT Customer_ID, gender, Partner, Dependents, Senior_Citizen, Call_Duration, Data_Usage, Plan_Type, Plan_Level, Monthly_Bill_Amount, Tenure_Months, Multiple_Lines, Tech_Support, Churn
FROM amdari.nexasat_data
WHERE Customer_ID IS NULL
    OR gender IS NULL
    OR Partner IS NULL
    OR Dependents IS NULL
    OR Senior_Citizen IS NULL
    OR Call_Duration IS NULL
    OR Data_Usage IS NULL
    OR Plan_Type IS NULL
    OR Plan_Level IS NULL
    OR Monthly_Bill_Amount IS NULL
    OR Tenure_Months IS NULL
    OR Multiple_Lines IS NULL
    OR Tech_Support IS NULL
    OR Churn IS NULL

## EDA
## Total USERS
Select count(customer_id) as current_users
FROM amdari.nexasat_data
where churn =0;

## Total USERS by level
Select plan_Level, count(customer_id) as total_users
FROM amdari.nexasat_data
where churn = 0
Group by 1;

## Summary statistics for numerical columns
SELECT 
    AVG(Call_Duration) AS avg_call_duration, 
    STD(Call_Duration) AS std_call_duration,
    MIN(Call_Duration) AS min_call_duration, 
    MAX(Call_Duration) AS max_call_duration,
    AVG(Data_Usage) AS avg_data_usage, 
    STD(Data_Usage) AS std_data_usage,
    MIN(Data_Usage) AS min_data_usage, 
    MAX(Data_Usage) AS max_data_usage,
    AVG(Monthly_Bill_Amount) AS avg_monthly_bill, 
    STD(Monthly_Bill_Amount) AS std_monthly_bill,
    MIN(Monthly_Bill_Amount) AS min_monthly_bill, 
    MAX(Monthly_Bill_Amount) AS max_monthly_bill,
    AVG(Tenure_Months) AS avg_tenure, 
    STD(Tenure_Months) AS std_tenure,
    MIN(Tenure_Months) AS min_tenure, 
    MAX(Tenure_Months) AS max_tenure
FROM amdari.nexasat_data;

-- Frequency counts for categorical columns
SELECT gender, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY gender;
SELECT Partner, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Partner;
SELECT Dependents, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Dependents;
SELECT Senior_Citizen, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Senior_Citizen;
SELECT Plan_Type, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Plan_Type;
SELECT Plan_Level, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Plan_Level;
SELECT Multiple_Lines, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Multiple_Lines;
SELECT Tech_Support, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Tech_Support;
SELECT Churn, COUNT(*) AS count FROM amdari.nexasat_data GROUP BY Churn;

## Total revenue 
SELECT 
    round(sum(monthly_bill_amount), 2) as revenue
FROM 
    amdari.nexasat_data
    
## Total revenue by monthly_bill_amount
SELECT 
    monthly_bill_amount,
    sum(monthly_bill_amount) as total_sum,  -- Check intermediate results
    round(sum(monthly_bill_amount), 2) as rounded_sum
FROM 
    amdari.nexasat_data
GROUP BY 
    monthly_bill_amount;
    
## Total revenue by plan level
SELECT 
    Plan_Level,
    round(sum(monthly_bill_amount), 2) as revenue
FROM 
    amdari.nexasat_data
group by 1;

## churn count by by plan level and plan type
SELECT 
    Plan_Level,
    Plan_type,
   count(*) as total_customers,
   sum(churn) as churn_count
FROM 
    amdari.nexasat_data
group by 1,2
order by 1;

## Average Tenure by plan level and plan type
SELECT 
    Plan_Level,
    Plan_type,
   round(Avg(tenure_months),2) as avg_tenure
FROM 
    amdari.nexasat_data
group by 1,2
order by 1;

##SEGMENTATION
## Marketing Segment
Create Table existing_users AS
select *
From amdari.nexasat_data
Where churn = 0;

select *
From existing_users;

## Calculate ARPU for existing users
select round(avg(Monthly_Bill_Amount),2) as ARPU
From existing_users;

## Calculate CLV and add column
Alter table existing_users
add column clv float;

UPDATE existing_users
SET clv = ROUND(monthly_bill_amount * tenure_months, 2)

## view new clv column
Select customer_id, clv
from existing_users; 

## Calculate the CLV score
## monthly_bill = 40%, tenure =30%, call_duration =10%, data_usage =10%, premium = 10%
Alter Table existing_users
Add column clv_score numeric(10,2);

Update existing_users
Set clv_score = 
(0.4 * monthly_bill_amount) + 
(0.3 * tenure_months) +
(0.1 * call_duration) +
(0.1 * data_usage) +
(0.1 * Case when plan_level = 'Premium'
        then 1 else 0
        end);

## view new clv column
Select customer_id, clv
from existing_users; 
        
## group users into segments based on their clv scores
ALTER TABLE existing_users
ADD COLUMN clv_segments VARCHAR(50);
 
-- Create a temporary table to store clv_scores and their percentiles
CREATE TEMPORARY TABLE temp_percentiles AS
SELECT 
    clv_score,
    PERCENT_RANK() OVER (ORDER BY clv_score) AS percentile
FROM existing_users;

-- Update the clv_segments in the existing_users table
UPDATE existing_users eu
JOIN temp_percentiles tp ON eu.clv_score = tp.clv_score
SET eu.clv_segments = 
    CASE 
        WHEN tp.percentile > 0.85 THEN 'High Value'
        WHEN tp.percentile > 0.50 THEN 'Moderate Value'
        WHEN tp.percentile > 0.25 THEN 'Low Value'
        ELSE 'Churn Risk'
    END;

-- Drop the temporary table
DROP TEMPORARY TABLE temp_percentiles;

select customer_id, clv, clv_score, clv_segments
from existing_users
limit 20;


##ANALYZING THE SEGMENTS
##avg bill and tenure per segment
SELECT clv_segments,
    ROUND(AVG(monthly_bill_amount),2) AS avg_monthly_charges,
    ROUND(AVG(tenure_months),2) AS avg_tenure
FROM existing_users
GROUP BY 1;

##tech support and multiple lines count
SELECT clv_segments,
    ROUND(AVG(CASE WHEN tech_support = 'Yes' THEN 1 ELSE 0 END), 2) AS tech_support_pct,
    ROUND(AVG(CASE WHEN multiple_lines = 'Yes' THEN 1 ELSE 0 END), 2) AS multiple_line_pct
FROM existing_users
GROUP BY 1;

##revenue per segment
SELECT clv_segments, COUNT(customer_id),
    CAST(SUM(monthly_bill_amount * tenure_months) AS DECIMAL(10,2)) AS total_revenue
FROM existing_users
GROUP BY clv_segments;

## Up-selling and cross-spelling
## Cross-spelling: Tech support to senior citizens
Select Customer_ID
from existing_users
where Senior_Citizen = 1 ##Senior citizens
AND Dependents= 'No' ## No children or tech savy helpers
AND Tech_Support = 'No' ## Those who doesnt already have this services.
And (clv_segments = 'Churn Risk' OR clv_segments = 'Low Value');

## Cross-spelling: Multiple for partners and dependents
select Customer_ID
From existing_users
Where Multiple_lines = 'No'
AND (Dependents = 'Yes' OR Partner = 'Yes')
AND Plan_level = 'Basic'

## up-spelling: premium discount for basic users with churn risk
select Customer_ID
From existing_users
Where clv_segments = 'Churn Risk'
AND Plan_Level = 'Basic'

##upselling: basic to premium for longer lock in priod and high ARPU
select Plan_Level, round(avg(monthly_bill_amount),2), round(avg(tenure_months),2)
from existing_users
where clv_segments = 'High Value'
or clv_segments = 'Moderate Value'
Group by 1;

##select customers
select Customer_ID, monthly_bill_amount
from existing_users
where Plan_level = 'Basic'
And (clv_segments = 'High Value' or Clv_segments = 'Moderate Value')
And monthly_bill_amount >150;

##create stored procedures
##Snr citizens who will be offered tech support
DELIMITER //
CREATE PROCEDURE tech_support_snr_citizens()
BEGIN
    SELECT eu.customer_id
    FROM existing_users eu
    WHERE eu.senior_citizen = 1  -- senior citizens
        AND eu.dependents = 'No' -- no children or tech savvy helpers
        AND eu.tech_support = 'No' -- do not already have this service
        AND (eu.clv_segments = 'Churn Risk' OR eu.clv_segments = 'Low Value');
END //
DELIMITER ;
CALL tech_support_snr_citizens();

##at risk customers who will be offered premium discount
DELIMITER //
CREATE PROCEDURE churn_risk_discount()
BEGIN
    SELECT eu.customer_id
    FROM existing_users eu
    WHERE eu.clv_segments = 'Churn Risk'
      AND eu.plan_level = 'Basic';
END //
DELIMITER ;
CALL churn_risk_discount();

## high usage customers who will be offered premium upgrade
DELIMITER //
CREATE PROCEDURE high_usage_basic()
BEGIN
    select eu.Customer_ID, eu.monthly_bill_amount
	from existing_users eu
	where eu.Plan_level = 'Basic'
	And (eu.clv_segments = 'High Value' or eu.Clv_segments = 'Moderate Value')
	And eu.monthly_bill_amount >150;
END //
DELIMITER ;
CALL high_usage_basic();

## Use procedures
CALL tech_support_snr_citizens();
CALL churn_risk_discount();
CALL high_usage_basic();

