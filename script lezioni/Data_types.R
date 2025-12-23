# -----------------------------
# Cross-Sectional Data
# -----------------------------
income <- c(45000, 52000, 48000, 50000, 47000)
mean(income)
summary(income)

# Basic plots
barplot(income, main="Income of 5 households",
        xlab="Household", ylab="Income", col="skyblue")
boxplot(income, main="Income Distribution", col="lightgreen")

# -----------------------------
# Time-Series Data
# -----------------------------
temp <- c(15.2, 16.5, 18.1, 20.3, 22.0)
time <- 1:5
plot(time, temp, type="o", main="Monthly Temperature",
     xlab="Month", ylab="Temperature")

# Adding trend line
lines(time, temp, type="b", col="red")

# -----------------------------
# Longitudinal (Panel) Data
# -----------------------------
income_panel <- matrix(c(45,47,50,52,
                         40,42,45,48,
                         55,56,58,60), nrow=4, byrow=TRUE)
colnames(income_panel) <- c("Person1","Person2","Person3")
rownames(income_panel) <- paste("Year",1:4)
income_panel

# Plot each person's income over time
matplot(income_panel, type="o", pch=1:3, col=1:3, 
        xlab="Year", ylab="Income", main="Panel Data")
legend("topleft", legend=colnames(income_panel), col=1:3, pch=1:3)

# -----------------------------
# Spatial Data
# -----------------------------
locations <- data.frame(
  lon = c(-73.95, -73.98, -74.01),
  lat = c(40.75, 40.76, 40.74),
  pollution = c(30, 45, 25)
)
plot(locations$lon, locations$lat, col=rainbow(3), pch=19, cex=2)
text(locations$lon, locations$lat, labels=locations$pollution, pos=3)

# -----------------------------
# Qualitative (Categorical) Variables
# -----------------------------
gender <- factor(c("Male","Female","Female","Male"))
table(gender)
barplot(table(gender), col=c("lightblue","pink"))

colors <- factor(c("red","blue","red","green"))
table(colors)
barplot(table(colors), col=rainbow(4))

# -----------------------------
# Quantitative Variables
# -----------------------------
# Discrete
children <- c(0,2,3,1,4)
mean(children)
table(children)
barplot(table(children), col="lightgreen")

# Continuous
height <- c(160.5,170.2,165.3,180.4)
summary(height)
hist(height, col="lightblue", main="Height Distribution", xlab="Height")
boxplot(height, col="lightgreen", main="Boxplot of Height")

weights <- c(60,65,70,75)
hist(weights, col="lightblue")
boxplot(weights, col="lightgreen")

# -----------------------------
# Practice Exercises
# -----------------------------
# 1. Cross-sectional vector
data <- c(10,15,20,25)
mean(data)
summary(data)

# 2. Time-series
ts_data <- ts(c(3,5,7,6,8), start=2020)
plot(ts_data, type="o")

# 3. Longitudinal matrix
long_data <- matrix(c(1,2,3,4,5,6), nrow=3)
matplot(long_data, type="o")

# 4. Qualitative factor
colors_ex <- factor(c("red","blue","red","green"))
table(colors_ex)
barplot(table(colors_ex), col=rainbow(4))

# 5. Continuous variable
weights_ex <- c(60,65,70,75)
hist(weights_ex, col="lightblue")
boxplot(weights_ex, col="lightgreen")
