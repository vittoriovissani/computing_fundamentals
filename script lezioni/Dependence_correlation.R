# -------------------------------------------------
# Dependence Analysis in R
# -------------------------------------------------

# Load libraries
library(ggplot2)
library(dplyr)

data <- read.csv("data.csv")

# -------------------------------
# Mean Dependence: Score by Gender
# -------------------------------

aggregate(Score ~ Gender, data, mean)

# Boxplot with mean points
ggplot(data, aes(x = Gender, y = Score)) +
  geom_boxplot(fill = "lightblue") +
  stat_summary(fun = mean, geom = "point", color = "red", size = 3) +
  labs(title = "Score by Gender with Mean Points")

# -------------------------------
# Linear Dependence: Height vs Score
# -------------------------------

# Scatterplot
ggplot(data, aes(x = Height, y = Score)) +
  geom_point(color = "blue") +
  labs(title = "Scatterplot of Height vs Score")


# Fit linear model
lm_model <- lm(Score ~ Height, data = data)
summary(lm_model)

# -------------------------------
# Correlation
# -------------------------------
correlation = cor(data$Height, data$Score)
correlation
