library(dplyr)
library(tidyr)


# Dataset 1: Sales data
sales <- data.frame(
  ID = 1:6 ,
  Product = c("A", "B", "A", "C", "B", "C"),
  Sales_Q1 = c(100 , 150 , NA , 200 , 130 , 210) ,
  Sales_Q2 = c(110 , 160 , 120 , NA , 140 , 220)
)

# Dataset 2: Product info
products <- data.frame(
  Product = c("A", "B", "C"),
  Category = c(" Electronics ", " Clothing ", " Electronics "),
  Price = c (99.99 , 49.99 , 79.99)
)


# Check missing values in sales
sum(is.na(sales))
# Remove rows with any NA
sales_clean <- na.omit(sales)



# Select Product and Sales_Q1 columns
sales_q1 <- select(sales_clean, Product, Sales_Q1)

# Filter rows where Sales_Q1 > 120
high_sales <- filter(sales_clean, Sales_Q1 > 120)


# Calculate total Sales Q1 + Q2
sales_clean <- mutate(sales_clean, Total_Sales = Sales_Q1 +
                          Sales_Q2)

# Convert sales from wide to long format
sales_long <- pivot_longer(sales_clean,
                             cols = starts_with("Sales_Q"),
                             names_to = "Quarter",
                             values_to = "Sales")


# Back to wide format
sales_wide <- pivot_wider(sales_long, names_from = Quarter,
                            values_from = Sales)

# Join sales and products by Product column
sales_info <- left_join(sales_clean, products, by = "Product")

