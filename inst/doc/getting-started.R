## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----installation, eval=FALSE-------------------------------------------------
# # install.packages("devtools")
# devtools::install_github("ericscheier/emburden")

## ----setup--------------------------------------------------------------------
library(emburden)
library(dplyr)

## ----single-household---------------------------------------------------------
# Calculate energy burden for a single household
gross_income <- 50000
energy_spending <- 3000

# Method 1: Direct energy burden
eb <- energy_burden_func(gross_income, energy_spending)
print(paste("Energy Burden:", scales::percent(eb)))

# Method 2: Via Net Energy Return (mathematically identical)
nh <- ner_func(gross_income, energy_spending)
neb <- 1 / (nh + 1)
print(paste("Net Energy Burden:", scales::percent(neb)))
print(paste("Net Energy Return:", round(nh, 2)))

## ----load-data, eval=FALSE----------------------------------------------------
# # Load census tract data for North Carolina
# nc_tracts <- load_census_tract_data(states = "NC")
# 
# # Load household cohort data by Area Median Income
# nc_ami <- load_cohort_data(dataset = "ami", states = "NC")
# 
# # View structure
# head(nc_ami)

## ----cohort-example, eval=FALSE-----------------------------------------------
# # Calculate mean income and spending from totals
# nc_data <- nc_ami %>%
#   mutate(
#     mean_income = total_income / households,
#     mean_energy_spending = (total_electricity_spend +
#                            coalesce(total_gas_spend, 0) +
#                            coalesce(total_other_spend, 0)) / households
#   ) %>%
#   filter(!is.na(mean_income), !is.na(mean_energy_spending), households > 0) %>%
#   mutate(
#     eb = energy_burden_func(mean_income, mean_energy_spending),
#     nh = ner_func(mean_income, mean_energy_spending),
#     neb = neb_func(mean_income, mean_energy_spending)
#   )

## ----wrong-aggregation, eval=FALSE--------------------------------------------
# # ❌ WRONG: Direct averaging of energy burden introduces ~1-5% error
# eb_wrong <- weighted.mean(nc_data$eb, nc_data$households)

## ----correct-aggregation, eval=FALSE------------------------------------------
# # ✅ CORRECT Method 1: Aggregate using Nh, then convert to NEB
# nh_mean <- weighted.mean(nc_data$nh, nc_data$households)
# neb_correct <- 1 / (1 + nh_mean)
# 
# # ✅ CORRECT Method 2: Use neb_func() with weights (simpler!)
# # neb_func() automatically uses the Nh method internally
# neb_correct2 <- neb_func(nc_data$mean_income,
#                          nc_data$mean_energy_spending,
#                          weights = nc_data$households)
# 
# print(paste("Correct NEB (manual Nh):", scales::percent(neb_correct)))
# print(paste("Correct NEB (neb_func): ", scales::percent(neb_correct2)))
# # Both give identical results!

## ----by-income, eval=FALSE----------------------------------------------------
# # Method 1: Manual Nh aggregation
# nc_by_income <- nc_data %>%
#   group_by(income_bracket) %>%
#   summarise(
#     households = sum(households),
#     nh_mean = weighted.mean(nh, households),
#     neb = 1 / (1 + nh_mean),  # Correct aggregation
#     .groups = "drop"
#   )
# 
# # Method 2: Using neb_func() with weights (simpler!)
# nc_by_income2 <- nc_data %>%
#   group_by(income_bracket) %>%
#   summarise(
#     neb = neb_func(mean_income, mean_energy_spending, weights = households),
#     households = sum(households),
#     .groups = "drop"
#   )
# 
# print(nc_by_income)

## ----high-burden, eval=FALSE--------------------------------------------------
# # 6% energy burden corresponds to Nh = 15.67
# high_burden_threshold <- 15.67
# 
# high_burden_households <- sum(nc_data$households[nc_data$nh < high_burden_threshold])
# total_households <- sum(nc_data$households)
# high_burden_pct <- (high_burden_households / total_households) * 100
# 
# print(paste("Households with >6% energy burden:",
#             scales::percent(high_burden_pct/100)))

## ----weighted-metrics, eval=FALSE---------------------------------------------
# results <- calculate_weighted_metrics(
#   graph_data = nc_ami,
#   group_columns = "income_bracket",
#   metric_name = "ner",
#   metric_cutoff_level = 15.67,  # 6% burden threshold
#   upper_quantile_view = 0.95,
#   lower_quantile_view = 0.05
# )
# 
# # Format for publication
# results$formatted_median <- to_percent(results$metric_median)
# print(results)

## ----temporal-comparison, eval=FALSE------------------------------------------
# # Compare by income bracket
# comparison <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "income_bracket"
# )
# 
# # View results
# print(comparison)
# 
# # The function automatically:
# # - Loads both 2018 and 2022 data
# # - Normalizes schema differences (4 vs 6 AMI brackets)
# # - Performs proper Nh-based aggregation
# # - Calculates changes in energy burden
# 
# # Grouping options:
# # - "income_bracket": Compare by AMI/FPL brackets (default)
# # - "state": Compare multiple states
# # - "none": Overall state-level comparison
# 
# # Example: State-level comparison
# state_comparison <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "none"
# )
# 
# # Access specific metrics
# state_comparison$neb_2018         # 2018 energy burden
# state_comparison$neb_2022         # 2022 energy burden
# state_comparison$neb_change_pp    # Change in percentage points
# state_comparison$neb_change_pct   # Relative change percentage

## ----housing-analysis, eval=FALSE---------------------------------------------
# # Load data with housing characteristics
# nc_housing <- load_cohort_data(dataset = "ami", states = "NC")
# 
# # Analyze energy burden by tenure and heating fuel
# housing_analysis <- nc_housing %>%
#   filter(!is.na(TEN), !is.na(`TEN-HFL`)) %>%
#   mutate(
#     mean_income = total_income / households,
#     mean_energy_spending = (total_electricity_spend +
#                            coalesce(total_gas_spend, 0) +
#                            coalesce(total_other_spend, 0)) / households,
#     nh = ner_func(mean_income, mean_energy_spending)
#   ) %>%
#   group_by(TEN, `TEN-HFL`) %>%
#   summarise(
#     total_households = sum(households),
#     nh_mean = weighted.mean(nh, households),
#     neb = 1 / (1 + nh_mean),
#     .groups = "drop"
#   ) %>%
#   arrange(desc(neb))
# 
# # View the top 10 tenure-heating fuel combinations with highest burden
# head(housing_analysis, 10)

## ----building-analysis, eval=FALSE--------------------------------------------
# # Analyze by building characteristics
# building_analysis <- nc_housing %>%
#   filter(!is.na(`TEN-YBL6`), !is.na(`TEN-BLD`)) %>%
#   mutate(
#     mean_income = total_income / households,
#     mean_energy_spending = (total_electricity_spend +
#                            coalesce(total_gas_spend, 0) +
#                            coalesce(total_other_spend, 0)) / households,
#     nh = ner_func(mean_income, mean_energy_spending)
#   ) %>%
#   group_by(`TEN-YBL6`, `TEN-BLD`) %>%
#   summarise(
#     total_households = sum(households),
#     nh_mean = weighted.mean(nh, households),
#     neb = 1 / (1 + nh_mean),
#     .groups = "drop"
#   )
# 
# # Identify building age/type combinations with highest burden
# high_burden_buildings <- building_analysis %>%
#   filter(neb > 0.06) %>%  # Above 6% burden threshold
#   arrange(desc(neb))
# 
# print(high_burden_buildings)

