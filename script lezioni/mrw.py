### load the required modules first

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

### now load the data and have a look at it

# Data from N. Gregory Mankiw, David Romer and David N. Weil,
# "A contribution to the empirics of economic growth,"
# Quarterly Journal of Economics, May 1992, pp. 407-437

mrw = pd.read_csv("mrw.csv")

print(mrw.info())
print(mrw.head())
print(mrw[ mrw.nonoil == 0 ]) # this is a bit weird

# this is necessary to have everything displayed
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)

desc = mrw.describe()
print(desc.T)

# for example, let's see the "school" variable

plt.hist(mrw['school'])
plt.show()

# let's see log(gdp) in 1960 and 1985

lgdp60 = np.log(mrw['gdp60'])
lgdp85 = np.log(mrw['gdp85'])
plt.subplot(1,2,1)
plt.boxplot(lgdp60.dropna())
plt.subplot(1,2,2)
plt.boxplot(lgdp85.dropna())

plt.show()

# let's see how single countries have done

plt.scatter(lgdp60, lgdp85)
plt.show()

# let's now compute growth; what does it depend on?
growth = lgdp85 - lgdp60
mrw['growth'] = growth

rank = mrw[['countryname', 'growth']].dropna().sort_values('growth', ascending=0)
print("top\n", rank.head(10), "\nbottom\n", rank.tail(10))

# is it oil?

grp = mrw.groupby('nonoil')
table = grp.growth.describe()
print(table)

mrw[['growth', 'nonoil']].boxplot(by='nonoil')
plt.show()

# is it education?

plt.scatter(mrw.school, growth)
plt.show()

# let's try the same with only countries with "fairly good data"

fgood = mrw[mrw.intermed == 1]
plt.scatter(fgood.school, fgood.growth)
plt.show()

# let's try the same with non-oil countries countries

no = mrw[mrw.nonoil == 1]
plt.scatter(no.school, no.growth)
plt.show()


