# ============================
# Data Visualization in R
# Examples for the lesson
# ============================

# Load ggplot2
library(ggplot2)

# --------------------------------
# Frequency Table
# --------------------------------
data <- read.csv("data.csv")
table(data$Gender)
prop.table(table(data$Gender))
round(prop.table(table(data$Gender))*100, 1)

# --------------------------------
# Bar Plot
# --------------------------------
ggplot(data, aes(x = Gender)) +
  geom_bar(fill = "skyblue") +
  labs(title = "Gender Distribution",
       x = "Gender",
       y = "Count")

table(data$Children)

ggplot(data, aes(x = factor(Children))) +
  geom_bar(fill = "orange") +
  labs(title = "Number of Children Distribution",
         x = "Children",
         y = "Count")

# --------------------------------
# Histogram
# --------------------------------

ggplot(data, aes(x = Height)) +
  geom_histogram(binwidth = 5, fill = "orange", color = "black") +
  labs(title = "Height Distribution",
       x = "Height (cm)",
       y = "Frequency")


ggplot(data, aes(x = Height)) +
  geom_histogram(aes(y = after_stat(count/sum(count))),
                 binwidth = 5,
                 fill = "lightgreen", color = "black") +
  labs(title = "Height Relative Frequency Histogram",
       x = "Height (cm)",
       y = "Density")

# --------------------------------
# Violin Plot
# --------------------------------

ggplot(data, aes(x = Group, y = Score, fill = Group)) +
  geom_violin(trim = FALSE, color = "black") +
  geom_boxplot(width = 0.1, fill = "white") +
  labs(title = "Score Distribution by Group",
       x = "Group",
       y = "Score")

# --------------------------------
# Scatterplot
# --------------------------------
ggplot(data, aes(x =VariableX, y=VariableY)) +
  geom_point(color = "darkgreen", size = 3) +
  labs(title = "Scatterplot Example",
         x = "Variable X",
         y = "Variable Y")

