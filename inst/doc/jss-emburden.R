## ----eval=FALSE---------------------------------------------------------------
# calculate_weighted_metrics(
#   data,
#   group_columns = c("state", "income_bracket"),
#   metric_name = "ner"
# )

## ----eval=FALSE---------------------------------------------------------------
# library(emburden)
# 
# # Energy metric calculations
# energy_burden_func(gross_income, energy_spending)
# ner_func(gross_income, energy_spending)  # Net Energy Return
# eroi_func(gross_income, energy_spending)  # EROI
# dear_func(gross_income, energy_spending)  # DEAR
# 
# # Statistical aggregation
# calculate_weighted_metrics(
#   graph_data,
#   group_columns = "state",
#   metric_name = "ner"
# )

## ----eval=FALSE---------------------------------------------------------------
# # Load census tract data (auto-downloads if not available)
# nc_tracts <- load_census_tract_data(states = "NC")
# 
# # Load cohort data by income bracket
# nc_ami <- load_cohort_data(
#   dataset = "ami",
#   states = "NC",
#   vintage = "2022"
# )
# 
# # Compare vintages
# comparison <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "state"
# )

## ----basic-comparison, eval=FALSE---------------------------------------------
# library(emburden)
# 
# # Compare North Carolina energy burden: 2018 vs 2022
# nc_comparison <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "income_bracket"
# )
# 
# # View formatted comparison table
# print(nc_comparison)

## ----comparison-metrics, eval=FALSE-------------------------------------------
# # Energy burden in 2018 and 2022
# nc_comparison$neb_2018
# nc_comparison$neb_2022
# 
# # Change in energy burden (percentage points)
# nc_comparison$neb_change_pp
# 
# # Net Energy Return values
# nc_comparison$ner_2018
# nc_comparison$ner_2022
# 
# # Household counts
# nc_comparison$households_2018
# nc_comparison$households_2022

## ----state-level, eval=FALSE--------------------------------------------------
# # Overall state comparison
# nc_state <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "none"
# )
# 
# # Extract key findings
# cat(sprintf(
#   "North Carolina energy burden changed from %.1f%% (2018) to %.1f%% (2022)\n",
#   nc_state$neb_2018 * 100,
#   nc_state$neb_2022 * 100
# ))
# 
# cat(sprintf(
#   "Change: %+.2f percentage points\n",
#   nc_state$neb_change_pp * 100
# ))

## ----income-bracket, eval=FALSE-----------------------------------------------
# # Compare by income bracket
# nc_income <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "income_bracket"
# )
# 
# # Visualize changes
# library(ggplot2)
# 
# ggplot(nc_income, aes(x = income_bracket, y = neb_change_pp * 100)) +
#   geom_col(fill = "steelblue") +
#   geom_hline(yintercept = 0, linetype = "dashed") +
#   labs(
#     title = "Change in Energy Burden by Income Bracket",
#     subtitle = "North Carolina, 2018 to 2022",
#     x = "Income Bracket (% of Area Median Income)",
#     y = "Change in Energy Burden (percentage points)"
#   ) +
#   theme_minimal()

## ----multi-state, eval=FALSE--------------------------------------------------
# # Compare Southern states
# southern_states <- compare_energy_burden(
#   dataset = "ami",
#   states = c("NC", "SC", "GA", "FL"),
#   group_by = "state"
# )
# 
# # Which states improved most?
# southern_states %>%
#   arrange(neb_change_pp) %>%
#   select(state_abbr, neb_2018, neb_2022, neb_change_pp)
# 
# # Visualize state comparison
# ggplot(southern_states, aes(x = reorder(state_abbr, neb_2022),
#                              y = neb_2022 * 100)) +
#   geom_col(fill = "darkgreen") +
#   geom_point(aes(y = neb_2018 * 100), color = "red", size = 3) +
#   labs(
#     title = "Energy Burden by State: 2022 (bars) vs 2018 (points)",
#     x = "State",
#     y = "Energy Burden (%)"
#   ) +
#   theme_minimal()

## ----housing-tenure, eval=FALSE-----------------------------------------------
# # Compare by housing tenure
# nc_tenure <- compare_energy_burden(
#   dataset = "ami",
#   states = "NC",
#   group_by = "housing_tenure"
# )
# 
# # Calculate the renter-owner gap
# gap_2018 <- nc_tenure$neb_2018[nc_tenure$housing_tenure == "RENTER"] -
#             nc_tenure$neb_2018[nc_tenure$housing_tenure == "OWNER"]
# 
# gap_2022 <- nc_tenure$neb_2022[nc_tenure$housing_tenure == "RENTER"] -
#             nc_tenure$neb_2022[nc_tenure$housing_tenure == "OWNER"]
# 
# cat(sprintf(
#   "Renter-Owner energy burden gap: %.2f pp (2018) → %.2f pp (2022)\n",
#   gap_2018 * 100,
#   gap_2022 * 100
# ))

## ----fpl-analysis, eval=FALSE-------------------------------------------------
# # Use FPL dataset instead of AMI
# nc_fpl <- compare_energy_burden(
#   dataset = "fpl",
#   states = "NC",
#   group_by = "income_bracket"
# )
# 
# # Compare poverty vs non-poverty households
# nc_fpl %>%
#   filter(income_bracket %in% c("Below Federal Poverty Line",
#                                 "Above Federal Poverty Line")) %>%
#   select(income_bracket, neb_2018, neb_2022, neb_change_pp)

## ----tract-level, eval=FALSE--------------------------------------------------
# # Load 2022 census tract data
# nc_tracts_2022 <- load_census_tract_data(
#   states = "NC",
#   vintage = "2022"
# )
# 
# # Calculate county-level statistics
# nc_counties <- calculate_weighted_metrics(
#   nc_tracts_2022,
#   group_columns = "county_name",
#   metric_name = "ner"
# )
# 
# # Identify counties with highest energy burden
# nc_counties %>%
#   mutate(energy_burden = 1 / (ner + 1)) %>%
#   arrange(desc(energy_burden)) %>%
#   head(10) %>%
#   select(county_name, energy_burden, household_count)

## ----split-incentive-example, eval=FALSE--------------------------------------
# # Quantify the renter-owner gap
# tenure_comparison <- compare_energy_burden(
#   dataset = "ami",
#   states = "all",  # National analysis
#   group_by = "housing_tenure"
# )
# 
# # Calculate disparity
# renter_burden <- tenure_comparison$neb_2022[
#   tenure_comparison$housing_tenure == "RENTER"
# ]
# owner_burden <- tenure_comparison$neb_2022[
#   tenure_comparison$housing_tenure == "OWNER"
# ]
# 
# disparity_ratio <- renter_burden / owner_burden

