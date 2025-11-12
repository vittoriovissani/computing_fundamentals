import os
from forex_python.converter import CurrencyRates
import pandas as pd
import numpy as np
os.chdir("/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/ocds_csvs")
c = CurrencyRates()
print(c.get_rate('USD', 'NGN'))  # Restituisce il tasso USD→NGN
currency_miscellaneous = pd.read_csv("rates_needed.csv")

date_obj = (2014, 5, 23, 18, 36, 28, 151012)
print(c.get_rate('USD', 'INR', date_obj))
print(c.get_rate('NGN', 'EUR', 2021, 1, 1))
pd.read_csv("rates_needed.csv")

def get_exchange_rate(df, currency, month):
    date_obj = pd.to_datetime(month)
    df['rate'] = c.get_rate(currency, 'EUR', date_obj)
    return df

for row in currency_miscellaneous.itertuples():
    get_exchange_rate(currency_miscellaneous, row.tender_value_currency, row.month)
