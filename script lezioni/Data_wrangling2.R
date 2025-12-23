library(dplyr)
library(tidyr)

# Load data
data1 <- read.csv("scores.csv", stringsAsFactors = FALSE)
data2 <- read.csv("salaries.csv", stringsAsFactors = FALSE)

# Check missing values
print(colSums(is.na(data1)))

# Remove rows where 'age' or 'score' is missing (critical info)
data1_clean <-  filter(data1, !is.na(age), !is.na(score))

# Impute missing Q1, Q2, Q3 with average per question
data1_clean <- mutate(data1_clean,
    Q1 = ifelse(is.na(Q1), round(mean(Q1, na.rm = TRUE),1), Q1),
    Q2 = ifelse(is.na(Q2), round(mean(Q2, na.rm = TRUE),1), Q2),
    Q3 = ifelse(is.na(Q3), round(mean(Q3, na.rm = TRUE),1), Q3)
  )

# Reshape data1: from wide (Q1, Q2, Q3) to long format
data1_long <-  pivot_longer(data1_clean, cols = starts_with("Q"),
               names_to = "question",
               values_to = "response")

# Summarize average response per person
data1_summary <- aggregate(response ~ id + name + age + country,
                           data = data1_long,
                           FUN = mean)
# Merge cleaned data1_summary with data2 by 'id'
merged_data <- left_join(data1_summary, data2, by = "id")

# View merged data
print(merged_data)
