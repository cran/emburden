## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library(emburden)
library(dplyr)

## ----simple-example-----------------------------------------------------------
# Three households with different income/spending patterns
households <- data.frame(
  id = 1:3,
  income = c(30000, 50000, 100000),
  spending = c(3000, 3500, 4000)
)

households$eb <- energy_burden_func(households$income, households$spending)
print(households)

## ----wrong-aggregation--------------------------------------------------------
# Attempt 1: Simple arithmetic mean (WRONG!)
mean_eb_wrong <- mean(households$eb)
print(paste("Simple mean EB:", scales::percent(mean_eb_wrong)))

## ----weighted-wrong-----------------------------------------------------------
# Attempt 2: Weighted arithmetic mean (STILL WRONG!)
# Let's weight by number of households (all equal here, but principle matters)
weights <- c(100, 150, 200)  # Different household counts

eb_arithmetic_mean <- weighted.mean(households$eb, weights)
print(paste("Weighted arithmetic mean EB:", scales::percent(eb_arithmetic_mean)))

## ----harmonic-mean------------------------------------------------------------
# Correct aggregation: Weighted harmonic mean
eb_harmonic <- 1 / weighted.mean(1 / households$eb, weights)
print(paste("Weighted harmonic mean EB:", scales::percent(eb_harmonic)))

# Verify by calculating from totals
total_spending <- sum(households$spending * weights)
total_income <- sum(households$income * weights)
eb_from_totals <- total_spending / total_income
print(paste("EB from totals:", scales::percent(eb_from_totals)))

# These should be identical
print(paste("Difference:", abs(eb_harmonic - eb_from_totals)))

## ----nh-identity--------------------------------------------------------------
# Starting from Nh = (G - S) / S
# Let's solve for EB = S / G

# Nh = (G - S) / S
# Nh = G/S - S/S
# Nh = G/S - 1
# Nh + 1 = G/S
# 1 / (Nh + 1) = S/G = EB

# Therefore: EB = 1 / (Nh + 1)

# Verify with our example
households$nh <- ner_func(households$income, households$spending)
households$eb_from_nh <- 1 / (households$nh + 1)

# Compare to original EB
households$identical <- all.equal(households$eb, households$eb_from_nh)
print(households[, c("id", "eb", "eb_from_nh", "nh")])

## ----nh-aggregation-----------------------------------------------------------
# Step 1: Calculate Nh for each household
nh_values <- ner_func(households$income, households$spending)

# Step 2: Arithmetic weighted mean (simple!)
nh_mean <- weighted.mean(nh_values, weights)
print(paste("Weighted mean Nh:", round(nh_mean, 2)))

# Step 3: Convert back to EB
eb_from_nh <- 1 / (nh_mean + 1)
print(paste("EB from Nh method:", scales::percent(eb_from_nh)))

# Compare to harmonic mean result
print(paste("EB from harmonic mean:", scales::percent(eb_harmonic)))
print(paste("Difference:", abs(eb_from_nh - eb_harmonic)))

## ----computational-comparison-------------------------------------------------
# Simulate larger dataset
set.seed(42)
n <- 10000
large_data <- data.frame(
  income = rlnorm(n, meanlog = 10.8, sdlog = 0.8),  # Log-normal income distribution
  spending = NA
)
large_data$spending <- pmin(
  rlnorm(n, meanlog = 8.2, sdlog = 0.5),  # Log-normal spending
  large_data$income * 0.5  # Cap at 50% of income
)
weights <- sample(50:500, n, replace = TRUE)

# Method 1: Nh with arithmetic mean
system.time({
  nh <- ner_func(large_data$income, large_data$spending)
  nh_mean <- weighted.mean(nh, weights)
  eb_nh <- 1 / (1 + nh_mean)
})

# Method 2: Harmonic mean
system.time({
  eb_direct <- energy_burden_func(large_data$income, large_data$spending)
  eb_harmonic <- 1 / weighted.mean(1 / eb_direct, weights)
})

