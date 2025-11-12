import os
from forex_python.converter import CurrencyRates
import pandas as pd
import numpy as np
os.chdir("/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/ocds_csvs")
c = CurrencyRates()
currency_miscellaneous = pd.read_csv("rates_needed.csv")

pd.read_csv("rates_needed.csv")

def get_exchange_rate(df, month, currency):
    date_obj = pd.to_datetime(month)
    df['rate'] = c.get_rate(currency, 'EUR', date_obj)
    return df

for row in currency_miscellaneous.itertuples():
    get_exchange_rate(currency_miscellaneous, row.tender_value_currency, row.month)
