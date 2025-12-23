# Load the iris dataset (included with R)
data(iris)

# Display the first rows
head(iris)

# Basic summary statistics
summary(iris)

# Calculate the mean of Sepal.Length
mean_sepal_length <- mean(iris$Sepal.Length)
cat("Mean Sepal.Length:", mean_sepal_length, "\n")

# Histogram of Sepal.Length
hist(iris$Sepal.Length, main = "Histogram of Sepal.Length", col = "lightblue", xlab = "Sepal.Length")

# Scatter plot of Sepal.Length vs Sepal.Width
plot(iris$Sepal.Length, iris$Sepal.Width,
     main = "Scatter plot Sepal Length vs Sepal Width",
     xlab = "Sepal Length",
     ylab = "Sepal Width",
     pch = 19,
     col = as.numeric(iris$Species))

legend("topright", legend = levels(iris$Species), 
       col = 1:length(levels(iris$Species)), pch = 19)

# Use dplyr to calculate mean Petal.Length by species
library(dplyr)

result <- iris %>%
  group_by(Species) %>%
  summarise(mean_petal_length = mean(Petal.Length))

print(result)

# Visualization with ggplot2
library(ggplot2)

ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
  geom_point() +
  ggtitle("Scatter plot Sepal Length vs Sepal Width (ggplot2)") +
  theme_minimal()