# Verify results are identical
print(paste("EB via Nh:", scales::percent(eb_nh)))
print(paste("EB via harmonic mean:", scales::percent(eb_harmonic)))
print(paste("Difference:", abs(eb_nh - eb_harmonic)))

## ----numerical-stability------------------------------------------------------
# Households with very low energy burden
low_burden <- data.frame(
  income = c(200000, 500000, 1000000),
  spending = c(2000, 3000, 5000)  # Very low spending relative to income
)

low_burden$eb <- energy_burden_func(low_burden$income, low_burden$spending)
low_burden$nh <- ner_func(low_burden$income, low_burden$spending)

print("Energy Burden (direct):")
print(low_burden$eb)

print("\nReciprocal of EB (used in harmonic mean):")
print(1 / low_burden$eb)  # Very large numbers!

print("\nNet Energy Return (Nh):")
print(low_burden$nh)  # More reasonable range

## ----error-demonstration------------------------------------------------------
# Use realistic North Carolina-like data
set.seed(123)
n_households <- 5000

realistic_data <- data.frame(
  income_bracket = sample(
    c("0-30% AMI", "30-50% AMI", "50-80% AMI", "80-100% AMI", "100%+ AMI"),
    n_households,
    replace = TRUE,
    prob = c(0.15, 0.12, 0.20, 0.10, 0.43)
  ),
  income = rlnorm(n_households, meanlog = 10.8, sdlog = 0.8),
  households = sample(10:100, n_households, replace = TRUE)
)

realistic_data$spending <- realistic_data$income * rlnorm(
  n_households,
  meanlog = log(0.05),
  sdlog = 0.6
)

# Calculate metrics
realistic_data <- realistic_data %>%
  mutate(
    eb = energy_burden_func(income, spending),
    nh = ner_func(income, spending),
    neb = neb_func(income, spending)
  )

# WRONG: Arithmetic mean of EB
eb_wrong <- weighted.mean(realistic_data$eb, realistic_data$households)

# CORRECT: Via Nh
nh_mean <- weighted.mean(realistic_data$nh, realistic_data$households)
eb_correct <- 1 / (1 + nh_mean)

# Calculate error
absolute_error <- eb_wrong - eb_correct
relative_error_pct <- (absolute_error / eb_correct) * 100

cat(sprintf("WRONG (arithmetic mean EB): %.2f%%\n", eb_wrong * 100))
cat(sprintf("CORRECT (via Nh method):   %.2f%%\n", eb_correct * 100))
cat(sprintf("Absolute error:             %.4f\n", absolute_error))
cat(sprintf("Relative error:             %.2f%%\n", relative_error_pct))

## ----practical-workflow-------------------------------------------------------
# Step 1: Calculate Nh for all observations
data_with_metrics <- realistic_data %>%
  mutate(
    nh = ner_func(income, spending),
    neb = neb_func(income, spending)  # Same as eb, but emphasizes proper aggregation
  )

# Step 2: Aggregate by groups using arithmetic weighted mean
by_bracket <- data_with_metrics %>%
  group_by(income_bracket) %>%
  summarise(
    total_households = sum(households),
    nh_mean = weighted.mean(nh, households),
    neb = 1 / (1 + nh_mean),  # Correct aggregation
    .groups = "drop"
  ) %>%
  arrange(desc(neb))

print(by_bracket)

# Step 3: Identify high-burden households
high_burden_threshold <- 0.06  # 6% energy burden threshold
nh_threshold <- (1 / high_burden_threshold) - 1  # = 15.67

high_burden_count <- sum(
  data_with_metrics$households[data_with_metrics$nh < nh_threshold]
)
total_households <- sum(data_with_metrics$households)

cat(sprintf("\nHouseholds with >6%% energy burden: %.1f%%\n",
            (high_burden_count / total_households) * 100))

