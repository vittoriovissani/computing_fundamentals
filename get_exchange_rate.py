import os
from forex_python.converter import CurrencyRates
import pandas as pd
import numpy as np
os.chdir("~/Documents/Computing fundamentals/workspace esame/ocds_csvs")
c = CurrencyRates()
currency_miscellaneous = pd.read_csv("needed_rates.csv")

def get_rate_for_row(date, currency, base='EUR'):
    try:
        dt = pd.to_datetime(date).to_pydatetime()
        return c.get_rate(currency, base, dt)
    except Exception:
        return np.nan
    
for i in range(len(needed_rates)):
    row = currency_miscellaneous.iloc[i]
    rate = get_rate_for_row(row['month'], row['currency'])
    