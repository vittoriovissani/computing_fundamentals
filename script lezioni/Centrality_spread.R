# =========================================
# Centrality and Spread Analysis in R
# =========================================

# Load necessary libraries
library(ggplot2)

# Load data
data <- read.csv("data.csv")

# ---------------------------
# Functions
# ---------------------------

# Function to compute mode
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

# ---------------------------
# 1. Measures of Centrality
# ---------------------------

# Mean
mean_height <- mean(data$Height)
mean_score  <- mean(data$Score)

# Median
median_height <- median(data$Height)
median_score  <- median(data$Score)

# Mode
mode_gender <- getmode(data$Gender)

# ---------------------------
# 2. Measures of Spread
# ---------------------------

# Range
range_height <- range(data$Height)
range_score  <- range(data$Score)

# Interquartile Range (IQR)
iqr_height <- IQR(data$Height)
iqr_score  <- IQR(data$Score)

# Variance
var_height <- var(data$Height)
var_score  <- var(data$Score)

# Standard Deviation
sd_height <- sd(data$Height)
sd_score  <- sd(data$Score)

# ---------------------------
# 3. Visualizations
# ---------------------------

# Boxplot Height
ggplot(data, aes(y = Height)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Boxplot of Height")

# Histogram Height with Mean & Median
ggplot(data, aes(x = Height)) +
  geom_histogram(binwidth = 5, fill = "lightgreen", color = "black") +
  geom_vline(aes(xintercept = mean(Height)), color = "red", linetype="dashed") +
  geom_vline(aes(xintercept = median(Height)), color = "blue", linetype="dotted") +
  labs(title = "Histogram of Height with Mean (red) and Median (blue)")

# Boxplot & Violin by Gender
ggplot(data, aes(x = Gender, y = Height, fill = Gender)) +
  geom_violin(trim = FALSE) +
  geom_boxplot(width = 0.1, fill = "white") +
  labs(title = "Height Distribution by Gender")

